#!/usr/bin/env python3
"""
Backend detector and switcher for zephyr-mojo.

Detects whether Mojo nightly (with std.ffi) is available and
switches between ctypes and native FFI backends automatically.

Usage:
  python3 scripts/switch_backend.py          # Auto-detect and switch
  python3 scripts/switch_backend.py ctypes   # Force ctypes
  python3 scripts/switch_backend.py native   # Force native
  python3 scripts/switch_backend.py --check  # Just report, don't switch
"""

import os
import subprocess
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VENV_MOJO = os.path.join(PROJECT_ROOT, ".venv", "bin", "mojo")


def detect_native_ffi() -> bool:
    """Check if the installed Mojo supports std.ffi (nightly feature)."""
    if not os.path.exists(VENV_MOJO):
        return False

    # Try to import std.ffi — if it compiles, native FFI is available
    test_code = "from std.ffi import external_call, c_int"
    try:
        result = subprocess.run(
            [VENV_MOJO, "run", "-"],
            input=test_code,
            capture_output=True,
            text=True,
            timeout=15,
            cwd=PROJECT_ROOT,
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def get_current_backend() -> str:
    """Read the current backend from zephyr_sys/__init__.mojo header."""
    init_path = os.path.join(PROJECT_ROOT, "zephyr_sys", "__init__.mojo")
    if not os.path.exists(init_path):
        return "unknown"

    with open(init_path) as f:
        for line in f:
            if "Backend:" in line:
                if "native" in line:
                    return "native"
                elif "ctypes" in line:
                    return "ctypes"
    return "unknown"


def switch_backend(backend: str) -> bool:
    """Run the code generator with the specified backend."""
    result = subprocess.run(
        [sys.executable, "-m", "codegen.gen_sys", "--backend", backend],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if result.returncode == 0:
        print(f"Switched to {backend} backend")
        return True
    else:
        print(f"Failed to switch: {result.stderr}")
        return False


def validate_native_output() -> bool:
    """Check that the native backend output is syntactically valid Mojo."""
    # Run mojo parse (if available) or just check imports exist
    test_code = """
from zephyr_sys import K_NO_WAIT, K_FOREVER, timeout_no_wait
"""
    result = subprocess.run(
        [VENV_MOJO, "run", "-I", PROJECT_ROOT, "-"],
        input=test_code,
        capture_output=True,
        text=True,
        timeout=15,
        cwd=PROJECT_ROOT,
    )
    # We expect failure at runtime (no Zephyr symbols) but not at parse time
    stderr = result.stderr
    if "error: failed to parse" in stderr:
        print("Native output has parse errors!")
        print(stderr)
        return False
    return True


def main():
    import argparse
    parser = argparse.ArgumentParser(description="zephyr-mojo backend switcher")
    parser.add_argument("backend", nargs="?", choices=["ctypes", "native"],
                        help="Force a specific backend")
    parser.add_argument("--check", action="store_true",
                        help="Just check, don't switch")
    args = parser.parse_args()

    current = get_current_backend()
    has_native = detect_native_ffi()

    print(f"Current backend: {current}")
    print(f"Native FFI available: {has_native}")

    if args.check:
        return

    if args.backend:
        target = args.backend
    elif has_native:
        target = "native"
        print("Auto-selecting native backend (std.ffi detected)")
    else:
        target = "ctypes"
        print("Falling back to ctypes backend (std.ffi not found)")

    if switch_backend(target):
        if target == "native":
            validate_native_output()


if __name__ == "__main__":
    main()
