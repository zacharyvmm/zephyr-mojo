# ─── Channel Demo ─────────────────────────────────────────────────────
# Multi-producer, single-consumer channel messaging.

from zephyr import channel, Forever, NoWait


def main() raises:
    print("=== Channel Demo ===")
    print("")

    # Create an MPSC channel
    var tx, rx = channel()
    print("Channel created")

    # Send messages
    var count: Int = 5
    print("Sending", count, "messages...")
    for i in range(count):
        tx.send(i * 10)
        print("  Sent", i * 10)
    print("")

    # Receive all messages
    print("Receiving...")
    var received: Int = 0
    while not rx.is_empty():
        var msg = rx.try_recv()
        received += 1
        print("  Received", msg)

    print("")
    print("Received", received, "messages (expected", count, ")")
    if received == count:
        print("Channel demo PASSED")
    else:
        print("Channel demo FAILED")
    print("")

    # Verify non-blocking receive on empty channel raises
    print("Testing empty receive...")
    try:
        var _ = rx.try_recv()
        print("ERROR: should have raised")
    except:
        print("Correctly raised Error on empty channel")

    print("")
    print("Channel demo complete!")
