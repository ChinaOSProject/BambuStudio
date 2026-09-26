find_package(CGAL CONFIG QUIET)
if(CGAL_FOUND)
    return()
endif()

find_path(CGAL_INCLUDE_DIR
    NAMES CGAL/config.h
)

if(CGAL_DIR AND EXISTS "${CGAL_DIR}/CGAL_SetupCGALDependencies.cmake")
    set(CGAL_MODULES_DIR "${CGAL_DIR}")
else()
    find_path(CGAL_MODULES_DIR
        NAMES CGAL_SetupCGALDependencies.cmake
        PATHS ${CMAKE_PREFIX_PATH}
        PATH_SUFFIXES
            "lib/${CMAKE_LIBRARY_ARCHITECTURE}/cmake/CGAL"
            lib/cmake/CGAL
    )
endif()

if(CGAL_INCLUDE_DIR AND CGAL_MODULES_DIR)
    include("${CGAL_MODULES_DIR}/CGAL_parse_version_h.cmake")
    cgal_parse_version_h("${CGAL_INCLUDE_DIR}/CGAL/version.h"
        "CGAL_VERSION_NAME"
        "CGAL_MAJOR_VERSION"
        "CGAL_MINOR_VERSION"
        "CGAL_BUGFIX_VERSION"
        "CGAL_BUILD_VERSION"
    )
    set(CGAL_VERSION "${CGAL_MAJOR_VERSION}.${CGAL_MINOR_VERSION}.${CGAL_BUGFIX_VERSION}.${CGAL_BUILD_VERSION}")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CGAL
    REQUIRED_VARS CGAL_INCLUDE_DIR CGAL_MODULES_DIR
    VERSION_VAR CGAL_VERSION
)

if(NOT CGAL_FOUND)
    return()
endif()

set(CGAL_CONFIG_DIR "${CGAL_MODULES_DIR}")
get_filename_component(CGAL_INSTALLATION_PACKAGE_DIR "${CGAL_INCLUDE_DIR}" DIRECTORY)
set(CGAL_GRAPHICSVIEW_PACKAGE_DIR "${CGAL_INSTALLATION_PACKAGE_DIR}")
set(CGAL_INCLUDE_DIRS "${CGAL_INCLUDE_DIR}")
set(CGAL_LIBRARIES CGAL)
set(CGAL_HEADER_ONLY TRUE)
set(CGAL_USE_FILE "${CGAL_MODULES_DIR}/UseCGAL.cmake")

list(APPEND CMAKE_MODULE_PATH "${CGAL_MODULES_DIR}")
include("${CGAL_MODULES_DIR}/CGAL_SetupCGALDependencies.cmake")
include("${CGAL_MODULES_DIR}/CGAL_setup_target_dependencies.cmake")
include("${CGAL_MODULES_DIR}/CGAL_target_use_TBB.cmake")

if(NOT TARGET CGAL)
    add_library(CGAL INTERFACE IMPORTED GLOBAL)
endif()
if(NOT TARGET CGAL::CGAL)
    add_library(CGAL::CGAL ALIAS CGAL)
endif()

CGAL_setup_target_dependencies(CGAL INTERFACE)
