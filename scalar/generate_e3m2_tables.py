#!/usr/bin/env python3
from fractions import Fraction


def decode(payload: int) -> Fraction:
    payload &= 0x3F
    negative = bool(payload & 0x20)
    code = payload & 0x1F
    exponent = code >> 2
    mantissa = code & 0x03
    if exponent == 0:
        value = Fraction(mantissa, 16)
    else:
        value = Fraction(4 + mantissa, 4) * (Fraction(2) ** (exponent - 3))
    return -value if negative else value


POSITIVE = [decode(code) for code in range(0x20)]


def quantize(value: Fraction) -> int:
    if value == 0:
        return 0
    negative = value < 0
    magnitude = -value if negative else value
    if magnitude >= POSITIVE[-1]:
        code = 0x1F
    else:
        code = min(
            range(0x20),
            key=lambda candidate: (
                abs(POSITIVE[candidate] - magnitude),
                candidate & 1,
            ),
        )
    return code | (0x20 if negative else 0)


def add(left: int, right: int) -> int:
    value = decode(left) + decode(right)
    if value == 0 and (left & 0x3F) == 0x20 and (right & 0x3F) == 0x20:
        return 0x20
    return quantize(value)


def subtract(left: int, right: int) -> int:
    return quantize(decode(left) - decode(right))


def multiply(left: int, right: int) -> int:
    value = decode(left) * decode(right)
    if value == 0:
        return 0x20 if bool(left & 0x20) ^ bool(right & 0x20) else 0
    return quantize(value)


def divide(left: int, right: int) -> int:
    numerator = decode(left)
    denominator = decode(right)
    negative = bool(left & 0x20) ^ bool(right & 0x20)
    if denominator == 0:
        if numerator == 0:
            return 0
        return 0x3F if negative else 0x1F
    if numerator == 0:
        return 0x20 if negative else 0
    return quantize(numerator / denominator)


def square_root(payload: int) -> int:
    value = decode(payload)
    if value < 0:
        return 0
    if value == 0:
        return 0x20 if payload & 0x20 else 0
    for lower in range(0x1F):
        upper = lower + 1
        midpoint = (POSITIVE[lower] + POSITIVE[upper]) / 2
        boundary = midpoint * midpoint
        if value < boundary:
            return lower
        if value == boundary:
            return lower if (lower & 1) == 0 else upper
    return 0x1F


def emit(name: str, values: list[int]) -> None:
    print(f".global {name}")
    print(f"{name}:")
    for at in range(0, len(values), 16):
        chunk = values[at:at + 16]
        print("        .byte   " + ",".join(f"0x{value:02x}" for value in chunk))


def binary_table(operation) -> list[int]:
    return [operation(left, right) for left in range(64) for right in range(64)]


def main() -> None:
    print("@ Generated from exact E3M2 rational values. Do not edit by hand.")
    emit("e3m2_add_table", binary_table(add))
    emit("e3m2_sub_table", binary_table(subtract))
    emit("e3m2_mul_table", binary_table(multiply))
    emit("e3m2_div_table", binary_table(divide))
    emit("e3m2_sqrt_table", [square_root(payload) for payload in range(64)])


if __name__ == "__main__":
    main()
