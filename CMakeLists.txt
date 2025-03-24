cmake_minimum_required(VERSION 3.30)

find_package(Python3 REQUIRED)

include(make/cmake/java.cmake)
include(make/cmake/libiconv.cmake)

project(oj-libjdwp)

# Build jdwpgen.jar
file(GLOB JDWPGEN_SOURCES make/src/classes/build/tools/jdwpgen/*.java)
add_jar(jdwpgen
    SOURCES ${JDWPGEN_SOURCES}
    MANIFEST etc/manifest.txt)

# Build JDWPCommands.h header
set(JDWP_GEN_HEADERS ${CMAKE_CURRENT_BINARY_DIR}/jdwpgen_include)
set(JDWP_GEN_HEADER_FILE ${JDWP_GEN_HEADERS}/JDWPCommands.h)
file(MAKE_DIRECTORY ${JDWP_GEN_HEADERS})
add_jar_run_command(jdwpgen jdwpgen_includes ${JDWP_GEN_HEADER_FILE}
    ${CMAKE_CURRENT_SOURCE_DIR}/make/data/jdwp/jdwp.spec -include ${JDWP_GEN_HEADER_FILE})

# Build JDWP.java from JDWP spec
set(JDWP_GEN_JDI ${CMAKE_CURRENT_BINARY_DIR}/jdwpgen_jdi)
set(JDWP_GEN_JDI_OUT ${JDWP_GEN_JDI}/JDWP.java)
file(MAKE_DIRECTORY ${JDWP_GEN_JDI})
add_jar_run_command(jdwpgen jdwpgen_jdi ${JDWP_GEN_JDI_OUT}
    ${CMAKE_CURRENT_SOURCE_DIR}/make/data/jdwp/jdwp.spec -jdi ${JDWP_GEN_JDI_OUT})

# Build jdwp messages classes from jdwp.properties
set(JDI_PROP ${CMAKE_CURRENT_BINARY_DIR}/jdwp_prop)
set(JDI_PROP_IN ${CMAKE_CURRENT_SOURCE_DIR}/src/share/classes/com/sun/tools/jdi/resources/jdi.properties)
set(JDI_PROP_OUT ${JDI_PROP}/jdi.java)
file(MAKE_DIRECTORY ${JDI_PROP})
add_custom_command(
    OUTPUT ${JDI_PROP_OUT}
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/etc/jdigen.py ${JDI_PROP_IN} ${JDI_PROP_OUT}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Generating jdi.java with Python script"
)
add_custom_target(jdwp_jdi_propgen
    DEPENDS ${JDI_PROP_OUT})

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_LITTLE_ENDIAN -Wall -Wno-unused-parameter -Wno-unused-but-set-variable")

set(JAVA_VM_HEADERS src/share/javavm/export
    src/solaris/javavm/export)

set(NPT_HEADERS src/share/npt
    src/solaris/npt)

set(JDWP_HEADERS src/share/back
    src/share/back/export
    src/solaris/back
    ${JDWP_GEN_HEADERS})

# Build libnpt
file(GLOB NPT_SOURCES src/share/npt/*.c src/solaris/npt/*.c)
add_library(npt OBJECT ${NPT_SOURCES})
include_directories(npt ${JAVA_VM_HEADERS} ${NPT_HEADERS})
target_link_libraries(npt iconv_static)

add_library(npt_shared SHARED $<TARGET_OBJECTS:npt>)
target_link_libraries(npt_shared PRIVATE iconv_shared)
set_target_properties(npt_shared PROPERTIES
  OUTPUT_NAME npt
)

add_library(npt_static STATIC $<TARGET_OBJECTS:npt>)
target_link_libraries(npt_static PRIVATE iconv_static)
set_target_properties(npt_static PROPERTIES
  OUTPUT_NAME npt
)

# Build libjdwp
file(GLOB JDWP_SOURCES src/share/back/*.c src/solaris/back/*.c)
add_library(jdwp OBJECT ${JDWP_SOURCES})
add_dependencies(jdwp jdwpgen_includes jdwpgen_jdi)
include_directories(jdwp ${JDWP_HEADERS})
target_compile_options(jdwp PRIVATE
    -DLINUX
    -DJDWP_LOGGING
    -Wno-switch
    -Wno-logical-op-parentheses
    -Wno-logical-not-parentheses
    -Wno-sometimes-uninitialized
    -Wno-self-assign
    -Wno-unused-variable
    -Wno-unused-function)

add_library(jdwp_shared SHARED $<TARGET_OBJECTS:jdwp>)
set_target_properties(jdwp_shared PROPERTIES
  OUTPUT_NAME jdwp
)
add_library(jdwp_static STATIC $<TARGET_OBJECTS:jdwp>)
set_target_properties(jdwp_static PROPERTIES
  OUTPUT_NAME jdwp
)

# Build libdt_socket
file(GLOB DTSOCKET_SOURCES src/share/transport/socket/*.c src/solaris/transport/socket/*.c)
add_library(dt_socket OBJECT ${DTSOCKET_SOURCES})
add_dependencies(dt_socket jdwpgen_includes)
include_directories(dt_socket src/share/transport/socket
    src/solaris/transport/socket
    ${JAVA_VM_HEADERS}
    ${JDWP_HEADERS}
    ${NPT_HEADERS})

add_library(dt_socket_shared SHARED $<TARGET_OBJECTS:dt_socket>)
set_target_properties(dt_socket_shared PROPERTIES
  OUTPUT_NAME dt_socket
)
add_library(dt_socket_static STATIC $<TARGET_OBJECTS:dt_socket>)
set_target_properties(dt_socket_static PROPERTIES
  OUTPUT_NAME dt_socket
)

# Build jdi-support
file(GLOB_RECURSE JDI_SUPPORT_SOURCES
    src/share/classes/com/sun/**/*.java
)
list(REMOVE_ITEM JDI_SUPPORT_SOURCES
    # We don't support process attachment and lack some of the classes to even compile this file.
    ${CMAKE_CURRENT_SOURCE_DIR}/src/share/classes/com/sun/tools/jdi/ProcessAttachingConnector.java
)
set(CMAKE_JAVA_COMPILE_FLAGS ${CMAKE_JAVA_COMPILE_FLAGS} -g)
add_jar(jdi-support
    SOURCES ${JDI_SUPPORT_SOURCES} ${JDWP_GEN_JDI_OUT} ${JDI_PROP_OUT}
    RESOURCES NAMESPACE "META-INF/services" ${CMAKE_CURRENT_SOURCE_DIR}/etc/com.sun.jdi.connect.Connector)
add_dependencies(jdi-support jdwpgen_jdi jdwp_jdi_propgen)
