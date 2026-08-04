#include "common.h"
#include "globalvar.h"

/* We use the POSIX regex functions to process regular expressions.
 * Type 'man regex' for more information about POSIX regex functions.
 */
#include <regex.h>

enum {
  TK_NOTYPE=255 , TK_EQ,

  /* TODO: Add more token types */
  TK_NUM,TK_NEQ,TK_AND,TK_H,TK_REG,
  DEREF,NEGATIVE,
};

static struct rule {
  const char *regex;
  int token_type;
} rules[] = {

  /* TODO: Add more rules.
   * Pay attention to the precedence level of different rules.
   */
  {"0[xX][A-Za-z0-9]{1,8}",TK_H},        
  {"\\$[a-z0-9]{1,2}",  TK_REG},        

  {" +", TK_NOTYPE},    // spaces
  {"\\+", '+'},         // plus
  {"==", TK_EQ},        // equal
  {"!=", TK_NEQ},
  {"&&", TK_AND},

  {"[0-9]+", TK_NUM},   //number
  {"-",  '-'},        
  {"\\*", '*'},        
  {"/",  '/'},

  {"\\(",  '('},        
  {")",  ')'},

};// () -> */ -> +- -> ==!= -> &&|| ->

#define NR_REGEX sizeof(rules)/sizeof(rules[0])

static regex_t re[NR_REGEX] = {};
/* Rules are used for many times.
 * Therefore we compile them only once before any usage.
 */
void init_regex() {
  int i;
  char error_msg[128];
  int ret;

  for (i = 0; i < NR_REGEX; i ++) {
    ret = regcomp(&re[i], rules[i].regex, REG_EXTENDED);
    if (ret != 0) {
      regerror(ret, &re[i], error_msg, 128);
      printf("regex compilation failed: %s\n%s", error_msg, rules[i].regex);
    }
  }
}

typedef struct token {
  int type;
  char str[32];
} Token;

static Token tokens[32] __attribute__((used)) = {};
static int nr_token __attribute__((used))  = 0;

static bool make_token(char *e) {
  int position = 0;
  int i;
  regmatch_t pmatch;

  nr_token = 0;
  for(int i=0;i<32;i++){
	  tokens[i].type = 0;
	  memset(tokens[i].str, 0, sizeof(tokens[i].str));
  }
  while (e[position] != '\0') {
    /* Try all rules one by one. */
    for (i = 0; i < NR_REGEX; i ++) {
     if (regexec(&re[i], e + position, 1, &pmatch, 0) == 0 && pmatch.rm_so == 0) {
        char *substr_start = e + position;
        int substr_len = pmatch.rm_eo;
        printf("match rules[%d] = \"%s\" at position %d with len %d: %.*s\n",
            i, rules[i].regex, position, substr_len, substr_len, substr_start);
        position += substr_len;
        /* TODO: Now a new token is recognized with rules[i]. Add codes
         * to record the token in the array `tokens'. For certain types
         * of tokens, some extra actions should be performed.
         */
        switch (rules[i].token_type) {
		  case TK_NOTYPE: break;
		  default  : {
						 tokens[nr_token].type = rules[i].token_type; 
						 strncpy(tokens[nr_token].str, substr_start, substr_len);
						 //printf("%s\n",tokens[nr_token].str);
						 nr_token ++;
					 }
        }
		//if (tokens[i].type == '*' && (i == 0 || tokens[i - 1].type != TK_NUM || tokens[i - 1].type != ')' )) {
		//	tokens[i].type = DEREF;
		//}
        break;
      }
    }
    if (i == NR_REGEX) {
      printf("no match at position %d\n%s\n%*.s^\n", position, e, position, "");
      return false;
    }
  }
  return true;
}

static bool check_parentheses(char** p,char** q){
	int n = 0;
	if(**p == '(' && **q == ')'){
		for(char** i=p+1;i<q;i++){
			if(**i == '('){
				n++;	
			}else if(**i == ')'&& (n!=0)){
				n--;
			}
		}
		if(n==0) return true;
	}else{
		return false;
	}
	return false;
}

static uint32_t eval(char** p, char** q) {
  if (p > q) {
    /* Bad expression */
	  printf("Bad expression:p>q\n");
	  return 0;
  }
  else if (p == q) {
    /* Single token.
     * For now this token should be a number.
     * Return the value of the number.
     */
	uint32_t a=strtoul (*p, NULL, 0);
	//uint a = atoi(*p);
	return a;
  }
  else if (check_parentheses(p, q) == true) {
    /* The expression is surrounded by a matched pair of parentheses.
     * If that is the case, just throw away the parentheses.
     */
    return eval(p + 1, q - 1);
  }
  else {
    char** op1 = p;
	char** op2 = p;
	char** op3 = p;
	char** op4 = p;
	char** op  = p;
	int n=0;
	for(char** i=p;i<q;i++){
		if(**i == '('){
				n++;	
		}else if(**i == ')'){
				n--;
		}else if(n==0){
			if(strcmp(*i,"&&") == 0){
				op1 = i;
			}else if(strcmp(*i,"==") == 0 || strcmp(*i,"!=") == 0){
				op2 = i;
			}else if(**i == '+' || **i == '-'){
				op3 = i;
			}else if((**(i-1)!='*'||**(i-1)!='/') && (**i=='*'||**i=='/')){
				op4 = i;
			}
		}
	}
	if(op1 != p){
		op = op1;
	}else if(op2 != p){
		op = op2;
	}else if(op3 != p){
		op = op3;
	}else{
		op = op4;
	}
	if(op ==  p && **p == '*'){
        return paddr_read(eval(p+1,q),4);
	}else{
		int32_t val1 = eval(p, op-1);
		int32_t val2 = eval(op+1, q);

    switch (**op) {
      case '+': return val1 + val2;
      case '-': return val1 - val2;
      case '*': return val1 * val2;
      case '/': if(val2 == 0) {printf("Can't /0\n");return 0;}
				else return val1 / val2;
      case '=': return val1 == val2;
      case '!': return val1 != val2;
      case '&': return val1 && val2;
      default: printf("Can't get op sign\n");return 0;
			}
		}
	}
}

uint32_t expr(char *e, bool *success) {
  if (!make_token(e)) {
    *success = false;
    return 0;
  }
  /* TODO: Insert codes to evaluate the expression. */
  //TODO();
  //
  static char* str[32] = {};
//  for(int i=0;i<32;i++){
//	 str[i]='\0';
//  }
  int a = 0;
  int n_1 = 0;
  for(int i=0;i<nr_token;i++){
	 if(tokens[i].type == TK_H){// "0x10" -> "16"
		  uint32_t tmp = strtol(tokens[i].str,NULL,0);
		  static char s1[32] ="";
		  sprintf(s1, "%u", tmp);
		  str[a]=s1;
	  }else if(tokens[i].type == TK_REG){// "$t0" -> "unsigned"
		  bool bo[1] = {0};
		  uint32_t tmp1 = isa_reg_str2val(tokens[i].str+1,bo);
		  if(bo[0]){
			static char s2[32]="";
			sprintf(s2, "%u", tmp1);
			str[a]=s2;
		  }
		  bo[0]=false;
	  }else{
		  str[a] = tokens[i].str;
	  }
	  //printf("%s ",str[a]);
	  a++;
  }
  char** p=str;
  char** q=str+nr_token-n_1-1;
  uint32_t result = eval(p,q);
  return result;
}
