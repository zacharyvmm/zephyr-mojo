#!/usr/bin/env python3
"""
Validate that the native backend output is syntactically valid Mojo.

Run after `python3 -m codegen.gen_sys --backend native` to verify
that the generated code will compile on a nightly Mojo with std.ffi.
"""

import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def validate_native_syntax(path: str) -> tuple[int, list[str]]:
    """Check a native-backend .mojo file for common issues. Returns (errors, messages)."""
    errors = 0
    messages = []

    with open(path) as f:
        content = f.read()

    # Check 1: No Python/ctypes imports in native mode
    if "from std.python import" in content:
        errors += 1
        messages.append("ERROR: native backend should not import std.python")

    if "Python.import_module" in content:
        errors += 1
        messages.append("ERROR: native backend should not use Python.import_module")

    if "ctypes.CDLL" in content:
        errors += 1
        messages.append("ERROR: native backend should not use ctypes.CDLL")

    if "PythonObject(" in content:
        errors += 1
        messages.append("ERROR: native backend should not use PythonObject()")

    # Check 2: Has std.ffi imports
    if "from std.ffi import" not in content:
        errors += 1
        messages.append("ERROR: native backend must import std.ffi")

    if "external_call" not in content:
        errors += 1
        messages.append("ERROR: native backend must use external_call")

    # Check 3: C type aliases used
    if "c_int" not in content and "c_uint" not in content:
        messages.append("WARNING: no C type aliases found (all pointers?)")

    # Check 4: Function count
    func_count = len(re.findall(r"external_call\[", content))
    messages.append(f"INFO: {func_count} external_call invocations")

    # Check 5: No Python conversion calls
    if "Int(py=" in content:
        errors += 1
        messages.append("ERROR: native backend should not use Int(py=...)")

    if "Python.evaluate" in content:
        errors += 1
        messages.append("ERROR: native backend should not use Python.evaluate")

    return errors, messages


def main():
    native_file = os.path.join(PROJECT_ROOT, "zephyr_sys", "__init__.mojo")

    if not os.path.exists(native_file):
        print("ERROR: zephyr_sys/__init__.mojo not found. Run gen_sys first.")
        sys.exit(1)

    # Check which backend is active
    with open(native_file) as f:
        first_lines = "".join(f.readline() for _ in range(5))
    if "Backend: native" not in first_lines:
        print("ERROR: Current backend is not native. Run:")
        print("  python3 -m codegen.gen_sys --backend native")
        sys.exit(1)

    print(f"Validating: {native_file}")
    errors, messages = validate_native_syntax(native_file)

    for msg in messages:
        print(f"  {msg}")

    if errors == 0:
        print("")
        print("✓ Native backend output is valid!")
        print("  Ready for Mojo nightly with std.ffi on Linux.")
        sys.exit(0)
    else:
        print("")
        print(f"✗ {errors} errors found")
        sys.exit(1)


if __name__ == "__main__":
    main()
