#ifndef CSYSTEMMETRICS_H
#define CSYSTEMMETRICS_H

#include <stdint.h>

typedef struct {
    uint32_t logical_cpu_count;
    uint32_t physical_cpu_count;
    uint64_t total_memory_bytes;
    uint64_t available_memory_bytes;
    uint64_t free_memory_bytes;
    double   cpu_load;
    double   memory_pressure;
} CSystemMetrics;

CSystemMetrics csystem_metrics_gather(void);

#endif
