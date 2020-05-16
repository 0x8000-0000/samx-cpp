cmake_minimum_required(VERSION 3.16.3 FATAL_ERROR)

project (samx VERSION 0.0.1 LANGUAGES CXX DESCRIPTION "SAMX Parser")

set (CMAKE_EXPORT_COMPILE_COMMANDS TRUE)
set (CMAKE_CXX_EXTENSIONS False)

include (${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
conan_basic_setup (TARGETS NO_OUTPUT_DIRS SKIP_STD)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
find_package (ANTLR REQUIRED)

add_library (project_options INTERFACE)
target_compile_features (project_options INTERFACE cxx_std_17)

add_library (project_warnings INTERFACE)
target_compile_options (project_warnings INTERFACE -Wall -Wextra -Werror -pedantic)

add_subdirectory (src)

add_subdirectory (test)
