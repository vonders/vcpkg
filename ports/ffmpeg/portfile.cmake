if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    message(STATUS "Building as static libraries not currently supported. Building as DLLs instead.")
    set(VCPKG_LIBRARY_LINKAGE "dynamic")
endif()

include(vcpkg_common_functions)
set(SOURCE_PATH ${CURRENT_BUILDTREES_DIR}/src/ffmpeg-3.2.1)
vcpkg_download_distfile(ARCHIVE
    URLS "http://ffmpeg.org/releases/ffmpeg-3.2.1.tar.bz2"
    FILENAME "ffmpeg-3.2.1.tar.bz2"
    SHA512  1cc63bf73356f4e618c0d3572a216bdf5689f10deff56b4262f6d740b0bee5a4b3eac234f45fca3d4d2da77903a507b4fba725b76d2d2070f31b6dae9e7a2dab
)
vcpkg_extract_source_archive(${ARCHIVE})

vcpkg_find_acquire_program(YASM)
get_filename_component(YASM_EXE_PATH ${YASM} DIRECTORY)
set(ENV{PATH} "$ENV{PATH};${YASM_EXE_PATH}")

vcpkg_acquire_msys(MSYS_ROOT)
set(BASH ${MSYS_ROOT}/usr/bin/bash.exe)

set(_csc_PROJECT_PATH ffmpeg)

file(REMOVE_RECURSE ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel)

set(OPTIONS "--disable-ffmpeg --disable-ffprobe --disable-doc --enable-debug")
set(OPTIONS "${OPTIONS} --enable-runtime-cpudetect")

if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
    set(OPTIONS "${OPTIONS} --disable-programs --enable-cross-compile --target-os=win32 --arch=${VCPKG_TARGET_ARCHITECTURE}")
    set(OPTIONS "${OPTIONS} --extra-cflags=-DWINAPI_FAMILY=WINAPI_FAMILY_APP --extra-cflags=-D_WIN32_WINNT=0x0A00")

    if (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        vcpkg_find_acquire_program(GASPREPROCESSOR)
        foreach(GAS_PATH ${GASPREPROCESSOR})
            get_filename_component(GAS_ITEM_PATH ${GAS_PATH} DIRECTORY)
            set(ENV{PATH} "$ENV{PATH};${GAS_ITEM_PATH}")
        endforeach(GAS_PATH)

        ## Get Perl and GCC for MSYS2
        vcpkg_execute_required_process(
            COMMAND ${BASH} --noprofile --norc -c 'PATH=/usr/bin:\$PATH;pacman -Sy --noconfirm --needed perl gcc'
            WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}
            LOGNAME msys-${TARGET_TRIPLET}
        )

    elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    else()
        message(FATAL_ERROR "Unsupported architecture")
    endif()
endif()

set(OPTIONS_DEBUG "") # Note: --disable-optimizations can't be used due to http://ffmpeg.org/pipermail/libav-user/2013-March/003945.html
set(OPTIONS_RELEASE "")

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    set(OPTIONS "${OPTIONS} --disable-static --enable-shared")
    if (VCPKG_CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
        set(OPTIONS "${OPTIONS} --extra-ldflags=-APPCONTAINER --extra-ldflags=WindowsApp.lib")
    endif()
endif()

if(VCPKG_CRT_LINKAGE STREQUAL "dynamic")
    set(OPTIONS_DEBUG "${OPTIONS_DEBUG} --extra-cflags=-MDd --extra-cxxflags=-MDd")
    set(OPTIONS_RELEASE "${OPTIONS_RELEASE} --extra-cflags=-MD --extra-cxxflags=-MD")
else()
    set(OPTIONS_DEBUG "${OPTIONS_DEBUG} --extra-cflags=-MTd --extra-cxxflags=-MTd")
    set(OPTIONS_RELEASE "${OPTIONS_RELEASE} --extra-cflags=-MT --extra-cxxflags=-MT")
endif()

message(STATUS "Building ${_csc_PROJECT_PATH} for Release")
file(MAKE_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel)
vcpkg_execute_required_process(
    COMMAND ${BASH} --noprofile --norc "${CMAKE_CURRENT_LIST_DIR}\\build.sh"
        "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel" # BUILD DIR
        "${SOURCE_PATH}" # SOURCE DIR
        "${CURRENT_PACKAGES_DIR}" # PACKAGE DIR
        "${OPTIONS} ${OPTIONS_RELEASE}"
    WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel
    LOGNAME build-${TARGET_TRIPLET}-rel
)

message(STATUS "Building ${_csc_PROJECT_PATH} for Debug")
file(MAKE_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg)
vcpkg_execute_required_process(
    COMMAND ${BASH} --noprofile --norc "${CMAKE_CURRENT_LIST_DIR}\\build.sh"
        "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg" # BUILD DIR
        "${SOURCE_PATH}" # SOURCE DIR
        "${CURRENT_PACKAGES_DIR}/debug" # PACKAGE DIR
        "${OPTIONS} ${OPTIONS_DEBUG}"
    WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg
    LOGNAME build-${TARGET_TRIPLET}-dbg
)

file(GLOB DEF_FILES ${CURRENT_PACKAGES_DIR}/lib/*.def ${CURRENT_PACKAGES_DIR}/debug/lib/*.def)

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
    set(LIB_MACHINE_ARG /machine:ARM)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    set(LIB_MACHINE_ARG /machine:x86)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(LIB_MACHINE_ARG /machine:x64)
else()
    message(FATAL_ERROR "Unsupported target architecture")
endif()

foreach(DEF_FILE ${DEF_FILES})
    get_filename_component(DEF_FILE_DIR "${DEF_FILE}" DIRECTORY)
    get_filename_component(DEF_FILE_NAME "${DEF_FILE}" NAME)
    string(REGEX REPLACE "-[0-9]*\\.def" ".lib" OUT_FILE_NAME "${DEF_FILE_NAME}")
    file(TO_NATIVE_PATH "${DEF_FILE}" DEF_FILE_NATIVE)
    file(TO_NATIVE_PATH "${DEF_FILE_DIR}/${OUT_FILE_NAME}" OUT_FILE_NATIVE)
    message(STATUS "Generating ${OUT_FILE_NATIVE}")
    vcpkg_execute_required_process(
        COMMAND lib.exe /def:${DEF_FILE_NATIVE} /out:${OUT_FILE_NATIVE} ${LIB_MACHINE_ARG}
        WORKING_DIRECTORY ${CURRENT_PACKAGES_DIR}
        LOGNAME libconvert-${TARGET_TRIPLET}
    )
endforeach()

file(GLOB EXP_FILES ${CURRENT_PACKAGES_DIR}/lib/*.exp ${CURRENT_PACKAGES_DIR}/debug/lib/*.exp)
file(GLOB LIB_FILES ${CURRENT_PACKAGES_DIR}/bin/*.lib ${CURRENT_PACKAGES_DIR}/debug/bin/*.lib)
file(GLOB EXE_FILES ${CURRENT_PACKAGES_DIR}/bin/*.exe ${CURRENT_PACKAGES_DIR}/debug/bin/*.exe)
set(FILES_TO_REMOVE ${EXP_FILES} ${LIB_FILES} ${DEF_FILES} ${EXE_FILES})
list(LENGTH FILES_TO_REMOVE FILES_TO_REMOVE_LEN)
if(FILES_TO_REMOVE_LEN GREATER 0)
    file(REMOVE ${FILES_TO_REMOVE})
endif()
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include ${CURRENT_PACKAGES_DIR}/debug/share)

vcpkg_copy_pdbs()

# Handle copyright
# TODO: Examine build log and confirm that this license matches the build output
file(COPY ${SOURCE_PATH}/COPYING.LGPLv2.1 DESTINATION ${CURRENT_PACKAGES_DIR}/share/ffmpeg)
file(RENAME ${CURRENT_PACKAGES_DIR}/share/ffmpeg/COPYING.LGPLv2.1 ${CURRENT_PACKAGES_DIR}/share/ffmpeg/copyright)
