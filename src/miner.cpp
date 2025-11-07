#include "miner.h"
#include "sha256_hash.h"
#include "metrics.h"
#include <chrono>
#include <thread>
#include <vector>
#include <atomic>
#include <sched.h>
#include <unistd.h>

Miner::Miner(const Config& config) : config_(config) {}

std::string Miner::create_block_data(uint64_t nonce) {
    return "block_" + std::to_string(config_.seed) + "_nonce_" + std::to_string(nonce);
}

bool Miner::check_difficulty(const std::string& hash, uint32_t difficulty) {
    uint32_t zero_bits = 0;
    for (char c : hash) {
        int val = (c >= '0' && c <= '9') ? (c - '0') : (c - 'a' + 10);
        if (val == 0) {
            zero_bits += 4;
        } else {
            for (int i = 3; i >= 0; --i) {
                if ((val & (1 << i)) == 0) {
                    zero_bits++;
                } else {
                    return zero_bits >= difficulty;
                }
            }
            return false;
        }
        if (zero_bits >= difficulty) {
            return true;
        }
    }
    return zero_bits >= difficulty;
}

MinerResult Miner::mine() {
    switch (config_.mode) {
        case ExecutionMode::SEQUENTIAL:
            return mine_sequential();
        case ExecutionMode::PARALLEL:
            return mine_parallel();
        case ExecutionMode::CONCURRENT:
            return mine_concurrent();
    }
    return MinerResult{};
}

MinerResult Miner::mine_sequential() {
    auto start_time = std::chrono::steady_clock::now();
    double start_cpu = Metrics::get_cpu_time();
    
    uint64_t nonce = config_.seed;
    uint64_t total_hashes = 0;
    bool found = false;
    std::string result_hash;
    
    auto timeout = std::chrono::seconds(config_.timeout_seconds);
    
    while (!found) {
        auto elapsed = std::chrono::steady_clock::now() - start_time;
        if (elapsed >= timeout) {
            break;
        }
        
        std::string block_data = create_block_data(nonce);
        std::string hash = sha256(block_data);
        total_hashes++;
        
        if (check_difficulty(hash, config_.difficulty)) {
            found = true;
            result_hash = hash;
            break;
        }
        
        nonce++;
    }
    
    auto end_time = std::chrono::steady_clock::now();
    double elapsed_seconds = std::chrono::duration<double>(end_time - start_time).count();
    double cpu_time = Metrics::get_cpu_time() - start_cpu;
    double memory = Metrics::get_memory_mb();
    
    return MinerResult{
        found,
        nonce,
        result_hash,
        total_hashes,
        elapsed_seconds,
        cpu_time,
        memory,
        "exp_001"
    };
}

MinerResult Miner::mine_parallel() {
    auto start_time = std::chrono::steady_clock::now();
    double start_cpu = Metrics::get_cpu_time();
    
    std::atomic<bool> found(false);
    std::atomic<uint64_t> result_nonce(0);
    std::atomic<uint64_t> total_hashes(0);
    std::string result_hash;
    
    uint32_t num_threads = config_.threads;
    std::vector<std::thread> threads;
    
    auto timeout = std::chrono::seconds(config_.timeout_seconds);
    const uint64_t chunk_size = UINT64_MAX / num_threads;
    
    for (uint32_t tid = 0; tid < num_threads; ++tid) {
        threads.emplace_back([&, tid]() {
            uint64_t start_nonce = config_.seed + tid * chunk_size;
            uint64_t nonce = start_nonce;
            uint64_t local_hashes = 0;
            
            while (!found.load(std::memory_order_relaxed)) {
                auto elapsed = std::chrono::steady_clock::now() - start_time;
                if (elapsed >= timeout) {
                    break;
                }
                
                std::string block_data = create_block_data(nonce);
                std::string hash = sha256(block_data);
                local_hashes++;
                
                if (check_difficulty(hash, config_.difficulty)) {
                    bool expected = false;
                    if (found.compare_exchange_strong(expected, true)) {
                        result_nonce.store(nonce);
                        result_hash = hash;
                    }
                    break;
                }
                
                nonce++;
            }
            
            total_hashes.fetch_add(local_hashes, std::memory_order_relaxed);
        });
    }
    
    for (auto& t : threads) {
        t.join();
    }
    
    auto end_time = std::chrono::steady_clock::now();
    double elapsed_seconds = std::chrono::duration<double>(end_time - start_time).count();
    double cpu_time = Metrics::get_cpu_time() - start_cpu;
    double memory = Metrics::get_memory_mb();
    
    return MinerResult{
        found.load(),
        result_nonce.load(),
        result_hash,
        total_hashes.load(),
        elapsed_seconds,
        cpu_time,
        memory,
        "exp_001"
    };
}

MinerResult Miner::mine_concurrent() {
    auto start_time = std::chrono::steady_clock::now();
    double start_cpu = Metrics::get_cpu_time();
    
    std::atomic<bool> found(false);
    std::atomic<uint64_t> result_nonce(0);
    std::atomic<uint64_t> total_hashes(0);
    std::string result_hash;
    
    uint32_t num_threads = config_.threads;
    std::vector<std::thread> threads;
    
    auto timeout = std::chrono::seconds(config_.timeout_seconds);
    const uint64_t chunk_size = UINT64_MAX / num_threads;
    
    int target_cpu = 0;
    if (config_.affinity) {
        target_cpu = sched_getcpu();
        if (target_cpu < 0) target_cpu = 0;
    }
    
    for (uint32_t tid = 0; tid < num_threads; ++tid) {
        threads.emplace_back([&, tid, target_cpu]() {
            if (config_.affinity) {
                cpu_set_t cpuset;
                CPU_ZERO(&cpuset);
                CPU_SET(target_cpu, &cpuset);
                pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
            }
            
            uint64_t start_nonce = config_.seed + tid * chunk_size;
            uint64_t nonce = start_nonce;
            uint64_t local_hashes = 0;
            
            while (!found.load(std::memory_order_relaxed)) {
                auto elapsed = std::chrono::steady_clock::now() - start_time;
                if (elapsed >= timeout) {
                    break;
                }
                
                std::string block_data = create_block_data(nonce);
                std::string hash = sha256(block_data);
                local_hashes++;
                
                if (check_difficulty(hash, config_.difficulty)) {
                    bool expected = false;
                    if (found.compare_exchange_strong(expected, true)) {
                        result_nonce.store(nonce);
                        result_hash = hash;
                    }
                    break;
                }
                
                nonce++;
            }
            
            total_hashes.fetch_add(local_hashes, std::memory_order_relaxed);
        });
    }
    
    for (auto& t : threads) {
        t.join();
    }
    
    auto end_time = std::chrono::steady_clock::now();
    double elapsed_seconds = std::chrono::duration<double>(end_time - start_time).count();
    double cpu_time = Metrics::get_cpu_time() - start_cpu;
    double memory = Metrics::get_memory_mb();
    
    return MinerResult{
        found.load(),
        result_nonce.load(),
        result_hash,
        total_hashes.load(),
        elapsed_seconds,
        cpu_time,
        memory,
        "exp_001"
    };
}
