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


## Second-pass details: addressing-mode cost, constant generator, and accelerator boundary

MSP430's compact instruction syntax hides an important performance fact: **instruction cost depends strongly on addressing mode and extension words**, not only on the mnemonic.

A machine-level cost model should therefore record an operation as something closer to:

```text
mnemonic + source addressing mode + destination addressing mode + byte/word width
```

rather than treating every `ADD`, `MOV`, or `CMP` as having one universal cost.

### Constant generator as a code-size/fetch optimization

R2 and R3 are not merely "lost general registers." Their special encodings form the constant generator, allowing common constants to be represented without fetching a separate literal word.

That matters for low-precision field manipulation because masks and small increments occur constantly. Code generation should notice when an operation can use a constant-generator value directly rather than materializing a literal.

The relevant question is not only instruction count:

- did the instruction require an extension word?
- did it require a memory fetch for a literal?
- can the constant generator encode the needed mask/value?
- does changing the field layout turn a common constant into a cheaply encodable one?

A format layout that saves one data bit but forces repeated literal loads may be a bad trade on this machine.

### Byte operations versus 16-bit working values

The datapath and registers are 16-bit, but many operations have byte forms.

For compact values this creates a useful separation:

- **storage/load width** may be one byte;
- **working width** may immediately become 16 bits;
- sign/exponent extraction may use byte operations where convenient;
- E5M3's 9 bits fit naturally in one working register.

Widening an 8-bit stored value into a 16-bit register is therefore not analogous to widening FP8 all the way to Float32 on a larger machine. On MSP430 it is the ordinary native integer width.

The backend should preserve whether a temporary's upper byte is known zero/sign-extended, because that fact can eliminate explicit masking before later comparisons or arithmetic.

### Carry and multiword arithmetic

MSP430's status register and add-with-carry/subtract-with-carry operations make multiword arithmetic possible without a special wide-integer unit.

For these small formats, however, multiword work should be exceptional. A 16-bit register can already hold:

- any current 6/8/9-bit payload;
- decoded sign/exponent/significand fields;
- several guard/round/sticky bits for deliberately small significands.

If a scalar E3M2/E4M3/E5M2/E5M3 operation regularly spills into 32-bit multiword arithmetic, that is evidence that the chosen algorithm is carrying more precision/state than the format actually needs.

### Hardware multiplier timing and scheduling

On MSP430 devices that include the classic 16-bit multiplier peripheral:

- the multiplier is memory mapped and independent of the CPU;
- writing the second operand starts the multiplication;
- the result can be available by the following instruction under the documented access rules;
- no multiply opcode is added to the CPU ISA.

This creates a scheduling opportunity similar in spirit to the RP2040 divider: issue the peripheral operation, perform unrelated CPU work, then read the result.

But there is also overhead:

- operand stores;
- result loads;
- possible address-mode restrictions;
- interrupt/concurrency rules around shared peripheral state.

Therefore compare the peripheral against a short shift/add sequence for the **actual small significand widths**. Multiplying two 2- or 3-bit significands does not automatically justify a 16×16 hardware multiply transaction.

### Newer MSP430 accelerators are separate targets

Some later MSP430 FRAM families contain additional hardware such as the Low-Energy Accelerator (LEA). That is not part of "the MSP430 CPU" and must not be treated as family-wide.

If LEA-backed kernels are explored, record them as a separate execution target with:

- exact MCU part;
- LEA revision/command;
- source/destination memory restrictions;
- setup cost;
- vector length at which setup is amortized;
- energy/cycle result versus CPU code.

The same rule applies to MPY32 and other peripheral arithmetic blocks.

### Memory technology matters

"MSP430 memory" may mean flash, FRAM, or RAM depending on the part.

For a precise hardware note, record:

- code memory technology;
- data memory technology;
- CPU clock;
- required wait states;
- whether code and data contend for the same physical memory/bus;
- DMA interaction;
- whether a lookup table lives in RAM, flash, or FRAM.

This is especially important for small-format lookup tables: on some parts the arithmetic may be cheaper than repeatedly fetching table entries from slower nonvolatile memory.

## Suggested per-device record

```text
part_number
cpu = MSP430 | MSP430X/CPUX
clock_hz
code_memory = flash | FRAM | ...
ram_bytes
nonvolatile_wait_states
multiplier = none | MPY | MPY32 | ...
lea = yes | no
source_addressing_mode
destination_addressing_mode
instruction_words
cycles
bytes_per_value
working_width_bits
table_location
```

This keeps family-wide ISA facts from being mistaken for one specific chip's hardware.

## Sources

- Texas Instruments, *MSP430x3xx Family User's Guide*:
  https://www.ti.com/lit/ug/slau012a/slau012a.pdf
- Texas Instruments, MSP430 hardware multiplier chapter:
  https://www.ti.com/sc/docs/products/micro/msp430/userguid/ag_06.pdf
- Texas Instruments MSP430 device documentation:
  https://www.ti.com/microcontrollers-mcus-processors/msp430-microcontrollers/overview.html
