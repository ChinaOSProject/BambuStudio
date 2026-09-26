if(WIN32)
    set(library_build_type "Shared")
else()
    set(library_build_type "Static")
endif()

if (BINARY_DIR_REL)
    set(OCCT_DIRECTORY_FLAG --directory ${BINARY_DIR_REL}/dep_OCCT-prefix/src/dep_OCCT)
endif ()

find_path(_OCCT_FREETYPE_INCLUDE_DIR
    NAMES ft2build.h
    PATHS ${CMAKE_INCLUDE_PATH} ${DESTDIR}/usr/local/include
    PATH_SUFFIXES freetype2
)
find_library(_OCCT_FREETYPE_LIBRARY
    NAMES freetype
    PATHS ${CMAKE_LIBRARY_PATH} ${DESTDIR}/usr/local/lib ${DESTDIR}/usr/local/lib/${CMAKE_LIBRARY_ARCHITECTURE}
)
if(NOT _OCCT_FREETYPE_INCLUDE_DIR OR NOT _OCCT_FREETYPE_LIBRARY)
    message(FATAL_ERROR "OCCT requires FreeType headers and libraries.")
endif()

set(_OCCT_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_path(_OCCT_X11_INCLUDE_DIR
        NAMES X11/Xlib.h
        PATHS ${CMAKE_INCLUDE_PATH}
        NO_DEFAULT_PATH
    )
    if(_OCCT_X11_INCLUDE_DIR)
        string(APPEND _OCCT_CXX_FLAGS " -idirafter ${_OCCT_X11_INCLUDE_DIR}")
    endif()
endif()

bambustudio_add_cmake_project(OCCT
    URL https://github.com/Open-Cascade-SAS/OCCT/archive/refs/tags/V7_6_0.zip
    URL_HASH SHA256=28334f0e98f1b1629799783e9b4d21e05349d89e695809d7e6dfa45ea43e1dbc
    PATCH_COMMAND git apply ${OCCT_DIRECTORY_FLAG} --verbose --ignore-space-change --whitespace=fix ${CMAKE_CURRENT_LIST_DIR}/0001-OCCT-fix.patch
    #DEPENDS dep_Boost
    #DEPENDS dep_FREETYPE
    CMAKE_ARGS
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5
        -DBUILD_LIBRARY_TYPE=${library_build_type}
        -DUSE_TK=OFF
        -DUSE_TBB=OFF
	#-DUSE_FREETYPE=OFF
        -DUSE_FFMPEG=OFF
        -DUSE_VTK=OFF
        -DBUILD_DOC_Overview=OFF
        -DBUILD_MODULE_ApplicationFramework=OFF
        #-DBUILD_MODULE_DataExchange=OFF
        -DBUILD_MODULE_Draw=OFF
        -DBUILD_MODULE_FoundationClasses=OFF
        -DBUILD_MODULE_ModelingAlgorithms=OFF
        -DBUILD_MODULE_ModelingData=OFF
        -DBUILD_MODULE_Visualization=OFF
        -DCMAKE_CXX_FLAGS:STRING=${_OCCT_CXX_FLAGS}
        -D3RDPARTY_FREETYPE_INCLUDE_DIR_ft2build:PATH=${_OCCT_FREETYPE_INCLUDE_DIR}
        -D3RDPARTY_FREETYPE_INCLUDE_DIR_freetype2:PATH=${_OCCT_FREETYPE_INCLUDE_DIR}
        -D3RDPARTY_FREETYPE_LIBRARY:FILEPATH=${_OCCT_FREETYPE_LIBRARY}
)

if (DEP_BUILD_FREETYPE)
    add_dependencies(dep_OCCT ${FREETYPE_PKG})
endif ()
