#
# Copyright 2018, Data61
# Commonwealth Scientific and Industrial Research Organisation (CSIRO)
# ABN 41 687 119 230.
#
# This software may be distributed and modified according to the terms of
# the BSD 2-Clause license. Note that NO WARRANTY is provided.
# See "LICENSE_BSD2.txt" for details.
#
# @TAG(DATA61_BSD)
#

cmake_minimum_required(VERSION 3.7.2)
project(libpicotcpng NONE)

include(external-project-helpers)

set(configure_string "")

set(PICOTCP_PATH "${CMAKE_CURRENT_LIST_DIR}/picotcp" CACHE STRING "")

add_config_library(picotcpng "${configure_string}")

# extract compiler args from cmake
get_property(compile_options DIRECTORY PROPERTY COMPILE_OPTIONS)
separate_arguments(cmake_c_flags_sep NATIVE_COMMAND "${CMAKE_C_FLAGS}")
list(APPEND compile_options "${cmake_c_flags_sep}")

# add the location of muslc headers to the cflags
string(
    APPEND compile_options
    " -I$<JOIN:$<TARGET_PROPERTY:muslc,INTERFACE_INCLUDE_DIRECTORIES>, -I>"
)

if (CMAKE_C_COMPILER_ID STREQUAL "Clang")
    list(APPEND compile_options "${CMAKE_C_COMPILE_OPTIONS_TARGET}${CMAKE_C_COMPILER_TARGET}")
    set(C_COMPILER clang)
else()
    set(C_COMPILER ${CROSS_COMPILER_PREFIX}gcc)
endif()

if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(perf_flags "\"PERF=1\" \"DEBUG=0\"")
endif()
# generate a build.sh script to avoid nasty escape issues, we then invoke this in ExternalProject_Add
file(
    GENERATE
    OUTPUT
    "${CMAKE_CURRENT_BINARY_DIR}/picotcp_external/picotcp/build.sh"
    CONTENT
    "${CMAKE_COMMAND} -E env \
    \"PLATFORM_CFLAGS=$<JOIN:${compile_options}, >\" \
    \"CROSS_COMPILE=${CROSS_COMPILER_PREFIX}\" \
    \"C_COMPILER=${C_COMPILER}\" \
    ${perf_flags} \
    make -s -j"
)

add_custom_target(get_muslc)
add_dependencies(get_muslc muslc)

# build picotcp using its very own build system
include(ExternalProject)
ExternalProject_Add(
    picotcp_external
    SOURCE_DIR
    "picotcp_external"
    DOWNLOAD_COMMAND
    rsync
    -qur
    --exclude='.git'
    ${PICOTCP_PATH}
    <SOURCE_DIR>
    UPDATE_COMMAND
    ""
    PATCH_COMMAND
    sed
    -i
    "s/(CROSS_COMPILE)gcc/(C_COMPILER)/g"
    picotcp/Makefile
    CONFIGURE_COMMAND
    ""
    BUILD_COMMAND
    cd
    <SOURCE_DIR>/picotcp/
    &&
    sh
    build.sh
    BUILD_IN_SOURCE
    1
    INSTALL_COMMAND
    ""
    EXCLUDE_FROM_ALL
    BUILD_BYPRODUCTS
    "<SOURCE_DIR>/picotcp/build/lib/libpicotcp.a"
    DEPENDS
    get_muslc
)

file(
    GLOB
        deps
        ${PICOTCP_PATH}/modules/*.c
        ${PICOTCP_PATH}/modules/*.h
        ${PICOTCP_PATH}/stack/*.c
        ${PICOTCP_PATH}/include/**/*.h
)

# Add file dependencies to picotcp
ExternalProject_Add_StepDependencies(
    picotcp_external
    download
    DEPENDS
    ${PICOTCP_PATH}/Makefile
    DEPENDS
    ${deps}
)
# get the dir that the picotcp sources have been copied to by ExternalProject_Add
ExternalProject_Get_Property(picotcp_external SOURCE_DIR)
set(BUILD_DIR "${SOURCE_DIR}/picotcp/build/")

DeclareExternalProjObjectFiles(picotcp_external "${BUILD_DIR}/lib/" FILES "libpicotcp.a")

# create a library which is the sources
add_library(picotcp_sources STATIC IMPORTED GLOBAL)
add_dependencies(picotcp_sources picotcp_external)
set_property(TARGET picotcp_sources PROPERTY IMPORTED_LOCATION "${BUILD_DIR}/lib/libpicotcp.a")

# create a library which is the header files, that depends on the sources
add_library(picotcp INTERFACE)
add_dependencies(picotcp picotcp_sources)
set_property(TARGET picotcp PROPERTY INTERFACE_LINK_LIBRARIES picotcp_sources)
target_include_directories(
    picotcp
    INTERFACE
        "${BUILD_DIR}/include" "$<TARGET_PROPERTY:picotcp_Config,INTERFACE_INCLUDE_DIRECTORIES>"
        "$<TARGET_PROPERTY:sel4_autoconf,INTERFACE_INCLUDE_DIRECTORIES>"
)

