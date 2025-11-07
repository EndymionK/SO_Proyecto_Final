#pragma once

#include "config.h"
#include <string>

class Metrics {
public:
    static double get_cpu_time();
    static double get_memory_mb();
    static void export_to_csv(const MinerResult& result, const Config& config, 
                             const std::string& filepath);
};
