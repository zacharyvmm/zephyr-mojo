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
#   from zephyr import Semaphore, Mutex, ThreadBuilder, Work, Signal
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
from zephyr.thread import (
    Thread, ThreadStack, ThreadBuilder,
    THREAD_PRIORITY_IDLE, THREAD_PRIORITY_LOW,
    THREAD_PRIORITY_NORMAL, THREAD_PRIORITY_HIGH, THREAD_PRIORITY_COOP,
)
from zephyr.channel import ChannelSender, ChannelReceiver, channel
from zephyr.work import Signal, Work, SubmitResult
from zephyr.logging import Logger, printk, panic, LOG_LEVEL_DBG
from zephyr.object import ZephyrObject, Fixed
