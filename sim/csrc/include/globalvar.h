#include "common.h"

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;
  char* string;
  uint64_t value;
} WP;
extern WP *head , *free_ ;

WP* new_wp();
void free_wp(WP *wp);

typedef struct func_name {
  char* name;
  uint64_t addr;
  uint64_t size;
} FN;
extern FN func[32];

extern uint64_t* cpu_gpr;
extern uint8_t cpu_state;
extern int is_batch_mode;

void cpu_exec(uint n);
void isa_reg_display();
word_t isa_reg_str2val(const char *s, bool *success);
uint8_t* get_mem_addr(paddr_t addr);

uint64_t paddr_read(uint64_t addr,int lens);
void paddr_write(uint64_t addr, int len, word_t data);

uint32_t expr(char *e, bool *success);
uint64_t get_time();