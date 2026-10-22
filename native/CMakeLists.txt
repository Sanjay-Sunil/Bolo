cmake_minimum_required(VERSION 3.22)
project(bolo_whisper C CXX)

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)

add_subdirectory(../third_party/whisper.cpp whisper)

add_library(bolo_whisper SHARED bolo_whisper.c)
target_link_libraries(bolo_whisper PRIVATE whisper m)
