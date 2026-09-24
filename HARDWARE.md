# RP2040 hardware / microarchitecture notes

Status: hardware evidence, separate from `INSTRUCTIONS.md` and separate from Idriç implementation status.

The instruction inventory tells us what Armv6-M Thumb can express. This file records what the **actual Cortex-M0+ / RP2040 hardware** does that matters for lowering and low-precision arithmetic.

## Cortex-M0+ core

RP2040 contains two Arm Cortex-M0+ cores, clocked up to 133 MHz in the normal published specification.

Cortex-M0+ is not just "an Arm Thumb target":

- 32-bit core implementing Armv6-M;
- **2-stage pipeline**;
- AMBA AHB-Lite system interface;
- von-Neumann core bus organization, with an optional separate single-cycle I/O path in the generic Cortex-M0+ design;
- 32-bit integer register datapath;
- deliberately small execution machinery compared with Cortex-A55: no NEON, no FPU, no FP16/FP8 datapath, no wide SIMD register file.

Arm's generic Cortex-M0+ permits either a single-cycle or area-optimized 32-cycle 32×32 multiplier. Do not infer the exact RP2040 multiplier timing from the generic core manual without checking the RP2040 integration.

## RP2040 memory system

The SoC integration is unusually important here.

RP2040 has **264 KiB SRAM in six physical banks**:

- four 64 KiB banks;
- two 4 KiB banks.

The first 256 KiB is word-striped across the four large banks. Each bank has its own AHB-Lite arbiter, so different bus masters can hit different banks simultaneously. Raspberry Pi documents up to **four 32-bit SRAM accesses per system clock** in the favorable case.

External flash is normally execute-in-place through the XIP subsystem. Its cache is:

- 16 KiB;
- 2-way set associative;
- 1-cycle hit.

That means a scalar kernel can have very different behavior depending on whether its loop/code/tables are resident in SRAM, hitting XIP cache, or missing to external flash.

## SoC arithmetic beside the CPU

RP2040 also has chip-level arithmetic facilities such as the integer divider and interpolators. These are **not Cortex-M0+ instructions**. A backend experiment should keep three questions separate:

1. what the Armv6-M core can issue;
2. what RP2040 exposes as memory-mapped/SoC accelerators;
3. whether using an accelerator actually beats a short scalar integer sequence once access overhead is counted.

## Consequences for small floating formats

For E3M2/E4M3/E5M2/E5M3-style scalar work, the interesting hardware facts are not native floating-point support—there is none—but:

- a 32-bit working register is cheap relative to the stored 6/8/9-bit payload;
- byte and halfword loads/stores can keep compact storage compact;
- E5M3's 9-bit payload naturally crosses a byte boundary, so storage layout matters;
- table-driven conversion may be attractive only if table placement/cache behavior is known;
- two cores plus banked SRAM can matter for bulk conversion/comparison, but memory-bank collisions have to be measured rather than assuming two cores double throughput.

The right comparison with Cortex-A55 is therefore not "does RP2040 have FP8?" but "what sequence of integer operations and memory traffic realizes the same scalar semantics, and where does the RP2040 memory fabric become the limit?"

## Evidence boundary

Public documentation is strong on the Cortex-M0+ pipeline and RP2040 memory/interconnect organization. It is not an A55-style floating-point optimization guide because RP2040 has no comparable FP/NEON unit. Do not invent execution-port diagrams, hidden bypass paths, or instruction latencies not stated by Arm/Raspberry Pi.

## Sources

- Raspberry Pi, *RP2040 Datasheet*:
  https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf
- Raspberry Pi, RP2040 specifications:
  https://www.raspberrypi.com/products/rp2040/specifications/
- Arm, *Cortex-M0+ Processor Datasheet*:
  https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/Processor%20Datasheets/Arm%20Cortex-M0%20plus%20Processor%20Datasheet.pdf
- Arm, *Cortex-M0+ Devices Generic User Guide*:
  https://documentation-service.arm.com/static/5f04aadfdbdee951c1cdc957
