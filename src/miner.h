#pragma once

#include "config.h"
#include <string>

class Miner {
public:
    Miner(const Config& config);
    MinerResult mine();

private:
    Config config_;
    
    MinerResult mine_sequential();
    MinerResult mine_parallel();
    MinerResult mine_concurrent();
    
    bool check_difficulty(const std::string& hash, uint32_t difficulty);
    std::string create_block_data(uint64_t nonce);
};
