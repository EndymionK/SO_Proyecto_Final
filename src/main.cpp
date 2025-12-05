#include "miner.h"
#include "metrics.h"
#include <iostream>
#include <string>
#include <cstring>

void print_usage(const char* program_name) {
    std::cerr << "Usage: " << program_name << " [options]\n"
              << "Options:\n"
              << "  --mode <sequential|concurrent|parallel>  Execution mode (required)\n"
              << "  --difficulty <N>                         Number of leading zero bits (required)\n"
              << "  --threads <N>                            Number of threads (required)\n"
              << "  --timeout <seconds>                      Timeout in seconds (required)\n"
              << "  --seed <N>                               Initial nonce seed (default: 0)\n"
              << "  --affinity <true|false>                  Enable CPU affinity (default: false)\n"
              << "  --metrics-out <path>                     Output CSV file path (required)\n";
}

bool parse_args(int argc, char* argv[], Config& config) {
    bool has_mode = false;
    bool has_difficulty = false;
    bool has_threads = false;
    bool has_timeout = false;
    bool has_metrics_out = false;
    
    config.seed = 0;
    config.affinity = false;
    
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        
        if (arg == "--mode" && i + 1 < argc) {
            std::string mode_str = argv[++i];
            if (mode_str == "sequential") {
                config.mode = ExecutionMode::SEQUENTIAL;
            } else if (mode_str == "concurrent") {
                config.mode = ExecutionMode::CONCURRENT;
            } else if (mode_str == "parallel") {
                config.mode = ExecutionMode::PARALLEL;
            } else {
                std::cerr << "Invalid mode: " << mode_str << std::endl;
                return false;
            }
            has_mode = true;
        }
        else if (arg == "--difficulty" && i + 1 < argc) {
            config.difficulty = std::stoul(argv[++i]);
            has_difficulty = true;
        }
        else if (arg == "--threads" && i + 1 < argc) {
            config.threads = std::stoul(argv[++i]);
            has_threads = true;
        }
        else if (arg == "--timeout" && i + 1 < argc) {
            config.timeout_seconds = std::stoul(argv[++i]);
            has_timeout = true;
        }
        else if (arg == "--seed" && i + 1 < argc) {
            config.seed = std::stoull(argv[++i]);
        }
        else if (arg == "--affinity" && i + 1 < argc) {
            std::string affinity_str = argv[++i];
            config.affinity = (affinity_str == "true" || affinity_str == "1");
        }
        else if (arg == "--metrics-out" && i + 1 < argc) {
            std::string path = argv[++i];
            // Remove quotes if present
            if (path.length() >= 2 && path.front() == '"' && path.back() == '"') {
                path = path.substr(1, path.length() - 2);
            }
            config.metrics_output = path;
            has_metrics_out = true;
        }
        else {
            std::cerr << "Unknown argument: " << arg << std::endl;
            return false;
        }
    }
    
    if (!has_mode || !has_difficulty || !has_threads || !has_timeout || !has_metrics_out) {
        std::cerr << "Missing required arguments" << std::endl;
        return false;
    }
    
    return true;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }
    
    Config config;
    if (!parse_args(argc, argv, config)) {
        print_usage(argv[0]);
        return 1;
    }
    
    std::cout << "Starting miner with configuration:" << std::endl;
    std::cout << "  Mode: ";
    switch (config.mode) {
        case ExecutionMode::SEQUENTIAL: std::cout << "sequential"; break;
        case ExecutionMode::CONCURRENT: std::cout << "concurrent"; break;
        case ExecutionMode::PARALLEL: std::cout << "parallel"; break;
    }
    std::cout << std::endl;
    std::cout << "  Difficulty: " << config.difficulty << " bits" << std::endl;
    std::cout << "  Threads: " << config.threads << std::endl;
    std::cout << "  Timeout: " << config.timeout_seconds << " seconds" << std::endl;
    std::cout << "  Seed: " << config.seed << std::endl;
    std::cout << "  Affinity: " << (config.affinity ? "enabled" : "disabled") << std::endl;
    std::cout << std::endl;
    
    Miner miner(config);
    MinerResult result = miner.mine();
    
    std::cout << "Mining completed:" << std::endl;
    std::cout << "  Found: " << (result.found ? "yes" : "no") << std::endl;
    if (result.found) {
        std::cout << "  Nonce: " << result.nonce << std::endl;
        std::cout << "  Hash: " << result.hash << std::endl;
    }
    std::cout << "  Total hashes: " << result.total_hashes << std::endl;
    std::cout << "  Elapsed time: " << result.elapsed_seconds << " s" << std::endl;
    std::cout << "  CPU time: " << result.cpu_time_seconds << " s" << std::endl;
    std::cout << "  Memory: " << result.memory_mb << " MB" << std::endl;
    std::cout << "  Throughput: " 
              << (result.elapsed_seconds > 0 ? result.total_hashes / result.elapsed_seconds : 0)
              << " hashes/s" << std::endl;
    
    Metrics::export_to_csv(result, config, config.metrics_output);
    
    return result.found ? 0 : 2;
}
