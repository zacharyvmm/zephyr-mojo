# ─── Safe Thread wrapper + ThreadBuilder ──────────────────────────────
# Thin, safe wrapper around Zephyr's k_thread with a high-level builder.
# Follows the Rust zephyr::sys::thread and zephyr::thread patterns.

from zephyr_sys import (
    k_thread_create, k_thread_abort, k_thread_join,
    k_thread_name_set, k_thread_priority_set, k_thread_priority_get,
    k_thread_suspend, k_thread_resume, k_current_get,
    k_yield, k_busy_wait, k_is_in_isr, k_is_preempt_thread,
    K_NO_WAIT, K_FOREVER,
)
from zephyr.error import to_result_void, to_result, Error
from zephyr.object import ZephyrObject, K_THREAD_SIZE


# ─── ThreadStack ───────────────────────────────────────────────────────


@fieldwise_init
struct ThreadStack(Movable):
    """Represents a Zephyr thread stack allocation.

    Create with ThreadStack.create(size_in_bytes).
    """
    var _obj: ZephyrObject
    var _size: Int

    @staticmethod
    def create(size: Int) raises -> Self:
        """Allocate a stack of the given size in bytes."""
        return Self(_obj=ZephyrObject.create(size), _size=size)

    def base(self) -> Int:
        """Get the base pointer for k_thread_create."""
        return self._obj.addr()

    def size(self) -> Int:
        """Get the usable stack size."""
        return self._size


# ─── ThreadPriority ────────────────────────────────────────────────────


comptime THREAD_PRIORITY_IDLE: Int = 15
comptime THREAD_PRIORITY_LOW: Int = 10
comptime THREAD_PRIORITY_NORMAL: Int = 7
comptime THREAD_PRIORITY_HIGH: Int = 3
comptime THREAD_PRIORITY_COOP: Int = -1  # Cooperative (no preemption)


# ─── Thread ────────────────────────────────────────────────────────────


struct Thread:
    """A Zephyr kernel thread handle.

    Provides safe methods for thread lifecycle management:
    - set_priority / priority
    - set_name
    - suspend / resume
    - join / abort

    Create threads with ThreadBuilder.
    """
    var _addr: Int

    def __init__(out self, addr: Int):
        self._addr = addr

    @staticmethod
    def current() raises -> Int:
        """Get the current thread's handle (k_tid_t)."""
        return k_current_get()

    @staticmethod
    def yield_() raises:
        """Yield to equal-priority peers."""
        k_yield()

    @staticmethod
    def busy_wait(usec: UInt32) raises:
        """Busy-wait for the given number of microseconds."""
        k_busy_wait(usec)

    @staticmethod
    def is_in_isr() raises -> Bool:
        """Check if currently in interrupt context."""
        return k_is_in_isr() != 0

    @staticmethod
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
        """Set this thread's name (requires CONFIG_THREAD_NAME)."""
        from std.python import Python
        var py_name = PythonObject(name)
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
        """Wait for this thread to terminate."""
        to_result_void(k_thread_join(self._addr, timeout))

    def abort(self) raises:
        """Force-terminate this thread."""
        k_thread_abort(self._addr)

    def addr(self) -> Int:
        """Get the raw thread pointer."""
        return self._addr


# ─── ThreadBuilder ─────────────────────────────────────────────────────


struct ThreadBuilder:
    """Builder for creating Zephyr threads.

    Example:
        var builder = ThreadBuilder()
        builder.set_priority(THREAD_PRIORITY_NORMAL)
        builder.set_name("my_thread")
        var thread = builder.spawn(stack, entry_fn_ptr)
    """
    var _priority: Int
    var _options: UInt32
    var _name: String
    var _delay: Int64

    def __init__(out self):
        self._priority = THREAD_PRIORITY_NORMAL
        self._options = 0
        self._name = ""
        self._delay = K_NO_WAIT

    def set_priority(mut self, prio: Int):
        """Set the thread's priority (lower = higher priority)."""
        self._priority = prio

    def set_name(mut self, name: String):
        """Set a name for the thread."""
        self._name = name

    def set_options(mut self, options: UInt32):
        """Set thread creation options."""
        self._options = options

    def set_delay_start(mut self):
        """Start the thread paused. Call thread.resume() to start."""
        self._delay = K_FOREVER

    def spawn(self, stack: Int, stack_size: Int, entry: Int) raises -> Thread:
        """Create and start the thread immediately.

        Args:
            stack: Base pointer of the thread's stack.
            stack_size: Size of the stack in bytes.
            entry: Function pointer for the thread entry point.

        Returns:
            A Thread handle.
        """
        var thread_obj = ZephyrObject.create(K_THREAD_SIZE)
        var thread_addr = thread_obj.addr()

        var tid = k_thread_create(
            thread_addr,
            stack,
            stack_size,
            entry,
            0, 0, 0,  # p1, p2, p3
            self._priority,
            self._options,
            self._delay,
        )

        var t = Thread(thread_addr)
        if self._name != "":
            t.set_name(self._name)
        return t
