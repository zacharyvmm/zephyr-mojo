# ─── ctypes overhead benchmark ────────────────────────────────────────
# Measures the overhead of Python ctypes calls vs direct C calls.
# Requires Zephyr symbols loaded (native_sim or real hardware).

from std.python import Python
from zephyr_sys import k_uptime_ticks, K_NO_WAIT, timeout_no_wait


def main() raises:
    print("=== zephyr-mojo ctypes benchmark ===")
    print("")

    # Benchmark 1: Pure Mojo operations (no FFI)
    print("--- Pure Mojo (no FFI) ---")
    var iterations: Int = 1000
    var start = k_uptime_ticks()
    var sum: Int64 = 0
    for i in range(iterations):
        sum += Int64(i)
    var end = k_uptime_ticks()
    print(iterations, "iterations:", end - start, "ticks")
    print("")

    # Benchmark 2: ctypes call overhead
    print("--- ctypes call (k_uptime_ticks) ---")
    start = k_uptime_ticks()
    for _ in range(iterations):
        var _ = k_uptime_ticks()
    end = k_uptime_ticks()
    var total_ticks = end - start
    var per_call = Float64(Int(total_ticks)) / Float64(iterations)
    print(iterations, "calls:", total_ticks, "ticks total")
    print("Per call:", per_call, "ticks (", per_call / 1000.0, "ms at 1MHz)")
    print("")

    # Benchmark 3: Timeout helper (pure Mojo, no FFI)
    print("--- Timeout helper (no FFI) ---")
    start = k_uptime_ticks()
    for _ in range(iterations):
        var _ = timeout_no_wait()
    end = k_uptime_ticks()
    total_ticks = end - start
    per_call = Float64(Int(total_ticks)) / Float64(iterations)
    print(iterations, "calls:", total_ticks, "ticks total")
    print("Per call:", per_call, "ticks")
    print("")

    # Summary
    print("=== Summary ===")
    print("All benchmarks require Zephyr symbols to be meaningful.")
    print("Run under native_sim or real hardware for actual measurements.")
    print("On host without Zephyr, k_uptime_ticks returns 0 (no overhead).")
