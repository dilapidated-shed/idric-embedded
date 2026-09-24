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

Likewise, OCP specifies E3M2/E4M3/E5M2 encodings and conversion behavior, not
arithmetic directly in those formats. This slice therefore adds no narrow
add/multiply/divide contract. `Bits8` arithmetic is defined and is implemented
modulo 256.

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
