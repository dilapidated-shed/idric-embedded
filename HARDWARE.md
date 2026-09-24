# ATmega hardware / microarchitecture notes

Status: hardware evidence, separate from `INSTRUCTIONS.md` and separate from Idriç implementation status.

The branch contains a family-wide AVR ISA inventory. For concrete hardware reasoning, use a named device. **ATmega328P** is the initial reference point here because its public documentation is detailed and it is a familiar implementation; it is not a claim that every ATmega has identical hardware.

## AVR core shape

For the ATmega328P-class enhanced AVR core:

- 8-bit integer datapath;
- **32 × 8-bit general-purpose working registers** directly connected to the ALU;
- Harvard organization with separate program and data memories/buses;
- a single-level fetch/execute pipeline: while one instruction executes, the next instruction is prefetched;
- many register ALU operations complete in one clock;
- register pairs provide 16-bit pointer/address work;
- the selected ATmega class includes an on-chip **2-cycle hardware multiplier**.

That register-rich 8-bit design is very different from Cortex-A55 even when both implement the same abstract scalar operation.

## Concrete ATmega328P memory scale

ATmega328P provides, in its common configuration:

- 32 KiB flash program memory;
- 2 KiB SRAM;
- 1 KiB EEPROM.

There is no large cache hierarchy to hide arbitrary tables. A conversion table that looks tiny on a phone can be a meaningful fraction of SRAM or flash on this target.

## Consequences for 6/8/9-bit formats

- E3M2, E4M3, E5M2, and Bits8 fit in one 8-bit register/storage byte.
- E5M3's 9-bit logical payload does **not** fit in one register or byte, so its representation forces an explicit choice: two-byte storage, packed bitstream, or another encoding.
- A two-byte working value is normal AVR work, but operations can require multiple instructions and explicit carry handling.
- Multiplication is materially different from shifts/masks/adds because a concrete ATmega may have the 2-cycle multiplier while other AVR family members do not.
- Table-based approaches must be compared against direct bit manipulation under the actual flash/SRAM access rules.

## Do not flatten the AVR family

The `INSTRUCTIONS.md` file deliberately records a union across AVR variants. Hardware notes must be stricter.

Before claiming a timing, multiplier, memory size, or instruction availability, name the actual ATmega part and AVR core generation. ATmega328P is the current reference device, not the definition of "ATmega."


## Second-pass details: register ports, cycle classes, and Harvard-memory effects

The ATmega328P execution model is simple enough that the backend can build a fairly exact cycle model instead of using vague "cheap/expensive" labels.

### Register-file bandwidth

The AVR register file is designed so that a normal two-register ALU instruction can, in one CPU clock:

1. read both source operands;
2. perform the ALU operation;
3. write the result back.

That is why many register operations sustain one instruction per clock in a straight-line dependency-compatible sequence.

The architectural abundance of **32 byte registers** is useful for low-precision arithmetic, but there are encoding restrictions:

- many immediate arithmetic/logical forms address only R16-R31;
- 16-bit pointer roles use X = R27:R26, Y = R29:R28, Z = R31:R30;
- `ADIW`/`SBIW` operate only on selected upper register pairs;
- multiplication deposits its 16-bit result specifically in R1:R0.

A backend that ignores those restrictions may create extra register moves even though the abstract register count looks generous.

### Representative ATmega328P cycle classes

For the operations most relevant to compact scalar formats, the device's instruction table gives a useful first-order model:

| operation class | representative instructions | clocks |
| --- | --- | ---: |
| register add/subtract/logic/compare | `ADD ADC SUB SBC AND OR EOR CP` | 1 |
| single-bit-width shifts/rotates on a register | `LSL LSR ASR ROL ROR` | 1 |
| 16-bit add/sub immediate on supported pair | `ADIW SBIW` | 2 |
| 8×8 → 16 multiply | `MUL MULS MULSU FMUL...` | 2 |
| indirect SRAM load/store | common `LD/ST` forms | typically 2 |
| program-memory load | `LPM` family | multi-cycle |
| conditional branch | `BRxx` | 1 if not taken, 2 if taken |
| skip instructions | `CPSE/SBRC/SBRS/SBIC/SBIS` | 1/2/3 depending on skip and skipped-instruction width |

The exact form still matters. This table is a cost-class guide, not permission to ignore the instruction summary.

### Multiply result placement

The hardware multiplier performs 8-bit × 8-bit → 16-bit multiplication and writes the result to **R1:R0**.

That is attractive for tiny significands, but it has secondary costs:

- live values in R0/R1 must be considered;
- the result may need to be moved to another pair before the next multiply;
- signed and fractional multiply forms have operand-register restrictions;
- an ABI may reserve R1 as a permanent zero register even though the hardware itself does not.

For Idriç code generation, ABI conventions are a backend policy rather than a hardware law, so the machine record should say whether R1 is being kept zero or used freely.

### Harvard memory is visible to table-driven code

ATmega328P has separate program and data memories.

A lookup table stored in flash is not equivalent to an SRAM array:

- SRAM is addressed by the data-space load/store machinery;
- flash-resident constants use program-memory access such as `LPM`;
- table placement changes both instruction sequence and cycle cost;
- copying a hot table to 2 KiB SRAM consumes a meaningful fraction of total RAM.

Therefore every table-based FP8-like conversion should report **where the table lives**.

A direct shift/mask implementation can be larger in ALU instruction count and still beat a flash lookup if program-memory access dominates.

### 9-bit E5M3 representation choices

On this 8-bit machine, E5M3 is a useful representation experiment because it exposes the boundary between logical and physical width.

Three concrete layouts are worth preserving as separate benchmark cases:

1. **16-bit slot per value**
   - two-byte load/store;
   - simple indexing;
   - easy 16-bit temporary;
   - ~44% storage overhead relative to 9 useful bits.

2. **dense 9-bit bitstream**
   - best payload density;
   - values periodically cross byte boundaries;
   - address/shift pattern changes with index;
   - writing one value may require read-modify-write.

3. **split high-bit plane + low bytes**
   - one byte stream plus one packed bit plane;
   - sequential low-byte access remains simple;
   - sign/high field may be processed in batches;
   - two memory streams instead of one.

That comparison is more useful than merely saying "E5M3 needs 16 bits on AVR."

### Branch and skip behavior

AVR's skip instructions deserve explicit consideration for classification code.

A pattern such as "test bit, skip one instruction" can be cheaper than a conventional branch, but its cost depends on:

- whether the skip happens;
- whether the skipped instruction is one or two words.

For common-path optimization, measure real format distributions:

- ordinary finite;
- zero;
- subnormal, if the format has them;
- infinity/NaN or reserved encodings.

Do not benchmark only a uniform sweep and assume the average carries over to real data.

## Suggested benchmark fields

```text
device                = ATmega328P
clock_hz              = ...
code_in_flash          = yes
table_location         = none | flash | SRAM
representation         = byte | 16bit_slot | dense9 | split9
live_registers_peak    = ...
r1_zero_convention     = yes | no
cycles_per_value       = ...
program_words_kernel   = ...
sram_bytes_table       = ...
flash_bytes_table      = ...
taken_branches         = ...
skipped_one_word       = ...
skipped_two_word       = ...
mul_count              = ...
```

## Sources

- Microchip, *ATmega48A/PA/88A/PA/168A/PA/328/P Data Sheet*:
  https://ww1.microchip.com/downloads/en/DeviceDoc/ATmega48A-PA-88A-PA-168A-PA-328-P-DS-DS40002061A.pdf
- Microchip, ATmega328P product/documentation page:
  https://www.microchip.com/en-us/product/atmega328p
- Microchip, *AVR Instruction Set Manual*:
  https://ww1.microchip.com/downloads/en/DeviceDoc/AVR-Instruction-Set-Manual-DS40002198.pdf
