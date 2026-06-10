# ─── Kernel Object System ─────────────────────────────────────────────

from std.python import Python, PythonObject


@fieldwise_init
struct ZephyrObject(Movable):
    """A dynamically allocated Zephyr kernel object. Use ZephyrObject.create(size)."""
    var _buf: PythonObject
    var _addr: Int

    @staticmethod
    def create(size: Int) raises -> Self:
        """Allocate a kernel object of the given size in bytes."""
        var ctypes = Python.import_module("ctypes")
        var buf = ctypes.create_string_buffer(size)
        var addr = Int(py=ctypes.addressof(buf))
        return Self(_buf=buf, _addr=addr)

    def addr(self) -> Int:
        """Get the raw pointer to the kernel object."""
        return self._addr


struct Fixed:
    """A pinned kernel object allocation. Use Fixed.create(size)."""
    var _obj: ZephyrObject

    @staticmethod
    def create(size: Int) raises -> Self:
        return Self(_obj=ZephyrObject.create(size))

    def addr(self) -> Int:
        return self._obj.addr()


# ─── Kernel object sizes (approximate) ──────────────────────────────────

comptime K_SEM_SIZE: Int = 32
comptime K_MUTEX_SIZE: Int = 32
comptime K_CONDVAR_SIZE: Int = 32
comptime K_QUEUE_SIZE: Int = 32
comptime K_THREAD_SIZE: Int = 256
comptime K_TIMER_SIZE: Int = 64
comptime K_STACK_SIZE: Int = 32
comptime K_MSGQ_SIZE: Int = 64
comptime K_POLL_SIGNAL_SIZE: Int = 64
comptime K_WORK_SIZE: Int = 64
comptime K_WORK_Q_SIZE: Int = 256
comptime K_FIFO_SIZE: Int = 32
comptime K_LIFO_SIZE: Int = 32
