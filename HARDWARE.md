# ESP hardware / microarchitecture notes

Status: hardware evidence, separate from `INSTRUCTIONS.md` and separate from Idriç implementation status.

There is **no single ESP microarchitecture**. The branch spans Xtensa LX6, Xtensa LX7, several Espressif RISC-V cores, and separate low-power cores. An A55-style hardware note therefore has to stay chip-specific.

## Concrete CPU implementations

| chip | CPU hardware facts relevant to lowering |
| --- | --- |
| classic ESP32 | One or two 32-bit Xtensa LX6 cores, **7-stage pipeline**, up to 240 MHz; single-precision FPU; DSP support including 32-bit multiply/divide and 40-bit MAC. |
| ESP32-S2 | One 32-bit Xtensa LX7, **7-stage pipeline**, up to 240 MHz; 32-bit multiply/divide; 64 physical general registers for the windowed ABI. |
| ESP32-S3 | Dual 32-bit Xtensa LX7, **5-stage pipeline**, up to 240 MHz; single-precision FPU; 32-bit multiply/divide; PIE adds **128-bit registers and 128-bit SIMD operations** over 8-, 16-, and 32-bit data. |
| ESP32-C3 | Single 32-bit RISC-V, **4-stage in-order scalar pipeline**, up to 160 MHz, RV32IMC; 32-bit multiply/divide; zero-wait-cycle interface to on-chip SRAM/cache through IRAM/DRAM paths. |
| ESP32-C6 | HP 32-bit RISC-V, **4-stage pipeline**, up to 160 MHz, RV32IMAC, with BTB/static branch prediction; separate LP RISC-V core with a 2-stage pipeline up to 20 MHz. |
| ESP32-H2 | 32-bit RV32IMAC core, **4-stage pipeline**, up to 96 MHz; zero-wait SRAM/cache interface and BTB/static branch prediction. |
| ESP32-P4 | Dual HP 32-bit RISC-V, **5-stage pipeline**, up to the frequency specified by the selected silicon revision; BHT/BTB/RAS branch prediction; custom AI/DSP extension with eight 128-bit registers and 128-bit vector operations. Separate LP RV32IMAC core uses a 2-stage pipeline. |

Do not move timing or vector assumptions from one row to another merely because both products are branded ESP32.

## The S3 and P4 are qualitatively different targets

For the small-number work, ESP32-S3 and ESP32-P4 deserve special attention.

ESP32-S3 PIE documents:

- 128-bit general-purpose extension registers;
- 128-bit vector addition, subtraction, multiplication, accumulation, shifting, comparison, and complex operations;
- 8-, 16-, and 32-bit lane formats;
- unaligned 128-bit vector data;
- saturation.

ESP32-P4 likewise exposes 128-bit AI/DSP vector operations and eight added 128-bit registers.

Neither fact means that an arbitrary E3M2/E5M3 encoding becomes a native floating type. It means we should ask whether packed small values can be decoded, compared, classified, or transformed several at a time using these integer/vector facilities.

## Memory belongs in the model

The ESP chips differ substantially in internal SRAM, cache, external flash/PSRAM, DMA, and bus structure. A result measured on one ESP chip is not a generic "ESP" result.

For low-precision work, record at least:

- where code executes: internal RAM versus cached external flash;
- where packed values live;
- cache line/refill effects;
- whether DMA can keep a stream fed while the CPU operates;
- whether a 128-bit vector load is naturally aligned or incurs special handling;
- contention between cores and other bus masters.

## What is still missing

The public Espressif manuals give much more microarchitecture information than we had recorded in this repository, but not every chip has an A55-style table of per-instruction latency and reciprocal throughput.

So distinguish:

- **documented:** pipeline depth, core count, clock limit, instruction extensions, register widths, memory/cache organization, some branch machinery;
- **to measure:** exact latency/throughput of the scalar sequences we care about, cache-miss costs under our access patterns, and packed E3M2/E5M3 kernels.

For Xtensa especially, "LX6" or "LX7" is not enough: configured extensions on the selected ESP chip remain part of the hardware contract.

## Sources

- Espressif, *ESP32 Series Datasheet*:
  https://documentation.espressif.com/esp32_datasheet_en.html
- Espressif, *ESP32-S2 Series Datasheet*:
  https://documentation.espressif.com/esp32-s2_datasheet_en.html
- Espressif, *ESP32-S3 Series Datasheet*:
  https://documentation.espressif.com/esp32_s3_datasheet_en.pdf
- Espressif, *ESP32-S3 Technical Reference Manual*:
  https://documentation.espressif.com/esp32-s3_technical_reference_manual_en.pdf
- Espressif, *ESP32-C3 Datasheet*:
  https://documentation.espressif.com/esp32-c3_datasheet_en.html
- Espressif, *ESP32-C3 Technical Reference Manual*:
  https://documentation.espressif.com/esp32-c3_technical_reference_manual_en.pdf
- Espressif, *ESP32-C6 Datasheet*:
  https://documentation.espressif.com/esp32-c6_datasheet_en.html
- Espressif, *ESP32-H2 Datasheet*:
  https://documentation.espressif.com/esp32-h2_datasheet_en.html
- Espressif, *ESP32-P4 Series Datasheet*:
  https://documentation.espressif.com/esp32-p4_datasheet_en.html
