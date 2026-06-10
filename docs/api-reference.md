# zephyr-mojo API Reference

Safe, idiomatic Mojo bindings for the [Zephyr RTOS](https://zephyrproject.org/) kernel API. Three-layer architecture inspired by [zephyr-lang-rust](https://github.com/zephyrproject-rtos/zephyr-lang-rust).

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Layer 1: `zephyr_sys` — Raw FFI](#layer-1-zephyr_sys--raw-ffi)
- [Layer 2: `zephyr` — Safe Wrappers](#layer-2-zephyr--safe-wrappers)
  - [Error Handling](#error-handling)
  - [Time](#time)
  - [Semaphore](#semaphore)
  - [Mutex (sys-level)](#mutex-sys-level)
  - [Condition Variable](#condition-variable)
  - [Timer](#timer)
  - [Queue](#queue)
  - [Thread](#thread)
  - [Channel](#channel)
  - [Signal & Work](#signal--work)
  - [Logging](#logging)
  - [Kernel Objects](#kernel-objects)
- [Layer 3: `zephyr/sync` — Idiomatic API](#layer-3-zephyrsync--idiomatic-api)
  - [Mutex[T]](#mutext)
  - [Condition Variable](#condition-variable-1)
  - [SpinMutex](#spinmutex)
- [Code Generator](#code-generator)
- [Dual FFI Backend](#dual-ffi-backend)

---

## Quick Start

```mojo
from zephyr import (
    Semaphore, Error, Forever, NoWait,
    ThreadBuilder, ThreadStack,
    Signal, Work, Logger,
)
from zephyr.time import Duration, Timeout, sleep
from zephyr.sync import Mutex

def main() raises:
    # Create a semaphore with initial count 0, max 10
    var sem = Semaphore(0, 10)

    # Give it from another context
    sem.give()

    # Take it (blocks until available or timeout)
    sem.take(Forever())

    # Sleep for 100ms
    sleep(Duration.from_ms(100))

    # Create a Mutex protecting an integer
    var mtx = Mutex[Int](42)
    var guard = mtx.lock(Forever())
    # ... use protected data ...
    guard.unlock()

    # Logging
    var log = Logger("my_app")
    log.info("Zephyr bindings working!")
```

Run the generator:

```bash
# Default (Python ctypes, works on stable Mojo 1.0)
python3 -m codegen.gen_sys --backend ctypes

# Native FFI (requires nightly Mojo with std.ffi)
python3 -m codegen.gen_sys --backend native
```

---

## Architecture

```
zephyr_sys/     Layer 1: Raw FFI (69 kernel functions, auto-generated)
    │
zephyr/         Layer 2: Safe wrappers with error handling (14 modules)
    │
zephyr/sync/    Layer 3: Idiomatic Mojo API (Mutex[T], Condvar, SpinMutex)
```

Each layer depends only on the layer below it. Application code uses Layer 2 or 3. The FFI backend (ctypes vs native) is confined to Layer 1 and transparent to higher layers.

---

## Layer 1: `zephyr_sys` — Raw FFI

Auto-generated from `codegen/spec.py`. Do not edit by hand.

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `K_NO_WAIT` | `0` | Operation returns immediately |
| `K_FOREVER` | `-1` | Wait indefinitely |
| `K_SEM_MAX_LIMIT` | `0xFFFFFFFF` | Maximum semaphore count |
| `K_POLL_TYPE_SEM_AVAILABLE` | `0` | Poll type: semaphore |
| `K_POLL_TYPE_DATA_AVAILABLE` | `1` | Poll type: data |
| `K_POLL_TYPE_SIGNAL` | `3` | Poll type: signal |

### Timeout Helpers

```mojo
timeout_no_wait() -> Int64       # K_NO_WAIT
timeout_forever() -> Int64       # K_FOREVER
timeout_ms(ms: Int) -> Int64     # Milliseconds to ticks
```

### Error Codes

```mojo
comptime EAGAIN: UInt32 = 11     # Try again
comptime ENOMEM: UInt32 = 12     # Out of memory
comptime EINVAL: UInt32 = 22     # Invalid argument
comptime ETIMEDOUT: UInt32 = 110 # Operation timed out
# ... 20 more errno codes ...

errno_name(code: UInt32) -> String  # Get human-readable name
```

### Function Convention

All generated functions have `raises` (Python ctypes calls may raise). Return values follow Zephyr's convention: negative values are errors (negated errno), non-negative values are success.

```mojo
k_sem_init(sem: Int, initial_count: UInt32, limit: UInt32) raises -> Int
k_sem_take(sem: Int, timeout: Int64) raises -> Int
k_sem_give(sem: Int) raises
k_mutex_lock(mutex: Int, timeout: Int64) raises -> Int
k_sleep(timeout: Int64) raises -> Int
# ... 69 functions total
```

---

## Layer 2: `zephyr` — Safe Wrappers

### Error Handling

`zephyr.error`

```mojo
struct Error(Writable):
    var code: UInt32

    def __init__(out self, code: UInt32)

def to_result_void(code: Int) raises Error
    """Convert Zephyr return code. Raises Error if code < 0."""

def to_result(code: Int) raises Error -> Int
    """Convert Zephyr return code. Returns value if >= 0, raises Error if < 0."""
```

Usage:
```mojo
from zephyr import Error

# Convert raw Zephyr return code
var result = k_sem_take(sem_addr, K_NO_WAIT)
to_result_void(result)  # Raises Error if negative

# Create error directly
var err = Error(UInt32(11))  # EAGAIN
print(err)  # "zephyr error errno:11 (EAGAIN)"
```

### Time

`zephyr.time`

```mojo
struct Duration:
    var ticks: Int64
    @staticmethod def from_ms(ms: Int) -> Self
    @staticmethod def no_wait() -> Self

struct Instant:
    var ticks: Int64
    @staticmethod def now() -> Self

struct Timeout:
    var raw: Int64
    @staticmethod def no_wait() -> Self
    @staticmethod def forever() -> Self
    @staticmethod def from_duration(dur: Duration) -> Self
    @staticmethod def from_ms(ms: Int) -> Self

def sleep(dur: Duration) raises -> Int
    """Put current thread to sleep. Returns remaining ticks if woken early."""
```

Usage:
```mojo
from zephyr.time import Duration, Timeout, Instant, sleep

# Sleep for 500ms
sleep(Duration.from_ms(500))

# Non-blocking timeout
var t = Timeout.no_wait()

# Wait forever
var t = Timeout.forever()

# Get current time
var now = Instant.now()
```

### Semaphore

`zephyr.semaphore`

```mojo
struct Semaphore:
    def __init__(out self, initial_count: Int, limit: Int)
    def take[T: TimeoutConvertible](self, timeout: T) raises Error
    def give(self)
    def reset(self)
    def count(self) -> Int

struct Forever(TimeoutConvertible):
    def to_k_timeout(self) -> Int64

struct NoWait(TimeoutConvertible):
    def to_k_timeout(self) -> Int64

trait TimeoutConvertible:
    def to_k_timeout(self) -> Int64
```

Usage:
```mojo
from zephyr import Semaphore, Forever, NoWait

# Binary semaphore (initial 0, max 1)
var sem = Semaphore(0, 1)

# Producer thread
sem.give()

# Consumer thread — blocks until available
sem.take(Forever())

# Non-blocking poll
try:
    sem.take(NoWait())
except:
    print("not available yet")

# Reset to zero
sem.reset()

# Check count
print(sem.count())
```

### Mutex (sys-level)

`zephyr.mutex`

```mojo
struct Mutex:
    def __init__(out self)
    def lock[T: TimeoutConvertible](self, timeout: T) raises Error
    def unlock(self) raises Error
```

Usage:
```mojo
from zephyr.mutex import Mutex
from zephyr import Forever

var mtx = Mutex()
mtx.lock(Forever())
# ... critical section ...
mtx.unlock()
```

For type-safe data protection, prefer `zephyr.sync.Mutex[T]` (see Layer 3).

### Condition Variable

`zephyr.condvar`

```mojo
struct Condvar:
    def __init__(out self)
    def wait[T: TimeoutConvertible](self, mutex: Int, timeout: T) raises Error
    def signal(self) raises Error
    def broadcast(self) raises Error
```

Usage:
```mojo
from zephyr.condvar import Condvar
from zephyr.mutex import Mutex
from zephyr import Forever

var mtx = Mutex()
var cv = Condvar()

# Thread A: wait for condition
mtx.lock(Forever())
while not condition_met:
    cv.wait(mtx._addr, Forever())
# ... condition is met ...
mtx.unlock()

# Thread B: signal condition change
cv.signal()      # Wake one waiter
cv.broadcast()   # Wake all waiters
```

### Timer

`zephyr.timer`

```mojo
struct Timer:
    def __init__(out self)
    def start(self, duration: Int64, period: Int64)
    def stop(self)
    def status(self) -> Int          # Non-blocking expiration count
    def status_sync(self) -> Int     # Block until expiration
    def expires_ticks(self) -> Int   # Ticks until next expiration
    def remaining_ticks(self) -> Int # Ticks remaining in period
    def set_user_data(self, data: Int)
    def user_data(self) -> Int
```

Usage:
```mojo
from zephyr import Timer
from zephyr_sys import timeout_ms

var timer = Timer()

# One-shot timer: fire after 100ms, period=0
timer.start(timeout_ms(100), 0)
var count = timer.status_sync()  # Blocks until timer fires

# Periodic timer: fire every 500ms
timer.start(timeout_ms(500), timeout_ms(500))
```

### Queue

`zephyr.queue`

```mojo
struct Queue:
    def __init__(out self)
    def append(self, data: Int) raises Error
    def prepend(self, data: Int) raises Error
    def get[T: TimeoutConvertible](self, timeout: T) raises Error -> Int
    def is_empty(self) -> Bool
    def peek_head(self) -> Int
    def peek_tail(self) -> Int
    def cancel_wait(self)
```

Usage:
```mojo
from zephyr import Queue, Forever, NoWait

var q = Queue()

# Send data (pass pointers as Int)
q.append(42)
q.prepend(99)  # High priority

# Receive
var val = q.get(Forever())  # Blocks until available

# Non-blocking poll
try:
    val = q.get(NoWait())
except:
    print("queue empty")

# Peek without removing
var next_val = q.peek_head()
```

### Thread

`zephyr.thread`

```mojo
struct ThreadStack:
    def __init__(out self, size: Int)
    def base(self) -> Int
    def size(self) -> Int

struct Thread:
    def __init__(out self, addr: Int)
    @staticmethod def current() raises -> Int
    @staticmethod def yield_() raises
    @staticmethod def busy_wait(usec: UInt32) raises
    @staticmethod def is_in_isr() raises -> Bool
    @staticmethod def is_preemptible() raises -> Bool
    def set_priority(self, prio: Int) raises
    def priority(self) raises -> Int
    def set_name(self, name: String) raises
    def suspend(self) raises
    def resume(self) raises
    def join(self, timeout: Int64) raises Error
    def abort(self) raises
    def addr(self) -> Int

struct ThreadBuilder:
    def __init__(out self)
    def set_priority(mut self, prio: Int) -> Self
    def set_name(mut self, name: String) -> Self
    def set_options(mut self, options: UInt32) -> Self
    def set_delay_start(mut self) -> Self
    def spawn(self, stack: Int, stack_size: Int, entry: Int) raises -> Thread

# Priority constants
comptime THREAD_PRIORITY_IDLE: Int = 15
comptime THREAD_PRIORITY_LOW: Int = 10
comptime THREAD_PRIORITY_NORMAL: Int = 7
comptime THREAD_PRIORITY_HIGH: Int = 3
comptime THREAD_PRIORITY_COOP: Int = -1  # Cooperative
```

Usage:
```mojo
from zephyr import Thread, ThreadBuilder, ThreadStack

# Allocate a stack
var stack = ThreadStack(2048)

# Builder pattern
var t = ThreadBuilder()
    .set_priority(THREAD_PRIORITY_NORMAL)
    .set_name("worker")
    .spawn(stack.base(), stack.size(), entry_function_ptr)

# Or delay start (thread created suspended)
var t2 = ThreadBuilder()
    .set_delay_start()
    .spawn(stack2.base(), stack2.size(), entry_fn)
# ... later ...
t2.resume()

# Thread control
t.suspend()
t.resume()
t.join(K_FOREVER)  # Wait for termination

# Current thread info
var me = Thread.current()
if Thread.is_in_isr():
    print("in interrupt context")
Thread.yield_()  # Yield to peers
```

### Channel

`zephyr.channel`

```mojo
struct ChannelSender:
    def send(self, value: Int) raises Error
    def send_prepend(self, value: Int) raises Error

struct ChannelReceiver:
    def recv[T: TimeoutConvertible](self, timeout: T) raises Error -> Int
    def try_recv(self) raises Error -> Int
    def recv_forever(self) raises Error -> Int
    def is_empty(self) -> Bool
    def peek(self) -> Int
    def cancel_wait(self) raises

def channel() raises -> Tuple[ChannelSender, ChannelReceiver]
```

Usage:
```mojo
from zephyr import channel, ChannelSender, ChannelReceiver, Forever

var tx, rx = channel()

# Send from multiple threads/producers
tx.send(42)
tx.send_prepend(99)  # Jump the queue

# Receive
var val = rx.recv_forever()  # Blocks
var val2 = rx.try_recv()     # Non-blocking

# Check
if rx.is_empty():
    print("no messages")
```

### Signal & Work

`zephyr.work`

```mojo
struct Signal:
    def __init__(out self)
    def raise_(self, result: Int) raises Error
    def addr(self) -> Int

struct Work:
    def __init__(out self)
    def submit(self) raises Error
    def submit_to_queue(self, work_q_addr: Int) raises Error
    def flush(self) raises Error
    def cancel(self) raises Error
    def addr(self) -> Int

struct SubmitResult:
    @staticmethod def already_submitted() -> Self
    @staticmethod def enqueued() -> Self
    @staticmethod def was_running() -> Self
    def is_enqueued(self) -> Bool
```

Usage:
```mojo
from zephyr import Signal, Work

# Create a signal (for triggering work from ISRs)
var sig = Signal()

# ISR context: raise signal
sig.raise_(0)

# Worker: poll on signal with k_poll
# (k_poll_event setup uses sig.addr())

# Create a work item
var work = Work()
work.submit()              # Submit to system work queue
work.submit_to_queue(wq)   # Submit to specific queue
work.flush()               # Wait for completion
work.cancel()              # Cancel if pending
```

### Logging

`zephyr.logging`

```mojo
def printk(message: String) raises
def panic(message: String) raises

struct Logger:
    def __init__(out self, tag: String, level: Int = LOG_LEVEL_INF)
    def err(self, message: String) raises      # Always printed
    def warn(self, message: String) raises     # If level >= WRN
    def info(self, message: String) raises     # If level >= INF
    def debug(self, message: String) raises    # If level >= DBG

comptime LOG_LEVEL_NONE: Int = 0
comptime LOG_LEVEL_ERR: Int = 1
comptime LOG_LEVEL_WRN: Int = 2
comptime LOG_LEVEL_INF: Int = 3
comptime LOG_LEVEL_DBG: Int = 4
```

Usage:
```mojo
from zephyr import Logger, printk, panic, LOG_LEVEL_DBG

# Direct kernel output
printk("hello from Mojo on Zephyr!")

# Structured logging
var log = Logger("sensor", LOG_LEVEL_DBG)
log.err("sensor read failed")     # Always shown
log.warn("battery low")           # Configurable threshold
log.info("sampling at 100Hz")     # Configurable threshold
log.debug("raw value: 0x42")      # Only in debug builds

# Fatal error
panic("unrecoverable hardware fault")
```

### Kernel Objects

`zephyr.object`

```mojo
struct ZephyrObject:
    def __init__(out self, size: Int)
    def addr(self) -> Int

struct Fixed:
    def __init__(out self, size: Int)
    def addr(self) -> Int

comptime K_SEM_SIZE: Int = 32
comptime K_MUTEX_SIZE: Int = 32
comptime K_THREAD_SIZE: Int = 256
comptime K_TIMER_SIZE: Int = 64
comptime K_QUEUE_SIZE: Int = 32
comptime K_POLL_SIGNAL_SIZE: Int = 64
comptime K_WORK_SIZE: Int = 64
comptime K_WORK_Q_SIZE: Int = 256

# Size constants for all kernel objects
```

Usage:
```mojo
from zephyr.object import ZephyrObject, Fixed, K_SEM_SIZE

# Dynamically allocate a kernel object
var obj = ZephyrObject(K_SEM_SIZE)
var addr = obj.addr()

# Pass to Zephyr init functions
k_sem_init(addr, 0, 10)
k_sem_take(addr, timeout_forever())

# Fixed (pinned) allocation — prevents moves
var fixed = Fixed(K_WORK_SIZE)
k_work_init(fixed.addr())
```

---

## Layer 3: `zephyr/sync` — Idiomatic API

### Mutex[T]

`zephyr.sync`

```mojo
struct Mutex[T: AnyType]:
    def __init__(out self, value: T)
    def lock(self, timeout: TimeoutConvertible) raises Error -> MutexGuard[T]
    def try_lock(self) raises Error -> MutexGuard[T]

struct MutexGuard[mut: Bool, //, T: AnyType]:
    def unlock(mut self)
    def deref(ref self) -> ref [self._data] T

struct Condvar:
    def __init__(out self)
    def wait[T](self, guard: MutexGuard[T]) raises Error
    def signal(self) raises Error
    def broadcast(self) raises Error
```

Usage:
```mojo
from zephyr.sync import Mutex, Condvar
from zephyr import Forever

# Type-safe mutex protecting an Int
var mtx = Mutex[Int](42)

var guard = mtx.lock(Forever())
# Access protected data
var val = guard.deref()
guard.unlock()

# Try-lock (non-blocking)
var guard2 = mtx.try_lock()
guard2.unlock()

# Condition variable with mutex
var cv = Condvar()
var mtx2 = Mutex[Int](0)

var g = mtx2.lock(Forever())
cv.wait(g)         # Atomically unlocks and waits
cv.signal()        # Wake one waiter
cv.broadcast()     # Wake all
g.unlock()
```

### SpinMutex

`zephyr.sync.spinmutex`

```mojo
struct SpinMutex:
    def __init__(out self)
    def lock(self) -> UInt32       # Disables interrupts, returns key
    def unlock(self, key: UInt32)  # Restores interrupts
    def is_locked(self) -> Bool

struct SpinMutexGuard:
    var _mutex_addr: Int
    var _key: UInt32
```

Usage:
```mojo
from zephyr.sync import SpinMutex

var spin = SpinMutex()

# Lock — disables interrupts
var key = spin.lock()
# ... very short critical section (no blocking allowed) ...
spin.unlock(key)
```

**Warning:** Only for extremely short sections. Prefer `Mutex[T]` for anything that might block.

---

## Code Generator

Located in `codegen/`. Reads `spec.py` (API specification) and generates `zephyr_sys/__init__.mojo`.

```bash
# Default backend (Python ctypes)
python3 -m codegen.gen_sys

# Native FFI backend (nightly only)
python3 -m codegen.gen_sys --backend native
```

### Adding new Zephyr functions

1. Add a `Function(...)` entry to `codegen/spec.py`
2. Regenerate: `python3 -m codegen.gen_sys`
3. Build safe wrappers in `zephyr/` if needed

### Spec format

```python
Function(
    name="k_sem_init",
    return_type="int",
    mojo_return="Int",
    params=[
        Param("sem", "struct k_sem *", "Pointer", is_pointer=True),
        Param("initial_count", "unsigned int", "UInt32"),
        Param("limit", "unsigned int", "UInt32"),
    ],
    returns_error=True,
    description="Initialize a semaphore.",
    category="semaphore",
),
```

---

## Dual FFI Backend

The code generator supports two FFI backends, selectable at generation time.

### ctypes (default)

Works on stable Mojo 1.0. Calls go through Python's `ctypes` module:

```mojo
from std.python import Python, PythonObject

def k_sem_init(sem: Int, count: UInt32, limit: UInt32) raises -> Int:
    var lib = _get_lib()  # ctypes.CDLL
    var _py = lib.k_sem_init(PythonObject(sem), ...)
    return Int(py=_py)
```

**Pro:** Works today on stable Mojo.
**Con:** ~1μs overhead per call (Python round-trip).

### native (nightly)

Requires nightly Mojo with `std.ffi`. Zero-overhead C calls:

```mojo
from std.ffi import external_call, c_int, c_uint

def k_sem_init(sem: Int, count: c_uint, limit: c_uint) raises -> c_int:
    return external_call["k_sem_init", c_int, Int, c_uint, c_uint](sem, count, limit)
```

**Pro:** Zero overhead, no Python dependency.
**Con:** Requires nightly Mojo (Linux wheels not yet available as of June 2026).

### Switching

```bash
# Switch to native when nightly supports your platform:
python3 -m codegen.gen_sys --backend native
mojo run -I . your_app.mojo
```

All Layer 2/3 code is backend-agnostic — no application changes needed.

---

## Building for Real Zephyr

When nightly Mojo's native FFI is available on your target:

1. **Generate native bindings:** `python3 -m codegen.gen_sys --backend native`
2. **Compile Mojo to object files:** `mojo build --target <arch> your_app.mojo`
3. **Link with Zephyr kernel:** Include the Mojo objects in your Zephyr build system (CMake/west)
4. **Zephyr symbols resolve at link time** — `external_call["k_sem_init", ...]` links directly to the kernel

The static allocation pattern (`ZephyrObject`, `Fixed`) uses ctypes for host testing. On real hardware, replace with Zephyr's `K_SEM_DEFINE`, `K_MUTEX_DEFINE`, etc. or use `kobj_define!` equivalent.

---

## Reference

- [Zephyr RTOS Documentation](https://docs.zephyrproject.org/)
- [Rust Zephyr Bindings](https://github.com/zephyrproject-rtos/zephyr-lang-rust) — architectural model
- [Mojo Manual](https://docs.modular.com/mojo/manual/)
- [Mojo Nightly FFI Docs](https://mojolang.org/nightly/docs/std/ffi/)
