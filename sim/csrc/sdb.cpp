#include "globalvar.h"
#include "common.h"
#include <stdlib.h>
#include <string.h>
#include <elf.h>
#include <readline/readline.h>
#include <readline/history.h>

#include <iostream>
using namespace std; 

int is_batch_mode = false;

void init_regex();
void init_wp_pool();
void set_cpu_state(int n);

static char* rl_gets() {
  static char *line_read = NULL;

  if (line_read) {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(nemu) ");

  if (line_read && *line_read) {
    add_history(line_read);
  }

  return line_read;
}

static int cmd_c(char *args) {
  cpu_exec(-1);
  return 0;
}

//q
static int cmd_q(char *args) {
  set_cpu_state(NPC_QUIT);
  cpu_exec(1);
  return 0;
}
//si
static int cmd_si(char *args) {
	if(args == NULL){
		cpu_exec(1);
	}else{
		char* arg=strtok(NULL," ");
		int i = atoi(arg);
		cpu_exec(i);
	}
  return 0;
}
//info
static int cmd_info(char *args) {
	char* arg1=strtok(NULL," ");
	if(*arg1 == 'r'){
		isa_reg_display();
	}else if(*arg1 == 'w'){
		WP* ptr = head;
		if(ptr == NULL){printf("No watchpoint to print\n");}
		while(ptr!=NULL){
			printf("Watchpoint %d expression is %s, value is %lu\n",ptr->NO,ptr->string,ptr->value);
			ptr=ptr->next;
		}
		ptr = NULL;
	}else{
		printf("Error cmd");
	}
	return 0;
}
//x
static int cmd_x(char *args) {
	char* arg1=strtok(NULL," ");
	char* arg2=strtok(NULL," ");
	if(arg1 == NULL || arg2 == NULL){
		printf("Error cmd");
	}else{
		int a = atoi(arg1);
		uint64_t addr = strtol(arg2, NULL, 0);
		for(;a>0;a--){
			uint64_t value = paddr_read(addr, 4);
			printf("0x%08lx value is: 0x%08lx\n",addr,value);
			addr = addr + 4;
		}
	}
	return 0;
}
//p
static int cmd_p(char *args) {
	char* arg1=strtok(NULL,"\0");
	if(arg1 == NULL){
		printf("Error cmd");
	}else{
		bool boo[1]={1};
		word_t a = expr(arg1,boo);
		if(boo[0] == false){
				printf("Regex failed");
			}else
				printf("Expression: %s = %ld\n",arg1,a);
		}
	return 0;
}
//w
static int cmd_w(char *args){
	char* arg1=strtok(NULL,"\0");
	if(arg1 == NULL){
		printf("Error cmd");
	}else{
		WP* newwp=new_wp();
		newwp->string=strdup(arg1);
		bool boo[1]={1};
		newwp->value =expr(newwp->string,boo);
		printf("Watchpoint %d has created,expression is %s\n",newwp->NO,newwp->string);
		newwp = NULL;
	}
	return 0;
}
//d
static int cmd_d(char *args){
	char* arg1=strtok(NULL,"\0");
	int a = atoi(arg1);
	WP* ptr = head;
	while(ptr!=NULL){
		if(ptr->NO == a){
			free_wp(ptr);
			break;
		}else{
			ptr = ptr->next;
		}
	}
	return 0;
}

static int cmd_help(char *args);

static struct {
  const char *name;
  const char *description;
  int (*handler) (char *);
} cmd_table [] = {
  { "help","Display informations about all supported commands", cmd_help },
  { "c","   Continue the execution of the program", cmd_c },
  { "q","   Exit NEMU", cmd_q },

  /* TODO: Add more commands */
  { "si","  si [N]: Execute N step", cmd_si},  
  { "info","info r: Print regs status", cmd_info},  
  { "x","   x [N] [ADDR]: Print N word in the begin of memory[ADDR] ", cmd_x},  
  { "p","   p EXPR: Calculate the expresion", cmd_p},  
  { "w","   w EXPR: Set watchpoint", cmd_w},  
  { "d","   p EXPR: Delete watchpoint N", cmd_d},  
};

#define NR_CMD sizeof(cmd_table)/sizeof(cmd_table[0]) //support cmd nuimber

//help
static int cmd_help(char *args) {
  /* extract the first argument */
  char *arg = strtok(NULL, " ");
  int i;

  if (arg == NULL) {
    /* no argument given */
    for (i = 0; i < NR_CMD; i ++) {
      printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
    }
  }
  else {
    for (i = 0; i < NR_CMD; i ++) {
      if (strcmp(arg, cmd_table[i].name) == 0) {
        printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
        return 0;
      }
    }
    printf("Unknown command '%s'\n", arg);
  }
  return 0;
}

void sdb_set_batch_mode() {
  is_batch_mode = true;
}
//*************************************//
void sdb_mainloop() {
  if (is_batch_mode) {
    cmd_c(NULL);
    return;
  }

  for (char *str; (str = rl_gets()) != NULL; ) {
    char *str_end = str + strlen(str);

    /* extract the first token as the command */
    char *cmd = strtok(str, " ");
    if (cmd == NULL) { continue; }

    /* treat the remaining string as the arguments,
     * which may need further parsing
     */
    char *args = cmd + strlen(cmd) + 1;
    if (args >= str_end) {
      args = NULL;
	}

    int i;
    for (i = 0; i < NR_CMD; i ++) {
      if (strcmp(cmd, cmd_table[i].name) == 0) {
        if (cmd_table[i].handler(args) < 0) { return; }
        break;
      }
    }

    if (i == NR_CMD) { printf("Unknown command '%s'\n", cmd);}
//****//
	if(cpu_state == NPC_QUIT) {return;}
  }
}
//*********************************************************//

void init_sdb() {
  /* Compile the regular expressions. */
  init_regex();

  /* Initialize the watchpoint pool. */
  init_wp_pool();
}

FN func[32] = {};
void read_elf(char* argv){
  //open flie
	FILE *fp;
	fp = fopen(argv, "r");
	if (NULL == fp){
		printf("fail to open the file");
		exit(0);
	}

//read elf_head
	Elf64_Ehdr elf_head;
  int a;
	a=fread(&elf_head, sizeof(Elf64_Ehdr), 1, fp);   //fread参数1：读取内容存储地址，参数2：读取内容大小，参数3：读取次数，参数4：文件读取引擎
	if (elf_head.e_ident[0] != 0x7F || elf_head.e_ident[1] != 'E' || elf_head.e_ident[2] != 'L' ||	elf_head.e_ident[3] != 'F'){
		printf("Not a ELF file\n");
		exit(0);
	}

//read section data
	Elf64_Shdr *shdr = (Elf64_Shdr*)malloc(sizeof(Elf64_Shdr) * elf_head.e_shnum);
	fseek(fp, elf_head.e_shoff, SEEK_SET); //fseek调整指针的位置，采用参考位置+偏移量
	a=fread(shdr, sizeof(Elf64_Shdr) * elf_head.e_shnum, 1, fp);

//read shstrndx data: record all of section info
	rewind(fp);//reset file point
	char shstrtab[shdr[elf_head.e_shstrndx].sh_size];
	fseek(fp, shdr[elf_head.e_shstrndx].sh_offset, SEEK_SET); // 第e_shstrndx项定义了字符串表 字节 长度 char类型 数组
	a=fread(shstrtab, shdr[elf_head.e_shstrndx].sh_size, 1, fp);
	char *temp = shstrtab;

//read data of .strtab
	char* pstr = {0};
	int j=0;
	for (int i = 0; i < elf_head.e_shnum; i++){
		temp = shstrtab;
		temp = temp + shdr[i].sh_name;
        if (strcmp(temp, ".strtab") == 0){
			char* str_data=(char*)malloc(sizeof(char)*shdr[i].sh_size);
			//char str_data[sizeof(char)*shdr[i].sh_size];
			fseek(fp, shdr[i].sh_offset, SEEK_SET);
			a=fread(str_data, sizeof(char)*shdr[i].sh_size, 1, fp);
			pstr = str_data;
			j=i-1;
			break;
		}
	}

//read data of .symtab
	Elf64_Sym* sym;
	temp = shstrtab;
	temp = temp + shdr[j].sh_name;
    if (strcmp(temp, ".symtab") == 0){
		char *sym_data=(char*)malloc(sizeof(char)*shdr[j].sh_size);
		fseek(fp, shdr[j].sh_offset, SEEK_SET);
		a=fread(sym_data, sizeof(char)*shdr[j].sh_size, 1, fp);if(a==0) printf("read_elf fail");
		sym=(Elf64_Sym*)sym_data;
		size_t m = 0;
		const size_t func_capacity = sizeof(func) / sizeof(func[0]);
		bool function_symbols_truncated = false;
		for(int x = 0; x<(shdr[j].sh_size/sizeof(Elf64_Sym)); x++){
			if ((sym[x].st_info & 0x0f) == 0x02 && m < func_capacity) {
        		func[m].addr = sym[x].st_value;
       			func[m].size = sym[x].st_size;
			func[m].name = pstr+sym[x].st_name;
				m++;
				//log_write("Func: %s\t addr is %08lx, size is %lu, \n",pstr+sym[x].st_name,sym[x].st_value,sym[x].st_size);
			} else if ((sym[x].st_info & 0x0f) == 0x02) {
				function_symbols_truncated = true;
			}
		}
		if (function_symbols_truncated) printf("ftrace: function symbol table truncated at %zu entries\n", func_capacity);
		free(sym_data);
	} else printf("no .symtab");
	free(shdr);
	printf("\n");
}
