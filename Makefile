include config/default.mk
-include config/local.mk

REPO_ROOT := $(CURDIR)
TOPNAME ?= rv64im_core_sim_top
TOP_CLASS_NAME ?= Vtop
OBJ_DIR ?= $(BUILD_DIR)
VSRCS ?= $(shell find $(VSRC_DIR) -name "*.*v" | sort)
CSRCS ?= $(shell find $(CSRC_DIR) -name "*.c" -o -name "*.cc" -o -name "*.cpp" | sort)

IMG ?=
TEST ?= $(DEFAULT_TEST)
ARGS ?=
ELF ?= $(if $(IMG),$(patsubst %.bin,%.elf,$(IMG)),)
RUN_ARGS := $(ARGS)
RUN_ARGS += -d $(NEMU_REF_SO)
RUN_ARGS += -b
RUN_ARGS += $(if $(ELF),-f $(ELF),)

CFLAGS ?= -I$(REPO_ROOT)/$(CSRC_DIR)/include -ggdb -O2
CFLAGS += $(shell llvm-config --cxxflags)
CFLAGS += -fPIE

LDFLAGS ?= -lLLVM-12 -lreadline -ldl -pie -fsanitize=address -lSDL2

.PHONY: all doctor build comp run run-img smoke regress gdb clean check-config release

all: build

check-config:
	@test -n "$(NEMU_REF_SO)" || { echo "NEMU_REF_SO is not configured"; exit 1; }
	@test -f "$(NEMU_REF_SO)" || { echo "NEMU_REF_SO not found: $(NEMU_REF_SO)"; exit 1; }

doctor:
	@mkdir -p "$(LOG_DIR)/doctor"
	@{ \
		echo "repo=$(REPO_ROOT)"; \
		command -v verilator; \
		command -v llvm-config; \
		command -v sha256sum; \
		test -f "$(SIM_FILELIST)"; \
		test -f "$(SYNTH_FILELIST)"; \
		test -f "$(LINT_FILELIST)"; \
		test -n "$(NEMU_REF_SO)"; \
		test -f "$(NEMU_REF_SO)"; \
		test -n "$(DEFAULT_DUMMY_IMG)"; \
		test -f "$(DEFAULT_DUMMY_IMG)"; \
	} 2>&1 | tee "$(LOG_DIR)/doctor/doctor.log"

build: comp

comp: check-config
	@if [ -d "$(OBJ_DIR)" ]; then rm -r "./$(OBJ_DIR)"; fi
	verilator --cc --trace --exe --build $(CSRCS) -f $(SIM_FILELIST) \
		-I$(INCLUDE_PATH) -top $(TOPNAME) --prefix $(TOP_CLASS_NAME) --Mdir $(OBJ_DIR) \
		$(addprefix -CFLAGS , $(CFLAGS)) $(addprefix -LDFLAGS , $(LDFLAGS))

run-img: comp
	@test -n "$(IMG)" || { echo "IMG is required for run-img"; exit 1; }
	./$(OBJ_DIR)/$(TOP_CLASS_NAME) $(RUN_ARGS) $(IMG)

run:
	@mkdir -p "$(LOG_DIR)/run"
	@scripts/run_smoke.sh "$(TEST)"

smoke:
	@mkdir -p "$(LOG_DIR)/smoke"
	@scripts/run_smoke.sh --manifest "$(SMOKE_MANIFEST)" 2>&1 | tee "$(LOG_DIR)/smoke/smoke.log"

regress:
	@mkdir -p "$(LOG_DIR)/regress"
	@bash -o pipefail -c 'scripts/run_regress.sh 2>&1 | tee "$(LOG_DIR)/regress/regress.log"'

release:
	@mkdir -p "$(LOG_DIR)/release"
	@bash -o pipefail -c 'scripts/make_release.sh 2>&1 | tee "$(LOG_DIR)/release/release.log"'

gdb: comp
	gdb --args ./$(OBJ_DIR)/$(TOP_CLASS_NAME) $(RUN_ARGS) $(IMG)

clean:
	@if [ -d "$(OBJ_DIR)" ]; then rm -r "./$(OBJ_DIR)"; fi
	@find . -maxdepth 1 -type f -name "*.vcd" -delete
	@if [ -d "$(OUT_DIR)/logs/run" ]; then rm -r "$(OUT_DIR)/logs/run"; fi
	@if [ -d "$(OUT_DIR)/logs/smoke" ]; then rm -r "$(OUT_DIR)/logs/smoke"; fi
	@if [ -d "$(OUT_DIR)/logs/regress" ]; then rm -r "$(OUT_DIR)/logs/regress"; fi
	@if [ -d "$(OUT_DIR)/logs/doctor" ]; then rm -r "$(OUT_DIR)/logs/doctor"; fi
