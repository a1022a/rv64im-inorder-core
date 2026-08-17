#include "dependency_observer.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

namespace {
enum class ProducerClass { kLoad, kMultiply, kOther };
enum class Source { kRs1, kRs2, kBoth, kFalse };
enum class LoadOutcome { kNotLoad, kPending, kHit, kMiss };

struct Episode {
  uint64_t first_cycle;
  uint64_t cycles;
  uint64_t consumer_pc;
  uint32_t consumer_inst;
  uint64_t producer_pc;
  uint32_t producer_inst;
  uint8_t producer_rd;
  uint64_t producer_address;
  ProducerClass producer_class;
  Source source;
  LoadOutcome load_outcome;
};

const char* output_path;
const char* workload;
bool enabled;
bool roi_requested;
bool roi_active;
bool roi_started;
bool roi_ended;
uint64_t roi_start_pc;
uint64_t roi_end_pc;
uint64_t roi_cycles;
bool previous_exclusive_dependency;
std::vector<Episode> episodes;

bool parse_u64_env(const char* name, uint64_t* value) {
  const char* text = std::getenv(name);
  if (!text || !*text) return false;
  char* end = nullptr;
  *value = std::strtoull(text, &end, 0);
  return end && end != text && *end == '\0';
}

bool is_load(uint32_t inst) { return (inst & 0x7fU) == 0x03U; }

bool is_multiply(uint32_t inst) {
  const uint32_t opcode = inst & 0x7fU;
  const uint32_t funct3 = (inst >> 12) & 7U;
  const uint32_t funct7 = inst >> 25;
  return (opcode == 0x33U || opcode == 0x3bU) && funct7 == 1U && funct3 <= 3U;
}

void operand_use(uint32_t inst, bool* use_rs1, bool* use_rs2) {
  const uint32_t opcode = inst & 0x7fU;
  const uint32_t funct3 = (inst >> 12) & 7U;
  *use_rs1 = false;
  *use_rs2 = false;
  switch (opcode) {
    case 0x33U:
    case 0x3bU:
    case 0x23U:
    case 0x63U:
      *use_rs1 = true;
      *use_rs2 = true;
      break;
    case 0x03U:
    case 0x13U:
    case 0x1bU:
    case 0x67U:
      *use_rs1 = true;
      break;
    case 0x73U:
      *use_rs1 = funct3 == 1U || funct3 == 2U || funct3 == 3U;
      break;
    default:
      break;
  }
}

Source classify_source(uint32_t inst, uint8_t rd) {
  bool use_rs1, use_rs2;
  operand_use(inst, &use_rs1, &use_rs2);
  const uint8_t rs1 = (inst >> 15) & 31U;
  const uint8_t rs2 = (inst >> 20) & 31U;
  const bool rs1_match = rd != 0 && use_rs1 && rs1 == rd;
  const bool rs2_match = rd != 0 && use_rs2 && rs2 == rd;
  if (rs1_match && rs2_match) return Source::kBoth;
  if (rs1_match) return Source::kRs1;
  if (rs2_match) return Source::kRs2;
  return Source::kFalse;
}

const char* producer_name(ProducerClass value) {
  if (value == ProducerClass::kLoad) return "LOAD";
  if (value == ProducerClass::kMultiply) return "MUL";
  return "OTHER";
}

const char* source_name(Source value) {
  if (value == Source::kRs1) return "RS1";
  if (value == Source::kRs2) return "RS2";
  if (value == Source::kBoth) return "BOTH";
  return "FALSE";
}

const char* outcome_name(LoadOutcome value) {
  if (value == LoadOutcome::kPending) return "PENDING";
  if (value == LoadOutcome::kHit) return "HIT";
  if (value == LoadOutcome::kMiss) return "MISS";
  return "NOT_LOAD";
}

void reset_profile() {
  roi_cycles = 0;
  previous_exclusive_dependency = false;
  episodes.clear();
}
}

void dependency_observer_init(const char* path, const char* name) {
  output_path = path;
  workload = name && *name ? name : "unspecified";
  enabled = output_path && *output_path;
  roi_requested = false;
  roi_active = enabled;
  roi_started = enabled;
  roi_ended = false;
  reset_profile();
}

void dependency_observer_init_from_env() {
  dependency_observer_init(std::getenv("DEPENDENCY_PROFILE_OUT"),
                           std::getenv("PERF_WORKLOAD"));
  if (!enabled) return;
  const bool has_start = parse_u64_env("PERF_ROI_START_PC", &roi_start_pc);
  const bool has_end = parse_u64_env("PERF_ROI_END_PC", &roi_end_pc);
  roi_requested = has_start || has_end;
  if (has_start != has_end || (has_start && roi_start_pc == roi_end_pc)) {
    std::fprintf(stderr, "dependency observer: invalid ROI marker environment\n");
    enabled = false;
    return;
  }
  roi_active = !roi_requested;
  roi_started = !roi_requested;
}

void dependency_observer_update_roi(bool wb_sign, uint64_t wb_pc) {
  if (!enabled || !roi_requested || !wb_sign) return;
  if (!roi_started && wb_pc == roi_start_pc) dependency_observer_begin_roi();
  else if (roi_active && wb_pc == roi_end_pc) dependency_observer_end_roi();
}

void dependency_observer_begin_roi() {
  if (!enabled) return;
  reset_profile();
  roi_started = true;
  roi_active = true;
  roi_ended = false;
}

void dependency_observer_end_roi() {
  if (!enabled) return;
  roi_active = false;
  roi_ended = true;
  previous_exclusive_dependency = false;
}

void dependency_observer_cycle() {
  if (enabled && roi_active) ++roi_cycles;
}

void dependency_observer_sample(const DependencyObserverSample& sample) {
  if (!enabled) return;
  const bool exclusive = roi_active && sample.dependency_stall &&
      !sample.dcache_total_stall && !sample.divider_stall && !sample.branch_recovery;
  if (exclusive && !previous_exclusive_dependency) {
    ProducerClass producer_class = ProducerClass::kOther;
    if (is_load(sample.producer_inst)) producer_class = ProducerClass::kLoad;
    else if (is_multiply(sample.producer_inst)) producer_class = ProducerClass::kMultiply;
    const Source source = classify_source(sample.consumer_inst, sample.producer_rd);
    episodes.push_back({roi_cycles, 0, sample.consumer_pc, sample.consumer_inst,
                        sample.producer_pc, sample.producer_inst, sample.producer_rd,
                        sample.producer_address, producer_class, source,
                        producer_class == ProducerClass::kLoad && source != Source::kFalse
                            ? LoadOutcome::kPending : LoadOutcome::kNotLoad});
  }
  if (exclusive) ++episodes.back().cycles;
  previous_exclusive_dependency = exclusive;
  if (sample.dcache_load_access) {
    for (Episode& episode : episodes) {
      if (episode.load_outcome == LoadOutcome::kPending &&
          (static_cast<uint32_t>(episode.producer_address) & ~UINT32_C(7)) ==
              sample.dcache_address) {
        episode.load_outcome = sample.dcache_hit ? LoadOutcome::kHit : LoadOutcome::kMiss;
        break;
      }
    }
  }
}

int dependency_observer_finalize(int exit_status) {
  if (!enabled) return 0;
  uint64_t dependency_cycles = 0, load_cycles = 0, load_episodes = 0;
  uint64_t hit_cycles = 0, hit_episodes = 0, miss_cycles = 0, miss_episodes = 0;
  uint64_t mul_cycles = 0, other_cycles = 0, unresolved = 0;
  for (const Episode& episode : episodes) {
    dependency_cycles += episode.cycles;
    const bool true_dependency = episode.source != Source::kFalse;
    if (episode.producer_class == ProducerClass::kLoad && true_dependency) {
      load_cycles += episode.cycles;
      ++load_episodes;
      if (episode.load_outcome == LoadOutcome::kHit) {
        hit_cycles += episode.cycles;
        ++hit_episodes;
      } else if (episode.load_outcome == LoadOutcome::kMiss) {
        miss_cycles += episode.cycles;
        ++miss_episodes;
      } else {
        ++unresolved;
      }
    } else if (episode.producer_class == ProducerClass::kMultiply && true_dependency) {
      mul_cycles += episode.cycles;
    } else {
      other_cycles += episode.cycles;
    }
  }
  FILE* file = std::fopen(output_path, "w");
  if (!file) return 1;
  std::fprintf(file, "{\n  \"schema_version\": \"a2-loaduse-phase8r-v1\",\n");
  std::fprintf(file, "  \"workload\": \"%s\",\n", workload);
  std::fprintf(file, "  \"roi_valid\": %s,\n", (!roi_requested || (roi_started && roi_ended)) ? "true" : "false");
  std::fprintf(file, "  \"roi_cycles\": %llu,\n", (unsigned long long)roi_cycles);
  std::fprintf(file, "  \"exclusive_dependency_cycles\": %llu,\n", (unsigned long long)dependency_cycles);
  std::fprintf(file, "  \"dependency_episodes\": %llu,\n", (unsigned long long)episodes.size());
  std::fprintf(file, "  \"load_use_stall_cycles\": %llu,\n  \"load_use_episodes\": %llu,\n",
               (unsigned long long)load_cycles, (unsigned long long)load_episodes);
  std::fprintf(file, "  \"load_hit_use_stall_cycles\": %llu,\n  \"load_hit_use_episodes\": %llu,\n",
               (unsigned long long)hit_cycles, (unsigned long long)hit_episodes);
  std::fprintf(file, "  \"load_miss_related_dependency_cycles\": %llu,\n  \"load_miss_related_dependency_episodes\": %llu,\n",
               (unsigned long long)miss_cycles, (unsigned long long)miss_episodes);
  std::fprintf(file, "  \"alu_raw_stall_cycles\": 0,\n  \"csr_dependency_stall_cycles\": 0,\n");
  std::fprintf(file, "  \"mul_dependency_stall_cycles\": %llu,\n  \"div_dependency_stall_cycles\": 0,\n",
               (unsigned long long)mul_cycles);
  std::fprintf(file, "  \"other_dependency_stall_cycles\": %llu,\n", (unsigned long long)other_cycles);
  std::fprintf(file, "  \"unresolved_load_outcomes\": %llu,\n", (unsigned long long)unresolved);
  std::fprintf(file, "  \"exit_status\": %d,\n  \"episodes\": [\n", exit_status);
  for (size_t index = 0; index < episodes.size(); ++index) {
    const Episode& episode = episodes[index];
    std::fprintf(file, "    {\"first_cycle\": %llu, \"cycles\": %llu, \"consumer_pc\": \"0x%016llx\", \"consumer_inst\": \"0x%08x\", \"producer_pc\": \"0x%016llx\", \"producer_inst\": \"0x%08x\", \"producer_rd\": %u, \"producer_class\": \"%s\", \"source\": \"%s\", \"producer_address\": \"0x%016llx\", \"load_outcome\": \"%s\"}%s\n",
                 (unsigned long long)episode.first_cycle,
                 (unsigned long long)episode.cycles,
                 (unsigned long long)episode.consumer_pc, episode.consumer_inst,
                 (unsigned long long)episode.producer_pc, episode.producer_inst,
                 episode.producer_rd, producer_name(episode.producer_class),
                 source_name(episode.source),
                 (unsigned long long)episode.producer_address,
                 outcome_name(episode.load_outcome), index + 1 == episodes.size() ? "" : ",");
  }
  std::fprintf(file, "  ]\n}\n");
  std::fclose(file);
  const bool valid = !roi_requested || (roi_started && roi_ended);
  return valid && unresolved == 0 ? 0 : 1;
}
