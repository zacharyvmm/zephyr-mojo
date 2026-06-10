# ─── Safe Mutex ───────────────────────────────────────────────────────
# A thin, safe wrapper around Zephyr's k_mutex.
# Follows the Rust zephyr::sys::sync::mutex pattern.

from zephyr_sys import k_mutex_init, k_mutex_lock, k_mutex_unlock
from zephyr.error import to_result_void, Error
from zephyr.time import Timeout
from zephyr.semaphore import TimeoutConvertible


struct Mutex:
    """A Zephyr kernel mutex.

    Mutexes are safe to share between threads. The same thread that
    locks the mutex must unlock it. Supports recursive locking.
    """
    var _addr: Int

    def __init__(out self):
        """Create a new unlocked mutex."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 32
        var buf = ctypes.create_string_buffer(size)
        var addr = ctypes.addressof(buf)
        self._addr = Int(Int(addr))

        var result = k_mutex_init(self._addr)
        if result < 0:
            raise Error(UInt32(-result))

    def lock[T: TimeoutConvertible](self, timeout: T) raises Error:
        """Lock the mutex. Blocks until acquired or timeout.

        Args:
            timeout: Max wait time. Use Forever() or NoWait() or Duration.
        """
        var t = timeout.to_k_timeout()
        to_result_void(k_mutex_lock(self._addr, t))

    def unlock(self) raises Error:
        """Unlock the mutex. Must be called by the locking thread."""
        to_result_void(k_mutex_unlock(self._addr))
