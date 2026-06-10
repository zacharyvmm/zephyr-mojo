# ─── Safe Queue ───────────────────────────────────────────────────────
# A thin, safe wrapper around Zephyr's k_queue.

from zephyr_sys import (
    k_queue_init, k_queue_alloc_append, k_queue_alloc_prepend,
    k_queue_get, k_queue_is_empty, k_queue_peek_head, k_queue_peek_tail,
    k_queue_cancel_wait,
)
from zephyr.error import to_result, Error
from zephyr.semaphore import TimeoutConvertible


struct Queue:
    """A Zephyr kernel queue (FIFO with optional prepend).

    Queues pass pointers to data. On Zephyr with CONFIG_RUST_ALLOC,
    elements are dynamically allocated.
    """
    var _addr: Int

    def __init__(out self):
        """Create a new empty queue."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 32
        var buf = ctypes.create_string_buffer(size)
        var addr = ctypes.addressof(buf)
        self._addr = Int(Int(addr))
        k_queue_init(self._addr)

    def append(self, data: Int) raises Error:
        """Append an element (pointer) to the queue.

        Returns the element pointer on success. May return -ENOMEM.
        """
        var result = k_queue_alloc_append(self._addr, data)
        if result < 0:
            raise Error(UInt32(-result))

    def prepend(self, data: Int) raises Error:
        """Prepend an element (pointer) to the queue."""
        var result = k_queue_alloc_prepend(self._addr, data)
        if result < 0:
            raise Error(UInt32(-result))

    def get[T: TimeoutConvertible](self, timeout: T) raises Error -> Int:
        """Get an element from the queue. May block.

        Returns the data pointer on success.

        Raises:
            Error: If timeout expires or queue is empty with NoWait.
        """
        var t = timeout.to_k_timeout()
        var result = k_queue_get(self._addr, t)
        # k_queue_get returns NULL on timeout/error
        if result == 0:
            raise Error(UInt32(110))  # ETIMEDOUT
        return result

    def is_empty(self) -> Bool:
        """Check if the queue is empty."""
        return k_queue_is_empty(self._addr) != 0

    def peek_head(self) -> Int:
        """Peek at the head without removing. Returns 0 if empty."""
        return k_queue_peek_head(self._addr)

    def peek_tail(self) -> Int:
        """Peek at the tail without removing. Returns 0 if empty."""
        return k_queue_peek_tail(self._addr)

    def cancel_wait(self):
        """Cancel all pending get operations on this queue."""
        k_queue_cancel_wait(self._addr)
