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


## Second-pass details: 8051 memory spaces, accumulator pressure, and byte movement

CH552's main architectural constraint is not merely "8-bit." It is the classic 8051-style separation of **different address spaces and access instructions**.

### Distinct data/code paths

A useful compiler-level model should distinguish:

- internal data RAM reached by ordinary direct/indirect data instructions;
- special-function registers (SFRs);
- XRAM reached through `MOVX`;
- program/code memory read through `MOVC`;
- bit-addressable state where the 8051 architecture exposes it.

Those are not interchangeable addresses with equal load cost.

For low-precision kernels, record whether a byte is:

```text
register
internal RAM
XRAM
code-memory table
SFR/peripheral state
```

before assigning a cost to an operation.

### Accumulator-centered arithmetic

The MCS-51 family is much more accumulator-centered than AVR, MSP430, Arm, or RISC-V.

Many arithmetic/logical forms use **A** explicitly. Multiplication/division use the `A` and `B` registers as architecturally fixed operands/results. That means a generic SSA lowering with many simultaneously live arithmetic temporaries can generate a large amount of traffic between A and other storage locations.

For small-format arithmetic, an effective lowering should therefore plan around A:

- keep the hottest value in A;
- schedule masks/shifts/compares to minimize A reloads;
- use ordinary registers/direct RAM for side values;
- avoid translating a register-rich algorithm literally from AVR or Arm.

Register pressure here is not just "number of registers"; it is **which operations require which special register**.

### 16-bit work is explicitly multi-byte

E5M3 and any widened temporary larger than eight bits must be represented across bytes.

The implementation should state:

- low-byte/high-byte ordering;
- which byte is kept in A;
- how carry/borrow propagates;
- whether the second byte lives in a register, direct RAM, or XRAM;
- whether a 16-bit temporary survives across a call.

This is exactly the sort of detail that disappears if the backend is written as though every target had a free 32-bit scalar register.

### Dual DPTR and XRAM streaming

CH552's dual data pointers and the WCH-specific `0xA5` DPTR1 auto-increment XRAM store form make stream layout worth studying.

For sequential arrays in XRAM, compare:

1. ordinary `MOVX` with explicit pointer maintenance;
2. DPTR0/DPTR1 ping-pong;
3. the CH55x-specific fast DPTR1 store where applicable.

This is potentially relevant to conversion kernels that read one compact representation and emit another.

The backend should not use the WCH extension in generic MCS-51 code; it belongs behind a CH552/CH55x capability bit.

### Code-memory lookup tables

A table in code space is read with `MOVC`, not the same mechanism as an XRAM or internal-RAM byte.

Therefore report table location explicitly.

The three main table strategies have different pressure:

- code-memory table: preserves scarce RAM, costs code-memory lookup sequence;
- XRAM table: consumes a large fraction of 1 KiB XRAM but uses data-space machinery;
- internal-RAM table: fastest/simplest addressing in some cases, but the capacity is tiny and competes with stack/locals.

A 256-entry whole-byte conversion table is large enough to matter here. Tiny field tables are much more plausible.

### Bit-addressable state

8051 bit operations are worth considering for control state, not for storing an entire numeric array.

Potential uses include:

- a sign flag held while A is reused;
- a sticky/rounding bit;
- a classification flag;
- loop/control flags shared by a hand-scheduled sequence.

Whether this helps depends on the exact instruction timing. Preserve it as an optimization option rather than encoding it into the language semantics.

### Instruction-timing extraction still needed

The next mechanical improvement for this branch is to turn the CH552/WCH timing table into a machine-readable CSV/TSV keyed by opcode/form.

That should include:

```text
mnemonic
operand_form
opcode
bytes
machine_cycles
clock_cycles
uses_A
uses_B
uses_DPTR
code_read
xram_read
xram_write
branch
```

Then small-format lowering can be costed without inventing a modern pipeline model that WCH does not publish.

## Suggested CH552 benchmark record

```text
chip                  = CH552
clock_hz              = ...
representation        = ...
source_space          = internal | XRAM | code
destination_space     = internal | XRAM
table_space           = none | code | internal | XRAM
A_reloads_per_value   = ...
MOVX_per_value        = ...
MOVC_per_value        = ...
branches_per_value    = ...
bytes_code            = ...
cycles_per_value      = ...
```

## Sources

- WCH, *CH552 Datasheet* download page:
  https://www.wch-ic.com/downloads/CH552DS1_PDF.html
- WCH product/download site:
  https://www.wch-ic.com/
