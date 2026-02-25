cmake_minimum_required(VERSION 3.30)
project(oj-libjdwp)

find_package(Python3 REQUIRED)

include(make/cmake/java.cmake)
include(make/cmake/libiconv.cmake)

option(BUILD_FAT_LIB "Whether or not to build a independent (fat) shared library" OFF)

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

set(C_FLAGS -D_LITTLE_ENDIAN -Wall -Wno-unused-parameter -Wno-unused-but-set-variable)

if(DEFINED ANDROID_NATIVE_LIB_SEARCH_PATH)
    set(C_FLAGS ${C_FLAGS} "-DANDROID_NATIVE_LIB_SEARCH_PATH=${ANDROID_NATIVE_LIB_SEARCH_PATH}")
endif()

set(JAVA_VM_HEADERS src/share/javavm/export
    src/solaris/javavm/export)

set(NPT_HEADERS src/share/npt
    src/solaris/npt)

set(JDWP_HEADERS src/share/back
    src/share/back/export
    src/solaris/back
    ${JDWP_GEN_HEADERS})

# Build npt obj
file(GLOB NPT_SOURCES src/share/npt/*.c src/solaris/npt/*.c)
add_library(npt_obj OBJECT ${NPT_SOURCES})
include_directories(npt_obj ${JAVA_VM_HEADERS} ${NPT_HEADERS})
target_link_libraries(npt_obj iconv log)
target_compile_options(npt_obj PRIVATE ${C_FLAGS})
set_property(TARGET npt_obj PROPERTY POSITION_INDEPENDENT_CODE ON)

# Build jdwp
file(GLOB JDWP_SOURCES src/share/back/*.c src/solaris/back/*.c)
add_library(jdwp_obj OBJECT ${JDWP_SOURCES})
add_dependencies(jdwp_obj jdwpgen_includes jdwpgen_jdi)
include_directories(jdwp_obj ${JDWP_HEADERS})
target_link_libraries(jdwp_obj log)
target_compile_options(jdwp_obj PRIVATE
    ${C_FLAGS}
    -DLINUX
    -DJDWP_LOGGING
    -Wno-switch
    -Wno-logical-op-parentheses
    -Wno-logical-not-parentheses
    -Wno-sometimes-uninitialized
    -Wno-self-assign
    -Wno-unused-variable
    -Wno-unused-function)
set_property(TARGET jdwp_obj PROPERTY POSITION_INDEPENDENT_CODE ON)

# Build libdt_socket
file(GLOB DTSOCKET_SOURCES src/share/transport/socket/*.c src/solaris/transport/socket/*.c)
add_library(dt_socket_obj OBJECT ${DTSOCKET_SOURCES})
add_dependencies(dt_socket_obj jdwpgen_includes)
target_link_libraries(dt_socket_obj log)
include_directories(dt_socket_obj src/share/transport/socket
    src/solaris/transport/socket
    ${JAVA_VM_HEADERS}
    ${JDWP_HEADERS}
    ${NPT_HEADERS})

set_property(TARGET dt_socket_obj PROPERTY POSITION_INDEPENDENT_CODE ON)

add_library(npt SHARED $<TARGET_OBJECTS:npt_obj>)
target_link_libraries(npt iconv log)

add_library(jdwp SHARED $<TARGET_OBJECTS:jdwp_obj>)
target_link_libraries(jdwp log)

add_library(dt_socket SHARED $<TARGET_OBJECTS:dt_socket_obj>)
target_link_libraries(dt_socket log)

if(BUILD_FAT_LIB)
    add_library(jdwp_fat SHARED
        $<TARGET_OBJECTS:npt_obj>
        $<TARGET_OBJECTS:jdwp_obj>
        $<TARGET_OBJECTS:dt_socket_obj>)

    target_link_libraries(jdwp_fat iconv log)

    target_compile_definitions(jdwp_fat PRIVATE JDWP_FAT_BUILD)
endif()

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
