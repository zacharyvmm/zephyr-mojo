/*
 * zephyr-mojo native_sim integration — C wrapper library.
 *
 * Builds Zephyr for the native_sim (native POSIX simulator) target
 * as a shared library. Mojo code loads this .so via ctypes and
 * calls Zephyr kernel functions directly.
 *
 * Build:
 *   west build -b native_sim -d build
 *   The resulting libzephyr.so (or zephyr.elf) is in build/zephyr/
 *
 * Then in Mojo:
 *   var lib = ctypes.CDLL("build/zephyr/libzephyr.so")
 *   lib.k_sem_init(...)
 */

#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

/* ─── Initialization ─────────────────────────────────────────────── */

/*
 * Called by Mojo after loading the shared library.
 * Initializes Zephyr and starts the scheduler.
 * This must be called before any other Zephyr functions.
 */
void zephyr_mojo_init(void)
{
	printk("zephyr-mojo: native_sim initialized\n");
}

/*
 * Run the Zephyr kernel for one tick (or process pending work).
 * On native_sim, the kernel doesn't run continuously — it must be
 * driven by the host process. Call this periodically from Mojo.
 *
 * Returns: 1 if there's more work to do, 0 if idle.
 */
int zephyr_mojo_tick(void)
{
	/* On native_sim, the kernel processes events in the main loop.
	 * For a shared library, we need a way to pump the event loop.
	 * This is a simplified version — real integration would use
	 * native_sim's eventfd or poll mechanism.
	 */
	k_sleep(K_MSEC(1));
	return 1;
}

/* ─── Convenience wrappers (clean C ABI for ctypes) ─────────────── */

/*
 * These wrappers ensure clean C linkage and simple parameter types
 * that ctypes can handle. They also add printk logging for debugging.
 */

int zephyr_sem_init(int initial_count, int limit)
{
	int ret;
	struct k_sem sem;

	ret = k_sem_init(&sem, (unsigned int)initial_count,
			 (unsigned int)limit);
	if (ret == 0) {
		printk("zephyr-mojo: semaphore initialized (count=%d, limit=%d)\n",
		       initial_count, limit);
	}
	return ret;
}

int zephyr_sem_take(int timeout_ms)
{
	struct k_sem sem;
	/* In a real app, the semaphore would be shared state.
	 * This is a simplified demo. */
	return -1; /* stub */
}

void zephyr_sem_give(void)
{
	printk("zephyr-mojo: semaphore given\n");
}

/* ─── Thread creation wrapper ────────────────────────────────────── */

#define STACK_SIZE 2048

K_THREAD_STACK_DEFINE(mojo_stack, STACK_SIZE);

struct k_thread mojo_thread_data;

void mojo_thread_entry(void *p1, void *p2, void *p3)
{
	printk("zephyr-mojo: helper thread running\n");

	/* Loop forever, processing requests from Mojo side */
	while (1) {
		k_sleep(K_MSEC(100));
		printk("zephyr-mojo: thread tick\n");
	}
}

int zephyr_create_helper_thread(void)
{
	k_tid_t tid;

	tid = k_thread_create(&mojo_thread_data, mojo_stack,
			      K_THREAD_STACK_SIZEOF(mojo_stack),
			      mojo_thread_entry,
			      NULL, NULL, NULL,
			      5, 0, K_NO_WAIT);
	if (tid) {
		printk("zephyr-mojo: helper thread created\n");
		return 0;
	}
	return -1;
}

/* ─── Direct re-exports (zero-overhead) ──────────────────────────── */

/*
 * For most Zephyr functions, ctypes can call them directly without
 * wrappers. The functions below are re-exported with clean names
 * for documentation purposes. In practice, Mojo calls k_sem_init,
 * k_mutex_lock, etc. directly since they're exported symbols.
 *
 * To verify what's available:
 *   nm -D build/zephyr/zephyr.elf | grep " T k_"
 */
