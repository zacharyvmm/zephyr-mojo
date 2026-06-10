# ─── Safe Semaphore ───────────────────────────────────────────────────
# A thin, safe wrapper around Zephyr's k_sem.
# Follows the Rust zephyr::sys::sync::semaphore pattern.

from zephyr_sys import k_sem_init, k_sem_take, k_sem_give, k_sem_reset, k_sem_count_get
from zephyr.error import to_result_void, to_result, Error
from zephyr.time import Timeout


struct Semaphore:
    """A Zephyr counting semaphore.

    Semaphores are safe to share between threads and ISRs.
    Use `take()` to decrement (blocking), `give()` to increment.
    """
    var _addr: Int  # Raw pointer to k_sem struct

    def __init__(out self, initial_count: Int, limit: Int):
        """Create a new semaphore. The semaphore's memory must be
        pre-allocated (statically or on the heap)."""
        # Allocate memory for the k_sem struct
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        # k_sem is typically ~16-24 bytes depending on arch
        var sem_size: Int = 32
        var sem_buf = ctypes.create_string_buffer(sem_size)
        var addr = ctypes.addressof(sem_buf)
        self._addr = Int(Int(addr))

        var result = k_sem_init(self._addr, UInt32(initial_count), UInt32(limit))
        if result < 0:
            raise Error(UInt32(-result))

    def take[T: TimeoutConvertible](self, timeout: T) raises Error:
        """Take the semaphore (decrement count). May block.

        Args:
            timeout: How long to wait. Use Timeout.forever(), Timeout.no_wait(),
                     or a Duration.
        Raises:
            Error: If the operation fails (timeout, etc.).
        """
        var t = timeout.to_k_timeout()
        to_result_void(k_sem_take(self._addr, t))

    def give(self):
        """Give the semaphore (increment count). Never blocks."""
        k_sem_give(self._addr)

    def reset(self):
        """Reset the semaphore count to zero."""
        k_sem_reset(self._addr)

    def count(self) -> Int:
        """Get the current semaphore count."""
        return Int(k_sem_count_get(self._addr))


# ─── TimeoutConvertible trait ──────────────────────────────────────────

trait TimeoutConvertible:
    def to_k_timeout(self) -> Int64:
        ...


# Implement for built-in types
# (These need to be in the same file as the trait for Mojo's coherence rules)

struct Forever(TimeoutConvertible):
    def to_k_timeout(self) -> Int64:
        return Timeout.forever().raw


struct NoWait(TimeoutConvertible):
    def to_k_timeout(self) -> Int64:
        return Timeout.no_wait().raw
