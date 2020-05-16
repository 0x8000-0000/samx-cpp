cmake_minimum_required(VERSION 3.13.0 FATAL_ERROR)

project (samx VERSION 0.0.1 LANGUAGES CXX DESCRIPTION "SAMX Parser")

set (CMAKE_EXPORT_COMPILE_COMMANDS TRUE)
set (CMAKE_CXX_EXTENSIONS False)

add_library (project_options INTERFACE)

target_compile_features (project_options INTERFACE cxx_std_17)

add_subdirectory (src)
