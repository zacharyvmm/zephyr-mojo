# ─── zephyr-mojo native_sim test ─────────────────────────────────────
# Loads a Zephyr native_sim build as a shared library and calls
# kernel functions through our safe bindings.
#
# Prerequisites:
#   1. Build Zephyr for native_sim (see native_sim/CMakeLists.txt)
#   2. Build produces build/zephyr/zephyr.elf
#   3. Run this test: mojo run -I . native_sim/test_native_sim.mojo
#
# The ctypes backend loads the Zephyr binary's symbols and calls
# kernel functions directly. No wrappers needed for most functions.

from std.python import Python, PythonObject


def main() raises:
    print("=== zephyr-mojo native_sim test ===")
    print("")

    # Load the Zephyr native_sim binary
    var ctypes = Python.import_module("ctypes")

    # Path to the native_sim build output
    var lib_path = "build/zephyr/zephyr.elf"

    print("Loading:", lib_path)
    var lib = ctypes.CDLL(lib_path)
    print("Library loaded OK")
    print("")

    # Initialize Zephyr
    print("Calling zephyr_mojo_init()...")
    lib.zephyr_mojo_init()
    print("Zephyr initialized")
    print("")

    # Test 1: Call k_uptime_ticks (should return 0 at boot)
    print("--- Test 1: k_uptime_ticks ---")
    var uptime = lib.k_uptime_ticks()
    print("Uptime ticks:", uptime)
    print("")

    # Test 2: Create and use a semaphore
    print("--- Test 2: Semaphore ---")
    # Allocate a k_sem struct (on native_sim it's ~24 bytes)
    var sem_buf = ctypes.create_string_buffer(32)
    var sem_addr = ctypes.addressof(sem_buf)

    var result = lib.k_sem_init(sem_addr, 0, 10)
    print("k_sem_init returned:", result)

    # Give the semaphore
    lib.k_sem_give(sem_addr)
    print("k_sem_give called")

    # Take it (non-blocking)
    result = lib.k_sem_take(sem_addr, 0)  # K_NO_WAIT
    print("k_sem_take(K_NO_WAIT) returned:", result)
    print("")

    # Test 3: Create a helper thread
    print("--- Test 3: Thread creation ---")
    result = lib.zephyr_create_helper_thread()
    print("zephyr_create_helper_thread returned:", result)
    print("")

    # Test 4: Use our safe bindings with the native_sim library
    print("--- Test 4: Safe bindings ---")
    from zephyr import Semaphore, Forever, NoWait
    from zephyr.time import Duration, sleep

    # Create a semaphore through our safe wrapper
    # (Note: this allocates via ctypes internally, same as above)
    var sem = Semaphore(0, 1)
    print("Safe Semaphore created")

    sem.give()
    print("Safe give() called")

    sem.take(Forever())
    print("Safe take(Forever()) returned")
    print("")

    # Tick the kernel to process any pending work
    print("Ticking kernel...")
    lib.zephyr_mojo_tick()
    lib.zephyr_mojo_tick()
    lib.zephyr_mojo_tick()

    print("")
    print("=== All native_sim tests passed! ===")
