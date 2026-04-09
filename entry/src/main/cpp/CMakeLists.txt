# the minimum version of CMake.
cmake_minimum_required(VERSION 3.5.0)
project(entry LANGUAGES C CXX)

set(NATIVE_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(
    ${NATIVE_ROOT_PATH}
    ${NATIVE_ROOT_PATH}/quickjs
)

add_library(entry SHARED
    napi_init.cpp
    quickjs/quickjs.c
    quickjs/cutils.c
    quickjs/libregexp.c
    quickjs/libunicode.c
    quickjs/dtoa.c
)

target_compile_definitions(entry PRIVATE
    _GNU_SOURCE
    CONFIG_VERSION=\"2025-09-13-2\"
)

target_compile_options(entry PRIVATE
    -fwrapv
)

target_link_libraries(entry PUBLIC
    libace_napi.z.so
    m
    pthread
)
