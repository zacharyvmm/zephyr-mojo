# CMakeLists.txt for zephyr-mojo native_sim integration
#
# Builds a Zephyr native_sim application as a shared library
# that Mojo code can load via ctypes.
#
# Prerequisites:
#   pip install west
#   west init -l /path/to/zephyr
#   west update
#   Install Zephyr SDK or use host toolchain
#
# Build:
#   west build -b native_sim -d build
#
# The resulting binary is at build/zephyr/zephyr.elf
# (or build/zephyr/libzephyr.so if configured as shared)

cmake_minimum_required(VERSION 3.20)

# Find Zephyr (must be in ZEPHYR_BASE or found via west)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

project(zephyr_mojo_native_sim)

# Target: build as a shared library so Mojo can load it
# set(BOARD native_sim)  # Set via west build -b flag

# Include the C wrapper
target_sources(app PRIVATE zephyr_mojo_wrapper.c)

# Enable features needed by our bindings
# CONFIG_PRINTK=y is usually default
# CONFIG_SEMAPHORE=y, CONFIG_MUTEX=y etc. are default in Zephyr

# For debugging: increase main stack
# set(KCONFIG_MAIN_STACK_SIZE 4096)

# Enable dynamic thread stacks (optional, for Thread object)
# set(CONFIG_DYNAMIC_THREAD y)

message(STATUS "zephyr-mojo: building native_sim integration")
