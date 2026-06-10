# ─── Dining Philosophers ──────────────────────────────────────────────
# Classic RTOS synchronization problem.
# Five philosophers share five forks. Each needs two forks to eat.
# Solution: asymmetric fork acquisition prevents deadlock.
#
# To run: mojo run -I . examples/dining_philosophers.mojo

from zephyr import Semaphore, Forever, NoWait
from zephyr.time import Duration, sleep


comptime NUM_PHILOSOPHERS = 5
comptime EAT_TIME_MS = 200
comptime THINK_TIME_MS = 300
comptime CYCLES = 3


def philosopher(id: Int, left_fork: Semaphore, right_fork: Semaphore) raises:
    """One philosopher's dining routine."""
    var meals: Int = 0

    for _ in range(CYCLES):
        # Think
        print("Philosopher", id, "is thinking...")
        _ = sleep(Duration.from_ms(THINK_TIME_MS))

        # Acquire forks (asymmetric: odd = left first, even = right first)
        if id % 2 == 1:
            left_fork.take(Forever())
            print("  P", id, "picked up left fork")
            _ = sleep(Duration.from_ms(10))
            right_fork.take(Forever())
            print("  P", id, "picked up right fork")
        else:
            right_fork.take(Forever())
            print("  P", id, "picked up right fork")
            _ = sleep(Duration.from_ms(10))
            left_fork.take(Forever())
            print("  P", id, "picked up left fork")

        # Eat
        meals += 1
        print("  P", id, "is EATING (meal", meals, "of", CYCLES, ")")
        _ = sleep(Duration.from_ms(EAT_TIME_MS))

        # Release forks
        left_fork.give()
        right_fork.give()
        print("  P", id, "put down forks")

    print("Philosopher", id, "finished. Ate", meals, "meals.")


def main() raises:
    print("=== Dining Philosophers ===")
    print(NUM_PHILOSOPHERS, "philosophers,", CYCLES, "meals each")
    print("")

    # Create forks (binary semaphores)
    var forks = List[Semaphore]()
    for _ in range(NUM_PHILOSOPHERS):
        forks.append(Semaphore.create(1, 1))  # Available initially

    # Run philosophers sequentially (simulates concurrent execution)
    for i in range(NUM_PHILOSOPHERS):
        var left = forks[i].copy()
        var right = forks[(i + 1) % NUM_PHILOSOPHERS].copy()
        philosopher(i, left, right)

    print("")
    print("=== Dinner complete! No deadlock. ===")
