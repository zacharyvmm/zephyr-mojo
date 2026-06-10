"""
Backend-specific code generation for zephyr_sys.

Two backends:
- ctypes: Python ctypes FFI (works on stable Mojo 1.0)
- native: Mojo std.ffi.external_call (requires nightly with C FFI)
"""

import os
from typing import Optional


# ─── C type → Mojo type mapping ────────────────────────────────────────

# For the ctypes backend, all C types map through PythonObject.
# For the native backend, we use std.ffi C type aliases.

NATIVE_C_TYPE_MAP = {
    "void": "NoneType",
    "int": "c_int",
    "int32_t": "c_int",
    "int64_t": "c_long_long",
    "uint32_t": "c_uint",
    "unsigned int": "c_uint",
    "size_t": "c_size_t",
    "void *": "Int",          # pointers as raw Int
    "struct k_sem *": "Int",
    "struct k_mutex *": "Int",
    "struct k_condvar *": "Int",
    "struct k_queue *": "Int",
    "struct k_timer *": "Int",
    "struct k_thread *": "Int",
    "struct k_msgq *": "Int",
    "struct k_stack *": "Int",
    "struct k_fifo *": "Int",
    "struct k_lifo *": "Int",
    "struct k_work *": "Int",
    "struct k_work_q *": "Int",
    "struct k_poll_event *": "Int",
    "struct k_poll_signal *": "Int",
    "k_thread_stack_t *": "Int",
    "k_thread_entry_t": "Int",
    "k_ticks_t": "c_long_long",
    "k_timeout_t": "c_long_long",  # int64_t on 64-bit
    "k_tid_t": "Int",
    "const char *": "Int",
    "stack_data_t": "Int",
    "stack_data_t *": "Int",
}


def native_type(c_type: str) -> str:
    """Map a C type to its native Mojo FFI type."""
    return NATIVE_C_TYPE_MAP.get(c_type, "Int")


def is_void_type(c_type: str) -> bool:
    """Check if a C type is void."""
    return c_type in ("void", "NoneType")


# ─── Backend base class ─────────────────────────────────────────────────

class Backend:
    """Base class for FFI backends."""
    name: str = "base"

    def emit_imports(self) -> list[str]:
        raise NotImplementedError

    def emit_function(self, func) -> list[str]:
        """Emit a single function wrapper. Returns list of source lines."""
        raise NotImplementedError

    def needs_raises(self) -> bool:
        """Does this backend require `raises` on generated functions?"""
        return True


# ─── Ctypes Backend ─────────────────────────────────────────────────────

class CtypesBackend(Backend):
    """Python ctypes FFI backend (works on stable Mojo 1.0)."""
    name = "ctypes"

    def emit_imports(self) -> list[str]:
        return [
            "from std.python import Python, PythonObject",
        ]

    def needs_raises(self) -> bool:
        return True

    def emit_function(self, func) -> list[str]:
        lines = []

        # Parameter list (pointers → Int)
        params = []
        for p in func.params:
            if p.is_pointer:
                params.append(f"{p.name}: Int")
            else:
                params.append(f"{p.name}: {p.mojo_type}")
        param_str = ", ".join(params)

        # Return type
        if func.mojo_return in ("NoneType",):
            ret = ""
        elif func.mojo_return == "Pointer":
            ret = " -> Int"
        else:
            ret = f" -> {func.mojo_return}"

        lines.append(f"def {func.name}({param_str}) raises{ret}:")
        lines.append(f'    """{func.description}"""')
        lines.append("    var lib = _get_lib()")

        # Build ctypes call args
        args_parts = []
        for p in func.params:
            if p.mojo_type in ("Int64", "Int"):
                args_parts.append(f"PythonObject({p.name})")
            elif p.mojo_type == "UInt32":
                args_parts.append(f"PythonObject(Int({p.name}))")
            elif p.mojo_type == "UInt64":
                args_parts.append(f"PythonObject(Int({p.name}))")
            else:
                args_parts.append(f"PythonObject({p.name})")
        args_str = ", ".join(args_parts)

        if func.mojo_return in ("NoneType",):
            lines.append(f"    var _ = lib.{func.name}({args_str})")
        else:
            lines.append(f"    var _py = lib.{func.name}({args_str})")
            if func.mojo_return == "Int":
                lines.append("    return Int(py=_py)")
            elif func.mojo_return == "Int64":
                lines.append("    return Int64(Int(py=_py))")
            elif func.mojo_return == "UInt32":
                lines.append("    return UInt32(Int(py=_py))")
            elif func.mojo_return == "UInt64":
                lines.append("    return UInt64(Int(py=_py))")
            elif func.mojo_return == "Pointer":
                lines.append("    return Int(py=_py)")
            else:
                lines.append(f"    return {func.mojo_return}(_py)")

        lines.append("")
        return lines

    def emit_get_lib(self) -> list[str]:
        """Emit the lazy ctypes CDLL loader."""
        return [
            "",
            "def _get_lib() raises -> PythonObject:",
            '    """Lazily load the C library for FFI calls."""',
            '    var ctypes = Python.import_module("ctypes")',
            '    return ctypes.CDLL(Python.evaluate("None"))',
        ]


# ─── Native FFI Backend ────────────────────────────────────────────────

class NativeBackend(Backend):
    """Native Mojo std.ffi.external_call backend (requires nightly)."""
    name = "native"

    def emit_imports(self) -> list[str]:
        return [
            "from std.ffi import external_call",
            "from std.ffi import c_int, c_uint, c_long, c_long_long",
            "from std.ffi import c_size_t, c_ssize_t",
            "from std.ffi import c_char, c_uchar",
            "from std.ffi import c_short, c_ushort",
            "from std.ffi import c_float, c_double",
        ]

    def needs_raises(self) -> bool:
        # external_call may raise if the symbol isn't found at link time
        return True

    def emit_function(self, func) -> list[str]:
        lines = []

        # Parameter list (pointers → Int)
        params = []
        for p in func.params:
            if p.is_pointer:
                params.append(f"{p.name}: Int")
            else:
                # Map to native C type
                nt = native_type(p.c_type)
                params.append(f"{p.name}: {nt}")
        param_str = ", ".join(params)

        # Return type mapping
        ret_c_type = native_type(func.return_type)
        if ret_c_type in ("NoneType",):
            ret_annotation = ""
        else:
            ret_annotation = f" -> {ret_c_type}"

        lines.append(f"def {func.name}({param_str}) raises{ret_annotation}:")
        lines.append(f'    """{func.description}"""')

        # Build external_call type parameters
        ret_native = native_type(func.return_type)
        arg_types = []
        for p in func.params:
            nt = native_type(p.c_type)
            arg_types.append(nt)

        type_params = f'"{func.name}", {ret_native}'
        if arg_types:
            type_params += ", " + ", ".join(arg_types)

        # Build call args
        arg_names = ", ".join(p.name for p in func.params)

        if func.mojo_return in ("NoneType",):
            lines.append(f"    var _ = external_call[{type_params}]({arg_names})")
        else:
            lines.append(f"    return external_call[{type_params}]({arg_names})")

        lines.append("")
        return lines

    def emit_get_lib(self) -> list[str]:
        """Native backend doesn't need a lazy loader."""
        return []


# ─── Backend factory ────────────────────────────────────────────────────

BACKENDS = {
    "ctypes": CtypesBackend,
    "native": NativeBackend,
}


def get_backend(name: str) -> Backend:
    """Get a backend by name."""
    if name not in BACKENDS:
        raise ValueError(f"Unknown backend: {name}. Available: {', '.join(BACKENDS)}")
    return BACKENDS[name]()
