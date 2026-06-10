# Quick import test
from zephyr import Semaphore, Error
from zephyr.sync import Mutex
from zephyr.time import Duration, Timeout, sleep
from zephyr.mutex import Mutex as SysMutex
from zephyr.condvar import Condvar
from zephyr.timer import Timer
from zephyr.queue import Queue

def main() raises:
    print("All modules import successfully!")
    print("  zephyr.Semaphore — OK")
    print("  zephyr.sync.Mutex[T] — OK")
    print("  zephyr.time.Duration — OK")
    print("  zephyr.mutex.Mutex — OK")
    print("  zephyr.condvar.Condvar — OK")
    print("  zephyr.timer.Timer — OK")
    print("  zephyr.queue.Queue — OK")
