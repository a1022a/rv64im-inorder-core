//must lib
#include "Vtop.h"			 //设计头文件 (./obj_dir)
#include "Vtop__Dpi.h"
#include "svdpi.h"
#include "verilated.h"		 //verilator头文件
#include "verilated_vcd_c.h" //生成波形头文件
//c lib
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "globalvar.h"
#include "difftest.h"
#ifdef PERFORMANCE_MODEL
#include "dependency_observer.h"
#endif

#ifdef ICACHE_64SET_MONITOR
#include "Vtop_rv64im_core_dcache__C2000.h"
#endif

vluint64_t main_time = 0;           // 仿真时间戳
const vluint64_t sim_time = 100;   // 最大仿真时间戳

VerilatedVcdC* tfp;
Vtop* top;

#ifdef LOADUSE_P1_MONITOR
static uint64_t loaduse_p1_hit_bypass_events;
static uint64_t loaduse_p1_miss_hazard_events;
static uint64_t loaduse_p1_operand_bypass_events;

static void loaduse_p1_monitor_sample() {
  loaduse_p1_hit_bypass_events += top->loaduse_p1_hit_bypass_event;
  loaduse_p1_miss_hazard_events += top->loaduse_p1_miss_hazard_event;
  loaduse_p1_operand_bypass_events += top->loaduse_p1_operand_bypass_event;
}

int loaduse_p1_monitor_finalize() {
  printf("LOADUSE_P1_HIT_BYPASS_EVENTS=%lu\n", loaduse_p1_hit_bypass_events);
  printf("LOADUSE_P1_MISS_HAZARD_EVENTS=%lu\n", loaduse_p1_miss_hazard_events);
  printf("LOADUSE_P1_OPERAND_BYPASS_EVENTS=%lu\n", loaduse_p1_operand_bypass_events);
  return loaduse_p1_hit_bypass_events > 0 &&
         loaduse_p1_miss_hazard_events > 0 &&
         loaduse_p1_operand_bypass_events == loaduse_p1_hit_bypass_events ? 0 : 1;
}
#endif

#ifdef ICACHE_64SET_MONITOR
void set_cpu_state(int n);

static const uint32_t icache_64set_lines[] = {
  0x80000400, 0x80000800, 0x80000c00, 0x80001000, 0x80001400,
};
static bool icache_64set_executed[5] = {};

static void icache_64set_monitor_sample() {
  if (!top->wb_sign) return;
  const uint32_t line_addr = top->wb_pc & ~0x1fU;
  for (unsigned int line = 0; line < 5; ++line) {
    if (line_addr == icache_64set_lines[line]) icache_64set_executed[line] = true;
  }
}

int icache_64set_monitor_finalize() {
  Vtop_rv64im_core_dcache__C2000* icache =
    top->__PVT__rv64im_core_sim_top__DOT__u_rv64im_core_top__DOT__u_rv64im_core_icache;
  unsigned int executed_count = 0;
  unsigned int resident_count = 0;
  for (unsigned int line = 0; line < 5; ++line) {
    const uint32_t line_addr = icache_64set_lines[line];
    const unsigned int index6 = (line_addr >> 5) & 0x3fU;
    const unsigned int index5 = (line_addr >> 5) & 0x1fU;
    const uint32_t tag = line_addr >> 11;
    int resident_way = -1;
    const uint32_t tags[] = {
      icache->__PVT__tag_arry0[index6], icache->__PVT__tag_arry1[index6],
      icache->__PVT__tag_arry2[index6], icache->__PVT__tag_arry3[index6],
    };
    const uint8_t valid[] = {
      icache->__PVT__sign_arry0[index6], icache->__PVT__sign_arry1[index6],
      icache->__PVT__sign_arry2[index6], icache->__PVT__sign_arry3[index6],
    };
    for (unsigned int way = 0; way < 4; ++way) {
      if ((valid[way] & 1U) && tags[way] == tag) resident_way = way;
    }
    executed_count += icache_64set_executed[line];
    resident_count += resident_way >= 0;
    printf("ICACHE64SET line addr=0x%08x executed=%u index6=%u index5=%u tag=0x%x resident_way=%d\n",
           line_addr, icache_64set_executed[line], index6, index5, tag, resident_way);
  }
  if (executed_count != 5 || resident_count != 5) {
    printf("ICACHE64SET monitor failure: executed=%u/5 resident=%u/5\n",
           executed_count, resident_count);
    return 1;
  }
  printf("ICACHE64SET_MONITOR: PASS target_lines=5 dynamic_way_residency=3+2 old_set32_distribution=5\n");
  return 0;
}
#endif

uint8_t cpu_state = NPC_RUNNING;
void set_cpu_state(int n){
	cpu_state = n;
}

u_int64_t get_inst(u_int64_t addr);
//static uint64_t pc_now = CONFIG_PC_RET;
static uint64_t pc_next = 0;
static uint32_t inst_now = 0;
void init_monitor(int argc, char** argv);


static int difftest_error=0;
void difftest_check(){
  if(ref_difftest_checkregs()==0) {set_cpu_state(NPC_ABORT);isa_reg_display();difftest_error=1;}
}


extern "C" void mem_read(int raddr, unsigned char ren,svBitVecVal* rdata){
  if(ren){
    if(raddr == 0xa0000048 | raddr == 0xa0000040) {uint64_t us = get_time();memmove(rdata,&us,8);return ;}  //rtc地址printf("load rtc %ld\n",us);
    uint32_t addr = (uint32_t)raddr;
    uint64_t r_data = paddr_read(addr,8);
    memmove(rdata,&r_data,8);
    if(CONFIG_MTRACE) Log("load memory: 0x%x, data: 0x%016lx\n",raddr, r_data);
  }
}

extern "C" void mem_write(int waddr, long long wdata, char wmask, unsigned char wen){
  if(wen & top->clk == 1){
    if(CONFIG_MTRACE) Log("store memory: 0x%016x, mask: 0x%02x, data: 0x%016llx\n",waddr,wmask,wdata);
    if(waddr == 0xa00003f8) {printf("%c",(char) wdata); fflush(stdout);return ;}  //串口地址
    uint32_t addr = (uint32_t)waddr;
    for(int i=0;i<8;i++){
      uint8_t* wda = (uint8_t*) &wdata;
      if((wmask & 1<<i) == 1<<i){paddr_write(addr+i,1,*(wda+i));}
    }
  }
}

static svLogic is_ebreak = 0;
extern "C" void set_ebreak(svLogic ebreak) {
  is_ebreak = ebreak;
}

uint64_t wb_pc_now = CONFIG_PC_RET;

uint64_t* cpu_gpr = NULL;
extern "C" void set_gpr_ptr(const svOpenArrayHandle h) {
	if(svGetArrayPtr(h) == NULL) {printf("fail get ptr\n");}
	else {cpu_gpr = (uint64_t *) svGetArrayPtr(h);}
}

void single_cycle() {
	top->clk = 0; top->eval();
#ifdef PERFORMANCE_MODEL
  dependency_observer_cycle();
#endif
	#ifdef LOADUSE_P1_MONITOR
	  loaduse_p1_monitor_sample();
	#endif
	#ifdef ICACHE_64SET_MONITOR
	  icache_64set_monitor_sample();
	#endif
	  if(CONFIG_WAVE){tfp->dump(main_time);}   //波形文件写入步进
    main_time++;

	top->clk = 1; top->eval();
#ifdef PERFORMANCE_MODEL
  dependency_observer_sample({
      static_cast<bool>(top->perf_dependency_stall),
      static_cast<bool>(top->perf_dcache_total_stall),
      static_cast<bool>(top->perf_divider_stall),
      static_cast<bool>(top->perf_branch_recovery),
      static_cast<bool>(top->perf_dcache_load_access_event),
      static_cast<bool>(top->perf_dcache_hit_event),
      static_cast<bool>(top->perf_dcache_miss_event),
      top->perf_dcache_access_address,
      top->perf_dependency_consumer_pc,
      top->perf_dependency_consumer_inst,
      top->perf_dependency_producer_pc,
      top->perf_dependency_producer_inst,
      top->perf_dependency_producer_rd,
      top->perf_dependency_producer_address,
  });
#endif
	#ifdef ICACHE_64SET_MONITOR
	  icache_64set_monitor_sample();
	#endif
	  if(CONFIG_WAVE){tfp->dump(main_time);}   //波形文件写入步进
    main_time++;
}

void reset(int n) {
	top->rstn = 0;
	while (n -- > 0) single_cycle();
	top->rstn = 1;
}


void init_sim(int argc, char** argv){
	//初始化
  Verilated::commandArgs(argc, argv); 
  Verilated::traceEverOn(true);
	//为对象分配空间
	if(CONFIG_WAVE){tfp = new VerilatedVcdC;}
  top = new Vtop;	
#ifdef PERFORMANCE_MODEL
  dependency_observer_init_from_env();
#endif
  if(CONFIG_WAVE){
    top->trace(tfp, 99);   
    tfp->open("wave.vcd"); //打开vcd  
  }
	reset(5);
	init_monitor(argc, argv);
  printf("initial ok!!!\n");
}

void end_sim(){
#ifndef PERFORMANCE_MODEL
	delete top;
#endif
	if(CONFIG_WAVE){delete tfp;}
}

extern "C" void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);
void itrace (uint64_t pc,uint32_t cpu_inst){
  char logbuf[128] = {0};
  char *p = logbuf;
  p += snprintf(p, sizeof(logbuf), "0x%016lx" ":", pc);

  uint8_t *inst = (uint8_t *)&cpu_inst;
  for (int i = 0; i < 4; i ++) {
    p += snprintf(p, 4, " %02x", inst[i]);
  }
  memset(p, ' ', 1);
  p ++;

  disassemble(p, logbuf + sizeof(logbuf) - p, pc, (uint8_t *)&cpu_inst, 4);
  if(is_batch_mode){log_write("%s\n",logbuf);}
  else {Log("%s\n",logbuf);} 
}

static void ftrace(uint32_t inst_now, uint64_t pc_now, uint64_t pc_next){
  if((inst_now & 0x7f) == 0x6f || (inst_now & 0x7f) == 0x63){//jal，bxx
    int j = 0;
    for(int i=0; i<32; i++){
      j++;
      if(pc_next >= func[i].addr && pc_next  < func[i].addr+func[i].size){
        log_write("0X%08lx\t call [%s\t@%08lx]\n", pc_now, func[i].name, pc_next);
        break;
      }
    } 
    if(j==32) log_write("no func to call\n");
  }else if ((inst_now & 0x7f) == 0x67){//jalr
    int j = 0;
    for(int i=0; i<32; i++){
      j++;
      if(pc_now >= func[i].addr && pc_now < func[i].addr+func[i].size){
        log_write("0X%08lx\t ret  [%s\t]\n", pc_now, func[i].name);
        break;
      }
    } 
    if(j==32) log_write("no func to ret\n");
  }
}

static int wb_num = 0;
void exec_once(){
#ifdef PERFORMANCE_MODEL
  dependency_observer_update_roi(top->wb_sign, top->wb_pc);
#endif
  if(top->wb_sign){
    wb_pc_now   = top->wb_pc;
    if (CONFIG_DIFFTEST && wb_num != 0) {
      /*
       * The DUT has completed the final pre-interrupt instruction.
       * Advance NEMU once, then inject the asynchronous interrupt.
       */
      difftest_step();
      if (top->wb_intr) {
        ref_difftest_raise_intr(top->intr_num);
      }

      difftest_check();

      if (top->wb_device) {
        difftest_skip_ref();
      }
    }
    wb_num ++;
    uint32_t wb_inst = top->wb_inst;
    if(CONFIG_ITRACE) {itrace(wb_pc_now, wb_inst);}
  }
}

void cpu_exec(uint n){
  switch (cpu_state) {
    case NPC_ABORT: Log("Program execution has ABORT at 0X%016lx\n",wb_pc_now);return;
    case NPC_QUIT: return;
    case NPC_END: 
      printf("Program execution has ended. To restart the program, exit NEMU and run again.\n");
      return;
    default: cpu_state = NPC_RUNNING;
  }

  for(int i=0;i<n;i++){
    if(difftest_error) {break;}
	  exec_once();
    if(is_ebreak == 1) {set_cpu_state(NPC_END);break;}
    single_cycle();
  }

  switch (cpu_state){
    case NPC_ABORT:  Log("npc: ABORT at pc = 0x%016lx\n",wb_pc_now); break;
    case NPC_END  :  Log("npc: %s at pc = 0x%016lx\n", (cpu_gpr[10] == 0 ? "HIT GOOD TRAP":"HIT BAD TRAP"),wb_pc_now); break;
    default: cpu_state = NPC_RUNNING;
  }
}


const char *regs[] = {
  "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6","pc",
};

void isa_reg_display(){
  int i;
  for (i = 0; i < 33; i++) {
    printf("reg[%d\t]: %s\t= 0x%lx\n", i, regs[i], cpu_gpr[i]);
  }
  printf("\n");
}

word_t isa_reg_str2val(const char *s, bool *success) {
	if(strcmp(s,"pc") == 0){
		*success = true;
		return wb_pc_now;
	}else if(strcmp(s,"0") == 0){
		*success = true;
		return cpu_gpr[0];
	}
	for(int i=1;i<31;i++){
		if(strcmp(s, regs[i]) == 0){
			*success = true;
			return cpu_gpr[i];
		}	
	}
  return 0;
}

int is_exit_status_bad() {
  int good = (cpu_state == NPC_END && cpu_gpr[10] == 0) ||
    (cpu_state == NPC_QUIT);
  return !good;
}
