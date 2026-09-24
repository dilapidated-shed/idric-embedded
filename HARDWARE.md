# MSP430 / MSP430X hardware / microarchitecture notes

Status: hardware evidence, separate from `INSTRUCTIONS.md` and separate from Idriç implementation status.

The current instruction inventory is family-wide. Hardware conclusions must distinguish the base MSP430 CPU, MSP430X/CPUX, and the particular MCU that integrates that CPU.

## CPU datapath

The classic MSP430 CPU is a **16-bit RISC** machine with sixteen 16-bit CPU registers:

- R0 = program counter;
- R1 = stack pointer;
- R2 = status register / constant generator;
- R3 = constant generator;
- R4-R15 = general-purpose registers.

TI documents register-to-register operations as executing in **one CPU clock** on representative MSP430 devices.

This is already a useful hardware fact for the small formats: an E5M3 value whose payload is 9 bits still fits naturally in one working register even though it does not fit in one storage byte.

## Addressing and MSP430X

Base MSP430 uses a 16-bit address model. MSP430X/CPUX extends the address space and adds 20-bit address operations, but that must not be paraphrased as "the whole CPU became a 20-bit arithmetic datapath." The ordinary data path and register organization remain something to describe precisely per CPU generation.

## Hardware multiply is often outside the CPU

A particularly important boundary for backend work: TI documents the MSP430 hardware multiplier as a **peripheral module**, not as an added CPU instruction. The CPU/instruction set remains unchanged; software writes operands to multiplier registers and reads the result.

Different MSP430 devices integrate different multiplier blocks—or none. Some have a 16-bit multiplier; later families may have MPY32.

Therefore never infer multiply cost from the ISA alone and never assume that a hardware multiplier exists merely because the branch is named `msp430`.

For E3M2/E5M3 arithmetic this gives us two distinct lowerings worth keeping separate:

1. pure CPU shifts/adds/compares in 16-bit registers;
2. memory-mapped multiplier assistance on a concrete device where it exists and is actually beneficial.

## Memory-system evidence boundary

Unlike Cortex-A55, there is no one modern optimization guide describing a single MSP430 implementation with fixed caches, pipeline depth, execution ports, and latency tables. MSP430 is a large MCU family with materially different flash/RAM/peripheral organizations.

A hardware receipt should therefore name the exact part and record:

- MSP430 versus MSP430X/CPUX;
- maximum clock;
- RAM and nonvolatile-memory organization;
- flash wait-state policy at the test clock;
- presence/version of the multiplier peripheral;
- DMA, if used;
- measured cycle counts for the small-format kernel.

## Sources

- Texas Instruments, *MSP430x3xx Family User's Guide*:
  https://www.ti.com/lit/ug/slau012a/slau012a.pdf
- Texas Instruments, MSP430 hardware multiplier chapter:
  https://www.ti.com/sc/docs/products/micro/msp430/userguid/ag_06.pdf
- Texas Instruments MSP430 device documentation:
  https://www.ti.com/microcontrollers-mcus-processors/msp430-microcontrollers/overview.html
