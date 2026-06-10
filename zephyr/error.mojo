# ─── Zephyr Error type ────────────────────────────────────────────────
# Models the Rust zephyr::error::Error pattern.
# Zephyr returns negative ints for errors (negated errno).
# We wrap these in an Error struct for safe error handling.

from zephyr_sys import errno_name


struct Error(Writable):
    """A Zephyr kernel error (negated errno as positive u32)."""
    var code: UInt32

    def __init__(out self, code: UInt32):
        self.code = code

    def write_to(self, mut writer: Some[Writer]):
        var name = errno_name(self.code)
        writer.write("zephyr error errno:", Int(self.code), " (", name, ")")


# ─── Result helpers ────────────────────────────────────────────────────


def to_result_void(code: Int) raises Error:
    """Convert a Zephyr return code to void Result. Raises Error on failure.

    Zephyr convention: negative return = error (errno), >= 0 = success.
    """
    if code < 0:
        raise Error(UInt32(-code))
    # Success — nothing to return


def to_result(code: Int) raises Error -> Int:
    """Convert a Zephyr return code to Result[Int]. Raises Error on failure.

    Returns the non-negative value (e.g., 0 for success, or a count).
    """
    if code < 0:
        raise Error(UInt32(-code))
    return code
