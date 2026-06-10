# ─── Safe Timer ───────────────────────────────────────────────────────
# A thin, safe wrapper around Zephyr's k_timer.

from zephyr_sys import (
    k_timer_start, k_timer_stop,
    k_timer_status_get, k_timer_status_sync,
    k_timer_expires_ticks, k_timer_remaining_ticks,
    k_timer_user_data_set, k_timer_user_data_get,
)
from zephyr.error import Error
from zephyr.time import Timeout


struct Timer:
    """A Zephyr kernel timer.

    Timers can be one-shot or periodic. Use `start()` to begin,
    `stop()` to cancel, and `status()` to check expiration.
    """
    var _addr: Int

    def __init__(out self):
        """Create a new stopped timer."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 64
        var buf = ctypes.create_string_buffer(size)
        var addr = ctypes.addressof(buf)
        self._addr = Int(Int(addr))

    def start(self, duration: Int64, period: Int64):
        """Start the timer.

        Args:
            duration: Initial delay before first expiration.
            period: Period between subsequent expirations (0 for one-shot).
        """
        k_timer_start(self._addr, duration, period)

    def stop(self):
        """Stop the timer."""
        k_timer_stop(self._addr)

    def status(self) -> Int:
        """Get timer expiration count since last check. Non-blocking."""
        return Int(k_timer_status_get(self._addr))

    def status_sync(self) -> Int:
        """Wait for timer expiration and get count. Blocking."""
        return Int(k_timer_status_sync(self._addr))

    def expires_ticks(self) -> Int:
        """Get ticks until next expiration."""
        return Int(k_timer_expires_ticks(self._addr))

    def remaining_ticks(self) -> Int:
        """Get remaining ticks of current timer period."""
        return Int(k_timer_remaining_ticks(self._addr))

    def set_user_data(self, data: Int):
        """Set a user data pointer on this timer."""
        k_timer_user_data_set(self._addr, data)

    def user_data(self) -> Int:
        """Get the user data pointer from this timer."""
        return k_timer_user_data_get(self._addr)
