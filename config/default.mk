VSRC_DIR ?= ./rtl/vsrc
CSRC_DIR ?= ./sim/csrc
INCLUDE_PATH ?= $(VSRC_DIR)
SIM_FILELIST ?= ./rtl/filelists/sim.f
SYNTH_FILELIST ?= ./rtl/filelists/synth.f
LINT_FILELIST ?= ./rtl/filelists/lint.f

BUILD_DIR ?= build
OUT_DIR ?= out
LOG_DIR ?= $(OUT_DIR)/logs

NEMU_REF_SO ?=
AM_KERNELS_DIR ?=
DEFAULT_TEST ?= dummy
DEFAULT_DUMMY_IMG ?=
SMOKE_MANIFEST ?= ./tests/manifests/smoke.txt
REGRESS_TIMEOUT_SEC ?= 120
MICROBENCH_TIMEOUT_SEC ?= 600
