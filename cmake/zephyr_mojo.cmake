# zephyr-mojo CMake module
#
# Provides find_package(zephyr_mojo) for Zephyr applications.
# Add to a Zephyr project to link Mojo-compiled code.
#
# Usage in CMakeLists.txt:
#
#   find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
#   project(my_app)
#
#   find_package(zephyr_mojo REQUIRED)
#   target_link_libraries(app PRIVATE zephyr_mojo)
#
#   # Add Mojo sources (when mojo build produces .o files):
#   # target_sources(app PRIVATE ${ZEPHYR_MOJO_OBJECTS})

# Determine where zephyr-mojo is installed
if(NOT DEFINED ZEPHYR_MOJO_DIR)
  set(ZEPHYR_MOJO_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../zephyr-mojo
    CACHE PATH "Path to zephyr-mojo project")
endif()

# Find Mojo compiler
find_program(MOJO_COMPILER mojo
  PATHS ${ZEPHYR_MOJO_DIR}/.venv/bin
)
if(NOT MOJO_COMPILER)
  message(WARNING "Mojo compiler not found. zephyr-mojo integration disabled.")
  set(ZEPHYR_MOJO_FOUND FALSE)
  return()
endif()

# Regenerate zephyr_sys bindings (native backend for real Zephyr)
execute_process(
  COMMAND ${CMAKE_COMMAND} -E env PYTHONPATH=${ZEPHYR_MOJO_DIR}
    python3 -m codegen.gen_sys --backend native
  WORKING_DIRECTORY ${ZEPHYR_MOJO_DIR}
  RESULT_VARIABLE gen_result
)

if(gen_result EQUAL 0)
  message(STATUS "zephyr-mojo: bindings regenerated (native backend)")
else()
  message(WARNING "zephyr-mojo: failed to regenerate bindings")
endif()

# Provide variables for applications
set(ZEPHYR_MOJO_INCLUDE_DIR ${ZEPHYR_MOJO_DIR})
set(ZEPHYR_MOJO_SOURCES ${ZEPHYR_MOJO_DIR}/zephyr_sys/__init__.mojo)

# Function to compile a Mojo source to an object file
function(zephyr_mojo_compile TARGET MOJO_SOURCE)
  set(OBJ_FILE ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.o)
  add_custom_command(
    OUTPUT ${OBJ_FILE}
    COMMAND ${MOJO_COMPILER} build ${MOJO_SOURCE} -o ${OBJ_FILE}
      -I ${ZEPHYR_MOJO_INCLUDE_DIR}
    DEPENDS ${MOJO_SOURCE}
    COMMENT "Compiling Mojo: ${MOJO_SOURCE}"
  )
  set(${TARGET}_OBJECT ${OBJ_FILE} PARENT_SCOPE)
endfunction()

set(ZEPHYR_MOJO_FOUND TRUE)
message(STATUS "zephyr-mojo: found at ${ZEPHYR_MOJO_DIR}")
