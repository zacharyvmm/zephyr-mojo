# ─── Producer-Consumer ────────────────────────────────────────────────
# Classic producer-consumer using Zephyr queue + counting semaphore.

from zephyr import Queue, Semaphore, Forever, NoWait
from zephyr.time import Duration, sleep


comptime ITEMS_PER_PRODUCER = 3


def main() raises:
    print("=== Producer-Consumer ===")
    print("")

    # Create primitives
    var q = Queue.create()
    var sem = Semaphore.create(0, ITEMS_PER_PRODUCER * 2)

    # Produce
    print("Producing...")
    for i in range(ITEMS_PER_PRODUCER):
        _ = sleep(Duration.from_ms(50))
        q.append(i)
        sem.give()
        print("  Produced item", i)

    # Consume
    print("")
    print("Consuming...")
    for _ in range(ITEMS_PER_PRODUCER):
        sem.take(Forever())
        var item = q.get(NoWait())
        print("  Consumed item", item)
        _ = sleep(Duration.from_ms(30))

    print("")
    print("All items produced and consumed!")
