# ─── Safe Mutex ───────────────────────────────────────────────────────
# Thin wrapper around Zephyr's k_mutex.

from zephyr_sys import k_mutex_init, k_mutex_lock, k_mutex_unlock
from zephyr.error import to_result_void, Error
from zephyr.time import Timeout
from zephyr.semaphore import TimeoutConvertible


@fieldwise_init
struct Mutex(Movable):
    """A Zephyr kernel mutex. Create with Mutex.create()."""
    var _addr: Int

    @staticmethod
    def create() raises -> Self:
        """Create a new unlocked mutex."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 32
        var buf = ctypes.create_string_buffer(size)
        var addr = Int(py=ctypes.addressof(buf))
        var result = k_mutex_init(addr)
        if result < 0:
            raise Error(UInt32(-result))
        return Self(_addr=addr)

    def lock[T: TimeoutConvertible](self, timeout: T) raises Error:
        """Lock the mutex. Blocks until acquired or timeout."""
        var t = timeout.to_k_timeout()
        try:
            to_result_void(k_mutex_lock(self._addr, t))
        except:
            raise Error(UInt32(11))  # EAGAIN

    def unlock(self) raises Error:
        """Unlock the mutex."""
        try:
            to_result_void(k_mutex_unlock(self._addr))
        except:
            raise Error(UInt32(11))
