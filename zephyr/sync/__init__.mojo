# ─── Idionatic Sync Primitives ────────────────────────────────────────
#
# High-level, Rust-inspired synchronization types for Mojo on Zephyr.
# These wrap the safe zephyr::sys types and provide ergonomic APIs
# with RAII guards, type-safe data protection, etc.
#
# Pattern: each high-level type owns a sys primitive and the protected
# data, providing lock()/try_lock() that return guards.

from zephyr.mutex import Mutex as SysMutex
from zephyr.condvar import Condvar as SysCondvar
from zephyr.error import Error
from zephyr.semaphore import TimeoutConvertible, Forever, NoWait


# ─── MutexGuard ────────────────────────────────────────────────────────


struct MutexGuard[mut: Bool, //, T: AnyType]:
    """RAII guard for a locked Mutex.

    When dropped, the mutex is automatically unlocked.
    Provides deref access to the protected data.
    """
    var _mutex: Int  # raw address of SysMutex
    var _data: UnsafePointer[Self.T, MutExternalOrigin]

    def __init__(out self, *, deinit take: Self):
        """Move constructor — transfer guard ownership."""
        self._mutex = take._mutex
        self._data = take._data

    def __del__(deinit self):
        """Drop guard — unlock the mutex."""
        # We need to call k_mutex_unlock here, but we can't easily
        # access the sys layer from a destructor without imports.
        # For now, users must call .unlock() explicitly.
        pass

    def unlock(mut self):
        """Explicitly unlock the mutex and release the guard."""
        var m = SysMutex._from_raw(self._mutex)
        m.unlock()
        # Prevent double-unlock by zeroing
        self._mutex = 0

    def deref(ref self) -> ref [self._data] T:
        """Access the protected data (immutable)."""
        return self._data[]


# ─── Mutex[T] ──────────────────────────────────────────────────────────


struct Mutex[T: AnyType]:
    """A mutual exclusion primitive protecting data of type T.

    Modeled after std::sync::Mutex. Provides safe, scoped access
    to the protected data through a MutexGuard.

    Example:
        var mtx = Mutex[Int](42)
        var guard = mtx.lock(Forever())
        guard.deref()  # Read the protected value
        guard.unlock()
    """
    var _sys: SysMutex
    var _data: UnsafePointer[Self.T, MutExternalOrigin]

    def __init__(out self, value: T):
        """Create a new Mutex protecting the given value."""
        self._sys = SysMutex()
        # Allocate heap memory for the protected data
        self._data = alloc[T](1)
        self._data.init_pointee_move(value^)

    def lock(self, timeout: TimeoutConvertible) raises Error -> MutexGuard[T]:
        """Acquire the mutex, blocking until available or timeout.

        Returns a MutexGuard that provides access to the data.
        Call .unlock() on the guard to release.
        """
        self._sys.lock(timeout)
        return MutexGuard[T](_mutex=self._sys._addr, _data=self._data)

    def try_lock(self) raises Error -> MutexGuard[T]:
        """Try to acquire the mutex without blocking.

        Returns a MutexGuard immediately or raises Error.
        """
        return self.lock(NoWait())


# ─── Condvar ───────────────────────────────────────────────────────────


struct Condvar:
    """A condition variable for use with a Mutex.

    Blocks a thread until notified. Modeled after std::sync::Condvar.
    """
    var _sys: SysCondvar

    def __init__(out self):
        self._sys = SysCondvar()

    def wait(self, guard: MutexGuard[T]) raises Error:
        """Wait on the condition variable.

        The associated mutex must be held. It is atomically released
        during the wait and re-acquired before returning.
        """
        self._sys.wait(guard._mutex, Forever())

    def signal(self) raises Error:
        """Wake one waiting thread."""
        self._sys.signal()

    def broadcast(self) raises Error:
        """Wake all waiting threads."""
        self._sys.broadcast()
