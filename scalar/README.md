# Scalar low-precision payload kernels

This directory is the first raw-ISA implementation slice for the five scalar
formats tracked by the ARM/Thumb work:

- `Bits8`: unsigned modular 8-bit integer;
- `E3M2`: OCP MX FP6 element encoding;
- `E4M3` and `E5M2`: OCP OFP8 encodings;
- `E5M3`: the unsigned Ootomo-Naruse 8-bit storage format.

The authoritative format restatements remain in
`isomorphisms/idric-arm-thumb`, branch `docs/five-scalar-reference-specs`, under
`specifications/`. This implementation does not redefine those formats.

## Implemented surface

`scalar_formats.S` exports:

```
bits8_add
bits8_sub
bits8_mul
e3m2_add
e3m2_sub
e3m2_mul
e3m2_div
e3m2_sqrt
f32_bits_to_e3m2_sat_rne
e3m2_to_f32_bits
f32_bits_to_e4m3_sat_rne
e4m3_to_f32_bits
f32_bits_to_e5m2_sat_rne
e5m2_to_f32_bits
f32_bits_to_e5m3
e5m3_to_f32_bits
```

The floating conversions take or return the **raw IEEE binary32 bit pattern**.
They do not require a floating-point unit.

For E3M2/E4M3/E5M2, binary32 -> narrow conversion is round-to-nearest,
ties-to-even with saturating overflow. E4M3 uses `0x7f` and E5M2 uses `0x7d`
as canonical destination NaNs. OCP leaves source-NaN conversion to E3M2
implementation-defined; this slice chooses `+0` and documents that local policy
rather than attributing it to OCP.

Ootomo-Naruse E5M3 is storage-only. `f32_bits_to_e5m3` therefore implements
only the paper's positive-normal binary32 storage conversion, and
`e5m3_to_f32_bits` implements its representative-value reconstruction. No E5M3
arithmetic is invented.

OCP specifies E3M2/E4M3/E5M2 encodings and conversion behavior, not arithmetic
directly in those formats. This branch therefore states a local E3M2 arithmetic
contract explicitly: add, subtract, multiply, divide, and square root return the
same E3M2 payload selected by exact-value computation followed by
round-to-nearest, ties-to-even and finite saturation. Division by nonzero signed
zero saturates to signed maximum finite magnitude; 0/0 and square root of a
negative nonzero value map to +0, matching the existing local E3M2 NaN policy.
Integer powers are exercised by repeated `e3m2_mul`.

The target routines do not require a floating-point unit. A build-time Python
generator computes the complete 64-payload operation tables from exact rational
E3M2 values; the target assembly performs the actual indexed lookup. This is a
backend-local arithmetic policy and is not attributed to OCP. `Bits8`
arithmetic remains modulo 256.

`TEST_VECTORS.tsv` records architecture-independent boundary vectors for the
implemented surface. These are reference vectors, not target-execution receipts.

## Evidence boundary

Assembling this file proves that the source is accepted for the named ISA and
that its instructions encode. It does **not** prove Idriç currently emits these
calls, that the functions executed on a simulator, or that they executed on a
physical target. Those are later and distinct acceptance stages.

## Target and ABI

Target: RP2040 Cortex-M0+, Armv6-M Thumb. AAPCS scalar input/result is `r0`; a
second scalar is `r1`. This source uses only the RP2040 CPU ISA, not PIO.

`check.sh` assembles with `clang --target=armv6m-none-eabi -mcpu=cortex-m0plus -mthumb`.


## E3M2 arithmetic measurement path

The generated tables contain 4096 payload results each for add, subtract,
multiply, and divide, plus 64 square-root results. They are generated from exact
fractions rather than decimal approximations. The next execution layer uses the
same arithmetic, power, rotation, and 14-by-26 Dakota Jacobian residue cases as
the ARM/Thumb and x86-64 observers.
