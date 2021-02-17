set(LIBPICOTCPNG_CURRENT_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE STRING "")
mark_as_advanced(LIBPICOTCPNG_CURRENT_DIR)

macro(libpicotcpng_import_library)
    add_subdirectory(${LIBPICOTCPNG_CURRENT_DIR} libpicotcpng)
endmacro()

include(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(libpicotcpng DEFAULT_MSG LIBPICOTCPNG_CURRENT_DIR)
