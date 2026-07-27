#include "SystemMetrics.h"
#include <mach/mach.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <unistd.h>

CSystemMetrics csystem_metrics_gather(void) {
    CSystemMetrics m = {0};

    /* CPU counts via sysctlbyname */
    int logical = 0;
    size_t len = sizeof(logical);
    sysctlbyname("hw.ncpu", &logical, &len, NULL, 0);
    m.logical_cpu_count = (uint32_t)logical;

    int physical = 0;
    len = sizeof(physical);
    sysctlbyname("hw.physicalcpu", &physical, &len, NULL, 0);
    m.physical_cpu_count = (uint32_t)(physical > 0 ? physical : logical);

    /* Total physical memory */
    uint64_t total_mem = 0;
    len = sizeof(total_mem);
    sysctlbyname("hw.memsize", &total_mem, &len, NULL, 0);
    m.total_memory_bytes = total_mem;

    /* Memory via host_statistics64 */
    mach_port_t host = mach_host_self();
    vm_statistics64_data_t vm_stat;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;

    kern_return_t kr = host_statistics64(host, HOST_VM_INFO64,
                                         (host_info64_t)&vm_stat, &count);
    if (kr == KERN_SUCCESS) {
        unsigned int page_size = 0;
        len = sizeof(page_size);
        sysctlbyname("hw.pagesize", &page_size, &len, NULL, 0);
        if (page_size == 0) page_size = 4096;

        m.free_memory_bytes = (uint64_t)vm_stat.free_count * page_size;
        uint64_t inactive = (uint64_t)vm_stat.inactive_count * page_size;
        uint64_t speculative = (uint64_t)vm_stat.speculative_count * page_size;
        m.available_memory_bytes = m.free_memory_bytes + inactive + speculative;
    }

    /* CPU load via host_processor_info */
    natural_t num_cpu_info = 0;
    processor_cpu_load_info_data_t *cpu_info = NULL;
    kr = host_processor_info(host, HOST_CPU_LOAD_INFO,
                             &num_cpu_info,
                             (processor_info_array_t *)&cpu_info,
                             &num_cpu_info);
    if (kr == KERN_SUCCESS && cpu_info != NULL && num_cpu_info > 0) {
        uint64_t total_ticks = 0;
        uint64_t idle_ticks = 0;
        for (natural_t i = 0; i < num_cpu_info; i++) {
            total_ticks += cpu_info[i].cpu_ticks[CPU_STATE_USER]
                         + cpu_info[i].cpu_ticks[CPU_STATE_SYSTEM]
                         + cpu_info[i].cpu_ticks[CPU_STATE_IDLE]
                         + cpu_info[i].cpu_ticks[CPU_STATE_NICE];
            idle_ticks  += cpu_info[i].cpu_ticks[CPU_STATE_IDLE];
        }
        m.cpu_load = total_ticks > 0
            ? (double)(total_ticks - idle_ticks) / (double)total_ticks
            : 0.0;
        vm_deallocate(mach_task_self(),
                      (vm_address_t)cpu_info,
                      num_cpu_info * sizeof(processor_cpu_load_info_data_t));
    }

    /* Memory pressure */
    if (m.total_memory_bytes > 0) {
        m.memory_pressure = 1.0 - (double)m.available_memory_bytes / (double)m.total_memory_bytes;
    }

    return m;
}
