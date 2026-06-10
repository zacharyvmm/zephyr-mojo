# ─── Safe Semaphore ───────────────────────────────────────────────────
# A thin, safe wrapper around Zephyr's k_sem.

from zephyr_sys import k_sem_init, k_sem_take, k_sem_give, k_sem_reset, k_sem_count_get
from zephyr.error import to_result_void, to_result, Error
from zephyr.time import Timeout


@fieldwise_init
struct Semaphore(Movable, Copyable):
    """A Zephyr counting semaphore. Thread-safe and ISR-safe.

    Create with Semaphore.create(initial_count, limit).
    """
    var _addr: Int

    @staticmethod
    def create(initial_count: Int, limit: Int) raises -> Self:
        """Create a new semaphore with the given initial count and limit."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var sem_size: Int = 32
        var sem_buf = ctypes.create_string_buffer(sem_size)
        var addr = Int(py=ctypes.addressof(sem_buf))

        var result = k_sem_init(addr, UInt32(initial_count), UInt32(limit))
        if result < 0:
            raise Error(UInt32(-result))
        return Self(_addr=addr)

    def take[T: TimeoutConvertible](self, timeout: T) raises Error:
        """Take (decrement) the semaphore. May block."""
        var t = timeout.to_k_timeout()
        try:
            to_result_void(k_sem_take(self._addr, t))
        except:
            raise Error(UInt32(11))  # EAGAIN

    def give(self) raises:
        """Give (increment) the semaphore. Never blocks."""
        k_sem_give(self._addr)

    def reset(self) raises:
        """Reset count to zero."""
        k_sem_reset(self._addr)

    def count(self) raises -> Int:
        """Get current count."""
        return Int(k_sem_count_get(self._addr))


# ─── TimeoutConvertible trait ──────────────────────────────────────────

trait TimeoutConvertible:
    def to_k_timeout(self) -> Int64:
        ...


@fieldwise_init
struct Forever(TimeoutConvertible):
    def to_k_timeout(self) -> Int64:
        return Timeout.forever().raw


@fieldwise_init
struct NoWait(TimeoutConvertible):
    def to_k_timeout(self) -> Int64:
        return Timeout.no_wait().raw
