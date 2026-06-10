# Quick import test — verifies all modules compile
from zephyr import (
    Semaphore, Error, Forever, NoWait,
    Timer, Queue, Thread, ThreadStack, ThreadBuilder,
    ChannelSender, ChannelReceiver, channel,
    Signal, Work, SubmitResult,
    Logger, printk, panic,
    ZephyrObject, Fixed,
)
from zephyr.sync import Mutex, Condvar, SpinMutex
from zephyr.time import Duration, Timeout, Instant, sleep
from zephyr.mutex import Mutex as SysMutex
from zephyr.condvar import Condvar as SysCondvar

def main() raises:
    print("All modules import successfully!")
    print("  zephyr.Semaphore      — OK")
    print("  zephyr.Timer          — OK")
    print("  zephyr.Queue          — OK")
    print("  zephyr.Thread         — OK")
    print("  zephyr.ThreadBuilder  — OK")
    print("  zephyr.Channel        — OK")
    print("  zephyr.Signal         — OK")
    print("  zephyr.Work           — OK")
    print("  zephyr.Logger         — OK")
    print("  zephyr.ZephyrObject   — OK")
    print("  zephyr.sync.Mutex     — OK")
    print("  zephyr.sync.Condvar   — OK")
    print("  zephyr.sync.SpinMutex — OK")
    print("  zephyr.time.*         — OK")
