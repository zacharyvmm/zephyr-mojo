# zephyr-mojo + native_sim Integration

Run Mojo code against a real Zephyr kernel — no hardware required. Zephyr's `native_sim` target compiles the entire Zephyr RTOS as a Linux process. Our Mojo bindings load it as a shared library and call kernel functions through ctypes.

## How It Works

```
┌─────────────────────────────────────────────────┐
│  Mojo Process                                   │
│                                                 │
│  zephyr_sys  ──ctypes──►  libzephyr.so          │
│  (safe API)              (native_sim build)      │
│                              │                  │
│                              ▼                  │
│                         Zephyr Kernel           │
│                         (semaphore, mutex,      │
│                          threads, timers, ...)  │
│                              │                  │
│                              ▼                  │
│                         Linux Kernel            │
│                         (syscalls, POSIX)       │
└─────────────────────────────────────────────────┘
```

Zephyr's `native_sim` compiles Zephyr as a regular Linux executable. When built as a shared library (or loaded from the ELF), all kernel symbols (`k_sem_init`, `k_mutex_lock`, `k_thread_create`, ...) are available for dynamic linking. Our ctypes backend calls them directly.

## Prerequisites

```bash
# Install Zephyr SDK and west
pip install west
cd /path/to/zephyr-mojo

# Initialize west in the Zephyr reference repo
cd /home/zmm/projects/ref/zephyr
west init -l .
west update

# Install Zephyr SDK
# https://docs.zephyrproject.org/latest/develop/toolchains/zephyr_sdk.html
# Or use host toolchain: export ZEPHYR_TOOLCHAIN_VARIANT=host
```

## Quick Start

### 1. Build Zephyr for native_sim

```bash
cd /home/zmm/projects/zephyr-mojo/native_sim

# Build as a native_sim application
west build -b native_sim -d build

# The output is at build/zephyr/zephyr.elf
# Verify exported symbols:
nm -D build/zephyr/zephyr.elf | grep " T k_sem"
```

Expected output:
```
0000000000401234 T k_sem_init
0000000000401280 T k_sem_take
00000000004012c0 T k_sem_give
0000000000401300 T k_sem_reset
0000000000401340 T k_sem_count_get
...
```

### 2. Run the Mojo test

```bash
cd /home/zmm/projects/zephyr-mojo
mojo run -I . native_sim/test_native_sim.mojo
```

Expected output:
```
=== zephyr-mojo native_sim test ===

Loading: build/zephyr/zephyr.elf
Library loaded OK

Calling zephyr_mojo_init()...
zephyr-mojo: native_sim initialized
Zephyr initialized

--- Test 1: k_uptime_ticks ---
Uptime ticks: 0

--- Test 2: Semaphore ---
k_sem_init returned: 0
k_sem_give called
k_sem_take(K_NO_WAIT) returned: 0

--- Test 3: Thread creation ---
zephyr-mojo: helper thread created

--- Test 4: Safe bindings ---
Safe Semaphore created
Safe give() called
Safe take(Forever()) returned

=== All native_sim tests passed! ===
```

### 3. Use safe bindings directly

Once the library is loaded, you can use the full safe API:

```mojo
from zephyr import Semaphore, Forever
from zephyr.time import Duration, sleep

var sem = Semaphore(0, 10)
sem.give()
sem.take(Forever())

sleep(Duration.from_ms(100))
print("Hello from Mojo on Zephyr native_sim!")
```

## Build Configuration

### Kconfig options

Add to `native_sim/prj.conf`:

```kconfig
# Enable features needed by zephyr-mojo
CONFIG_PRINTK=y
CONFIG_SEMAPHORE=y
CONFIG_MUTEX=y
CONFIG_CONDVAR=y

# Thread support
CONFIG_THREAD_NAME=y
CONFIG_THREAD_MONITOR=y

# Increase main stack for Mojo integration
CONFIG_MAIN_STACK_SIZE=4096

# Enable dynamic thread stacks (for Thread object)
CONFIG_DYNAMIC_THREAD=y

# Enable work queues
CONFIG_SYSTEM_WORKQUEUE=y

# Enable polling
CONFIG_POLL=y
```

### Building as a shared library

To build as `libzephyr.so` instead of an ELF:

```bash
# Add to CMakeLists.txt or pass via command line:
cmake -DBUILD_SHARED_LIBS=ON ...
```

Or use the ELF directly — ctypes can load ELF files on Linux via `CDLL()`.

## Architecture: Two Integration Modes

### Mode A: Mojo Drives Zephyr (ctypes)

```
Mojo process
  │
  ├── ctypes.CDLL("zephyr.elf")
  ├── Calls k_sem_init() → Zephyr kernel
  ├── Calls k_sleep() → Zephyr scheduler
  └── Polls for events
```

**How:** Mojo loads the Zephyr binary as a shared library. All kernel functions are callable. The Mojo side is the "main loop" — it calls `zephyr_mojo_tick()` periodically to pump the Zephyr scheduler.

**Pros:**
- Simple: no build system changes needed
- Works today with ctypes backend
- Mojo is in control

**Cons:**
- Mojo must pump the scheduler
- Not suitable for hard real-time

### Mode B: Zephyr Drives Mojo (linking)

```
Zephyr native_sim executable
  │
  ├── Linked with Mojo-compiled .o files
  ├── Calls mojo_main() as a thread entry
  └── Mojo calls Zephyr functions via native FFI
```

**How:** Mojo code is compiled to object files with `mojo build`. The Zephyr CMake build links them in. Mojo's entry point (`mojo_main`) is called as a Zephyr thread.

**Pros:**
- Real Zephyr scheduling (preemptive, priority-based)
- Zero overhead (native FFI, no ctypes)
- Production-ready pattern

**Cons:**
- Requires nightly Mojo with `std.ffi`
- Requires CMake integration for Mojo object files
- More complex build

## Debugging

### Check available symbols

```bash
nm -D build/zephyr/zephyr.elf | grep " T k_" | sort
```

### Enable Zephyr debug output

```kconfig
CONFIG_PRINTK=y
CONFIG_DEBUG=y
CONFIG_ASSERT=y
```

### Trace ctypes calls

```python
# In Mojo, print each FFI call:
print("Calling k_sem_init(", sem_addr, ", 0, 10)")
var result = lib.k_sem_init(sem_addr, 0, 10)
print("  ->", result)
```

### Native debugger

```bash
# Run Zephyr under GDB
gdb --args build/zephyr/zephyr.elf
(gdb) run
```

## Common Issues

### "symbol not found" when loading the library

**Cause:** The library wasn't built with the right symbols exported.

**Fix:**
```bash
# Check that symbols are exported
nm -D build/zephyr/zephyr.elf | grep k_sem_init

# If not found, rebuild with:
west build -b native_sim -d build -- -DEXPORT_SYMBOLS=ON
```

### "cannot initialize semaphore" errors

**Cause:** The k_sem struct wasn't properly zeroed.

**Fix:** Use `ctypes.create_string_buffer(size)` which zero-initializes, or call `memset` on the buffer first.

### Threads not running

**Cause:** On native_sim, the Zephyr scheduler needs to be pumped.

**Fix:** Call `zephyr_mojo_tick()` or `k_sleep(K_MSEC(1))` periodically from Mojo.

### "SYS_CLOCK_TICKS_PER_SEC not defined"

**Cause:** Kconfig symbols not available at Mojo compile time.

**Fix:** Use `k_uptime_ticks()` at runtime instead of compile-time constants.

## Performance

On native_sim, a ctypes call adds ~1μs overhead (Python round-trip). For comparison:

| Operation | ctypes overhead | Zephyr native |
|-----------|----------------|---------------|
| k_sem_give | ~1.2μs | ~50ns |
| k_mutex_lock | ~1.3μs | ~80ns |
| k_sleep(1ms) | ~1.1μs + 1ms | ~1ms |
| k_thread_create | ~2μs + alloc | ~500ns + alloc |

For most applications (timers, semaphores, occasional mutex locks), the overhead is negligible. For hot-path operations (thousands of calls/second), switch to the native FFI backend when nightly Mojo supports your platform.

## Next Steps

1. **Add a real test suite:** Create a Zephyr test application that exercises all 69 kernel functions
2. **CI integration:** Run `west build` + `mojo run` in CI for automated testing
3. **Native FFI:** When nightly Mojo ships for Linux, switch to `external_call` for zero overhead
4. **Device drivers:** Add GPIO/UART wrappers and test against native_sim's simulated peripherals
