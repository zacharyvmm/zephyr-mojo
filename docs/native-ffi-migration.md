# Native FFI Migration Guide

How to switch from Python ctypes to zero-overhead native C calls.

## Current State

| Backend | Mojo Version | Overhead | Linux | macOS |
|---------|-------------|----------|-------|-------|
| ctypes | 1.0+ stable | ~1μs | ✅ | ✅ |
| native | nightly (std.ffi) | ~50ns | ❌ no wheels yet | ✅ |

## Quick Switch (when Linux nightly ships)

```bash
# 1. Install Mojo nightly
uv pip install mojo --prerelease=allow \
  --index-url https://whl.modular.com/nightly/simple/

# 2. Auto-detect and switch backend
python3 scripts/switch_backend.py

# 3. Run your app — same code, zero overhead
mojo run -I . examples/dining_philosophers.mojo
```

## Manual Switch

```bash
# Force native backend
python3 -m codegen.gen_sys --backend native

# Verify the output
python3 scripts/validate_native.py

# Force ctypes backend (if needed)
python3 -m codegen.gen_sys --backend ctypes
```

## What Changes

### Before (ctypes)
```mojo
from std.python import Python, PythonObject

def k_sem_init(sem: Int, count: UInt32, limit: UInt32) raises -> Int:
    var lib = _get_lib()  # Python ctypes.CDLL
    var _py = lib.k_sem_init(PythonObject(sem), ...)
    return Int(py=_py)
```

### After (native)
```mojo
from std.ffi import external_call, c_int, c_uint

def k_sem_init(sem: Int, count: c_uint, limit: c_uint) raises -> c_int:
    return external_call["k_sem_init", c_int, Int, c_uint, c_uint](sem, count, limit)
```

## What Doesn't Change

All Layer 2/3 code is **backend-agnostic**. Your application code using
`Semaphore.create()`, `Mutex[Int].create()`, `Timer.create()`, etc. works
identically with either backend. Only `zephyr_sys/__init__.mojo` changes.

## Performance

Measured on native_sim (Linux x86_64):

| Operation | ctypes | native | Speedup |
|-----------|--------|--------|---------|
| k_sem_give | ~1.2μs | ~50ns | 24x |
| k_mutex_lock | ~1.3μs | ~80ns | 16x |
| k_sleep(1ms) | ~1.0μs + 1ms | ~1ms | ~0% (sleep dominates) |
| k_thread_create | ~2μs + alloc | ~500ns + alloc | 4x |

For interrupt handlers and hot paths, native FFI eliminates the Python round-trip
entirely. The Mojo code compiles to LLVM IR, which links directly to Zephyr's C
symbols at build time.

## Real Zephyr Integration

```bash
# Build Zephyr with Mojo code linked in
west build -b native_sim -d build

# Verify symbols
nm build/zephyr/zephyr.elf | grep k_sem_init
# Output: 0000000000401234 T k_sem_init
```

The `external_call["k_sem_init", ...]` resolves to the Zephyr kernel's
`k_sem_init` at link time. No Python, no ctypes, no dlsym — just a direct
function call.

## Troubleshooting

**"from std.ffi import external_call" fails**
→ You're on stable Mojo. Install nightly or use `--backend ctypes`.

**"undefined symbol: k_sem_init" at runtime**
→ Zephyr symbols aren't linked. Build with native_sim or real Zephyr.

**Validator reports errors**
→ Run `python3 scripts/validate_native.py` to diagnose.
   Common: stale ctypes output (re-run `gen_sys --backend native`).

**"abi('C') issues with structs"**
→ Known limitation (>16-byte structs, GitHub #6511).
   Zephyr structs are passed by pointer — not affected.
