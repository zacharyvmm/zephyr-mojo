# ─── Printk / Logging ─────────────────────────────────────────────────
# Basic printk and logging support for Zephyr.
# Inspired by the Rust zephyr::printk and zephyr::logging modules.

from std.python import Python, PythonObject


def printk(message: String) raises:
    """Print a message to the Zephyr kernel log (via printk).

    On a real Zephyr system, this outputs to the configured console.
    For host testing, this calls Python's print since libc's printf
    may not be easily accessible through ctypes alone.
    """
    # On real Zephyr, this would call k_printk or similar.
    # For host testing, use Python print as fallback.
    print("printk:", message)


def panic(message: String) raises:
    """Halt the system with a panic message.

    Outputs the message via printk and then enters an infinite loop
    (or calls the Zephyr panic handler on real hardware).
    """
    printk("PANIC: " + message)
    # On real Zephyr: k_panic() or similar
    # For host: just print and exit
    from std.sys import exit
    exit(1)


# ─── Log levels ────────────────────────────────────────────────────────


comptime LOG_LEVEL_NONE: Int = 0
comptime LOG_LEVEL_ERR: Int = 1
comptime LOG_LEVEL_WRN: Int = 2
comptime LOG_LEVEL_INF: Int = 3
comptime LOG_LEVEL_DBG: Int = 4


struct Logger:
    """A simple logger for Zephyr applications.

    Provides leveled logging (err, warn, info, debug) that outputs
    through printk. The log level can be configured at compile time
    or runtime.
    """
    var _level: Int
    var _tag: String

    def __init__(out self, tag: String, level: Int = LOG_LEVEL_INF):
        self._tag = tag
        self._level = level

    def err(self, message: String) raises:
        """Log an error message (always printed)."""
        printk("[" + self._tag + "] ERR: " + message)

    def warn(self, message: String) raises:
        """Log a warning (if level >= WRN)."""
        if self._level >= LOG_LEVEL_WRN:
            printk("[" + self._tag + "] WRN: " + message)

    def info(self, message: String) raises:
        """Log an info message (if level >= INF)."""
        if self._level >= LOG_LEVEL_INF:
            printk("[" + self._tag + "] INF: " + message)

    def debug(self, message: String) raises:
        """Log a debug message (if level >= DBG)."""
        if self._level >= LOG_LEVEL_DBG:
            printk("[" + self._tag + "] DBG: " + message)
