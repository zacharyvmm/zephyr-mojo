# Examples

Practical examples demonstrating zephyr-mojo bindings.

## Running

All examples run on the host via the ctypes backend (no hardware needed):

```bash
mojo run -I . examples/dining_philosophers.mojo
mojo run -I . examples/producer_consumer.mojo
mojo run -I . examples/blinky.mojo
mojo run -I . examples/mutex_guard.mojo
mojo run -I . examples/channel_demo.mojo
mojo run -I . examples/thread_demo.mojo
```

For real Zephyr hardware or native_sim, see [docs/native-sim.md](../docs/native-sim.md).

## Examples

| Example | Concepts | Description |
|---------|----------|-------------|
| `dining_philosophers.mojo` | Semaphore, deadlock prevention | Classic RTOS synchronization problem |
| `producer_consumer.mojo` | Queue, Semaphore | Producer-consumer with counting semaphore |
| `blinky.mojo` | Timer, sleep | Periodic LED blinker (hello world of embedded) |
| `mutex_guard.mojo` | Mutex[T], MutexGuard | Type-safe data protection with RAII |
| `channel_demo.mojo` | Channel, MPSC | Multi-producer, single-consumer messaging |
| `thread_demo.mojo` | Thread, ThreadBuilder | Thread lifecycle, priorities, scheduling |

## On real Zephyr

Replace `mojo run` with `west build` + the native_sim integration:

```bash
# Build Zephyr native_sim with the example
west build -b native_sim -d build

# Or compile with Mojo + link:
# (requires nightly Mojo with std.ffi on Linux)
mojo build examples/dining_philosophers.mojo -o build/philosophers.o
```
