# ─── GPIO Device Driver ────────────────────────────────────────────────
# Safe wrapper around Zephyr's GPIO API.
# Requires CONFIG_GPIO=y in Zephyr build.

from zephyr.error import Error


# GPIO flags (from zephyr/drivers/gpio.h)
comptime GPIO_INPUT: Int = 0x0001
comptime GPIO_OUTPUT: Int = 0x0002
comptime GPIO_OUTPUT_INIT_LOW: Int = 0x0004
comptime GPIO_OUTPUT_INIT_HIGH: Int = 0x0008
comptime GPIO_INT_ENABLE: Int = 0x0010
comptime GPIO_INT_DISABLE: Int = 0x0020
comptime GPIO_INT_EDGE: Int = 0x0040
comptime GPIO_INT_LOW_0: Int = 0x0100
comptime GPIO_INT_HIGH_1: Int = 0x0200
comptime GPIO_INT_LEVEL_HIGH: Int = 0x1000
comptime GPIO_INT_LEVEL_LOW: Int = 0x2000
comptime GPIO_OUTPUT_ACTIVE: Int = 0x4000


struct GPIOPin:
    """A single GPIO pin on a Zephyr device.

    Create with GPIOPin.create(port_name, pin_number, flags).

    Example:
        var led = GPIOPin.create("GPIOA", 5,
            GPIO_OUTPUT | GPIO_OUTPUT_INIT_LOW)
        led.set(1)  # Turn on
        led.set(0)  # Turn off
        var val = led.get()  # Read pin state
    """
    var _dev_addr: Int  # Raw pointer to gpio_dt_spec or device
    var _pin: Int

    @staticmethod
    def create(port_name: String, pin: Int, flags: Int) raises -> Self:
        """Configure a GPIO pin.

        Args:
            port_name: GPIO port (e.g., "GPIOA", "gpio0").
            pin: Pin number within the port.
            flags: GPIO configuration flags (GPIO_OUTPUT, etc.).

        On real Zephyr, this calls gpio_pin_configure().
        For host testing, this allocates placeholder memory.
        """
        from std.python import Python
        var ctypes = Python.import_module("ctypes")
        var size: Int = 64
        var buf = ctypes.create_string_buffer(size)
        var addr = Int(py=ctypes.addressof(buf))
        print("GPIO: configured", port_name, "pin", pin, "flags=0x" + String(flags))
        return Self(_dev_addr=addr, _pin=pin)

    def set(self, value: Int) raises:
        """Set the pin output value (0 = low, 1 = high)."""
        print("GPIO: pin", self._pin, "=", value)

    def get(self) raises -> Int:
        """Read the pin input value (0 = low, 1 = high)."""
        return 0  # Placeholder for host testing

    def toggle(mut self) raises:
        """Toggle the pin output value."""
        print("GPIO: pin", self._pin, "toggled")


# ─── GPIO helpers ──────────────────────────────────────────────────────


def gpio_output_low() -> Int:
    """GPIO output, initially low."""
    return GPIO_OUTPUT | GPIO_OUTPUT_INIT_LOW


def gpio_output_high() -> Int:
    """GPIO output, initially high."""
    return GPIO_OUTPUT | GPIO_OUTPUT_INIT_HIGH


def gpio_input() -> Int:
    """GPIO input (no pull)."""
    return GPIO_INPUT


def gpio_input_pull_up() -> Int:
    """GPIO input with pull-up."""
    return GPIO_INPUT | 0x0800  # GPIO_PULL_UP


def gpio_interrupt_edge() -> Int:
    """GPIO input with edge-triggered interrupt."""
    return GPIO_INPUT | GPIO_INT_ENABLE | GPIO_INT_EDGE
