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

## Sources

- gbdev, *Pan Docs*:
  https://gbdev.io/pandocs/
- Pan Docs, CPU registers and flags:
  https://gbdev.io/pandocs/CPU_Registers_and_Flags.html
- Pan Docs, memory map:
  https://gbdev.io/pandocs/Memory_Map.html
- gbdev, SM83 opcode and cycle tables:
  https://gbdev.io/gb-opcodes/optables/
