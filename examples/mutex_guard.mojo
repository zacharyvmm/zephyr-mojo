# ─── Mutex Guard Demo ─────────────────────────────────────────────────
# Type-safe data protection with idiomatic Mutex[T].

from zephyr.sync import Mutex, Condvar
from zephyr import Forever


def main() raises:
    print("=== Mutex Guard Demo ===")
    print("")

    # Create a Mutex protecting an Int
    var mtx = Mutex[Int].create(1000)
    print("Mutex[Int] created with value 1000")

    # Lock, check, unlock
    mtx.lock(Forever())
    print("Lock acquired")
    mtx.unlock()
    print("Lock released")
    print("")

    # Condition variable
    var cv = Condvar.create()
    print("Condvar created")
    cv.signal()
    print("Signal sent")
    cv.broadcast()
    print("Broadcast sent")
    print("")

    # Sys-level mutex (Layer 2)
    from zephyr.mutex import Mutex as SysMutex
    var raw = SysMutex.create()
    raw.lock(Forever())
    print("Sys-level mutex locked")
    raw.unlock()
    print("Sys-level mutex unlocked")
    print("")

    print("Mutex guard demo complete!")
