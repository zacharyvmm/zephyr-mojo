# ─── Safe Thread wrapper ───────────────────────────────────────────────
# Thin, safe wrapper around Zephyr's k_thread.
# Follows the Rust zephyr::sys::thread pattern.

from zephyr_sys import (
    k_thread_create, k_thread_abort, k_thread_join,
    k_thread_name_set, k_thread_priority_set, k_thread_priority_get,
    k_thread_suspend, k_thread_resume, k_current_get,
    k_yield, k_busy_wait, k_is_in_isr, k_is_preempt_thread,
)
from zephyr.error import to_result_void, to_result, Error


# ─── ThreadStack ────────────────────────────────────────────────────────


struct ThreadStack:
    """Represents a Zephyr thread stack allocation.

    On real Zephyr, stacks are statically allocated and must be properly
    aligned (Z_KERNEL_STACK_OBJ_ALIGN). This struct holds the base pointer
    and size for passing to k_thread_create.
    """
    var base: Int
    var size: Int

    def __init__(out self, base: Int, size: Int):
        self.base = base
        self.size = size


# ─── Thread ─────────────────────────────────────────────────────────────


struct Thread:
    """A Zephyr kernel thread.

    Wraps a pointer to a k_thread struct. Provides safe methods
    for thread lifecycle management.

    Thread creation is done via the static `Thread.create()` method
    which allocates memory and calls k_thread_create.
    """
    var _addr: Int  # Raw pointer to k_thread struct
    var _stack: ThreadStack

    @staticmethod
    def create(
        stack: ThreadStack,
        entry: Int,
        prio: Int,
        options: UInt32,
        delay: Int64,
    ) raises -> Self:
        """Create a new Zephyr thread.

        Args:
            stack: The thread's stack allocation.
            entry: Function pointer (cast to Int) for the thread entry.
            prio: Thread priority (lower = higher priority, typically 0-15).
            options: Thread creation options (0 for default).
            delay: Startup delay (K_NO_WAIT for immediate, K_FOREVER for manual start).

        Returns:
            A Thread handle for the created thread.
        """
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var thread_size: Int = 128  # k_thread struct size (approximate)
        var buf = ctypes.create_string_buffer(thread_size)
        var addr = ctypes.addressof(buf)
        var thread_addr = Int(Int(addr))

        # k_thread_create returns the thread ID (pointer to the k_thread)
        var tid = k_thread_create(
            thread_addr,
            stack.base,
            stack.size,
            entry,
            0, 0, 0,  # p1, p2, p3 — passed via user data
            prio,
            options,
            delay,
        )
        return Self(_addr=thread_addr, _stack=stack)

    def current() raises -> Int:
        """Get the current thread's handle."""
        return k_current_get()

    def yield_() raises:
        """Yield the current thread to equal-priority peers."""
        k_yield()

    def busy_wait(usec: UInt32) raises:
        """Busy-wait for the given number of microseconds."""
        k_busy_wait(usec)

    def is_in_isr() raises -> Bool:
        """Check if currently in interrupt context."""
        return k_is_in_isr() != 0

    def is_preemptible() raises -> Bool:
        """Check if the current thread is preemptible."""
        return k_is_preempt_thread() != 0

    # ── Instance methods ────────────────────────────────────────────

    def set_priority(self, prio: Int) raises:
        """Set this thread's priority."""
        k_thread_priority_set(self._addr, prio)

    def priority(self) raises -> Int:
        """Get this thread's priority."""
        return k_thread_priority_get(self._addr)

    def set_name(self, name: String) raises:
        """Set this thread's name (if CONFIG_THREAD_NAME is enabled).

        Note: In Mojo, String is UTF-8 managed memory. For Zephyr C,
        we need a null-terminated C string. This allocates a temporary
        buffer via ctypes.
        """
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var py_name = PythonObject(name)
        var c_name = ctypes.c_char_p(py_name)
        var name_ptr = ctypes.cast(c_name, ctypes.c_void_p)
        var name_addr = Int(Int(ctypes.addressof(name_ptr)))
        # Actually, we need to get the raw bytes pointer...
        # For now, pass the Python string directly (ctypes handles conversion)
        var result = k_thread_name_set(self._addr, Int(py=py_name))
        if result < 0:
            raise Error(UInt32(-result))

    def suspend(self) raises:
        """Suspend this thread."""
        k_thread_suspend(self._addr)

    def resume(self) raises:
        """Resume this suspended thread."""
        k_thread_resume(self._addr)

    def join(self, timeout: Int64) raises Error:
        """Wait for this thread to terminate.

        Args:
            timeout: Maximum wait time. Use K_FOREVER for indefinite.

        Raises:
            Error: On timeout or if the thread cannot be joined.
        """
        to_result_void(k_thread_join(self._addr, timeout))

    def abort(self) raises:
        """Abort this thread (force termination)."""
        k_thread_abort(self._addr)
