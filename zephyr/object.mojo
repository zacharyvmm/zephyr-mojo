# ─── Kernel Object System ─────────────────────────────────────────────
# Abstraction for Zephyr kernel objects (static and dynamic allocation).
# Inspired by the Rust zephyr::object module.
#
# Zephyr kernel objects (k_sem, k_mutex, k_thread, etc.) need special
# handling for:
#   - Static allocation (placed in special linker sections)
#   - Userspace permission grants (CONFIG_USERSPACE)
#   - Kernel object validation (compile-time hash tables)
#
# This module provides two allocation strategies:
#   ZephyrObject<T>  — Dynamic (heap) allocation via ctypes
#   Fixed<T>          — Pinned allocation (prevents moving)

from std.python import Python, PythonObject


struct ZephyrObject:
    """A dynamically allocated Zephyr kernel object.

    Allocates memory via Python ctypes and provides a raw pointer
    to the underlying C struct. The memory is pinned — the object
    cannot be moved after initialization, as Zephyr may hold internal
    pointers to it.

    Usage:
        var sem_obj = ZephyrObject(32)  # 32 bytes for k_sem
        var sem_addr = sem_obj.addr()
        k_sem_init(sem_addr, 0, 10)
    """
    var _buf: PythonObject  # ctypes string buffer
    var _addr: Int

    def __init__(out self, size: Int):
        """Allocate a kernel object of the given size in bytes."""
        var ctypes = Python.import_module("ctypes")
        self._buf = ctypes.create_string_buffer(size)
        self._addr = Int(py=ctypes.addressof(self._buf))

    def addr(self) -> Int:
        """Get the raw pointer to the kernel object."""
        return self._addr


struct Fixed:
    """A pinned kernel object allocation.

    Similar to ZephyrObject but guarantees the object will never be
    moved. This is important for objects like k_poll_signal where
    Zephyr may hold internal pointers across calls.

    The object cannot be copied or moved after construction.
    """
    var _obj: ZephyrObject

    def __init__(out self, size: Int):
        self._obj = ZephyrObject(size)

    def addr(self) -> Int:
        """Get the raw pointer to the pinned object."""
        return self._obj.addr()


# ─── Kernel object sizes (approximate, arch-dependent) ──────────────────

# These sizes are estimates for 64-bit systems. On real Zephyr,
# sizeof() would be used at build time. For host testing via ctypes,
# these generous estimates ensure enough space.

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
