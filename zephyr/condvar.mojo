# ─── Safe Condvar ─────────────────────────────────────────────────────
# A thin, safe wrapper around Zephyr's k_condvar.
# Follows the Rust zephyr::sys::sync::mutex pattern.

from zephyr_sys import k_condvar_init, k_condvar_wait, k_condvar_signal, k_condvar_broadcast
from zephyr.error import to_result_void, Error
from zephyr.time import Timeout
from zephyr.semaphore import TimeoutConvertible


struct Condvar:
    """A Zephyr condition variable.

    Used with a Mutex to wait for a condition to become true.
    """
    var _addr: Int

    def __init__(out self):
        """Create a new condition variable."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 32
        var buf = ctypes.create_string_buffer(size)
        var addr = ctypes.addressof(buf)
        self._addr = Int(Int(addr))

        var result = k_condvar_init(self._addr)
        if result < 0:
            raise Error(UInt32(-result))

    def wait[T: TimeoutConvertible](self, mutex: Int, timeout: T) raises Error:
        """Wait on the condition variable.

        The associated mutex must be locked before calling this.
        It is atomically unlocked during the wait and re-locked after.

        Args:
            mutex: The raw address of the associated k_mutex.
            timeout: Max wait time.
        """
        var t = timeout.to_k_timeout()
        to_result_void(k_condvar_wait(self._addr, mutex, t))

    def signal(self) raises Error:
        """Wake one thread waiting on this condvar."""
        to_result_void(k_condvar_signal(self._addr))

    def broadcast(self) raises Error:
        """Wake all threads waiting on this condvar."""
        to_result_void(k_condvar_broadcast(self._addr))
