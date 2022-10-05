cmake_minimum_required(VERSION 3.15)

project(add_jedi_inc
        VERSION 1.0.0
        LANGUAGES Fortran)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include(${PROJECT_NAME}_compiler_flags)
include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE MATCHES "^(Debug|Release|RelWithDebInfo|MinSizeRel)$")
  message(STATUS "Setting build type to 'Release' as none was specified.")
  set(CMAKE_BUILD_TYPE
      "Release"
      CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

if(NOT CMAKE_Fortran_COMPILER_ID MATCHES "^(GNU|Intel)$")
  message(WARNING "${CMAKE_Fortran_COMPILER_ID} is not supported.")
endif()

option(ENABLE_NCDIAG_SERIAL "Enable Serial NetCDF diagnostics" ON)

# Dependencies
#find_package(MPI REQUIRED)
find_package(NetCDF REQUIRED COMPONENTS Fortran)

# Get list of files
list(APPEND ADD_JEDI_INCR_SRC apply_incr_noahmp_snow.f90  NoahMPdisag_module.f90)

add_executable(apply_incr ${ADD_JEDI_INCR_SRC})
target_link_libraries(apply_incr NetCDF::NetCDF_Fortran)


