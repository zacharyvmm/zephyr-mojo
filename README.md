# zephyr-mojo

Safe, idiomatic Mojo bindings for the [Zephyr RTOS](https://zephyrproject.org/) kernel API.

## Architecture

Inspired by the [Rust Zephyr bindings](https://github.com/zephyrproject-rtos/zephyr-lang-rust), three-layer design:

```
zephyr_sys/     Layer 1: Raw FFI bindings (auto-generated, dual-backend)
zephyr/         Layer 2: Safe wrappers with error handling (14 modules)
zephyr/sync/    Layer 3: Idiomatic Mojo API (Mutex[T], Condvar, SpinMutex)
```

## Project status

Early development. Targeting Mojo 1.0.0b1 (stable) and nightly.

**69 Zephyr kernel API functions:** semaphore, mutex, condvar, queue, timer, thread, msgq, stack, work, poll, fifo, lifo, irq, scheduling.

**14 safe wrapper modules:**
| Module | Contents |
|--------|----------|
| `zephyr/error.mojo` | Error(UInt32), to_result, to_result_void |
| `zephyr/time.mojo` | Duration, Instant, Timeout, sleep |
| `zephyr/semaphore.mojo` | Semaphore + TimeoutConvertible trait |
| `zephyr/mutex.mojo` | Sys-level Mutex |
| `zephyr/condvar.mojo` | Sys-level Condvar |
| `zephyr/timer.mojo` | Timer |
| `zephyr/queue.mojo` | Queue |
| `zephyr/thread.mojo` | Thread, ThreadStack, ThreadBuilder |
| `zephyr/channel.mojo` | ChannelSender, ChannelReceiver (MPSC) |
| `zephyr/work.mojo` | Signal, Work, SubmitResult |
| `zephyr/logging.mojo` | printk, panic, Logger with leveled output |
| `zephyr/object.mojo` | ZephyrObject, Fixed |
| `zephyr/sync/` | Mutex[T] + MutexGuard, Condvar, SpinMutex |

## Dual FFI Backend

The code generator supports two backends:

```bash
# Python ctypes backend (default, works on stable Mojo 1.0)
python3 -m codegen.gen_sys --backend ctypes

# Native FFI backend (requires nightly Mojo with std.ffi)
python3 -m codegen.gen_sys --backend native
```

**ctypes backend** generates code like:
```mojo
var lib = _get_lib()                          # Python ctypes CDLL
var _py = lib.k_sem_init(PythonObject(sem), ...)
return Int(py=_py)
```

**native backend** generates zero-overhead C calls:
```mojo
from std.ffi import external_call, c_int, c_uint
return external_call["k_sem_init", c_int, Int, c_uint, c_uint](sem, count, limit)
```

The higher-level API (`zephyr/`) is backend-agnostic — swap backends without changing application code.

## Run tests

```bash
mojo run -I . tests/test_smoke.mojo         # Constants, timeouts, error type
mojo run -I . tests/test_imports.mojo       # All 14 modules compile
mojo run -I . tests/test_native_smoke.mojo  # Native FFI imports (nightly only)
```

## Reference

The Rust bindings at `zephyr-lang-rust` serve as the architectural model:
- `zephyr-sys/` → `zephyr_sys/` (raw FFI)
- `zephyr/src/sys/` → `zephyr/` (safe wrappers)
- `zephyr/src/sync/` → `zephyr/sync/` (idiomatic API)

## Documentation

- [API Reference](docs/api-reference.md) — Complete API docs with examples
- [native_sim Integration](docs/native-sim.md) — Run Mojo on Zephyr without hardware
