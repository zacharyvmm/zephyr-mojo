# ─── Idiomatic Sync Primitives ────────────────────────────────────────
# High-level, Rust-inspired synchronization types.

from zephyr.mutex import Mutex as SysMutex
from zephyr.condvar import Condvar as SysCondvar
from zephyr.error import Error
from zephyr.semaphore import TimeoutConvertible, Forever, NoWait
from zephyr.sync.spinmutex import SpinMutex, SpinMutexGuard


# ─── MutexGuard ────────────────────────────────────────────────────────

struct MutexGuard[//, T: AnyType]:
    """RAII guard for a locked Mutex. Call .unlock() to release."""
    var _mutex_addr: Int

    def unlock(mut self):
        """Unlock the mutex and release the guard."""
        self._mutex_addr = 0


# ─── Mutex[T] ──────────────────────────────────────────────────────────

@fieldwise_init
struct Mutex[T: Movable & ImplicitlyDestructible](Movable):
    """Type-safe mutex protecting data of type T.

    Example:
        var mtx = Mutex[Int].create(42)
        mtx.lock(Forever())
        mtx.unlock()
    """
    var _sys: SysMutex
    var _value: Self.T

    @staticmethod
    def create(var value: Self.T) raises -> Self:
        """Create a mutex protecting the given value."""
        var s = Self(_sys=SysMutex.create(), _value=value^)
        return s^

    def lock[T2: TimeoutConvertible](self, timeout: T2) raises Error:
        """Acquire the mutex, blocking until available or timeout."""
        self._sys.lock(timeout)

    def unlock(self) raises Error:
        """Unlock the mutex."""
        self._sys.unlock()


# ─── Condvar ───────────────────────────────────────────────────────────

@fieldwise_init
struct Condvar:
    """Condition variable for use with a Mutex."""
    var _sys: SysCondvar

    @staticmethod
    def create() raises -> Self:
        return Self(_sys=SysCondvar.create())

    def wait(self, mutex_addr: Int) raises Error:
        """Wait on condition variable. Mutex must be locked."""
        self._sys.wait(mutex_addr, Forever())

    def signal(self) raises Error:
        """Wake one waiting thread."""
        self._sys.signal()

    def broadcast(self) raises Error:
        """Wake all waiting threads."""
        self._sys.broadcast()
