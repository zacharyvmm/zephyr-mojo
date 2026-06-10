"""
Zephyr kernel API specification.

Defines the functions and types we want to generate Mojo bindings for.
Data extracted from zephyr/include/zephyr/kernel.h (Zephyr v4.1.0).

Each entry maps a Zephyr C function to its Mojo binding metadata.
"""

from dataclasses import dataclass, field
from typing import Optional

# Zephyr magic timeout values
K_NO_WAIT = 0
K_FOREVER = -1
K_MSEC = lambda ms: ms  # k_timeout_t from milliseconds
K_SECONDS = lambda s: s * 1000


@dataclass
class Param:
    """A C function parameter."""
    name: str
    c_type: str           # C type string (e.g., "struct k_sem *", "k_timeout_t")
    mojo_type: str        # Mojo type (e.g., "Int", "Pointer")
    is_pointer: bool = False
    is_const: bool = False
    description: str = ""


@dataclass
class Function:
    """A Zephyr kernel API function."""
    name: str
    return_type: str       # C return type
    mojo_return: str       # Mojo return type
    params: list[Param] = field(default_factory=list)
    is_syscall: bool = True  # Most Zephyr kernel APIs are __syscall
    returns_error: bool = False  # negative return = errno
    description: str = ""
    category: str = ""     # semaphore, mutex, thread, time, queue, timer


@dataclass
class StructField:
    """A field in a C struct."""
    name: str
    c_type: str
    description: str = ""


@dataclass
class StructDef:
    """A Zephyr C struct definition."""
    name: str
    fields: list[StructField] = field(default_factory=list)
    description: str = ""


# ─── Type mapping ────────────────────────────────────────────────────────

C_TO_MOJO = {
    "int": "Int",
    "int32_t": "Int",
    "int64_t": "Int",
    "uint32_t": "UInt32",
    "unsigned int": "UInt32",
    "void": "NoneType",
    "size_t": "Int",
    "k_ticks_t": "Int64",
    "k_timeout_t": "Int64",   # passed as raw 64-bit value
    "k_tid_t": "Pointer",
    "stack_data_t": "Int",
}


# ─── API Specification ───────────────────────────────────────────────────

FUNCTIONS = [
    # ── Time ──────────────────────────────────────────────────────────
    Function(
        name="k_sleep",
        return_type="int32_t",
        mojo_return="Int",
        params=[Param("timeout", "k_timeout_t", "Int64", description="Sleep duration")],
        returns_error=False,
        description="Put the current thread to sleep.",
        category="time",
    ),
    Function(
        name="k_uptime_ticks",
        return_type="int64_t",
        mojo_return="Int64",
        params=[],
        returns_error=False,
        description="Get the system uptime in ticks.",
        category="time",
    ),

    # ── Semaphore ──────────────────────────────────────────────────────
    Function(
        name="k_sem_init",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("sem", "struct k_sem *", "Pointer", is_pointer=True),
            Param("initial_count", "unsigned int", "UInt32"),
            Param("limit", "unsigned int", "UInt32"),
        ],
        returns_error=True,
        description="Initialize a semaphore.",
        category="semaphore",
    ),
    Function(
        name="k_sem_take",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("sem", "struct k_sem *", "Pointer", is_pointer=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Take a semaphore (decrement count, possibly waiting).",
        category="semaphore",
    ),
    Function(
        name="k_sem_give",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("sem", "struct k_sem *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Give a semaphore (increment count).",
        category="semaphore",
    ),
    Function(
        name="k_sem_reset",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("sem", "struct k_sem *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Reset semaphore count to zero.",
        category="semaphore",
    ),
    Function(
        name="k_sem_count_get",
        return_type="unsigned int",
        mojo_return="UInt32",
        params=[Param("sem", "struct k_sem *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Get current semaphore count.",
        category="semaphore",
    ),

    # ── Mutex ──────────────────────────────────────────────────────────
    Function(
        name="k_mutex_init",
        return_type="int",
        mojo_return="Int",
        params=[Param("mutex", "struct k_mutex *", "Pointer", is_pointer=True)],
        returns_error=True,
        description="Initialize a mutex.",
        category="mutex",
    ),
    Function(
        name="k_mutex_lock",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("mutex", "struct k_mutex *", "Pointer", is_pointer=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Lock a mutex (blocking until acquired or timeout).",
        category="mutex",
    ),
    Function(
        name="k_mutex_unlock",
        return_type="int",
        mojo_return="Int",
        params=[Param("mutex", "struct k_mutex *", "Pointer", is_pointer=True)],
        returns_error=True,
        description="Unlock a mutex.",
        category="mutex",
    ),

    # ── Condvar ────────────────────────────────────────────────────────
    Function(
        name="k_condvar_init",
        return_type="int",
        mojo_return="Int",
        params=[Param("condvar", "struct k_condvar *", "Pointer", is_pointer=True)],
        returns_error=True,
        description="Initialize a condition variable.",
        category="condvar",
    ),
    Function(
        name="k_condvar_signal",
        return_type="int",
        mojo_return="Int",
        params=[Param("condvar", "struct k_condvar *", "Pointer", is_pointer=True)],
        returns_error=True,
        description="Signal one thread waiting on the condvar.",
        category="condvar",
    ),
    Function(
        name="k_condvar_broadcast",
        return_type="int",
        mojo_return="Int",
        params=[Param("condvar", "struct k_condvar *", "Pointer", is_pointer=True)],
        returns_error=True,
        description="Signal all threads waiting on the condvar.",
        category="condvar",
    ),
    Function(
        name="k_condvar_wait",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("condvar", "struct k_condvar *", "Pointer", is_pointer=True),
            Param("mutex", "struct k_mutex *", "Pointer", is_pointer=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Wait on a condition variable.",
        category="condvar",
    ),

    # ── Queue ──────────────────────────────────────────────────────────
    Function(
        name="k_queue_init",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("queue", "struct k_queue *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Initialize a queue.",
        category="queue",
    ),
    Function(
        name="k_queue_alloc_append",
        return_type="int32_t",
        mojo_return="Int",
        params=[
            Param("queue", "struct k_queue *", "Pointer", is_pointer=True),
            Param("data", "void *", "Pointer", is_pointer=True),
        ],
        returns_error=False,  # returns -ENOMEM on failure
        description="Append an element to a queue (memory is allocated).",
        category="queue",
    ),
    Function(
        name="k_queue_alloc_prepend",
        return_type="int32_t",
        mojo_return="Int",
        params=[
            Param("queue", "struct k_queue *", "Pointer", is_pointer=True),
            Param("data", "void *", "Pointer", is_pointer=True),
        ],
        returns_error=False,
        description="Prepend an element to a queue.",
        category="queue",
    ),
    Function(
        name="k_queue_get",
        return_type="void *",
        mojo_return="Pointer",
        params=[
            Param("queue", "struct k_queue *", "Pointer", is_pointer=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=False,  # returns NULL on failure
        description="Get an element from a queue (blocking if empty).",
        category="queue",
    ),
    Function(
        name="k_queue_is_empty",
        return_type="int",
        mojo_return="Int",
        params=[Param("queue", "struct k_queue *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Check if a queue is empty.",
        category="queue",
    ),
    Function(
        name="k_queue_peek_head",
        return_type="void *",
        mojo_return="Pointer",
        params=[Param("queue", "struct k_queue *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Peek at the head of a queue without removing.",
        category="queue",
    ),
    Function(
        name="k_queue_peek_tail",
        return_type="void *",
        mojo_return="Pointer",
        params=[Param("queue", "struct k_queue *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Peek at the tail of a queue without removing.",
        category="queue",
    ),
    Function(
        name="k_queue_cancel_wait",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("queue", "struct k_queue *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Cancel all pending waiters on a queue.",
        category="queue",
    ),

    # ── Timer ──────────────────────────────────────────────────────────
    Function(
        name="k_timer_start",
        return_type="void",
        mojo_return="NoneType",
        params=[
            Param("timer", "struct k_timer *", "Pointer", is_pointer=True),
            Param("duration", "k_timeout_t", "Int64"),
            Param("period", "k_timeout_t", "Int64"),
        ],
        returns_error=False,
        description="Start a timer.",
        category="timer",
    ),
    Function(
        name="k_timer_stop",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("timer", "struct k_timer *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Stop a timer.",
        category="timer",
    ),
    Function(
        name="k_timer_status_get",
        return_type="uint32_t",
        mojo_return="UInt32",
        params=[Param("timer", "struct k_timer *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Get timer status (number of expirations since last check).",
        category="timer",
    ),
    Function(
        name="k_timer_status_sync",
        return_type="uint32_t",
        mojo_return="UInt32",
        params=[Param("timer", "struct k_timer *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Wait for timer expiration and get status.",
        category="timer",
    ),
    Function(
        name="k_timer_expires_ticks",
        return_type="k_ticks_t",
        mojo_return="Int64",
        params=[Param("timer", "struct k_timer *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Get remaining ticks until timer expiration.",
        category="timer",
    ),
    Function(
        name="k_timer_remaining_ticks",
        return_type="k_ticks_t",
        mojo_return="Int64",
        params=[Param("timer", "struct k_timer *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Get remaining ticks of the timer.",
        category="timer",
    ),
    Function(
        name="k_timer_user_data_set",
        return_type="void",
        mojo_return="NoneType",
        params=[
            Param("timer", "struct k_timer *", "Pointer", is_pointer=True),
            Param("user_data", "void *", "Pointer", is_pointer=True),
        ],
        returns_error=False,
        description="Set user data pointer on a timer.",
        category="timer",
    ),
    Function(
        name="k_timer_user_data_get",
        return_type="void *",
        mojo_return="Pointer",
        params=[Param("timer", "struct k_timer *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Get user data pointer from a timer.",
        category="timer",
    ),

    # ── Thread ─────────────────────────────────────────────────────────
    Function(
        name="k_thread_create",
        return_type="k_tid_t",
        mojo_return="Pointer",
        params=[
            Param("new_thread", "struct k_thread *", "Pointer", is_pointer=True),
            Param("stack", "k_thread_stack_t *", "Pointer", is_pointer=True),
            Param("stack_size", "size_t", "Int"),
            Param("entry", "k_thread_entry_t", "Pointer", is_pointer=True),
            Param("p1", "void *", "Pointer", is_pointer=True),
            Param("p2", "void *", "Pointer", is_pointer=True),
            Param("p3", "void *", "Pointer", is_pointer=True),
            Param("prio", "int", "Int"),
            Param("options", "uint32_t", "UInt32"),
            Param("delay", "k_timeout_t", "Int64"),
        ],
        returns_error=False,
        description="Create a new thread.",
        category="thread",
    ),
    Function(
        name="k_thread_abort",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("thread", "k_tid_t", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Abort a thread.",
        category="thread",
    ),
    Function(
        name="k_thread_join",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("thread", "struct k_thread *", "Pointer", is_pointer=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Wait for a thread to terminate.",
        category="thread",
    ),
    Function(
        name="k_thread_name_set",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("thread", "k_tid_t", "Pointer", is_pointer=True),
            Param("name", "const char *", "Pointer", is_pointer=True, is_const=True),
        ],
        returns_error=True,
        description="Set a thread's name.",
        category="thread",
    ),

    # ── Message Queue ──────────────────────────────────────────────────
    Function(
        name="k_msgq_alloc_init",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("msgq", "struct k_msgq *", "Pointer", is_pointer=True),
            Param("msg_size", "size_t", "Int"),
            Param("max_msgs", "uint32_t", "UInt32"),
        ],
        returns_error=True,
        description="Initialize a message queue with allocated buffer.",
        category="msgq",
    ),
    Function(
        name="k_msgq_put",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("msgq", "struct k_msgq *", "Pointer", is_pointer=True),
            Param("data", "const void *", "Pointer", is_pointer=True, is_const=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Put a message in a message queue.",
        category="msgq",
    ),
    Function(
        name="k_msgq_get",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("msgq", "struct k_msgq *", "Pointer", is_pointer=True),
            Param("data", "void *", "Pointer", is_pointer=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Get a message from a message queue.",
        category="msgq",
    ),
    Function(
        name="k_msgq_num_free_get",
        return_type="uint32_t",
        mojo_return="UInt32",
        params=[Param("msgq", "struct k_msgq *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Get number of free slots in a message queue.",
        category="msgq",
    ),
    Function(
        name="k_msgq_purge",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("msgq", "struct k_msgq *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Purge all messages from a message queue.",
        category="msgq",
    ),

    # ── Stack (k_stack) ────────────────────────────────────────────────
    Function(
        name="k_stack_alloc_init",
        return_type="int32_t",
        mojo_return="Int",
        params=[
            Param("stack", "struct k_stack *", "Pointer", is_pointer=True),
            Param("num_entries", "uint32_t", "UInt32"),
        ],
        returns_error=True,
        description="Initialize a stack with allocated buffer.",
        category="stack",
    ),
    Function(
        name="k_stack_push",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("stack", "struct k_stack *", "Pointer", is_pointer=True),
            Param("data", "stack_data_t", "Int"),
        ],
        returns_error=True,
        description="Push an element onto a stack.",
        category="stack",
    ),
    Function(
        name="k_stack_pop",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("stack", "struct k_stack *", "Pointer", is_pointer=True),
            Param("data", "stack_data_t *", "Pointer", is_pointer=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Pop an element from a stack.",
        category="stack",
    ),

    # ── Current Thread / Scheduling ──────────────────────────────────
    Function(
        name="k_current_get",
        return_type="k_tid_t",
        mojo_return="Pointer",
        params=[],
        returns_error=False,
        description="Get the handle of the current thread.",
        category="thread",
    ),
    Function(
        name="k_yield",
        return_type="void",
        mojo_return="NoneType",
        params=[],
        returns_error=False,
        description="Yield the current thread to other threads of equal priority.",
        category="thread",
    ),
    Function(
        name="k_busy_wait",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("usec", "uint32_t", "UInt32")],
        returns_error=False,
        description="Busy-wait for the given number of microseconds.",
        category="time",
    ),
    Function(
        name="k_is_in_isr",
        return_type="int",
        mojo_return="Int",
        params=[],
        returns_error=False,
        description="Check if the current context is an interrupt service routine.",
        category="thread",
    ),
    Function(
        name="k_is_preempt_thread",
        return_type="int",
        mojo_return="Int",
        params=[],
        returns_error=False,
        description="Check if the current thread is preemptible.",
        category="thread",
    ),
    Function(
        name="k_thread_priority_set",
        return_type="void",
        mojo_return="NoneType",
        params=[
            Param("thread", "k_tid_t", "Pointer", is_pointer=True),
            Param("prio", "int", "Int"),
        ],
        returns_error=False,
        description="Set a thread's priority.",
        category="thread",
    ),
    Function(
        name="k_thread_priority_get",
        return_type="int",
        mojo_return="Int",
        params=[Param("thread", "k_tid_t", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Get a thread's priority.",
        category="thread",
    ),
    Function(
        name="k_thread_suspend",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("thread", "k_tid_t", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Suspend a thread.",
        category="thread",
    ),
    Function(
        name="k_thread_resume",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("thread", "k_tid_t", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Resume a suspended thread.",
        category="thread",
    ),

    # ── Work Queue ────────────────────────────────────────────────────
    Function(
        name="k_work_init",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("work", "struct k_work *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Initialize a work item.",
        category="work",
    ),
    Function(
        name="k_work_submit",
        return_type="int",
        mojo_return="Int",
        params=[Param("work", "struct k_work *", "Pointer", is_pointer=True)],
        returns_error=True,
        description="Submit a work item to the system work queue.",
        category="work",
    ),
    Function(
        name="k_work_submit_to_queue",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("work_q", "struct k_work_q *", "Pointer", is_pointer=True),
            Param("work", "struct k_work *", "Pointer", is_pointer=True),
        ],
        returns_error=True,
        description="Submit a work item to a specific work queue.",
        category="work",
    ),
    Function(
        name="k_work_flush",
        return_type="int",
        mojo_return="Int",
        params=[Param("work", "struct k_work *", "Pointer", is_pointer=True)],
        returns_error=True,
        description="Wait for a work item to complete.",
        category="work",
    ),
    Function(
        name="k_work_cancel",
        return_type="int",
        mojo_return="Int",
        params=[Param("work", "struct k_work *", "Pointer", is_pointer=True)],
        returns_error=True,
        description="Cancel a pending work item.",
        category="work",
    ),
    Function(
        name="k_work_poll_init",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("work", "struct k_work *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Initialize a work item for k_work_poll_submit.",
        category="work",
    ),
    Function(
        name="k_work_poll_submit",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("work", "struct k_work *", "Pointer", is_pointer=True),
            Param("events", "struct k_poll_event *", "Pointer", is_pointer=True),
            Param("num_events", "int", "Int"),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Submit a work item triggered by poll events.",
        category="work",
    ),

    # ── Polling ───────────────────────────────────────────────────────
    Function(
        name="k_poll",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("events", "struct k_poll_event *", "Pointer", is_pointer=True),
            Param("num_events", "int", "Int"),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Wait for one of multiple events to become active.",
        category="poll",
    ),
    Function(
        name="k_poll_signal_init",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("signal", "struct k_poll_signal *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Initialize a poll signal.",
        category="poll",
    ),
    Function(
        name="k_poll_signal_raise",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("signal", "struct k_poll_signal *", "Pointer", is_pointer=True),
            Param("result", "int", "Int"),
        ],
        returns_error=True,
        description="Raise a poll signal.",
        category="poll",
    ),

    # ── FIFO / LIFO ───────────────────────────────────────────────────
    Function(
        name="k_fifo_init",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("fifo", "struct k_fifo *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Initialize a FIFO queue.",
        category="queue",
    ),
    Function(
        name="k_fifo_put",
        return_type="void",
        mojo_return="NoneType",
        params=[
            Param("fifo", "struct k_fifo *", "Pointer", is_pointer=True),
            Param("data", "void *", "Pointer", is_pointer=True),
        ],
        returns_error=False,
        description="Put an element into a FIFO.",
        category="queue",
    ),
    Function(
        name="k_fifo_get",
        return_type="void *",
        mojo_return="Pointer",
        params=[
            Param("fifo", "struct k_fifo *", "Pointer", is_pointer=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=False,
        description="Get an element from a FIFO.",
        category="queue",
    ),
    Function(
        name="k_lifo_init",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("lifo", "struct k_lifo *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Initialize a LIFO stack.",
        category="queue",
    ),
    Function(
        name="k_lifo_put",
        return_type="void",
        mojo_return="NoneType",
        params=[
            Param("lifo", "struct k_lifo *", "Pointer", is_pointer=True),
            Param("data", "void *", "Pointer", is_pointer=True),
        ],
        returns_error=False,
        description="Push an element onto a LIFO.",
        category="queue",
    ),
    Function(
        name="k_lifo_get",
        return_type="void *",
        mojo_return="Pointer",
        params=[
            Param("lifo", "struct k_lifo *", "Pointer", is_pointer=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=False,
        description="Pop an element from a LIFO.",
        category="queue",
    ),

    # ── IRQ ───────────────────────────────────────────────────────────
    Function(
        name="irq_lock",
        return_type="unsigned int",
        mojo_return="UInt32",
        params=[],
        returns_error=False,
        description="Lock interrupts and return the previous interrupt key.",
        category="irq",
    ),
    Function(
        name="irq_unlock",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("key", "unsigned int", "UInt32")],
        returns_error=False,
        description="Unlock interrupts with the given key.",
        category="irq",
    ),
    # ── Events ──────────────────────────────────────────────────────
    Function(
        name="k_event_init",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("event", "struct k_event *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Initialize an event object.",
        category="event",
    ),
    Function(
        name="k_event_post",
        return_type="void",
        mojo_return="NoneType",
        params=[
            Param("event", "struct k_event *", "Pointer", is_pointer=True),
            Param("events", "uint32_t", "UInt32"),
        ],
        returns_error=False,
        description="Post events to an event object.",
        category="event",
    ),
    Function(
        name="k_event_wait",
        return_type="uint32_t",
        mojo_return="UInt32",
        params=[
            Param("event", "struct k_event *", "Pointer", is_pointer=True),
            Param("events", "uint32_t", "UInt32"),
            Param("reset", "int", "Int"),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=False,
        description="Wait for events on an event object.",
        category="event",
    ),

    # ── Spinlock ────────────────────────────────────────────────────
    Function(
        name="k_spin_lock",
        return_type="k_spinlock_key_t",
        mojo_return="UInt32",
        params=[Param("lock", "struct k_spinlock *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Lock a spinlock, returning the interrupt key.",
        category="spinlock",
    ),
    Function(
        name="k_spin_unlock",
        return_type="void",
        mojo_return="NoneType",
        params=[
            Param("lock", "struct k_spinlock *", "Pointer", is_pointer=True),
            Param("key", "k_spinlock_key_t", "UInt32"),
        ],
        returns_error=False,
        description="Unlock a spinlock, restoring interrupts.",
        category="spinlock",
    ),

    # ── Memory Slab ─────────────────────────────────────────────────
    Function(
        name="k_mem_slab_init",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("slab", "struct k_mem_slab *", "Pointer", is_pointer=True),
            Param("buffer", "void *", "Pointer", is_pointer=True),
            Param("block_size", "size_t", "Int"),
            Param("num_blocks", "uint32_t", "UInt32"),
        ],
        returns_error=True,
        description="Initialize a memory slab.",
        category="mem_slab",
    ),
    Function(
        name="k_mem_slab_alloc",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("slab", "struct k_mem_slab *", "Pointer", is_pointer=True),
            Param("mem", "void **", "Pointer", is_pointer=True),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Allocate a block from a memory slab.",
        category="mem_slab",
    ),
    Function(
        name="k_mem_slab_free",
        return_type="void",
        mojo_return="NoneType",
        params=[
            Param("slab", "struct k_mem_slab *", "Pointer", is_pointer=True),
            Param("mem", "void **", "Pointer", is_pointer=True),
        ],
        returns_error=False,
        description="Free a block back to a memory slab.",
        category="mem_slab",
    ),

    # ── Pipe ────────────────────────────────────────────────────────
    Function(
        name="k_pipe_init",
        return_type="void",
        mojo_return="NoneType",
        params=[
            Param("pipe", "struct k_pipe *", "Pointer", is_pointer=True),
            Param("buffer", "unsigned char *", "Pointer", is_pointer=True),
            Param("size", "size_t", "Int"),
        ],
        returns_error=False,
        description="Initialize a pipe.",
        category="pipe",
    ),
    Function(
        name="k_pipe_put",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("pipe", "struct k_pipe *", "Pointer", is_pointer=True),
            Param("data", "void *", "Pointer", is_pointer=True),
            Param("bytes_to_write", "size_t", "Int"),
            Param("bytes_written", "size_t *", "Pointer", is_pointer=True),
            Param("min_xfer", "size_t", "Int"),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Write data to a pipe.",
        category="pipe",
    ),
    Function(
        name="k_pipe_get",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("pipe", "struct k_pipe *", "Pointer", is_pointer=True),
            Param("data", "void *", "Pointer", is_pointer=True),
            Param("bytes_to_read", "size_t", "Int"),
            Param("bytes_read", "size_t *", "Pointer", is_pointer=True),
            Param("min_xfer", "size_t", "Int"),
            Param("timeout", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Read data from a pipe.",
        category="pipe",
    ),

    # ── Delayable Work ──────────────────────────────────────────────
    Function(
        name="k_work_delayable_init",
        return_type="void",
        mojo_return="NoneType",
        params=[Param("work", "struct k_work_delayable *", "Pointer", is_pointer=True)],
        returns_error=False,
        description="Initialize a delayable work item.",
        category="work",
    ),
    Function(
        name="k_work_schedule",
        return_type="int",
        mojo_return="Int",
        params=[
            Param("work", "struct k_work_delayable *", "Pointer", is_pointer=True),
            Param("delay", "k_timeout_t", "Int64"),
        ],
        returns_error=True,
        description="Schedule a delayable work item.",
        category="work",
    ),


]

# Zephyr error codes (negated POSIX errnos as positive u32 values)
# These are the values returned in error conditions.
ERRNO_MAP = {
    0: "OK",
    1: "EPERM",
    2: "ENOENT",
    4: "EINTR",
    5: "EIO",
    6: "ENXIO",
    9: "EBADF",
    11: "EAGAIN",
    12: "ENOMEM",
    13: "EACCES",
    14: "EFAULT",
    16: "EBUSY",
    17: "EEXIST",
    19: "ENODEV",
    22: "EINVAL",
    27: "EFBIG",
    28: "ENOSPC",
    38: "ENOSYS",
    62: "ETIME",
    84: "EILSEQ",
    110: "ETIMEDOUT",
    111: "ECONNREFUSED",
    114: "EALREADY",
    116: "ESTALE",
    120: "ECANCELED",
}


def timeout_no_wait() -> int:
    """K_NO_WAIT: operation should not block."""
    return 0


def timeout_forever() -> int:
    """K_FOREVER: wait indefinitely."""
    return -1


def timeout_ms(ms: int) -> int:
    """Convert milliseconds to a Zephyr k_timeout_t value."""
    return ms


def timeout_ticks(ticks: int) -> int:
    """Use raw ticks as timeout."""
    return ticks
