include(ExternalProject)

set(ICONV_VERSION "1.17")
set(ICONV_SOURCE "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${ICONV_VERSION}.tar.gz")
set(ICONV_HOST_TRIPLE "${NDK_ABI_${ANDROID_ABI}_TRIPLE}")
set(ICONV_PREFIX_DIR "${CMAKE_CURRENT_BINARY_DIR}/libiconv-prefix")

set(ICONV_CONFIGURE_ARGS --host=${ICONV_HOST_TRIPLE}
                         --enable-static
                         --prefix=${ICONV_PREFIX_DIR})
# Create the include directory before CMake configuration
file(MAKE_DIRECTORY "${ICONV_PREFIX_DIR}/include")

ExternalProject_Add(
    libiconv
    URL ${ICONV_SOURCE}
    CONFIGURE_COMMAND <SOURCE_DIR>/configure ${ICONV_CONFIGURE_ARGS}
    BUILD_IN_SOURCE 1
)

add_library(iconv STATIC IMPORTED)
set_target_properties(iconv PROPERTIES
  IMPORTED_LOCATION "${ICONV_PREFIX_DIR}/lib/libiconv.a"
  INTERFACE_INCLUDE_DIRECTORIES "${ICONV_PREFIX_DIR}/include"
)

add_dependencies(iconv libiconv)