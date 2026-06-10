# ─── Safe Queue ───────────────────────────────────────────────────────
# Thin wrapper around Zephyr's k_queue.

from zephyr_sys import (
    k_queue_init, k_queue_alloc_append, k_queue_alloc_prepend,
    k_queue_get, k_queue_is_empty, k_queue_peek_head, k_queue_peek_tail,
    k_queue_cancel_wait,
)
from zephyr.error import to_result, Error
from zephyr.semaphore import TimeoutConvertible


@fieldwise_init
struct Queue(Movable):
    """A Zephyr kernel queue. Create with Queue.create()."""
    var _addr: Int

    @staticmethod
    def create() raises -> Self:
        """Create a new empty queue."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 32
        var buf = ctypes.create_string_buffer(size)
        var addr = Int(py=ctypes.addressof(buf))
        k_queue_init(addr)
        return Self(_addr=addr)

    def append(self, data: Int) raises Error:
        """Append an element (pointer) to the queue."""
        try:
            var result = k_queue_alloc_append(self._addr, data)
            if result < 0:
                raise Error(UInt32(-result))
        except:
            raise Error(UInt32(12))  # ENOMEM

    def prepend(self, data: Int) raises Error:
        """Prepend an element (pointer) to the queue."""
        try:
            var result = k_queue_alloc_prepend(self._addr, data)
            if result < 0:
                raise Error(UInt32(-result))
        except:
            raise Error(UInt32(12))

    def get[T: TimeoutConvertible](self, timeout: T) raises Error -> Int:
        """Get an element from the queue. May block."""
        var t = timeout.to_k_timeout()
        try:
            var result = k_queue_get(self._addr, t)
            if result == 0:
                raise Error(UInt32(110))  # ETIMEDOUT
            return result
        except:
            raise Error(UInt32(110))

    def is_empty(self) raises -> Bool:
        """Check if queue is empty."""
        return k_queue_is_empty(self._addr) != 0

    def peek_head(self) raises -> Int:
        """Peek at head without removing. Returns 0 if empty."""
        return k_queue_peek_head(self._addr)

    def peek_tail(self) raises -> Int:
        """Peek at tail without removing. Returns 0 if empty."""
        return k_queue_peek_tail(self._addr)

    def cancel_wait(self) raises:
        """Cancel all pending get operations."""
        k_queue_cancel_wait(self._addr)
