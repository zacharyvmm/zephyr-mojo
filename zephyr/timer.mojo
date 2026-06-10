# ─── Safe Timer ───────────────────────────────────────────────────────
# Thin wrapper around Zephyr's k_timer.

from zephyr_sys import (
    k_timer_start, k_timer_stop,
    k_timer_status_get, k_timer_status_sync,
    k_timer_expires_ticks, k_timer_remaining_ticks,
    k_timer_user_data_set, k_timer_user_data_get,
)
from zephyr.error import Error


@fieldwise_init
struct Timer(Movable):
    """A Zephyr kernel timer. Create with Timer.create()."""
    var _addr: Int

    @staticmethod
    def create() raises -> Self:
        """Create a new stopped timer."""
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 64
        var buf = ctypes.create_string_buffer(size)
        var addr = Int(py=ctypes.addressof(buf))
        return Self(_addr=addr)

    def start(self, duration: Int64, period: Int64) raises:
        """Start the timer."""
        k_timer_start(self._addr, duration, period)

    def stop(self) raises:
        """Stop the timer."""
        k_timer_stop(self._addr)

    def status(self) raises -> Int:
        """Get expiration count (non-blocking)."""
        return Int(k_timer_status_get(self._addr))

    def status_sync(self) raises -> Int:
        """Wait for expiration and get count."""
        return Int(k_timer_status_sync(self._addr))

    def expires_ticks(self) raises -> Int:
        """Ticks until next expiration."""
        return Int(k_timer_expires_ticks(self._addr))

    def remaining_ticks(self) raises -> Int:
        """Ticks remaining in current period."""
        return Int(k_timer_remaining_ticks(self._addr))

    def set_user_data(self, data: Int) raises:
        """Set user data pointer."""
        k_timer_user_data_set(self._addr, data)

    def user_data(self) raises -> Int:
        """Get user data pointer."""
        return k_timer_user_data_get(self._addr)
