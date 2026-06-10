# ─── Signal ────────────────────────────────────────────────────────────
# A Zephyr poll signal — an event mechanism for work queue triggering.
# Inspired by the Rust zephyr::work::Signal.

from zephyr_sys import k_poll_signal_init, k_poll_signal_raise
from zephyr.error import to_result_void, Error


struct Signal:
    """A poll signal for triggering work queue items.

    Signals work like half-boolean semaphores. A blocked task will
    wake when the signal is raised. The signal can carry an integer
    result value from the signalling task to the waiting task.

    Typical use:
    - A worker waits on signals (via k_poll or work_poll)
    - An ISR or other thread raises the signal when an event occurs
    - The worker wakes, processes, and may reset the signal
    """
    var _addr: Int

    def __init__(out self):
        """Create a new signal in the unsignaled state."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 64
        var buf = ctypes.create_string_buffer(size)
        var addr = Int(py=ctypes.addressof(buf))
        self._addr = addr
        k_poll_signal_init(self._addr)

    def raise_(self, result: Int) raises Error:
        """Raise the signal with the given result value.

        Args:
            result: An integer value passed to the waiting task.

        Raises:
            Error: If the signal cannot be raised (e.g., EAGAIN if a
                   polling thread is expiring).
        """
        to_result_void(k_poll_signal_raise(self._addr, result))

    def addr(self) -> Int:
        """Get the raw address of this signal for use with k_poll."""
        return self._addr


# ─── Work ──────────────────────────────────────────────────────────────
# Higher-level work queue item. Wraps k_work with a callback.
# Inspired by the Rust zephyr::work module.

from zephyr_sys import (
    k_work_init, k_work_submit, k_work_submit_to_queue,
    k_work_flush, k_work_cancel,
)


struct Work:
    """A Zephyr work item with an associated action.

    Work items are scheduled to run on a work queue thread. The action
    (a function pointer) is called when the work item is processed.

    Work items can be rescheduled from within their handler, which is
    the standard pattern for periodic work in Zephyr.
    """
    var _addr: Int

    def __init__(out self):
        """Create an uninitialized work item."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 64
        var buf = ctypes.create_string_buffer(size)
        var addr = Int(py=ctypes.addressof(buf))
        self._addr = addr
        k_work_init(self._addr)

    def submit(self) raises Error:
        """Submit this work to the system work queue.

        Returns:
            SubmitResult indicating whether the work was enqueued.

        Raises:
            Error: On failure.
        """
        var result = k_work_submit(self._addr)
        if result < 0:
            raise Error(UInt32(-result))

    def submit_to_queue(self, work_q_addr: Int) raises Error:
        """Submit this work to a specific work queue.

        Args:
            work_q_addr: Raw address of the k_work_q struct.
        """
        var result = k_work_submit_to_queue(work_q_addr, self._addr)
        if result < 0:
            raise Error(UInt32(-result))

    def flush(self) raises Error:
        """Wait for this work item to complete if it's pending."""
        var result = k_work_flush(self._addr)
        if result < 0:
            raise Error(UInt32(-result))

    def cancel(self) raises Error:
        """Cancel this work item if it's pending.

        Note: Cancelling a work item that has already started running
        will leak the work item's resources (per Zephyr docs). This is
        because ownership is transferred to C during execution.
        """
        var result = k_work_cancel(self._addr)
        if result < 0:
            raise Error(UInt32(-result))

    def addr(self) -> Int:
        """Get the raw address of this work item."""
        return self._addr


# ─── SubmitResult ──────────────────────────────────────────────────────


struct SubmitResult:
    """Result of submitting a work item to a work queue."""
    var value: Int

    @staticmethod
    def already_submitted() -> Self:
        """Work was already in a queue."""
        return Self(value=0)

    @staticmethod
    def enqueued() -> Self:
        """Work has been added to the queue."""
        return Self(value=1)

    @staticmethod
    def was_running() -> Self:
        """Work was called from the worker itself, and re-queued."""
        return Self(value=2)

    def is_enqueued(self) -> Bool:
        """Did the submit result in the work being queued?"""
        return self.value == 1 or self.value == 2
