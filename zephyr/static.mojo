# ─── Static Kernel Object Allocation ──────────────────────────────────
# Macros and patterns for compile-time kernel object allocation.
#
# On real Zephyr, kernel objects must be statically allocated and
# registered in the kernel object hash table. This module provides
# comptime helpers that mirror Zephyr's K_SEM_DEFINE, K_MUTEX_DEFINE, etc.
#
# For host testing via ctypes, these allocate memory dynamically.
# On real Zephyr with native FFI, these would use linker sections.

from zephyr.object import (
    K_SEM_SIZE, K_MUTEX_SIZE, K_CONDVAR_SIZE,
    K_QUEUE_SIZE, K_TIMER_SIZE, K_THREAD_SIZE,
    K_STACK_SIZE,
)


# ─── Static Semaphore ──────────────────────────────────────────────────
#
# Usage:
#   comptime MY_SEM = StaticSemaphore(initial_count=0, limit=1)
#   MY_SEM.give()
#   MY_SEM.take(Forever())


struct StaticSemaphore:
    """A statically allocated semaphore. Initialize once, use anywhere."""
    var _initial_count: Int
    var _limit: Int
    var _addr: Int  # 0 until initialized

    def __init__(out self, initial_count: Int, limit: Int):
        self._initial_count = initial_count
        self._limit = limit
        self._addr = 0

    def init(mut self) raises:
        """Initialize the underlying k_sem. Call once at startup."""
        if self._addr != 0:
            return  # Already initialized
        from zephyr.semaphore import Semaphore
        var sem = Semaphore.create(self._initial_count, self._limit)
        self._addr = sem._addr

    def give(self) raises:
        """Give the semaphore."""
        from zephyr_sys import k_sem_give
        k_sem_give(self._addr)

    def take(self, timeout: Int64) raises:
        """Take the semaphore."""
        from zephyr_sys import k_sem_take
        var _ = k_sem_take(self._addr, timeout)


# ─── Static Mutex ──────────────────────────────────────────────────────


struct StaticMutex:
    """A statically allocated mutex."""
    var _addr: Int

    def __init__(out self):
        self._addr = 0

    def init(mut self) raises:
        if self._addr != 0:
            return
        from zephyr.mutex import Mutex
        var m = Mutex.create()
        self._addr = m._addr

    def lock(self, timeout: Int64) raises:
        from zephyr_sys import k_mutex_lock
        var _ = k_mutex_lock(self._addr, timeout)

    def unlock(self) raises:
        from zephyr_sys import k_mutex_unlock
        var _ = k_mutex_unlock(self._addr)


# ─── Static Thread ─────────────────────────────────────────────────────


struct StaticThread:
    """A statically allocated thread.

    Usage:
        var MY_STACK = StaticThreadStack(2048)
        var MY_THREAD = StaticThread()
        MY_THREAD.init(MY_STACK, entry_fn_ptr, "my_thread")
    """
    var _addr: Int
    var _stack_addr: Int
    var _stack_size: Int

    def __init__(out self):
        self._addr = 0

    def init(mut self, stack: StaticThreadStack, entry: Int, name: String) raises:
        """Initialize and start the thread."""
        from zephyr_sys import k_thread_create, k_thread_name_set
        from std.python import Python
        var obj = Python.import_module("ctypes").create_string_buffer(K_THREAD_SIZE)
        self._addr = Int(py=Python.import_module("ctypes").addressof(obj))
        self._stack_addr = stack._addr
        self._stack_size = stack._size
        var _ = k_thread_create(
            self._addr, self._stack_addr, self._stack_size,
            entry, 0, 0, 0, 7, 0, 0  # priority 7, K_NO_WAIT
        )
        if name != "":
            var py_name = Python.import_module("ctypes").c_char_p(
                Python.import_module("builtins").bytes(name, "utf-8")
            )
            var _ = k_thread_name_set(self._addr, Int(py=Python.import_module("builtins").id(py_name)))


struct StaticThreadStack:
    """A statically allocated thread stack."""
    var _addr: Int
    var _size: Int

    def __init__(out self, size: Int):
        from std.python import Python
        var obj = Python.import_module("ctypes").create_string_buffer(size)
        self._addr = Int(py=Python.import_module("ctypes").addressof(obj))
        self._size = size
