#include "globalvar.h"

#define NR_WP 32

static WP wp_pool[NR_WP] = {};

WP *head , *free_ ;

void init_wp_pool() {
  int i;
  for (i = 0; i < NR_WP; i ++) {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);

	wp_pool[i].string=NULL;
	wp_pool[i].value=0;
  }

  head = NULL;
  free_ = wp_pool;
}

/* TODO: Implement the functionality of watchpoint */
WP* new_wp(){
	if(free_==NULL){assert(0);}
	WP* tmp = free_;
	free_ = free_->next;
	tmp->next = head;
	head = tmp;
	printf("Set watchpoint %d\n",head->NO);
	return tmp;
}

void free_wp(WP *wp){
	WP* p1 = head;
	WP* p2 = head;
	//delete from head;
	if(head->NO == wp->NO){
		head = head->next;
		printf("Free watchpoint %d\n",p1->NO);
	}else{
		while(p1->NO != wp->NO){
			p2 = p1;
			p1 = p1->next;
		}
		p2->next = p1->next;
		printf("Free watchpoint %d\n",p1->NO);
	}
	//return free_
	p1->next = free_->next;
	free_ = p1;
}; 
