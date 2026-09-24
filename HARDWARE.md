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

## Sources

- Microchip/Atmel, *ATtiny25/45/85 Datasheet*:
  https://ww1.microchip.com/downloads/en/DeviceDoc/Atmel-2586-AVR-8-bit-Microcontroller-ATtiny25-ATtiny45-ATtiny85_Datasheet.pdf
- Microchip, *AVR Instruction Set Manual*:
  https://ww1.microchip.com/downloads/en/DeviceDoc/AVR-Instruction-Set-Manual-DS40002198.pdf
