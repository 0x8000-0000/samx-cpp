Getting Started with SAMx
=========================

Build the Distribution Package
------------------------------

```shell script
# Check Conan version
$ conan --version
Conan version 1.25.0

$ cmake --version
cmake version 3.16.3

# Clone the repository
$ git clone https://github.com/0x8000-0000/samx-cpp/
Cloning into 'samx-cpp'...
remote: Enumerating objects: 20, done.
remote: Counting objects: 100% (20/20), done.
remote: Compressing objects: 100% (12/12), done.
remote: Total 1778 (delta 0), reused 14 (delta 0), pack-reused 1758
Receiving objects: 100% (1778/1778), 290.76 KiB | 2.57 MiB/s, done.
Resolving deltas: 100% (661/661), done.
$ mkdir samx-cpp.build
$ conan install ../samx-cpp --build
$ cmake ../samx-cpp -DCMAKE_BUILD_TYPE=Release
$ cmake --build .
```

Use the built-in apps
---------------------

There is one application bundled in the distribution package, `dump_tokens`

```shell script
$ ./test/lexer/dump_tokens ../samxj/src/test/resources/literate/internet.samx > /tmp/cpp.tokens
```

You can use it to compare with the output from `raw_tokens` tool bundled with
the samx-java package.

