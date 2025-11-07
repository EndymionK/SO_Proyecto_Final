cmake_minimum_required(VERSION 3.15)
project(pow_miner VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(CMAKE_CXX_FLAGS_RELEASE "-O3 -march=native -DNDEBUG")

find_package(OpenSSL REQUIRED)
find_package(Threads REQUIRED)

add_executable(miner
  src/main.cpp
  src/miner.cpp
  src/sha256_hash.cpp
  src/metrics.cpp
)

target_include_directories(miner PRIVATE src)

target_link_libraries(miner PRIVATE
  OpenSSL::Crypto
  Threads::Threads
)

target_compile_options(miner PRIVATE
  -Wall
  -Wextra
  -Wpedantic
)
