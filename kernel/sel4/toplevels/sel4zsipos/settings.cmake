set(project_dir "${CMAKE_CURRENT_LIST_DIR}/../../")
file(GLOB project_modules ${project_dir}/projects/*)

list(
    APPEND
        CMAKE_MODULE_PATH
        ${project_dir}/kernel/
        ${project_dir}/tools/seL4/cmake-tool/helpers/
        ${project_dir}/tools/seL4/elfloader-tool/
	${project_dir}/tools/camkes-tool/
	${project_dir}/tools/capdl/
        ${project_modules}
)

# correct platform strings

include(application_settings)
include(${CMAKE_CURRENT_LIST_DIR}/easy-settings.cmake)

correct_platform_strings()

# capdl objects
include(${project_dir}/kernel/configs/seL4Config.cmake)

set(CapDLLoaderMaxObjects 20000 CACHE STRING "" FORCE)
set(KernelRootCNodeSizeBits 16 CACHE STRING "")

# misc
set(BBL_PATH ${project_dir}/tools/riscv-pk CACHE STRING "BBL Folder location")

ApplyData61ElfLoaderSettings(${KernelPlatform} ${KernelSel4Arch})
ApplyCommonSimulationSettings(${KernelArch})

# build debug version
set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "" FORCE)

# to get simple printf
set(LibSel4PlatSupportUseDebugPutChar true CACHE BOOL "" FORCE)
ApplyCommonReleaseVerificationSettings(FALSE FALSE)



