# CH552 hardware / microarchitecture notes

Status: hardware evidence, separate from `INSTRUCTIONS.md` and separate from Idriç implementation status.

CH552 is a concrete WCH device built around an enhanced **1T E8051** core. The ISA inventory tells us which MCS-51-compatible operations exist; this file records the implementation facts we can support publicly.

## Core and memory

WCH documents the CH552 as an 8-bit enhanced E8051/MCS-51-compatible MCU.

Useful concrete facts include:

- 8-bit CPU;
- "1T" enhanced 8051 implementation rather than the original multi-clock-per-machine-cycle MCS-51 timing model;
- current WCH documentation specifies operation up to 24 MHz;
- 16 KiB program memory;
- 256 B internal RAM;
- 1 KiB XRAM;
- XRAM participates in the chip's internal address/data/DMA system;
- dual data pointers are available, and the CH55x-specific `0xA5` operation provides the fast DPTR1 XRAM-copy step already recorded in `INSTRUCTIONS.md`.

## What "1T" does and does not tell us

"1T" is useful evidence that the implementation is much tighter than a classic 12-clock 8051 machine cycle, but it is **not** a complete pipeline diagram.

WCH's device documentation gives instruction timing and chip organization. It does not expose anything comparable to the Cortex-A55 Software Optimization Guide's execution-resource diagram and latency/throughput tables.

So do not invent:

- a named number of internal pipeline stages unless WCH documents it;
- hidden forwarding/bypass paths;
- superscalar behavior;
- cache structures that are not present in the device documentation.

For this target, the honest hardware model is instruction-cycle timing + the documented memory/data-pointer system + measurement.

## Consequences for E3M2/E5M3-style work

This is a useful stress target:

- 6/8-bit stored formats line up with the byte-oriented CPU;
- E5M3 crosses the byte boundary and requires explicit multi-byte handling;
- shifts, masks and comparisons are cheap conceptual operations but not necessarily one instruction for arbitrary multi-byte values;
- DPTR/XRAM placement can matter as much as the arithmetic sequence;
- a lookup table must be judged against the very small RAM and the code-memory access path.

The CH552 implementation should therefore keep byte layout and temporary-width decisions visible instead of hiding them under a generic integer abstraction.

## Sources

- WCH, *CH552 Datasheet* download page:
  https://www.wch-ic.com/downloads/CH552DS1_PDF.html
- WCH product/download site:
  https://www.wch-ic.com/
