add_executable (dump_tokens dump_tokens.cpp)

target_link_libraries (dump_tokens PUBLIC samx)
target_link_libraries (dump_tokens PUBLIC CONAN_PKG::gflags)


