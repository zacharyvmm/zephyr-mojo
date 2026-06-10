# ─── Zephyr Time types ────────────────────────────────────────────────
# Inspired by Rust zephyr::time — Duration, Instant, and Timeout.
#
# k_timeout_t is a signed 64-bit value encoding:
#   0 = K_NO_WAIT
#   -1 = K_FOREVER
#   positive = ticks from now (Duration)
#   very negative = absolute tick deadline (Instant, ~2^63 - 1)

from zephyr_sys import (
    K_NO_WAIT,
    K_FOREVER,
    k_uptime_ticks,
    timeout_no_wait,
    timeout_forever,
    timeout_ms,
)


# ─── Duration ──────────────────────────────────────────────────────────


struct Duration:
    """A span of time, represented in system ticks."""
    var ticks: Int64

    def __init__(out self, ticks: Int64):
        self.ticks = ticks

    @staticmethod
    def from_ms(ms: Int) -> Self:
        """Create a Duration from milliseconds."""
        return Self(Int64(ms))

    @staticmethod
    def no_wait() -> Self:
        """A zero-length duration (K_NO_WAIT)."""
        return Self(K_NO_WAIT)

    def to_timeout(self) -> Int64:
        """Convert this duration to a k_timeout_t."""
        return self.ticks


# ─── Instant ───────────────────────────────────────────────────────────


struct Instant:
    """An absolute point in time (system tick count)."""
    var ticks: Int64

    def __init__(out self, ticks: Int64):
        self.ticks = ticks

    @staticmethod
    def now() -> Self:
        """Get the current system time as an Instant."""
        return Self(k_uptime_ticks())

    def to_timeout(self) -> Int64:
        """Convert to a k_timeout_t for an absolute deadline."""
        return self.ticks


# ─── Timeout ───────────────────────────────────────────────────────────


struct Timeout:
    """A timeout value for Zephyr kernel operations."""
    var raw: Int64

    def __init__(out self, raw: Int64):
        self.raw = raw

    @staticmethod
    def no_wait() -> Self:
        """K_NO_WAIT — operation returns immediately."""
        return Self(timeout_no_wait())

    @staticmethod
    def forever() -> Self:
        """K_FOREVER — wait indefinitely."""
        return Self(timeout_forever())

    @staticmethod
    def from_duration(dur: Duration) -> Self:
        """Create a timeout from a Duration."""
        return Self(dur.to_timeout())

    @staticmethod
    def from_ms(ms: Int) -> Self:
        """Create a timeout from milliseconds."""
        return Self(Int64(ms))


# ─── Sleep ─────────────────────────────────────────────────────────────

from zephyr_sys import k_sleep


def sleep(dur: Duration) raises -> Int:
    """Put the current thread to sleep for the given duration.

    Returns the remaining time if woken early (0 if duration completed).
    """
    return k_sleep(dur.to_timeout())
