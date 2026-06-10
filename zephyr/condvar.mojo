# ─── Safe Condvar ─────────────────────────────────────────────────────
# Thin wrapper around Zephyr's k_condvar.

from zephyr_sys import k_condvar_init, k_condvar_wait, k_condvar_signal, k_condvar_broadcast
from zephyr.error import to_result_void, Error
from zephyr.semaphore import TimeoutConvertible


@fieldwise_init
struct Condvar(Movable):
    """A Zephyr condition variable. Create with Condvar.create()."""
    var _addr: Int

    @staticmethod
    def create() raises -> Self:
        """Create a new condition variable."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 32
        var buf = ctypes.create_string_buffer(size)
        var addr = Int(py=ctypes.addressof(buf))
        var result = k_condvar_init(addr)
        if result < 0:
            raise Error(UInt32(-result))
        return Self(_addr=addr)

    def wait[T: TimeoutConvertible](self, mutex_addr: Int, timeout: T) raises Error:
        """Wait on condition variable. Mutex must be locked."""
        var t = timeout.to_k_timeout()
        to_result_void(k_condvar_wait(self._addr, mutex_addr, t))

    def signal(self) raises Error:
        """Wake one waiting thread."""
        try:
            to_result_void(k_condvar_signal(self._addr))
        except:
            raise Error(UInt32(11))

    def broadcast(self) raises Error:
        """Wake all waiting threads."""
        try:
            to_result_void(k_condvar_broadcast(self._addr))
        except:
            raise Error(UInt32(11))
