# AURIX / TriCore hardware / microarchitecture notes

Status: hardware evidence, separate from `INSTRUCTIONS.md` and separate from Idriç implementation status.

This target actually has public microarchitecture material much closer in spirit to the Cortex-A55 note. Keep TC1.6.2P/TC3xx and TC1.8/TC4xx separate.

## TC3xx / TC1.6.2P execution unit

Infineon documents the TC1.6.2P implementation with three parallel pipelines:

- **Integer Pipeline (IP)**;
- **Load/Store Pipeline (LS)**;
- **Loop Pipeline (LP)**.

The execution unit can in favorable circumstances execute **up to three instructions in one clock**: one suitable integer/MAC instruction, one load/store instruction, and one loop instruction.

Instructions pass through a decode stage and two execute stages. Forwarding paths are documented as reducing pipeline stalls.

TC1.6.2P also documents:

- 32-bit load/store architecture;
- 16- and 32-bit instruction encodings;
- most instructions executing in one cycle;
- dynamic branch prediction, with branches taking 1, 2, or 3 cycles depending on the case;
- dual issue into Integer and Load/Store pipelines;
- separate A0-A15 address-register and D0-D15 data-register files;
- DSP/MAC facilities including dual single-cycle 16×16 multiply-accumulate capability and packed operations.

This is a much richer scalar/DSP target than AVR, SM83, or Cortex-M0+.

## Load/store ordering matters

TC1.6.2P also has a store buffer. In normal operation, non-dependent loads may bypass earlier stores, subject to documented exceptions. That means memory behavior cannot be modeled as a naive strictly serialized sequence if we are trying to understand throughput.

For low-precision high-dimensional work, the separation of address generation/load-store work from integer/MAC work is particularly relevant: a good packed representation may let address/memory traffic and arithmetic overlap.

## TC4xx / TC1.8

TC4xx uses TriCore TC1.8 and must stay separate from TC3xx.

Infineon's TC4xx execution-unit documentation still describes Integer, Load/Store, and Loop pipelines operating in parallel, permitting up to three instructions per clock. It specifies decode followed by two execute stages, with a third execute stage for MAC operations.

TC1.8 also brings architectural changes beyond TC1.6.2P, including facilities documented separately in the TC1.8 manuals. Do not copy a TC3xx timing assumption into TC4xx merely because both are called TriCore.

## Consequences for small floating formats

This target should test more than "can shifts and masks implement FP8-like scalars?"

Questions worth measuring are:

- can decode/classification integer work dual-issue with loads/stores?
- can two packed low-precision values feed the DSP/MAC paths profitably?
- do 8-/16-bit packed operations help comparisons, normalization, or small rotations?
- does the storage layout allow address-generation and arithmetic to overlap?
- when does unpack/repack cost erase the gain from compact memory traffic?

The exact AURIX part still matters because core count, local memories, caches/scratchpads, clock, and optional facilities vary across the product family.

## Evidence boundary

Unlike several other embedded targets, the public Infineon documentation gives real pipeline and issue information. Use it. But continue to distinguish:

- ISA facts from `INSTRUCTIONS.md`;
- TC1.6.2P versus TC1.8 implementation facts;
- family-level core documentation versus exact-device memory/cache capacities;
- theoretical issue width versus measured throughput of our instruction mix.

## Sources

- Infineon, AURIX TC3xx CPU subsystem:
  https://documentation.infineon.com/aurixtc3xx/docs/dex1702559585636
- Infineon, AURIX TC3xx family / TriCore architecture overview:
  https://www.infineon.com/products/microcontroller/32-bit-tricore/aurix-tc3xx
- Infineon, *AURIX MCU: Assembly optimization*:
  https://community.infineon.com/t5/Knowledge-Base-Articles/AURIX-MCU-Assembly-optimization-KBA236155/ta-p/368853
- Infineon, TC4xx execution unit:
  https://documentation.infineon.com/aurixtc4xx/docs/iov1509959051909
