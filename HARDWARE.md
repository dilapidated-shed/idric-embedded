# ESP hardware / microarchitecture notes

Status: hardware evidence, separate from `INSTRUCTIONS.md` and separate from Idriç implementation status.

There is **no single ESP microarchitecture**. The branch spans Xtensa LX6, Xtensa LX7, several Espressif RISC-V cores, and separate low-power cores. An A55-style hardware note therefore has to stay chip-specific.

## Concrete CPU implementations

| chip | CPU hardware facts relevant to lowering |
| --- | --- |
| classic ESP32 | One or two 32-bit Xtensa LX6 cores, **7-stage pipeline**, up to 240 MHz; single-precision FPU; DSP support including 32-bit multiply/divide and 40-bit MAC. |
| ESP32-S2 | One 32-bit Xtensa LX7, **7-stage pipeline**, up to 240 MHz; 32-bit multiply/divide; 64 physical general registers for the windowed ABI. |
| ESP32-S3 | Dual 32-bit Xtensa LX7, **5-stage pipeline**, up to 240 MHz; single-precision FPU; 32-bit multiply/divide; PIE adds **128-bit registers and 128-bit SIMD operations** over 8-, 16-, and 32-bit data. |
| ESP32-C3 | Single 32-bit RISC-V, **4-stage in-order scalar pipeline**, up to 160 MHz, RV32IMC; 32-bit multiply/divide; zero-wait-cycle interface to on-chip SRAM/cache through IRAM/DRAM paths. |
| ESP32-C6 | HP 32-bit RISC-V, **4-stage pipeline**, up to 160 MHz, RV32IMAC, with BTB/static branch prediction; separate LP RISC-V core with a 2-stage pipeline up to 20 MHz. |
| ESP32-H2 | 32-bit RV32IMAC core, **4-stage pipeline**, up to 96 MHz; zero-wait SRAM/cache interface and BTB/static branch prediction. |
| ESP32-P4 | Dual HP 32-bit RISC-V, **5-stage pipeline**, up to the frequency specified by the selected silicon revision; BHT/BTB/RAS branch prediction; custom AI/DSP extension with eight 128-bit registers and 128-bit vector operations. Separate LP RV32IMAC core uses a 2-stage pipeline. |

Do not move timing or vector assumptions from one row to another merely because both products are branded ESP32.

## The S3 and P4 are qualitatively different targets

For the small-number work, ESP32-S3 and ESP32-P4 deserve special attention.

ESP32-S3 PIE documents:

- 128-bit general-purpose extension registers;
- 128-bit vector addition, subtraction, multiplication, accumulation, shifting, comparison, and complex operations;
- 8-, 16-, and 32-bit lane formats;
- unaligned 128-bit vector data;
- saturation.

ESP32-P4 likewise exposes 128-bit AI/DSP vector operations and eight added 128-bit registers.

Neither fact means that an arbitrary E3M2/E5M3 encoding becomes a native floating type. It means we should ask whether packed small values can be decoded, compared, classified, or transformed several at a time using these integer/vector facilities.

## Memory belongs in the model

The ESP chips differ substantially in internal SRAM, cache, external flash/PSRAM, DMA, and bus structure. A result measured on one ESP chip is not a generic "ESP" result.

For low-precision work, record at least:

- where code executes: internal RAM versus cached external flash;
- where packed values live;
- cache line/refill effects;
- whether DMA can keep a stream fed while the CPU operates;
- whether a 128-bit vector load is naturally aligned or incurs special handling;
- contention between cores and other bus masters.

## What is still missing

The public Espressif manuals give much more microarchitecture information than we had recorded in this repository, but not every chip has an A55-style table of per-instruction latency and reciprocal throughput.

So distinguish:

- **documented:** pipeline depth, core count, clock limit, instruction extensions, register widths, memory/cache organization, some branch machinery;
- **to measure:** exact latency/throughput of the scalar sequences we care about, cache-miss costs under our access patterns, and packed E3M2/E5M3 kernels.

For Xtensa especially, "LX6" or "LX7" is not enough: configured extensions on the selected ESP chip remain part of the hardware contract.


## Second-pass details: register files, packed lanes, and chip-specific cost models

The most important correction to a generic "ESP scalar backend" is that there are at least three qualitatively different execution styles in this one branch:

1. scalar Xtensa LX6/LX7;
2. scalar RV32I-family cores;
3. ESP-specific 128-bit packed/vector extensions on parts such as ESP32-S3 and ESP32-P4.

A machine-readable hardware record should say which one is being used before recording any performance claim.

### Xtensa register-window pressure

Xtensa's register-window architecture changes the meaning of "available registers" relative to Arm or RISC-V.

For low-precision inner loops the compiler needs to distinguish:

- physical AR registers present in the configured core;
- the architectural window visible to a procedure under the chosen ABI;
- caller/callee/window-rotation costs;
- whether a tight leaf kernel can avoid window movement entirely.

This matters because unpacking one compact value can consume several temporaries: raw byte/word, sign, exponent, significand, normalization shift, second operand, and result. A scalar kernel that looks register-cheap in an abstract IR can become move/spill heavy after the Xtensa ABI is applied.

The branch should therefore retain both **instruction semantics** and **ABI-visible register pressure** as separate facts.

### ESP32-S3 PIE register geometry

ESP32-S3 provides unusually concrete hardware for packed operations.

The Processor Instruction Extensions add **eight 128-bit QR registers**. For vector operations one QR register can be interpreted as:

- 16 × 8-bit lanes;
- 8 × 16-bit lanes;
- 4 × 32-bit lanes.

The TRM explicitly motivates QR because ordinary Xtensa AR registers are only 32 bits wide while the added data path can move **128 bits at a time**. The extended floating-data read/write forms can use that 128-bit access bandwidth even though the native Xtensa floating registers are 32-bit.

For this project, the useful distinction is:

```text
native FP arithmetic precision      != packed data movement width
packed integer/vector width         != a native FP8 arithmetic type
```

E4M3/E5M2 bytes may fit sixteen-at-a-time in one QR register. E3M2 can be stored as one byte per value and get the same lane density, or densely packed at the cost of extra extraction. E5M3 cannot fit one logical value per byte and therefore needs either:

- 16-bit lanes with seven unused bits;
- a denser bitstream plus unpack/repack;
- a split representation.

The 128-bit unit makes those choices worth measuring rather than deciding by storage size alone.

### PIE operations relevant to compact formats

The S3 PIE instruction family contains vector operations over 8-, 16-, and 32-bit elements including arithmetic, shifts, comparisons, multiply/accumulate, saturation, and some complex-number-oriented operations.

That suggests several possible uses without claiming native floating semantics:

- parallel extraction of sign/exponent fields;
- lane-wise exponent comparison;
- saturating intermediate integer arithmetic;
- widening 8-bit lanes before significand operations;
- parallel table-index preparation;
- packed small-rotation or complex operations after an explicit integer/fixed-point mapping.

A backend should preserve the format's rounding and special-value rules above this layer. PIE is a lowering target, not the definition of E4M3/E5M2/E5M3 semantics.

### RISC-V ESP parts

The C3/C6/H2/P4 scalar cores have the regular RV32 integer-register model rather than Xtensa windows. The baseline register file has 32 integer registers with x0 fixed to zero, but the usable ABI subset and extension set still depend on the selected chip/toolchain.

For compact scalar arithmetic, RISC-V gives a relatively clean lowering vocabulary:

- logical/arithmetic shifts;
- masks through immediate/register logical operations;
- signed and unsigned comparisons;
- multiply/divide where M is present;
- loads/stores of byte, halfword, and word;
- conditional branches without a condition-code register.

That last point is worth retaining in comparative notes: ARM/AVR/MSP430 frequently produce flags as a side effect of arithmetic, whereas RISC-V branch conditions consume register operands directly. The best classification sequence can therefore differ even when the abstract test is the same.

### Branch machinery is chip-specific

ESP32-C6/H2 and later cores document branch-target/prediction machinery. Do not export those assumptions backward to ESP32-C3 or sideways to Xtensa.

For a branch-heavy FP8 decoder, record:

- number of conditional branches per value;
- taken/not-taken distribution;
- whether special values are rare;
- whether classification is rewritten branchlessly;
- whether vector compares replace scalar branches.

A decoder that wins on uniformly random test encodings can lose badly on real tensors dominated by ordinary finite values if its common path is not laid out correctly.

### Memory/cache record

The ESP family makes "where the bytes are" a first-class benchmark field.

A useful record should distinguish at least:

- internal SRAM;
- instruction RAM;
- cached external flash;
- external PSRAM where present;
- DMA-owned buffers;
- cacheable versus non-cacheable aliases where the chip exposes them.

For a packed format also record:

- alignment of the first value;
- stride in bytes/bits;
- whether values cross 32- or 128-bit boundaries;
- whether loads are aligned;
- whether the kernel does read-modify-write on partially packed destination words.

The arithmetic can be identical while memory cost changes by multiples.

### What to extract next from the manuals

The next machine-oriented pass should eventually populate a per-chip table rather than a family paragraph:

```text
chip
core ISA/configuration
pipeline stages
clock used
integer register model
FP register model
custom vector registers
vector width
lane widths
multiply facilities
divide facilities
branch predictor
internal SRAM regions
I-cache geometry
D-cache geometry
external-memory path
DMA engines useful to streaming
alignment rules/penalties
documented instruction latency
measured instruction latency
```

Fields should stay `unknown` rather than being inherited from another ESP chip.

## Sources

- Espressif, *ESP32 Series Datasheet*:
  https://documentation.espressif.com/esp32_datasheet_en.html
- Espressif, *ESP32-S2 Series Datasheet*:
  https://documentation.espressif.com/esp32-s2_datasheet_en.html
- Espressif, *ESP32-S3 Series Datasheet*:
  https://documentation.espressif.com/esp32_s3_datasheet_en.pdf
- Espressif, *ESP32-S3 Technical Reference Manual*:
  https://documentation.espressif.com/esp32-s3_technical_reference_manual_en.pdf
- Espressif, *ESP32-C3 Datasheet*:
  https://documentation.espressif.com/esp32-c3_datasheet_en.html
- Espressif, *ESP32-C3 Technical Reference Manual*:
  https://documentation.espressif.com/esp32-c3_technical_reference_manual_en.pdf
- Espressif, *ESP32-C6 Datasheet*:
  https://documentation.espressif.com/esp32-c6_datasheet_en.html
- Espressif, *ESP32-H2 Datasheet*:
  https://documentation.espressif.com/esp32-h2_datasheet_en.html
- Espressif, *ESP32-P4 Series Datasheet*:
  https://documentation.espressif.com/esp32-p4_datasheet_en.html
