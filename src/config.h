#pragma once

#include <string>
#include <cstdint>

enum class ExecutionMode {
    SEQUENTIAL,
    CONCURRENT,
    PARALLEL
};

struct Config {
    ExecutionMode mode;
    uint32_t difficulty;
    uint32_t threads;
    bool affinity;
    uint32_t timeout_seconds;
    uint64_t seed;
    std::string metrics_output;
};

struct MinerResult {
    bool found;
    uint64_t nonce;
    std::string hash;
    uint64_t total_hashes;
    double elapsed_seconds;
    double cpu_time_seconds;
    double memory_mb;
    std::string experiment_id;
};
