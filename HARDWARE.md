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


## Second-pass details: issue pairing, local memories, register classes, and packed DSP

TriCore is the embedded target in this repository where a modern scheduling model can be most explicit.

### Issue width is constrained by pipeline class

"Up to three instructions per cycle" should not be read as a generic three-wide superscalar promise.

The documented execution unit has distinct Integer, Load/Store, and Loop pipelines. Useful scheduling therefore depends on finding instructions from compatible classes.

For a low-precision inner loop, keep separate counts for:

- IP instructions: integer arithmetic, logical/bit work, MAC/DSP operations as applicable;
- LS instructions: loads, stores, address generation;
- LP instructions: hardware-loop/control work;
- instructions that serialize or otherwise block pairing.

A representation that saves one integer instruction but adds an extra load can move pressure from one pipeline to another; the right metric is **pipeline balance**, not only total instruction count.

### Address and data register files are intentionally separate

A0-A15 and D0-D15 are different register files with different roles.

This is useful for stream kernels:

- pointers/indexes can remain in address registers;
- packed numeric values and arithmetic temporaries can remain in data registers;
- load/store issue can perform address work without consuming the same register namespace used for arithmetic.

The backend should preserve this distinction early enough that generic register allocation does not create avoidable A↔D shuffling.

Some TriCore operations also use paired data registers for wider values. Treat those as a scarce resource when evaluating any algorithm that widens tiny formats to 64-bit intermediates.

### Local memory versus shared/nonlocal memory

AURIX devices have per-core/local memory structures such as data/program scratchpad and caches, plus shared/nonlocal memories whose exact size and arrangement depend on the selected device.

For the low-precision experiments, every receipt should state whether the hot array is in:

- core-local data scratchpad;
- cached memory;
- shared LMU-class memory;
- flash;
- another core's local memory;
- externally attached memory, if relevant to the selected part.

The three-pipeline execution model is most meaningful when the LS pipeline is not stalled on a slow target.

Do not quote one TC3xx part's DSPR/PSPR/cache sizes as "TriCore sizes"; keep capacities per exact device.

### Store buffer and apparent ordering

The store buffer means ordinary non-dependent loads can, under the default ordering mode, bypass older stores except in documented cases such as peripheral/atomic accesses or a full store buffer.

For throughput experiments:

- avoid inserting unnecessary ordering operations;
- do not infer completion-at-memory from store-instruction retirement;
- separate producer/consumer dependencies from unrelated streaming stores;
- record when strict ordering is enabled because it changes performance materially.

This is directly relevant to conversion kernels that stream input → output while continuing to load later input.

### Branch prediction versus hardware loops

TC1.6.2P has dynamic branch prediction and a Loop Pipeline.

A small-format array loop should therefore compare:

- ordinary counted branch;
- architecture loop mechanism where applicable;
- unrolling;
- vector/packed work that reduces trip count.

Classification branches *inside* the loop remain a different problem from the loop-control branch. Record them separately.

### Packed/DSP arithmetic deserves a real lowering experiment

TriCore's DSP facilities include packed arithmetic and dual 16×16 MAC capability.

For E5M3 and the 8-bit formats, useful questions include:

- can two or more decoded significands be held in packed 16-bit lanes?
- can exponent alignment be expressed with packed shifts or bit-field operations?
- can small rotations use packed 16-bit multiply/accumulate after an explicit scaling map?
- is saturating packed arithmetic useful for a chosen non-IEEE coarse operation?
- does packing reduce LS traffic enough to offset unpack/repack IP instructions?

Do not equate the availability of DSP instructions with native support for the floating encoding. The format semantics still live above this layer.

### Context machinery and ABI cost

TriCore's fast context mechanism and context save areas are part of the architecture's real-time design.

For tiny leaf kernels, the backend should still ask:

- which A/D registers are call-clobbered under the selected ABI?
- can the kernel remain a leaf?
- does a helper call for rounding/classification trigger context/register traffic that dwarfs the arithmetic?
- should special-value handling be outlined into a cold helper or kept inline?

A low-precision primitive should not be benchmarked only as an isolated hand-coded basic block if the generated calling convention makes it expensive in real code.

### TC1.8 must get its own measured table

TC4xx/TC1.8 should eventually have a side-by-side machine table rather than prose inheritance from TC1.6.2P:

```text
field                       TC1.6.2P / TC3xx       TC1.8 / TC4xx
pipeline classes            ...                    ...
issue constraints            ...                    ...
branch predictor             ...                    ...
loop mechanism               ...                    ...
A/D registers                ...                    ...
packed integer/DSP ops       ...                    ...
MAC resources                ...                    ...
FPU facilities               ...                    ...
local memories               exact part             exact part
cache geometry               exact part             exact part
store buffering              ...                    ...
documented latency table     ...                    ...
measured kernel table        ...                    ...
```

Unknown cells should remain explicit.

## Suggested TriCore low-precision receipt

```text
device
core_revision
clock_hz
representation
source_memory_region
destination_memory_region
values
cycles_total
cycles_per_value
IP_instructions
LS_instructions
LP_instructions
paired_issue_cycles
single_issue_cycles
load_stalls
store_buffer_stalls
branches
branch_mispredicts_if_measurable
packed_DSP_instructions
MAC_instructions
register_spills
```

That record is detailed enough for a machine to distinguish a good arithmetic sequence from one that only looked short in architecture-neutral source.

## Sources

- Infineon, AURIX TC3xx CPU subsystem:
  https://documentation.infineon.com/aurixtc3xx/docs/dex1702559585636
- Infineon, AURIX TC3xx family / TriCore architecture overview:
  https://www.infineon.com/products/microcontroller/32-bit-tricore/aurix-tc3xx
- Infineon, *AURIX MCU: Assembly optimization*:
  https://community.infineon.com/t5/Knowledge-Base-Articles/AURIX-MCU-Assembly-optimization-KBA236155/ta-p/368853
- Infineon, TC4xx execution unit:
  https://documentation.infineon.com/aurixtc4xx/docs/iov1509959051909
