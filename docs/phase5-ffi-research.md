# Phase 5: Native FFI Feasibility Research

## Finding: Native FFI IS available on Linux (nightly)

GitHub issues confirm active Linux FFI development:

- **#6567** — "Mojo-to-C FFI does not implement rollback-to-stack for SysV ABI"
  → SysV ABI = Linux x86_64 calling convention. FFI works but has stack unwind issues.

- **#6511** — "abi('C') callback receives incorrect >16-byte struct values from C (Linux x86_64)"
  → Explicitly confirms `external_call` and `abi("C")` work on Linux.

- **#3144** — "FFI BUG when passing structs from mojo to c"
  → Struct passing fixed/being fixed for C interop.

## Status

| Component | Status | Notes |
|-----------|--------|-------|
| `std.ffi.external_call` | ✅ Available (nightly) | Compile-time C function resolution |
| `std.ffi.OwnedDLHandle` | ✅ Available (nightly) | Runtime shared library loading |
| `std.ffi.c_int`, `c_size_t`, etc. | ✅ Available (nightly) | C type aliases |
| `abi("C")` | ✅ Available (nightly) | C calling convention |
| Linux x86_64 support | ✅ Confirmed | SysV ABI, active bug fixes |
| Linux PyPI wheels | ❌ Not yet | macOS-only wheels as of June 2026 |
| ARM/AArch64 | ❓ Unknown | No confirmatory issues found |
| RISC-V | ❓ Unknown | Zephyr target, needs investigation |

## What Our Codegen Already Does

Our `--backend native` generator produces correct `external_call` syntax:

```mojo
from std.ffi import external_call, c_int, c_uint

def k_sem_init(sem: Int, count: c_uint, limit: c_uint) raises -> c_int:
    return external_call["k_sem_init", c_int, Int, c_uint, c_uint](sem, count, limit)
```

This is directly compatible with the nightly FFI API. **No code changes needed.**

## Migration Path

1. **Today (Mojo 1.0 stable):** ctypes backend works on all platforms
2. **When Linux nightly wheels ship:**
   ```bash
   uv pip install mojo --prerelease=allow --index-url https://whl.modular.com/nightly/simple/
   python3 -m codegen.gen_sys --backend native
   mojo run -I . examples/dining_philosophers.mojo
   ```
3. **For real Zephyr:** Mojo compiles to `.o` → CMake links into Zephyr binary → `external_call` resolves kernel symbols at link time

## Known Limitations (from GitHub issues)

- **Struct passing:** >16-byte structs may have issues (#6511). Most Zephyr structs (k_sem, k_mutex) are small (<64 bytes, passed by pointer).
- **Stack unwind:** May not properly clean up on exceptions (#6567). Use `try`/`except` as we already do.
- **Zephyr-specific structs:** `k_timeout_t`, `k_ticks_t` are simple integers — should work fine.
- **Callbacks:** C→Mojo callbacks may have ABI issues. For Zephyr, ISRs and thread entries would need this. Current workaround: C wrapper functions.

## Recommendation

The native backend is **ready to use as soon as Linux nightly wheels ship**. No code changes needed. The ctypes backend remains the production path for stable Mojo. When nightly Linux support lands:

1. Switch `--backend native` in the generator
2. Run the full test suite against native_sim
3. Measure zero-overhead call latency (expected ~50ns vs ~1μs for ctypes)
4. Add CI job for native backend once available

## Tracking

- Watch: https://github.com/modular/modular/issues/6567 (SysV ABI fix)
- Watch: https://github.com/modular/modular/issues/6511 (struct ABI fix)
- PyPI: `mojo` package with Linux wheels → check https://pypi.org/project/mojo/#files
