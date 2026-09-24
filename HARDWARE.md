# ATtiny hardware / microarchitecture notes

Status: hardware evidence, separate from `INSTRUCTIONS.md` and separate from Idriç implementation status.

ATtiny is not one microarchitecture. Older ATtiny25/45/85-class parts and newer tinyAVR/AVRxt parts must not be given one undifferentiated hardware profile.

## Concrete old-tiny reference: ATtiny25/45/85

The ATtiny25/45/85 datasheet gives a useful constrained reference:

- 8-bit AVR core;
- **32 × 8-bit general-purpose registers**;
- register file directly connected to the ALU;
- Harvard organization: separate program and data memories/buses;
- single-level instruction pipeline, prefetching the next instruction while the current one executes;
- most register-file operations are single cycle;
- R26-R31 pair into the 16-bit X, Y, and Z pointer registers;
- 2/4/8 KiB flash, 128/256/512 B SRAM depending on part.

This is a much harsher environment for table-heavy numeric emulation than ATmega328P.

The device's instruction summary must be the authority for what arithmetic hardware is actually exposed. The generic AVR core text says that **some implementations** provide a multiplier; that sentence must not be turned into a family-wide ATtiny multiplier assumption.

## Newer tinyAVR is a separate hardware target

Newer tinyAVR devices use newer AVR core generations and have different instruction availability, peripheral sets, clocks, memories, and in some cases multiplication support.

So the branch should preserve at least two hardware classes:

1. classic ATtiny25/45/85-style enhanced AVR;
2. newer tinyAVR / AVRxt, pinned to an exact part before optimization work.

## Consequences for small floating formats

The old ATtiny reference makes width costs visible:

- 6- and 8-bit payloads can remain one-byte values;
- 9-bit E5M3 immediately becomes a multi-byte storage/working problem;
- 16-bit temporary values consume register pairs;
- large lookup tables are expensive relative to SRAM and flash;
- direct shifts/masks/branches may be preferable even when a larger CPU would choose a table.

This target is useful precisely because it exposes hidden assumptions in a supposedly "portable" scalar implementation.

## Evidence boundary

Public device datasheets describe the programmer-visible AVR core, register file, pipeline model, instruction cycle counts, and memory. They do not provide an A55-style execution-port/forwarding-resource optimization guide. Use the per-instruction cycle table and measurements instead of inventing hidden pipeline details.


## Second-pass details: exact old-tiny costs and what disappears without multiply

The ATtiny25/45/85 reference is especially useful because the published instruction summary gives a compact cycle model while omitting hardware features that programmers often assume after working on larger AVR parts.

### No multiply instruction in the ATtiny25/45/85 instruction set

The ATtiny25/45/85 instruction summary does **not** include the AVR `MUL/MULS/MULSU/FMUL...` family.

That is a concrete difference from the ATmega328P reference, not merely a difference in clock speed.

For small floating formats it means that significand multiplication must be realized with some combination of:

- shifts and adds;
- tiny lookup tables;
- special-case formulas exploiting 2- or 3-bit significands;
- precomputed product tables when memory permits.

Because E3M2/E5M2/E4M3 significands are so small, this is not automatically disastrous. It is actually a good target for testing whether the algorithm has been designed around the **true small width** or mechanically widened into a general integer multiply.

### Representative old-tiny cycle behavior

The ATtiny25/45/85 summary documents, among others:

- `ADD/ADC/SUB/SBC/AND/OR/EOR/CP`: 1 clock;
- `ADIW/SBIW`: 2 clocks;
- register shifts/rotates: 1 clock;
- `RJMP`: 2 clocks;
- `RCALL`: 3 clocks;
- `RET/RETI`: 4 clocks;
- conditional `BRxx`: 1 clock not taken, 2 taken;
- skip instructions: 1/2/3 clocks depending on whether a one- or two-word instruction is skipped.

This makes branch structure measurable exactly enough to compare alternative classifiers.

### Register restrictions still matter

Like the larger classic AVR parts:

- there are 32 × 8-bit registers;
- immediate forms are concentrated in the upper register half;
- X/Y/Z consume three register pairs;
- `ADIW/SBIW` only target selected pairs.

But the much smaller SRAM means a spill is not merely a timing cost; repeated stack/local use can consume a noticeable part of the device's memory budget.

For ATtiny85 specifically, 512 bytes of SRAM is the upper end of this 25/45/85 family. A table or scratch buffer that would be trivial on ATmega328P should be reported as a percentage of total SRAM here.

### Flash lookup versus ALU sequence

The Harvard-memory issue is even sharper on old ATtiny:

- constants in flash require program-memory reads;
- SRAM is scarce;
- there is no cache;
- moving a table to RAM has an obvious capacity cost.

For all 256 possible 8-bit encodings, a one-byte result table is already 256 bytes—half of an ATtiny85's SRAM and more than the entire SRAM on smaller siblings.

That makes "just use a 256-byte table" a machine-specific design decision, not a neutral implementation detail.

### Tiny product tables may still be excellent

The small mantissas invite much smaller tables.

For example, if an operation has already separated sign and exponent, a product table indexed only by the few explicit significand bits can contain tens of entries rather than 256.

The backend/research notes should therefore distinguish:

- **whole-encoding table**;
- **field-only table**;
- **direct arithmetic**;
- **hybrid**, such as a field table plus branchless exponent logic.

ATtiny is a good machine for forcing that distinction.

### E5M3 storage

E5M3's 9-bit payload is especially expensive when RAM is measured in hundreds of bytes.

A dense 9-bit array saves 7 bits/value versus a 16-bit slot. At 256 values:

- dense payload: 288 bytes;
- 16-bit slots: 512 bytes.

That difference is an entire ATtiny85 SRAM's worth of storage at 256 values.

The counter-cost is unpacking complexity. The branch should keep both byte count and cycle count so a later machine can choose based on the actual application.

## Suggested old-tiny record

```text
device                = ATtiny25 | ATtiny45 | ATtiny85
flash_bytes           = ...
sram_bytes            = ...
clock_hz              = ...
hardware_multiply     = no
representation        = ...
table_location        = none | flash | SRAM
table_bytes           = ...
stack_high_water      = ...
cycles_per_value      = ...
code_words            = ...
branch_taken_rate     = ...
```

## Sources

- Microchip/Atmel, *ATtiny25/45/85 Datasheet*:
  https://ww1.microchip.com/downloads/en/DeviceDoc/Atmel-2586-AVR-8-bit-Microcontroller-ATtiny25-ATtiny45-ATtiny85_Datasheet.pdf
- Microchip, *AVR Instruction Set Manual*:
  https://ww1.microchip.com/downloads/en/DeviceDoc/AVR-Instruction-Set-Manual-DS40002198.pdf
