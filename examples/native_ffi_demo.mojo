# ─── Native FFI Example ────────────────────────────────────────────────
# Demonstrates the native FFI backend (requires Mojo nightly with std.ffi).
#
# Prerequisites:
#   1. Install Mojo nightly (when Linux wheels are available):
#      uv pip install mojo --prerelease=allow --index-url https://whl.modular.com/nightly/simple/
#
#   2. Switch to native backend:
#      python3 scripts/switch_backend.py native
#
#   3. Run this example (on native_sim or real Zephyr):
#      mojo run -I . examples/native_ffi_demo.mojo
#
# The native backend generates zero-overhead C calls:
#   external_call["k_sem_init", c_int, Int, c_uint, c_uint](sem, count, limit)
#
# This eliminates the Python ctypes overhead entirely (~1μs → ~50ns).

from zephyr import Semaphore, Forever, NoWait
from zephyr.time import Duration, sleep


def main() raises:
    print("=== Native FFI Demo ===")
    print("")
    print("Backend: native (std.ffi.external_call)")
    print("Overhead: ~50ns per call (vs ~1μs for ctypes)")
    print("")

    # All safe wrappers work identically regardless of backend
    var sem = Semaphore.create(0, 10)
    print("Semaphore created (native FFI)")

    sem.give()
    print("Semaphore given")

    sem.take(Forever())
    print("Semaphore taken")

    _ = sleep(Duration.from_ms(10))

    # On real Zephyr: kernel functions resolve at link time
    # On native_sim: symbols exported from the Zephyr binary
    print("")
    print("Native FFI demo complete!")
    print("")
    print("Key difference from ctypes backend:")
    print("  Before: Mojo -> Python ctypes -> dlsym -> C function")
    print("  After:  Mojo -> external_call -> C function (direct)")
    print("")
    print("Generated LLVM IR links directly to Zephyr symbols.")
    print("No Python runtime needed on the target device.")
