include(ExternalProject)
include(${CMAKE_TOOLCHAIN_FILE})

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
  --with-sysroot=${CMAKE_SYSROOT})

set(ICONV_CONFIGURE_STATIC_ARGS ${ICONV_CONFIGURE_ARGS} --enable-static)

set(ICONV_CONFIGURE_COMMAND ${ICONV_ENVS}
  <SOURCE_DIR>/configure ${ICONV_CONFIGURE_ARGS})

set(ICONV_BUILD_COMMAND ${ICONV_ENVS} make)

file(MAKE_DIRECTORY "${ICONV_PREFIX_DIR}/include")

ExternalProject_Add(
  libiconv
  URL ${ICONV_SOURCE}
  CONFIGURE_COMMAND ${ICONV_CONFIGURE_COMMAND}
  BUILD_COMMAND ${ICONV_BUILD_COMMAND}
  BUILD_IN_SOURCE 1
  BUILD_BYPRODUCTS "${ICONV_PREFIX_DIR}/lib/libiconv.a" "${ICONV_PREFIX_DIR}/lib/libiconv.so"
)

add_library(iconv_static STATIC IMPORTED)
add_dependencies(iconv_static libiconv)
set_target_properties(iconv_static PROPERTIES
  IMPORTED_LOCATION "${ICONV_PREFIX_DIR}/lib/libiconv.a"
  INTERFACE_INCLUDE_DIRECTORIES "${ICONV_PREFIX_DIR}/include"
  OUTPUT_NAME iconv
)

add_library(iconv_shared STATIC IMPORTED)
add_dependencies(iconv_shared libiconv)
set_target_properties(iconv_shared PROPERTIES
  IMPORTED_LOCATION "${ICONV_PREFIX_DIR}/lib/libiconv.so"
  INTERFACE_INCLUDE_DIRECTORIES "${ICONV_PREFIX_DIR}/include"
  OUTPUT_NAME iconv
)
