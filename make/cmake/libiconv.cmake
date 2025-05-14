include(ExternalProject)
include(${CMAKE_TOOLCHAIN_FILE})

if(NOT DEFINED NDK_DEFAULT_ABIS)
        get_filename_component(TOOLCHAIN_DIR "${CMAKE_TOOLCHAIN_FILE}/.." ABSOLUTE)
        include(${TOOLCHAIN_DIR}/abis.cmake)
endif()

set(ICONV_CC ${NDK_ABI_${ANDROID_ABI}_TRIPLE}${ANDROID_NATIVE_API_LEVEL}-clang)
if(${ANDROID_ABI} STREQUAL "armeabi-v7a")
        set(ICONV_CC armv7a-linux-androideabi${ANDROID_NATIVE_API_LEVEL}-clang)
endif()
set(ICONV_CC "${ANDROID_TOOLCHAIN_ROOT}/bin/${ICONV_CC}")
set(ICONV_CXX ${ICONV_CC}++)
set(ICONV_ENVS CC=${ICONV_CC}
        CXX=${ICONV_CXX}
        AR=${ANDROID_AR}
        RANLIB=${ANDROID_RANLIB}
        STRIP=${CMAKE_STRIP})
set(ICONV_VERSION "1.17")
set(ICONV_SOURCE "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${ICONV_VERSION}.tar.gz")
set(ICONV_PREFIX_DIR "${CMAKE_CURRENT_BINARY_DIR}/libiconv")

set(ICONV_CONFIGURE_ARGS --host=${CMAKE_LIBRARY_ARCHITECTURE}
        --enable-extra-encodings
        --prefix=${ICONV_PREFIX_DIR}
        --with-sysroot=${CMAKE_SYSROOT}
        --enable-static)

set(ICONV_CONFIGURE_COMMAND
        ${CMAKE_COMMAND} -E env ${ICONV_ENVS} --
        <SOURCE_DIR>/configure)

set(ICONV_BUILD_COMMAND
        ${CMAKE_COMMAND} -E env ${ICONV_ENVS} --
        make)

file(MAKE_DIRECTORY "${ICONV_PREFIX_DIR}/include")

ExternalProject_Add(
        libiconv
        URL ${ICONV_SOURCE}
        CONFIGURE_COMMAND ${ICONV_CONFIGURE_COMMAND} ${ICONV_CONFIGURE_ARGS}
        BUILD_COMMAND ${ICONV_BUILD_COMMAND}
        BUILD_IN_SOURCE 1
        BUILD_BYPRODUCTS "${ICONV_PREFIX_DIR}/lib/libiconv.a"
)

add_library(iconv STATIC IMPORTED)
add_dependencies(iconv libiconv)
set_target_properties(iconv PROPERTIES
        IMPORTED_LOCATION "${ICONV_PREFIX_DIR}/lib/libiconv.a"
        INTERFACE_INCLUDE_DIRECTORIES "${ICONV_PREFIX_DIR}/include"
        OUTPUT_NAME iconv
)
