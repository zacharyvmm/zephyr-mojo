# ─── Smoke test for native FFI backend ────────────────────────────────
# Tests that the native backend output is valid Mojo syntax.
# NOTE: This file requires nightly Mojo with std.ffi support
# and will fail on stable Mojo 1.0. Use --backend ctypes for stable.

# The native backend generates code like:
#   from std.ffi import external_call, c_int, ...
#   return external_call["k_sleep", c_int, c_long_long](timeout)

# On stable Mojo, this import will fail because std.ffi doesn't exist.
# On nightly Mojo, this should compile and run (with real Zephyr symbols).

from zephyr_sys import (
    K_NO_WAIT, K_FOREVER,
    timeout_no_wait, timeout_forever, timeout_ms,
)


def main() raises:
    print("Native FFI backend smoke test")
    print("K_NO_WAIT =", K_NO_WAIT)
    print("K_FOREVER =", K_FOREVER)
    print("timeout_no_wait() =", timeout_no_wait())
    print("timeout_forever() =", timeout_forever())
    print("timeout_ms(100) =", timeout_ms(100))
    print("Native FFI imports OK")
    print("NOTE: actual C calls will fail without Zephyr symbols linked")
