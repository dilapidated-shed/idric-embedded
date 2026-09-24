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

Arm's generic Cortex-M0+ permits different multiplier implementations, but the RP2040 datasheet resolves the integration choice: RP2040 uses the **standard single-cycle 32-bit hardware multiplier**.

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


## Second-pass details: instruction timing, core-local arithmetic, and register pressure

The RP2040 integration removes one ambiguity from the generic Cortex-M0+ documentation: the processor uses the **standard single-cycle 32-bit hardware multiplier**. This matters for low-precision formats because a scalar implementation does not have to model integer multiplication as a 32-cycle fallback on this chip.

The architectural register set is small enough that register allocation is part of the cost model:

- R0-R12 are ordinary integer registers;
- R13 is SP, R14 is LR, and R15 is PC;
- many compact 16-bit Thumb encodings are restricted to the low register set R0-R7;
- higher registers are usable, but instruction-form restrictions can increase code size or require moves.

For one isolated scalar value this is generous: a 6-, 8-, or 9-bit payload can be widened into a 32-bit register with room for sign, exponent, mantissa, guard bits, and intermediate carry. For a loop over many packed values, however, keeping source pointer, destination pointer, loop counter, unpacked operands, masks, temporaries, and results live at once can force spills or extra moves. The backend should therefore measure **whole-loop register pressure**, not only count arithmetic instructions for one value.

### Main bus versus single-cycle I/O

RP2040 makes a useful distinction between ordinary AHB-Lite accesses and the processor's single-cycle I/O path.

The datasheet states that:

- SIO reads/writes take exactly **one cycle**;
- Cortex-M0+ accesses through the main AHB-Lite system bus require **two cycles for a load or store** before any additional arbitration delay;
- main-bus accesses may take longer under contention from the other core, DMA, or other bus masters.

This is a concrete example of why "one load" is not a sufficient machine cost.

The SIO block contains core-local or low-latency machinery including:

- CPUID;
- inter-core FIFOs;
- 32 hardware spinlocks;
- GPIO access with atomic set/clear/xor;
- one integer divider per core;
- two interpolators per core.

Using those blocks is not the same as emitting a CPU arithmetic instruction, but on RP2040 they are close enough to the cores that they can participate in tight kernels.

### Hardware divider

The SIO divider is a particularly clean timing point:

- signed and unsigned 32-bit divide/modulo are supported;
- writing dividend/divisor starts the operation;
- the division takes **8 cycles**;
- quotient and remainder can be read on the following cycle;
- each processor has its own divider, so the two cores do not contend for one shared divide unit;
- software can do independent work while the divider runs instead of polling immediately.

This makes division qualitatively different from multiplication on RP2040: multiply is a CPU instruction using the single-cycle multiplier, while divide is an asynchronous SIO operation with a fixed multi-cycle completion time.

For low-precision floating arithmetic this suggests three distinct implementation strategies that should not be conflated:

1. avoid division entirely when exponent/significand transforms suffice;
2. use reciprocal/shift logic in the CPU when that sequence is shorter;
3. start the SIO divider and schedule independent unpack/load/classification work across its eight-cycle window.

### Interpolators

Each core has two hardware interpolators in SIO. They are intended for operations built from accumulator values, shifts, masks, additions, and address-generation-like transformations.

For this project the important point is not to force FP-like arithmetic through them. It is to consider them for the **bit plumbing around** compact formats:

- extracting packed fields;
- shifting a field into a normalized integer position;
- masking sign/exponent/significand pieces;
- forming lookup-table or destination addresses;
- combining a transformed value with a base address/value.

An interpolator lowering should only be added after comparing it with ordinary Thumb shifts/masks. A single scalar conversion may be faster as straight CPU code; a stream with repeated identical extraction geometry may give the interpolator more opportunity.

### SRAM banking and data layout

The 264 KiB SRAM is not one uniform physical block.

The four 64 KiB banks making up the first 256 KiB are word-striped. The two 4 KiB banks are separate scratch banks. Because the large banks arbitrate independently, physical placement and access stride can affect whether two cores or DMA streams collide.

That creates several layout questions for packed low-precision arrays:

- byte-packed streams can make several adjacent logical values share a 32-bit SRAM word;
- 9-bit E5M3 packed densely causes values to cross byte and word boundaries periodically;
- 16-bit-per-value E5M3 storage wastes bits but simplifies addressing and halfword loads;
- structure-of-arrays storage for sign/exponent/significand may improve one operation while increasing total memory traffic;
- two-core partitioning should preferably give each core long contiguous regions rather than interleaving writes to the same words.

Do not infer the best representation from payload density alone.

### XIP flash and lookup tables

The XIP cache means program code and read-only tables in external flash have a two-level cost:

1. cache-hit behavior;
2. refill behavior when the table/code working set stops fitting or conflicts.

A 256-entry table for an 8-bit encoding is small in absolute terms but can still compete with code for a 16 KiB cache. A denser or multi-table design should therefore be benchmarked from:

- SRAM;
- XIP flash with a warm cache;
- XIP flash after deliberate cache disturbance.

That is more informative than quoting only the table's byte count.

## Suggested machine-readable benchmark record

For each RP2040 low-precision kernel, preserve at least:

```text
chip                  = RP2040
core                  = Cortex-M0+
clock_hz              = ...
code_location         = SRAM | XIP
data_location         = SRAM bank/alias ...
cores_used            = 1 | 2
dma_active             = yes | no
representation        = byte | halfword | dense-packed | ...
values_processed      = ...
cycles_total          = ...
cycles_per_value      = ...
loads_per_value       = ...
stores_per_value      = ...
branches_per_value    = ...
multiplies_per_value  = ...
divider_uses          = ...
interpolator_uses     = ...
xip_cache_state       = warm | cold | not_applicable
```

A future machine can then compare arithmetic sequences without silently changing memory placement or cache state.

## Sources

- Raspberry Pi, *RP2040 Datasheet*:
  https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf
- Raspberry Pi, RP2040 specifications:
  https://www.raspberrypi.com/products/rp2040/specifications/
- Arm, *Cortex-M0+ Processor Datasheet*:
  https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/Processor%20Datasheets/Arm%20Cortex-M0%20plus%20Processor%20Datasheet.pdf
- Arm, *Cortex-M0+ Devices Generic User Guide*:
  https://documentation-service.arm.com/static/5f04aadfdbdee951c1cdc957
