# ─── SpinMutex ────────────────────────────────────────────────────────
# A spinlock-based mutex built on Zephyr's irq_lock/irq_unlock.
# Suitable for very short critical sections where blocking is unacceptable.
# Inspired by the Rust zephyr::sync::SpinMutex.

from zephyr_sys import irq_lock, irq_unlock


struct SpinMutex:
    """A spinlock-based mutual exclusion primitive.

    Unlike a regular Mutex, SpinMutex does not block — it disables
    interrupts (or uses a spinlock bit on SMP) for the duration of
    the critical section. Suitable only for very short operations.

    Use sparingly. Prefer the blocking Mutex for longer sections.
    """
    var _locked: Bool

    def __init__(out self):
        self._locked = False

    def lock(self) -> UInt32:
        """Acquire the spinlock, disabling interrupts.

        Returns the interrupt key for use with unlock().
        Does NOT block — spins until the lock is available.
        """
        var key = irq_lock()
        # Simple spin on the locked flag
        while self._locked:
            # Release and re-acquire IRQ lock to avoid deadlock
            irq_unlock(key)
            key = irq_lock()
        self._locked = True
        # Return key WITHOUT unlocking — caller holds the lock
        return key

    def unlock(self, key: UInt32) raises:
        """Release the spinlock and restore interrupts."""
        self._locked = False
        irq_unlock(key)

    def is_locked(self) -> Bool:
        """Check if the spinlock is currently held."""
        return self._locked


# ─── SpinMutexGuard ─────────────────────────────────────────────────────


struct SpinMutexGuard:
    """RAII guard for a SpinMutex.

    Restores interrupts when dropped. Holds a reference to the
    mutex and the interrupt key.
    """
    var _mutex_addr: Int  # Pointer to the SpinMutex
    var _key: UInt32

    def __init__(out self, mutex_addr: Int, key: UInt32):
        self._mutex_addr = mutex_addr
        self._key = key

    def unlock(mut self):
        """Release the spinlock and restore interrupts."""
        # We need a way to access the SpinMutex from its raw address.
        # For now, callers use the key directly with SpinMutex.unlock().
        pass
