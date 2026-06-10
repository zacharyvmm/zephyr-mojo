# zephyr-mojo

Safe, idiomatic Mojo bindings for the [Zephyr RTOS](https://zephyrproject.org/) kernel API.

## Architecture

Inspired by the [Rust Zephyr bindings](https://github.com/zephyrproject-rtos/zephyr-lang-rust), this project uses a three-layer design:

```
zephyr_sys/     Layer 1: Raw FFI bindings via Python ctypes (auto-generated)
zephyr/         Layer 2: Safe wrappers with error handling
zephyr/sync/    Layer 3: Idiomatic Mojo API (Mutex[T], Condvar, etc.)
```

## Project status

Early development. Currently targeting Mojo 1.0.0b1.

**Implemented:**
- 42 Zephyr kernel API functions (semaphore, mutex, condvar, queue, timer, thread, msgq, stack)
- Error type with errno lookup
- Time types (Duration, Instant, Timeout, sleep)
- Safe semaphore wrapper with trait-based timeout handling
- Safe mutex wrapper
- Safe condition variable wrapper
- Safe timer wrapper
- Safe queue wrapper
- Idiomatic sync primitives (Mutex[T], Condvar)

**Code generator:**
```bash
python3 -m codegen.gen_sys    # Regenerate zephyr_sys/ from spec
```

**Run tests:**
```bash
mojo run -I . tests/test_smoke.mojo
mojo run -I . tests/test_imports.mojo
```

## FFI Backend

Mojo currently has no native C FFI. All kernel calls go through Python's `ctypes` module. When Mojo adds native C interop, the `zephyr_sys` layer can be regenerated to use `extern` declarations — the higher-level API stays unchanged.

## Reference

The Rust bindings at `zephyr-lang-rust` serve as the architectural model:
- `zephyr-sys/` → `zephyr_sys/` (raw FFI)
- `zephyr/src/sys/` → `zephyr/` (safe wrappers)
- `zephyr/src/sync/` → `zephyr/sync/` (idiomatic API)
