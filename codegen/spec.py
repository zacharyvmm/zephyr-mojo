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
