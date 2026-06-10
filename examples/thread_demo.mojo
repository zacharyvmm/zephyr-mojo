# ─── Thread Demo ──────────────────────────────────────────────────────
# Thread utilities, priority management, and ThreadBuilder API.

from zephyr import (
    Thread, ThreadStack, ThreadBuilder,
    THREAD_PRIORITY_IDLE, THREAD_PRIORITY_HIGH,
    THREAD_PRIORITY_NORMAL, THREAD_PRIORITY_LOW, THREAD_PRIORITY_COOP,
)


def main() raises:
    print("=== Thread Demo ===")
    print("")

    # Thread utilities
    print("--- Utilities ---")
    print("Current thread ID:", Thread.current())
    print("Is preemptible:", Thread.is_preemptible())

    Thread.busy_wait(UInt32(1000))
    print("Busy-wait 1000μs done")

    Thread.yield_()
    print("Yield done")
    print("")

    # Priority constants
    print("--- Priority Levels ---")
    print("  IDLE:  ", THREAD_PRIORITY_IDLE)
    print("  LOW:   ", THREAD_PRIORITY_LOW)
    print("  NORMAL:", THREAD_PRIORITY_NORMAL)
    print("  HIGH:  ", THREAD_PRIORITY_HIGH)
    print("  COOP:  ", THREAD_PRIORITY_COOP)
    print("")

    # ThreadBuilder
    print("--- ThreadBuilder ---")
    var stack = ThreadStack.create(2048)
    print("Stack allocated:", stack.size(), "bytes")

    var builder = ThreadBuilder()
    builder.set_priority(THREAD_PRIORITY_NORMAL)
    builder.set_name("demo_thread")
    print("ThreadBuilder configured OK")
    print("")

    # Lifecycle (pseudo-code for real Zephyr)
    print("--- Lifecycle (real Zephyr) ---")
    print("# t = builder.spawn(stack.base(), stack.size(), entry_fn)")
    print("# t.suspend() / t.resume()")
    print("# t.join(K_FOREVER)")
    print("# t.abort()")
    print("")
    print("Thread demo complete!")
