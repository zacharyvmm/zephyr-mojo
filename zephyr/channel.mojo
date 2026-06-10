# ─── Channel (MPSC) ───────────────────────────────────────────────────
# A multi-producer, single-consumer channel built on Zephyr's k_queue.
# Inspired by the Rust zephyr::sync::channel module.

from zephyr_sys import (
    k_queue_init, k_queue_alloc_append, k_queue_alloc_prepend,
    k_queue_get, k_queue_is_empty, k_queue_peek_head, k_queue_peek_tail,
    k_queue_cancel_wait,
)
from zephyr.error import Error
from zephyr.semaphore import TimeoutConvertible, Forever, NoWait


@fieldwise_init
struct ChannelSender(Movable, ImplicitlyCopyable):
    """The sending half of an MPSC channel. Multiple senders OK."""
    var _queue_addr: Int

    def send(self, value: Int) raises Error:
        """Send a value through the channel. Never blocks."""
        var result = k_queue_alloc_append(self._queue_addr, value)
        if result < 0:
            raise Error(UInt32(-result))

    def send_prepend(self, value: Int) raises Error:
        """Send a value to the front of the channel (high priority)."""
        var result = k_queue_alloc_prepend(self._queue_addr, value)
        if result < 0:
            raise Error(UInt32(-result))


@fieldwise_init
struct ChannelReceiver(Movable, ImplicitlyCopyable):
    """The receiving half of an MPSC channel. Single consumer."""
    var _queue_addr: Int

    def recv[T: TimeoutConvertible](self, timeout: T) raises Error -> Int:
        """Receive a value with a timeout."""
        var t = timeout.to_k_timeout()
        var result = k_queue_get(self._queue_addr, t)
        if result == 0:
            raise Error(UInt32(110))  # ETIMEDOUT
        return result

    def try_recv(self) raises Error -> Int:
        """Try to receive without blocking."""
        return self.recv(NoWait())

    def recv_forever(self) raises Error -> Int:
        """Block until a value arrives."""
        return self.recv(Forever())

    def is_empty(self) -> Bool:
        """Check if the channel has pending messages."""
        return k_queue_is_empty(self._queue_addr) != 0

    def peek(self) -> Int:
        """Peek at the next value without removing it. Returns 0 if empty."""
        return k_queue_peek_head(self._queue_addr)

    def cancel_wait(self) raises:
        """Cancel all pending receive operations on this channel."""
        k_queue_cancel_wait(self._queue_addr)


def channel() raises -> Tuple[ChannelSender, ChannelReceiver]:
    """Create a new unbounded MPSC channel.

    Returns a (Sender, Receiver) pair backed by a Zephyr k_queue.
    The channel dynamically allocates elements and never blocks on send.

    Example:
        var tx, rx = channel()
        tx.send(42)
        var val = rx.recv_forever()  # returns 42
    """
    from std.python import Python
    var ctypes = Python.import_module("ctypes")
    var size: Int = 32
    var buf = ctypes.create_string_buffer(size)
    var py_addr = ctypes.addressof(buf)
    var addr = Int(py=py_addr)
    k_queue_init(addr)

    var tx = ChannelSender(_queue_addr=addr)
    var rx = ChannelReceiver(_queue_addr=addr)
    return (tx, rx)
