#include "globalvar.h"

void init_sim(int argc, char** argv);
void sdb_mainloop();
void end_sim();
int is_exit_status_bad();

int main(int argc, char* argv[]){
    init_sim(argc,argv);
    sdb_mainloop();
    end_sim();
    return is_exit_status_bad();
}