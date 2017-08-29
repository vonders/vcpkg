include(vcpkg_common_functions)

set(SOURCE_PATH ${CURRENT_BUILDTREES_DIR}/src/glew/glew-2.1.0)

vcpkg_download_distfile(ARCHIVE_FILE
    URLS "https://sourceforge.net/projects/glew/files/glew/1.12.0/glew-1.12.0.tgz"
    FILENAME "glew-1.12.0.tgz"
    SHA512 9af4db32f6ada61f578c903fe1674f98fcaba2fb6fafced2cea2b1d82769427283d940b095c69237860357dcb1629b5227bb74a392b80da41f7be6288cbda0ae
)
vcpkg_extract_source_archive(${ARCHIVE_FILE} ${CURRENT_BUILDTREES_DIR}/src/glew)

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}/build/cmake
)

vcpkg_install_cmake()

vcpkg_fixup_cmake_targets(CONFIG_PATH "lib/cmake/glew")

foreach(FILE ${CURRENT_PACKAGES_DIR}/share/glew/glew-targets-debug.cmake ${CURRENT_PACKAGES_DIR}/share/glew/glew-targets-release.cmake)
    file(READ ${FILE} _contents)
    string(REPLACE "libglew32" "glew32" _contents "${_contents}")
    file(WRITE ${FILE} "${_contents}")
endforeach()

if(EXISTS ${CURRENT_PACKAGES_DIR}/lib/libglew32.lib)
    file(RENAME ${CURRENT_PACKAGES_DIR}/lib/libglew32.lib ${CURRENT_PACKAGES_DIR}/lib/glew32.lib)
    file(RENAME ${CURRENT_PACKAGES_DIR}/debug/lib/libglew32d.lib ${CURRENT_PACKAGES_DIR}/debug/lib/glew32d.lib)
endif()

file(REMOVE ${CURRENT_PACKAGES_DIR}/bin/glewinfo.exe)
file(REMOVE ${CURRENT_PACKAGES_DIR}/bin/visualinfo.exe)
file(REMOVE ${CURRENT_PACKAGES_DIR}/debug/bin/glewinfo.exe)
file(REMOVE ${CURRENT_PACKAGES_DIR}/debug/bin/visualinfo.exe)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/bin)
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/bin)
endif()

vcpkg_copy_pdbs()

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/share)

file(INSTALL ${SOURCE_PATH}/LICENSE.txt DESTINATION ${CURRENT_PACKAGES_DIR}/share/glew RENAME copyright)