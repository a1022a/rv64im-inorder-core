#include <getopt.h>
#include "common.h"
#include "axi4_mem.hpp"

static uint8_t pmem[CONFIG_MSIZE]={};
uint8_t* get_mem_addr(paddr_t addr){
  return pmem+addr-CONFIG_PC_RET;
}

char *img_file = NULL;
static char *log_file = NULL;
static char *diff_so_file = NULL;
static int  difftest_port = 1234;

extern "C" void init_disasm(const char *triple);
void sdb_set_batch_mode();
void read_elf(char* argv);
void init_difftest(char *ref_so_file, void *img_file,long img_size, int port);
//void init_difftest(paddr_t img_addr, void* dut,long img_size);

static int parse_args(int argc, char *argv[]) {
  const struct option table[] = {
    {"batch"    , no_argument      , NULL, 'b'},
    {"log"      , required_argument, NULL, 'l'},
    {"diff"     , required_argument, NULL, 'd'},
    {"port"     , required_argument, NULL, 'p'},
    {"help"     , no_argument      , NULL, 'h'},
    {"ftrace"   , required_argument, NULL, 'f'},
    {0          , 0                , NULL,  0 },
  };
  int o;
  while ( (o = getopt_long(argc, argv, "-bhl:d:p:f:", table, NULL)) != -1) {
    switch (o) {
      case 'b': sdb_set_batch_mode(); break;
      //case 'p': sscanf(optarg, "%d", &difftest_port); break;
      case 'l': log_file = optarg; break;
      case 'd': diff_so_file = optarg; break;
      case 'f': read_elf(optarg); break;
      case 1: img_file = optarg; return 0;
      default:
        printf("Usage: %s [OPTION...] IMAGE [args]\n\n", argv[0]);
        printf("\t-b,--batch              run with batch mode\n");
        printf("\t-l,--log=FILE           output log to FILE\n");
        printf("\t-d,--diff=REF_SO        run DiffTest with reference REF_SO\n");
        printf("\t-p,--port=PORT          run DiffTest with port PORT\n");
        printf("\n");
        exit(0);
    }
  }
  return 0;
}

FILE *log_fp = NULL;
void init_log(const char *log_file) {
  log_fp = stdout;
  if (log_file != NULL) {
    FILE *fp = fopen(log_file, "w");
    //Assert(fp, "Can not open '%s'", log_file);
    log_fp = fp;
  }
  Log("Log is written to %s\n", log_file ? log_file : "stdout");
}

static long load_img() {
  if (img_file == NULL) {
    printf("No image is given. Use the default build-in image.");
    return 4096; // built-in image size
  }

  FILE *fp = fopen(img_file, "rb");
  fseek(fp, 0, SEEK_END);

  long size = ftell(fp);
  printf("The image is %s, size = %ld\n", img_file, size);

  fseek(fp, 0, SEEK_SET);
  //int ret = fread(pmem+CONFIG_MSIZE, size, 1, fp);
  int ret = fread(pmem, size, 1, fp);
  assert(ret == 1);

  fclose(fp);
  return size;
}

void init_args(int argc, char *argv[]){
    parse_args(argc,argv);
    long img_size = load_img();
    if(CONFIG_DIFFTEST){init_difftest(diff_so_file, (void*) pmem, img_size, difftest_port);}
}

void init_sdb();

void init_monitor(int argc, char *argv[]){
  init_args(argc, argv);
  init_log(log_file);
  init_sdb();
  init_disasm("riscv64-pc-linux-gnu");
}

static bool addr_in_mem(uint64_t addr){
  if(addr < (CONFIG_PC_RET+CONFIG_MSIZE) && addr >= CONFIG_PC_RET) {
    return true;
  }else{
    return false;
  }
}

uint64_t paddr_read(uint64_t addr,int lens){
  if(addr_in_mem(addr)){
	  switch (lens) {
    case 1: return *(uint8_t  *)get_mem_addr(addr);
    case 2: return *(uint16_t *)get_mem_addr(addr);
    case 4: return *(uint32_t *)get_mem_addr(addr);
    case 8: return *(uint64_t *)get_mem_addr(addr);
    default: assert(0);
   }
  }else{
    printf("addr 0x%016lx over mem boundry\n",addr);
    return 0;
    }
}

void paddr_write(uint64_t addr, int len, word_t data) {
  if(addr_in_mem(addr)){
    switch (len) {
    case 1: *(uint8_t  *)get_mem_addr(addr) = data; return;
    case 2: *(uint16_t *)get_mem_addr(addr) = data; return;
    case 4: *(uint32_t *)get_mem_addr(addr) = data; return;
    case 8: *(uint64_t *)get_mem_addr(addr) = data; return;
    default: assert(0);
    }
  }else{
    printf("addr 0x%016lx over mem boundry\n",addr); 
    return;
  }
}
