#include <dlfcn.h>
//#include "common.h"
#include "globalvar.h"
#include "difftest.h"

void (*ref_difftest_memcpy)(paddr_t addr, void *buf, size_t n, bool direction) = NULL;
void (*ref_difftest_regcpy)(void *dut, bool direction) = NULL;
void (*ref_difftest_exec)(uint64_t n) = NULL;
//void (*ref_difftest_init)()=NULL;
void (*ref_difftest_raise_intr)(uint64_t NO) = NULL; 


//static int skip_dut_nr_inst = 0;
enum { DIFFTEST_TO_DUT, DIFFTEST_TO_REF };
//void difftest_memcpy(paddr_t addr, void *buf, size_t n, bool direction);
//void difftest_regcpy(void *dut, bool direction);
//void init_difftest(paddr_t img_addr, void* dut_mem, long img_size){
void init_difftest(char *ref_so_file, void *img_file,long img_size, int port){
  assert(ref_so_file != NULL);
  printf("Difftesd file is %s\n",ref_so_file);
  
  void *handle;
  //handle = dlopen(ref_so_file, RTLD_LAZY | MUXNDEF(CONFIG_CC_ASAN, RTLD_DEEPBIND, 0));
  handle = dlopen(ref_so_file, RTLD_LAZY | 0);
  if (handle==NULL)
  {
    printf("dlopen error. msg:%s", dlerror());
  }
  assert(handle);

  ref_difftest_memcpy = (void (*)(paddr_t addr, void *buf, size_t n, bool direction))dlsym(handle, "difftest_memcpy");
  assert(ref_difftest_memcpy);

  ref_difftest_regcpy = (void (*)(void *dut, bool direction))dlsym(handle, "difftest_regcpy");
  assert(ref_difftest_regcpy);

  ref_difftest_exec = (void (*)(uint64_t n))dlsym(handle, "difftest_exec");
  assert(ref_difftest_exec);

  ref_difftest_raise_intr = (void (*)(uint64_t NO))dlsym(handle, "difftest_raise_intr");
  assert(ref_difftest_raise_intr);
/*
  ref_difftest_init = (void (*)())dlsym(handle, "difftest_init");
  assert(ref_difftest_init);
*/
  //Log("Differential testing: %s", ASNI_FMT("ON", ASNI_FG_GREEN));
  //Log("The result of every instruction will be compared with %s. "
    //  "This will help you a lot for debugging, but also significantly reduce the performance. "
      //"If it is not necessary, you can turn it off in menuconfig.", ref_so_file);

  //ref_difftest_init();
  ref_difftest_memcpy(CONFIG_PC_RET, img_file, img_size, DIFFTEST_TO_REF);
  ref_difftest_regcpy(cpu_gpr, DIFFTEST_TO_REF);
}

static bool is_skip_ref = false;
void difftest_skip_ref() {
  is_skip_ref = true;
  //skip_dut_nr_inst = 0;
  //printf("skip difftest:%d\n",is_skip_ref);
}

void difftest_step() {
  if (is_skip_ref) {
    // to skip the checking of an instruction, just copy the reg state to reference design
    ref_difftest_regcpy(cpu_gpr, DIFFTEST_TO_REF);
    is_skip_ref=false;
  }else{
    ref_difftest_exec(1);
  }
}

bool ref_difftest_checkregs(){
  uint64_t ref_reg[33]={};
  ref_difftest_regcpy((void*)ref_reg,DIFFTEST_TO_DUT);
  for(int i=0;i<33;i++){
    if(ref_reg[i] != cpu_gpr[i]){
        printf("ref_reg[%d] = 0x%lx; cpu_gpr[%d] = 0x%lx; Difftest regs error\n",i,ref_reg[i],i,cpu_gpr[i]);
        return false;
    }
  }
    return true;
}