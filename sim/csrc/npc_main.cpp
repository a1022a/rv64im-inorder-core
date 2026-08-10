#include "globalvar.h"

void init_sim(int argc, char** argv);
void sdb_mainloop();
void end_sim();
int is_exit_status_bad();
#ifdef ICACHE_64SET_MONITOR
int icache_64set_monitor_finalize();
#endif

int main(int argc, char* argv[]){
    init_sim(argc,argv);
    sdb_mainloop();
#ifdef ICACHE_64SET_MONITOR
    int monitor_status = icache_64set_monitor_finalize();
#endif
    end_sim();
#ifdef ICACHE_64SET_MONITOR
    if (monitor_status != 0) return monitor_status;
#endif
    return is_exit_status_bad();
}
