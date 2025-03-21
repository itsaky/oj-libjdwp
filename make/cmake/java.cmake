find_package(Java REQUIRED)
find_package(Java COMPONENTS Runtime)
find_package(Java COMPONENTS Development)
find_package(JNI REQUIRED)

if(NOT ${Java_VERSION_MAJOR} EQUAL "1" AND NOT ${Java_VERSION_MINOR} EQUAL "8")
    message(FATAL_ERROR "${CMAKE_PROJECT_NAME} requires JDK 8 to build")
endif()

include(UseJava)

execute_process(
    COMMAND ${Java_JAVA_EXECUTABLE} -XshowSettings:properties -version
    ERROR_VARIABLE java_settings
    OUTPUT_QUIET
)

string(REGEX MATCH "java\\.home = ([^\n]+)" _ ${java_settings})
set(JAVA_HOME ${CMAKE_MATCH_1})
message(STATUS "Java home: ${JAVA_HOME}")

if(WIN32)
    set(RT_JAR_PATH "${JAVA_HOME}/lib/rt.jar")
else()
    if(EXISTS "${JAVA_HOME}/jre/lib/rt.jar")
        set(RT_JAR_PATH "${JAVA_HOME}/jre/lib/rt.jar")
    else()
        set(RT_JAR_PATH "${JAVA_HOME}/lib/rt.jar")
    endif()
endif()

if(NOT EXISTS ${RT_JAR_PATH})
    message(WARNING "rt.jar not found at ${RT_JAR_PATH}")
else()
    message(STATUS "Found rt.jar: ${RT_JAR_PATH}")
endif()

set(JAVA8_RT_JAR ${RT_JAR_PATH})
set(JAVA8_JNI_H ${JNI_INCLUDE_DIRS})

set(CMAKE_JAVA_COMPILE_FLAGS -source 8 -target 8 -bootclasspath ${JAVA8_RT_JAR})

function(add_jar_run_command JAR_TARGET RUN_TARGET_NAME OUTPUT)
    add_custom_command(
        OUTPUT ${OUTPUT}
        COMMAND ${Java_JAVA_EXECUTABLE} -jar $<TARGET_PROPERTY:${JAR_TARGET},JAR_FILE> ${ARGN}
        DEPENDS ${JAR_TARGET}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Running ${JAR_TARGET}.jar with arguments: ${ARGN}"
    )
    add_custom_target(${RUN_TARGET_NAME}
        DEPENDS ${OUTPUT})
endfunction()
