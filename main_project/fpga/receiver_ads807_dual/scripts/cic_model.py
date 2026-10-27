"""Independent arithmetic model for the fixed R87 Intel Hogenauer configuration."""


def signed(value, width):
    return (value + (1 << (width - 1))) % (1 << width) - (1 << (width - 1))


class PrunedCIC:
    def __init__(self, width=20):
        assert width in (17, 20)
        extra = width - 17
        self.i_widths = [w + extra for w in (48, 41, 36, 30, 25)]
        self.c_widths = [w + extra for w in (23, 22, 21, 20, 20)]
        self.width = width
        self.integrators = [0] * 5
        self.delays = [0] * 5
        self.count = 0

    def push(self, value):
        previous_width = 57
        for index, width in enumerate(self.i_widths):
            value >>= previous_width - width
            value = signed(self.integrators[index] + value, width)
            self.integrators[index] = value
            previous_width = width
        output = None
        if self.count == 0:
            for index, width in enumerate(self.c_widths):
                value >>= previous_width - width
                previous = value
                value = signed(value - self.delays[index], width)
                self.delays[index] = previous
                previous_width = width
            output = value >> (previous_width - self.width)
        self.count = (self.count + 1) % 87
        return output
