#include "globalvar.h"

void init_sim(int argc, char** argv);
void sdb_mainloop();
void end_sim();
int is_exit_status_bad();
#ifdef PERFORMANCE_MODEL
int dependency_observer_finalize(int exit_status);
#endif
#ifdef ICACHE_64SET_MONITOR
int icache_64set_monitor_finalize();
#endif
#ifdef LOADUSE_P1_MONITOR
int loaduse_p1_monitor_finalize();
#endif

int main(int argc, char* argv[]){
    init_sim(argc,argv);
    sdb_mainloop();
    int exit_status = is_exit_status_bad();
#ifdef PERFORMANCE_MODEL
    int dependency_status = dependency_observer_finalize(exit_status);
#endif
#ifdef ICACHE_64SET_MONITOR
    int monitor_status = icache_64set_monitor_finalize();
#endif
#ifdef LOADUSE_P1_MONITOR
    int loaduse_p1_status = loaduse_p1_monitor_finalize();
#endif
    end_sim();
#ifdef ICACHE_64SET_MONITOR
    if (monitor_status != 0) return monitor_status;
#endif
#ifdef LOADUSE_P1_MONITOR
    if (loaduse_p1_status != 0) return loaduse_p1_status;
#endif
#ifdef PERFORMANCE_MODEL
    if (dependency_status != 0) return dependency_status;
#endif
    return exit_status;
}
