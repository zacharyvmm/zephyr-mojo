# Smoke test for zephyr-mojo bindings
# Tests that all modules compile.

from zephyr_sys import (
    K_NO_WAIT, K_FOREVER,
    timeout_no_wait, timeout_forever, timeout_ms,
    k_sleep,
    errno_name,
)


def test_constants():
    """Verify Zephyr constants are defined."""
    print("K_NO_WAIT =", K_NO_WAIT)
    print("K_FOREVER =", K_FOREVER)


def test_timeout_helpers():
    """Verify timeout helper functions."""
    var t0 = timeout_no_wait()
    print("timeout_no_wait() =", t0)

    var tf = timeout_forever()
    print("timeout_forever() =", tf)

    var t100 = timeout_ms(100)
    print("timeout_ms(100) =", t100)


def test_errno_names():
    """Verify errno name lookup."""
    print("errno 11 =", errno_name(UInt32(11)))
    print("errno 22 =", errno_name(UInt32(22)))


def test_zephyr_types():
    """Verify safe wrapper types compile."""
    from zephyr import Error
    from zephyr.time import Duration, Timeout

    var err = Error(UInt32(11))  # EAGAIN
    print("Error created:", err)

    var dur = Duration(Int64(100))
    print("Duration(100 ticks):", dur.ticks)

    var t = Timeout.from_ms(500)
    print("Timeout.from_ms(500):", t.raw)


def main() raises:
    test_constants()
    test_timeout_helpers()
    test_errno_names()
    test_zephyr_types()
    print("All smoke tests passed!")
