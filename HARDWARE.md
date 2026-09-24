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

## Sources

- Microchip, *ATmega48A/PA/88A/PA/168A/PA/328/P Data Sheet*:
  https://ww1.microchip.com/downloads/en/DeviceDoc/ATmega48A-PA-88A-PA-168A-PA-328-P-DS-DS40002061A.pdf
- Microchip, ATmega328P product/documentation page:
  https://www.microchip.com/en-us/product/atmega328p
- Microchip, *AVR Instruction Set Manual*:
  https://ww1.microchip.com/downloads/en/DeviceDoc/AVR-Instruction-Set-Manual-DS40002198.pdf
