# ─── Zephyr Safe Bindings for Mojo ────────────────────────────────────
#
# This package provides safe, idiomatic Mojo wrappers around the Zephyr
# kernel API. Architecture (inspired by zephyr-lang-rust):
#
#   zephyr_sys/  — Raw FFI bindings via Python ctypes (auto-generated)
#   zephyr/      — Safe wrappers with Error handling
#   zephyr/sync/ — High-level idiomatic API (Mutex[T], Condvar, etc.)
#
# Usage:
#   from zephyr import Semaphore, Mutex, Timer
#   from zephyr.time import Duration, sleep
#   from zephyr.sync import Mutex  # Idiomatic Mutex[T]

from zephyr.error import Error, to_result, to_result_void
from zephyr.semaphore import (
    Semaphore,
    Forever,
    NoWait,
    TimeoutConvertible,
)
from zephyr.mutex import Mutex as SysMutex
from zephyr.condvar import Condvar as SysCondvar
from zephyr.timer import Timer
from zephyr.queue import Queue
