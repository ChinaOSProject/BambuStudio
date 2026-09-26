set(_OpenCASCADE_components
    TKXDESTEP
    TKSTEP
    TKSTEP209
    TKSTEPAttr
    TKSTEPBase
    TKXCAF
    TKXSBase
    TKVCAF
    TKCAF
    TKLCAF
    TKCDF
    TKV3d
    TKService
    TKMesh
    TKBO
    TKPrim
    TKHLR
    TKShHealing
    TKTopAlgo
    TKGeomAlgo
    TKBRep
    TKGeomBase
    TKG3d
    TKG2d
    TKMath
    TKernel
)

set(_OpenCASCADE_prefixes ${CMAKE_PREFIX_PATH})
if(NOT _OpenCASCADE_prefixes AND DEFINED PREFIX_PATH_CHECK)
    set(_OpenCASCADE_prefixes ${PREFIX_PATH_CHECK})
endif()
if(NOT _OpenCASCADE_prefixes AND DEFINED ENV{CMAKE_PREFIX_PATH})
    set(_OpenCASCADE_prefixes $ENV{CMAKE_PREFIX_PATH})
endif()

find_path(OpenCASCADE_INCLUDE_DIR
    NAMES Standard.hxx
    PATHS ${_OpenCASCADE_prefixes}
    PATH_SUFFIXES include/opencascade include
    NO_DEFAULT_PATH
)

set(_OpenCASCADE_missing "")
foreach(_OpenCASCADE_component IN LISTS _OpenCASCADE_components)
    find_library(_OpenCASCADE_library_${_OpenCASCADE_component}
        NAMES ${_OpenCASCADE_component}
        PATHS ${_OpenCASCADE_prefixes}
        PATH_SUFFIXES lib/${CMAKE_LIBRARY_ARCHITECTURE} lib
        NO_DEFAULT_PATH
    )
    if(NOT _OpenCASCADE_library_${_OpenCASCADE_component})
        list(APPEND _OpenCASCADE_missing ${_OpenCASCADE_component})
    elseif(NOT OpenCASCADE_LIBRARY_DIR)
        get_filename_component(OpenCASCADE_LIBRARY_DIR
            "${_OpenCASCADE_library_${_OpenCASCADE_component}}" DIRECTORY
        )
    endif()
endforeach()

if(_OpenCASCADE_missing)
    set(OpenCASCADE_LIBRARY_DIR "OpenCASCADE_LIBRARY_DIR-NOTFOUND")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(OpenCASCADE
    REQUIRED_VARS OpenCASCADE_INCLUDE_DIR OpenCASCADE_LIBRARY_DIR
)

if(OpenCASCADE_FOUND)
    link_directories("${OpenCASCADE_LIBRARY_DIR}")
endif()

mark_as_advanced(OpenCASCADE_INCLUDE_DIR OpenCASCADE_LIBRARY_DIR)
