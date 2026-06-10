# ─── Blinky ───────────────────────────────────────────────────────────
# Periodic LED blinker using Zephyr sleep/timer.

from zephyr.time import Duration, sleep


comptime BLINK_PERIOD_MS = 500
comptime NUM_BLINKS = 4


def main() raises:
    print("=== Blinky ===")
    print("")

    var state: Bool = False

    for i in range(NUM_BLINKS):
        state = not state
        if state:
            print("[LED] ON  (blink", i + 1, "of", NUM_BLINKS, ")")
        else:
            print("[LED] OFF (blink", i + 1, "of", NUM_BLINKS, ")")
        _ = sleep(Duration.from_ms(BLINK_PERIOD_MS))

    print("")
    print("Blinky complete!")
