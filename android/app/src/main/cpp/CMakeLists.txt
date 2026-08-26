cmake_minimum_required(VERSION 3.22.1)
project(audio_dsp LANGUAGES CXX)

add_library(stretch SHARED stretch_wrapper.cpp)

target_include_directories(stretch PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}/../../../../../native/signalsmith"
)

target_compile_features(stretch PRIVATE cxx_std_17)

# Avoid -ffast-math: it can introduce audible artifacts in DSP pipelines.
target_compile_options(stretch PRIVATE
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:RelWithDebInfo>:-O3>
)

find_library(log-lib log)
target_link_libraries(stretch ${log-lib})
