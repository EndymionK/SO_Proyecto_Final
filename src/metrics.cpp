#include "metrics.h"
#include <sys/resource.h>
#include <fstream>
#include <sstream>
#include <iostream>

double Metrics::get_cpu_time() {
    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    return usage.ru_utime.tv_sec + usage.ru_utime.tv_usec / 1e6 +
           usage.ru_stime.tv_sec + usage.ru_stime.tv_usec / 1e6;
}

double Metrics::get_memory_mb() {
    std::ifstream status_file("/proc/self/status");
    std::string line;
    while (std::getline(status_file, line)) {
        if (line.substr(0, 6) == "VmRSS:") {
            std::istringstream iss(line.substr(6));
            double kb;
            iss >> kb;
            return kb / 1024.0;
        }
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
