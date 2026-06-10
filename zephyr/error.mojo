# ─── Typed Zephyr Error ───────────────────────────────────────────────
# Named error variants matching Zephyr's errno values.
# Replaces raw UInt32 codes with type-safe enum.

from zephyr_sys import errno_name


struct Error(Writable):
    """A Zephyr kernel error with a named variant."""
    var _code: UInt32

    def __init__(out self, code: UInt32):
        """Create an error from a raw errno code."""
        self._code = code

    # ── Named constructors ──────────────────────────────────────────

    @staticmethod
    def again() -> Self:
        """EAGAIN — resource temporarily unavailable, try again."""
        return Self(_code=11)

    @staticmethod
    def nomem() -> Self:
        """ENOMEM — out of memory."""
        return Self(_code=12)

    @staticmethod
    def inval() -> Self:
        """EINVAL — invalid argument."""
        return Self(_code=22)

    @staticmethod
    def timedout() -> Self:
        """ETIMEDOUT — operation timed out."""
        return Self(_code=110)

    @staticmethod
    def busy() -> Self:
        """EBUSY — device or resource busy."""
        return Self(_code=16)

    @staticmethod
    def perm() -> Self:
        """EPERM — operation not permitted."""
        return Self(_code=1)

    @staticmethod
    def noent() -> Self:
        """ENOENT — no such file or directory."""
        return Self(_code=2)

    @staticmethod
    def exist() -> Self:
        """EEXIST — file or resource already exists."""
        return Self(_code=17)

    @staticmethod
    def canceled() -> Self:
        """ECANCELED — operation canceled."""
        return Self(_code=120)

    @staticmethod
    def notsup() -> Self:
        """ENOSYS — function not supported."""
        return Self(_code=38)

    @staticmethod
    def fault() -> Self:
        """EFAULT — bad address."""
        return Self(_code=14)

    @staticmethod
    def acces() -> Self:
        """EACCES — permission denied."""
        return Self(_code=13)

    @staticmethod
    def io() -> Self:
        """EIO — I/O error."""
        return Self(_code=5)

    @staticmethod
    def from_code(code: UInt32) -> Self:
        """Create from a raw Zephyr error code."""
        return Self(_code=code)

    # ── Introspection ───────────────────────────────────────────────

    def code(self) -> UInt32:
        """Get the raw errno value."""
        return self._code

    def name(self) -> String:
        """Get the human-readable errno name (e.g., 'EAGAIN')."""
        return errno_name(self._code)

    def is_again(self) -> Bool:
        return self._code == 11

    def is_timedout(self) -> Bool:
        return self._code == 110

    def is_nomem(self) -> Bool:
        return self._code == 12

    # ── Display ─────────────────────────────────────────────────────

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Error(", self.name(), ":", Int(self._code), ")")


# ─── Result helpers (unchanged) ────────────────────────────────────────


def to_result_void(code: Int) raises Error:
    """Convert Zephyr return code. Raises Error if code < 0."""
    if code < 0:
        raise Error.from_code(UInt32(-code))


def to_result(code: Int) raises Error -> Int:
    """Convert Zephyr return code. Returns value if >= 0."""
    if code < 0:
        raise Error.from_code(UInt32(-code))
    return code


# ─── ISR Safety ────────────────────────────────────────────────────────
# These functions are safe to call from interrupt context.

# Semaphore: give() — ISR-safe (see k_sem_give docs)
# Queue:     get() with K_NO_WAIT, append(), prepend(), cancel_wait() — ISR-safe
# Signal:    raise_() — ISR-safe (designed for ISR→worker signaling)
# SpinMutex: lock()/unlock() — ISR-safe by design (uses irq_lock)
# Timer:     stop(), status_get() — ISR-safe

# NOT ISR-safe:
# - Semaphore take() with timeout (may block)
# - Mutex lock() (may block)
# - Thread create/join/abort (may block)
# - Any function that may sleep or block
