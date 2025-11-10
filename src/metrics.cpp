#include "metrics.h"
#include <windows.h>
#include <psapi.h>
#include <fstream>
#include <iostream>

double Metrics::get_cpu_time() {
    FILETIME creation_time, exit_time, kernel_time, user_time;
    if (GetProcessTimes(GetCurrentProcess(), &creation_time, &exit_time, &kernel_time, &user_time)) {
        ULARGE_INTEGER kernel, user;
        kernel.LowPart = kernel_time.dwLowDateTime;
        kernel.HighPart = kernel_time.dwHighDateTime;
        user.LowPart = user_time.dwLowDateTime;
        user.HighPart = user_time.dwHighDateTime;
        
        return (kernel.QuadPart + user.QuadPart) / 10000000.0;
    }
    return 0.0;
}

double Metrics::get_memory_mb() {
    PROCESS_MEMORY_COUNTERS_EX pmc;
    if (GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
        return pmc.WorkingSetSize / (1024.0 * 1024.0);
    }
    return 0.0;
}

void Metrics::export_to_csv(const MinerResult& result, const Config& config, 
                            const std::string& filepath) {
    std::ofstream file(filepath);
    if (!file.is_open()) {
        std::cerr << "Failed to open metrics file: " << filepath << std::endl;
        return;
    }

    file << "experiment_id,mode,difficulty,threads,affinity,found,nonce,total_hashes,"
         << "elapsed_s,cpu_time_s,memory_mb,hashes_per_second\n";

    std::string mode_str;
    switch (config.mode) {
        case ExecutionMode::SEQUENTIAL: mode_str = "sequential"; break;
        case ExecutionMode::CONCURRENT: mode_str = "concurrent"; break;
        case ExecutionMode::PARALLEL: mode_str = "parallel"; break;
    }

    double hps = result.elapsed_seconds > 0 ? 
                 result.total_hashes / result.elapsed_seconds : 0.0;

    file << result.experiment_id << ","
         << mode_str << ","
         << config.difficulty << ","
         << config.threads << ","
         << (config.affinity ? "true" : "false") << ","
         << (result.found ? "true" : "false") << ","
         << result.nonce << ","
         << result.total_hashes << ","
         << result.elapsed_seconds << ","
         << result.cpu_time_seconds << ","
         << result.memory_mb << ","
         << hps << "\n";

    file.close();
}
