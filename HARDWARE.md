# Game Boy SM83 hardware / timing notes

Status: hardware evidence, separate from `INSTRUCTIONS.md` and separate from Idriç implementation status.

The SM83 branch already has an exhaustive opcode inventory. For this machine the most useful A55-equivalent evidence is not a modern vendor pipeline guide; it is the **cycle-accurate instruction table plus the documented memory/bus behavior**.

## Programmer-visible machine

The CPU exposes:

- 8-bit registers A, B, C, D, E, H, L plus flags;
- 16-bit AF, BC, DE, HL pairings, SP and PC;
- a 16-bit address bus;
- memory-mapped I/O in the same logical 64 KiB address space.

There is no floating-point unit, SIMD unit, cache hierarchy, or native multiply/divide instruction to lean on.

## Instruction timing is the primary microarchitecture evidence

Game Boy instruction timings are multiples of four T-states; one M-cycle is four T-states.

Representative costs from the maintained opcode tables:

- `NOP`: 4 T-states;
- register-to-register `LD r,r`: commonly 4;
- simple 8-bit register ALU operations: commonly 4;
- `LD r,[HL]`: commonly 8;
- `INC [HL]` / `DEC [HL]`: 12;
- CB-prefixed register shifts/rotates: commonly 8;
- corresponding CB operations on `[HL]`: commonly 12 or 16 depending on operation.

That is enough to make an exact cost model for a scalar small-format routine without pretending we know undocumented internal execution ports.

## Memory system

Pan Docs documents one 16-bit address space covering:

- cartridge ROM;
- VRAM;
- external cartridge RAM;
- WRAM;
- OAM;
- I/O registers;
- HRAM.

The PPU can make VRAM/OAM unavailable to the CPU during portions of rendering. Therefore "one load" is not only an opcode question: where data is placed and when code runs can matter.

For numeric experiments, WRAM/HRAM timing should be kept distinct from cartridge and video-memory behavior.

## Consequences for small formats

SM83 is a useful lower bound for the scalar design:

- one-byte E3M2/E4M3/E5M2 values are natural;
- 9-bit E5M3 becomes multi-byte;
- no native multiply means multiply-like floating operations must be decomposed or table-driven;
- register pressure appears immediately because the useful register set is small;
- memory operands are visibly more expensive than register operands in the published cycle table.

If a representation only looks attractive when arbitrary 16/32-bit temporaries are assumed free, this target will expose that assumption.

## Evidence boundary

There is no public Nintendo/Sharp document comparable to Arm's Cortex-A55 optimization guide that gives a modern pipeline/resource diagram. Community documentation is much stronger on **externally observable cycle behavior**, and that is what this branch should use.

Do not infer a speculative internal pipeline from opcode timings.


## Second-pass details: clock domains, branch costs, and exact storage pressure

The SM83 is unusually well suited to an **externally observable cycle model**. We do not need to invent hidden execution resources to get useful cost information.

### Clock reference

For the original DMG-class machine:

- CPU/T-state clock: **4.194304 MHz**;
- one M-cycle = **4 T-states**.

Game Boy Color can run the CPU in double-speed mode at **8.388608 MHz**, while other parts of the machine do not all simply double with it. Benchmark records should therefore state model and speed mode rather than quoting wall-clock time alone.

Cycle counts should be preserved in T-states or M-cycles so they remain meaningful across speed modes.

### Register-pair reality

BC, DE, and HL are useful 16-bit views, but the machine does not become a general 16-bit ALU.

The useful distinction is:

- 8-bit arithmetic is rich and ordinary;
- 16-bit increment/decrement exists on register pairs;
- 16-bit addition is specialized, especially around HL and SP;
- arbitrary 16-bit shifts, masks, and multiplies are not native operations.

Therefore a 9-bit E5M3 temporary is feasible but should not automatically be treated as a generic cheap 16-bit scalar.

The exact field layout can decide whether most work stays in one byte with one extra carry/high bit, or repeatedly enters slower multi-byte sequences.

### Conditional-control cost

SM83 branch timing is visible and predictable.

A low-precision decoder should report the taken/not-taken behavior of branches such as conditional `JR`/returns/calls rather than only count branch instructions.

For the common inner-loop case, particularly useful transformations to compare are:

- branch on rare special encoding;
- table lookup for classification;
- mask/compare sequence with one final branch;
- CB-prefixed bit test followed by conditional jump.

Because register operations and memory operations have noticeably different cycle counts, "branchless" code is not automatically faster if it increases memory traffic.

### Memory operand penalty

The opcode tables make a recurring pattern obvious:

- register operations are often one M-cycle;
- the corresponding `[HL]` operation generally costs more;
- CB-prefixed operations on `[HL]` are substantially more expensive than on a register.

That argues for loading one compact value into a register, doing several field operations there, and writing back once, rather than repeatedly operating directly on memory.

A backend cost model should count **memory operand uses**, not only loads/stores spelled explicitly in the IR.

### ROM tables versus WRAM/HRAM tables

Cartridge ROM, WRAM, and HRAM are different implementation choices.

For lookup-heavy kernels preserve:

- table bank/location;
- whether mapper/bank switching is involved;
- whether the table fits in fixed ROM;
- whether copying to WRAM is worthwhile;
- whether HRAM capacity is sufficient for only a tiny hot table.

A whole 256-entry table can be reasonable in ROM but may compete with more valuable WRAM space.

### DMA and video-bus interference

VRAM/OAM access restrictions and DMA activity mean that a benchmark run during active rendering can observe constraints unrelated to the arithmetic.

For machine-readable receipts record:

```text
model = DMG | CGB
double_speed = yes | no
lcd_enabled = yes | no
dma_active = yes | no
source_region = ROM | WRAM | HRAM | VRAM | ...
destination_region = ...
```

A numeric microbenchmark should normally use WRAM/HRAM and a controlled display/DMA state unless it is intentionally measuring coexistence with rendering.

### Dense E5M3 cost

A 9-bit packed stream has a repeating byte-boundary pattern. On SM83 that is important because shifts through carry are native 8-bit operations while arbitrary bit-field extraction is not.

The branch should compare at least:

1. 16-bit slot/value;
2. dense 9-bit bitstream;
3. low-byte stream plus packed one-bit high plane.

For each case record:

- bytes per N values;
- loads;
- stores;
- shifts/rotates;
- carry-dependent operations;
- branches;
- T-states.

The split-plane representation may be especially interesting here because the common low eight bits stay byte-addressable while the ninth bits can be processed in groups.

## Suggested cycle receipt

```text
machine               = DMG | CGB
cpu_hz                = ...
double_speed          = ...
representation        = ...
source_region         = ...
destination_region    = ...
values                = ...
t_states_total        = ...
t_states_per_value    = ...
register_ops          = ...
memory_operand_ops    = ...
loads                 = ...
stores                = ...
taken_branches        = ...
cb_prefixed_ops       = ...
```

## Sources

- gbdev, *Pan Docs*:
  https://gbdev.io/pandocs/
- Pan Docs, CPU registers and flags:
  https://gbdev.io/pandocs/CPU_Registers_and_Flags.html
- Pan Docs, memory map:
  https://gbdev.io/pandocs/Memory_Map.html
- gbdev, SM83 opcode and cycle tables:
  https://gbdev.io/gb-opcodes/optables/
