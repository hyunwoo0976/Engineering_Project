# Project 10 — mini RISC-V CPU (RV32I + F): Detailed Development Document (English)

> This is the **in-depth record**. For the portfolio summary, see [`../../README.md`](../../README.md).
> It covers the development storyline, a module-by-module walkthrough, and the **full story of every
> bug — how it appeared and how it was fixed**.

---

## 1. Development Storyline — why this build order

### Bottom-up methodology
I brought the design up **one layer at a time, verifying each layer before adding the next.** When a
new bug appeared, this let me immediately point to **"the layer I just added"** as the culprit. Order:

```
1. IEEE-754 FPU (standalone)   → completed and verified on its own before entering the pipeline
2. Integer core (5-stage pipe) → basic RV32I execution
3. Hazard unit (stall / flush)
4. Forwarding (integer)
5. FPU pipeline integration    → folding the 7-cycle latency into the pipeline
6. FP-aware forwarding & hazard → operands still "in flight" inside the FPU
```

### Why the FPU first?
The FPU is the **most timing-constrained block** in this project (multi-cycle). I first **integrated
FADD and FMUL into a single FPU and optimized it to compress the internal pipeline as much as
possible**, then **designed the CPU pipeline around that compressed FPU timing.** If you add the FPU
last, you have to cram a multi-cycle FPU into an already-fixed CPU timing; by finishing the FPU first,
you can **fit everything else around the tightest block**, which makes integration far cleaner.

---

## 2. Architecture

A 5-stage pipeline (IF·ID·EX·MEM·WB) with the **FPU branching off EX as a parallel multi-cycle unit.**

```
 IF        ID            EX                       MEM         WB
[PC]→[IM]→[Decoder]────→[ALU]────────────┐
          [RegFile]                      ├→[EX/MEM]→[DataMem]→[WB MUX]→ RegFile
          [ImmGen]    →[FPU 6-stage]·7cyc·→[shadow]─┘
             ↑ forwarding (int + FP) / stall·flush (hazard) wrap the whole pipeline
```

- **Integer ops** finish in EX in one cycle.
- **FP ops** enter the FPU (6 internal stages) at EX → the result appears 7 cycles later → a
  **shadow register** returns that result, at the cycle the pipeline expects, **into the EX/MEM
  pipeline register** → from there it rides down MEM and WB exactly like an integer result. (It does
  *not* go straight to WB; it merges at the EX/MEM boundary.)
- The **integer register file and FP register file are independent** — forwarding and write-back
  paths are split accordingly.

---

## 3. Module-by-Module

### 3.1 FPU subsystem (the biggest differentiator)

#### `FPU.v` — FPU top (6-stage pipeline)
Unpacks both operands into `{sign, exponent, fraction}`, runs **FADD_core and FMUL_core in parallel**
through 6 pipeline stages, and selects the result at the final stage by `op`. The rounding mode (`rm`)
and `op` ride down the pipeline at the same rate as the data, arriving together at the last stage.

```verilog
FADD_core u_FADD_core(.clk, .reset, .s1_en, .s1_op(s1_op[0]),
                      .s1_SIGN_A, .s1_EXPO_A, .s1_FRAC_A, ...,
                      .s6_ADD_out, .s6_OF(s6_OF_ADD), .s6_UF(s6_UF_ADD), .s6_rm);

FMUL_core u_FMUL_core(.clk, .reset, .s1_en, ...,
                      .s6_MUL_out, .s6_OF(s6_OF_MUL), .s6_UF(s6_UF_MUL));

MUX s6_u_mux(.ADD_out, .MUL_out, .op(s6_op),
             .OF_ADD, .UF_ADD, .OF_MUL, .UF_MUL,
             .Final_out, .OF, .UF, .ZF, .sign);   // overflow→Inf, underflow→0 resolved here
```

#### `FADD_core.v` — 6-stage floating-point adder
Three lanes (FRAC mantissa / EXPO exponent / SIGN) advance together through 6 stages:

| Stage | Work | Sub-modules |
|---|---|---|
| **S1** | exponent difference, magnitude compare | `EXPO_SUB`, `comparator` |
| **S2** | right-shift the smaller mantissa by the exp diff (align); conditional-invert for subtraction | `barrel_shifter`, `Cond_Inverter`, `Mode_Detector` |
| **S3** | add `A+B` and `B+A` with CLA, pick the non-negative one (clean A−A=0) | `CLA`, `Magnitude_Restoration` |
| **S4** | find the leading 1 → normalization direction/amount | `Normalization_Controller`, `LZD` |
| **S5** | normalize-shift the mantissa + adjust exponent | `barrel_shifter`, `EXPO_CAL` |
| **S6** | round + exceptions (overflow→Inf, underflow→0) | `Rounding`, `Exception_Handler_ADD` |

> Because the datapath is **split into small modules**, when overflow once produced a NaN I could narrow
> the fault straight to "S6 Exception_Handler."

#### `FMUL_core.v` — 6-stage floating-point multiplier
Mantissa via a multiplier (`Multiplier`), exponent via add-then-debias (`MUL_EXPO`, `MUL_EXPO_ADD`),
sign via XOR (`MUL_SIGN`), then normalize (`Normalization_MUL`) → round → exceptions.

#### FPU shared / sub-modules (roles)
- `FPU_unpack` — split 32 bits into sign/expo/frac (zeros when FPU_en=0)
- `FPU_Control` — decode op/rm
- `barrel_shifter` — parametrized barrel shifter (reused for both alignment and normalization)
- `LZD` — leading-zero detector (normalization shift amount)
- `CLA` — carry-lookahead adder (mantissa add)
- `EXPO_SUB` / `EXPO_CAL` / `EXPO_MUX` — exponent diff / adjust / select
- `Rounding` — round-to-nearest, returns whether a carry-out occurred (`count`)
- `Exception_Handler(_ADD)` — on OF clears mantissa to 0 (→Inf), on UF returns 0

### 3.2 Integer datapath
- **`Main_Decoder.v`** — from opcode, generates control signals (RegWrite/MemWrite/ALUsrc/…) and the
  `is_*` flags. Every signal is defaulted at the top of the `always @(*)` to prevent latches. Supports
  R/I/S/B/J + FLW/FSW/FPU.
- **`ALU.v`** — `calculate_group` (add/sub, sign, ZF), `logical_group` (AND/OR/XOR), `shift_group`
  (SLL/SRL/SRA) in parallel, selected by `ALU_MUX` under `ALU_Control`.
- **`ALU_Control.v`** — decodes 8 operations from ALUOp + funct3 + funct7[30].
- **`Register_file.v`** — integer register file with a **write-first bypass** (same-cycle write→read
  returns the new value), which resolves the distance-3 hazard (E24).
- **`Data_Memory.v`** — RAM for LW/SW.
- **`ImmGen.v`** — assembles I/S/B/J + FLW/FSW immediates, handling the B/J-type scramble and the
  implicit LSB `1'b0` (×2).
- **`Instruction_Memory.v`** — `mem[0:127]` addressed by `pc[8:2]` (128 words; prevents wrap on long
  programs).

### 3.3 Pipeline & PC
- **`Pipeline_CPU.v`** — the top module. Wires ~80 sub-modules into 5 stages: IF (PC/IM), ID
  (Decoder/RegFile/ImmGen), EX (ALU/FPU/shadow/forwarding MUXes), MEM (DataMem), WB (write-back MUX),
  plus the Hazard and Forwarding units.
- **`Pipe_reg_1clk(_control/_en).v`** — the stage registers. The `_control` variant supports stall
  (hold) and flush (clear).
- **`PC_reg` / `PC_Adder` / `PC_Target` / `PCSrc`** — PC register, +4, branch target, branch-taken test.
- **`PC_MUX.v`** — next-PC select, with **priority `EX_PCSrc(branch) > EX_is_JALR > ID_PCSrc(JAL)`**
  (E27 fix).
- **`Early_Jump_Unit.v`** — takes a JAL early, in ID. Fires **only when `is_JAL`** (E02 fix).
- **`JALR_Jump_Unit.v`** — JALR target = rs1 + imm.

### 3.4 Hazard & Forwarding (the heart of the pipeline)
- **`Forwarding_Unit.v`** — **splits integer and FP forwarding**, then combines by instruction type:
  `CPU_Forwarding_Unit` (int) + `FPU_Forwarding_Unit` (FP) + `Forwarding_Combine` (select by
  EX_is_FPU/FLW/FSW).
- **`CPU_Hazard.v`** — load-use stall, branch/jump flush. **Forces PCWrite=1 on a redirect** (E29).
- **`FPU_Hazard.v`** — the FP in-flight stall. Holds the consumer in ID (IF_ID_stall) and lets the
  producer drain (ID_EX_flush).
- **`FPU_Check.v`** — the **FP in-flight detector.** A 7-deep shift register tracks in-flight FP
  destinations:

```verilog
assign Rd0_next = (EX_is_FPU) ? {EX_Rd,1'b1} : 6'b0;   // inject the producer now in EX
// Rd[0]→Rd[6] shift each cycle;  FPU_Valid = Rd[6][0] (result is ready)
assign FPU_6clk = Rd[5][0];                            // combinational (E28): one cycle before Valid
if (ID_is_FPU) begin
    if (EX_is_FPU && EX_Rd==ID_Rs1) FPU_Left = 3'd7;   // producer still in EX → full 7-cycle wait
    for (x=0;x<7;x=x+1)
        if (Rd[x][0] && Rd[x][5:1]==ID_Rs1) FPU_Left = 6-x;   // already in flight → cycles left
end
```

- **`FPU_shadow_reg.v`** — when the instruction is an FPU op, it **holds that instruction's control
  signals and releases them together with the FPU result, at the same cycle (7 cycles later),** into
  EX/MEM. If it is not an FPU-related signal, it simply passes through.

### 3.5 MUXes & others (roles)
`port_MUX` (operand forwarding + store data), `Result_MUX`/`CPU_MUX`/`FPU_MUX` (result select),
`ALU_A/B_MUX`, `FPU_common/MUX` (merge FPU result + flags) — the selection logic scattered through
the datapath.

---

## 4. Verification — an independent golden model

FP arithmetic and branchy programs make hand-computed expected values impossible. So I wrote a **Python
ISS** (Instruction Set Simulator) that executes each program per the ISA spec and prints the final state
as `check()` lines. The DUT (pipeline CPU) runs the same program and I compare — any mismatch is a DUT
bug. The key point: the expected values come from the **spec, not the DUT.**

| Test | Focus |
|---|---|
| 01–03 | integer ALU, memory + forwarding, branches + backward loops |
| 04 | FPU integration, FP in-flight hazards, FSW→FLW round-trip, overflow→Inf |
| 05 | jal/jalr + mixed int/FP + subroutines |
| 06 | full ISA + nested jalr + control-flow × FP-stall (hardcore) |
| 07 | **MEGA** — 120 instructions, every case in one program |

MEGA (120 instructions) **passes on the first run** — 30 integer and 30 FP registers all match the
golden model bit-for-bit.

---

## 5. ⭐ Bugs — the full story

For each bug I recorded **symptom → waveform → root cause → fix → lesson.**
(Full original log: [`../error_log.md`](../error_log.md).)

### 5.1 Early days — instruction memory & branches (E01–E07)
- **E01 · program.txt not loaded** — a `$readmemh` path issue (tangled F_file folders). → path cleanup.
- **E02 · Early Jump always jumps** — `assign PCSrc=(Early_Target)?1:0` was always true. → gate with `if(is_JAL)`.
- **E03 · BEQ jumps to wrong place** — PC_MUX couldn't distinguish an ID-jump from an EX-branch.
  → split `ID_PCSrc→Early_Target`, `EX_PCSrc→Target`; widen PCSrc to 4 branch kinds.
- **E04 · B-type imm ×2 error** — duplicated `inst[31]` + missing LSB `1'b0`. → add LSB `1'b0`, drop dup.
- **E05 · JAL not taken** — E02+E04 overlapping. → fix both.
- **E07 · BEQ looks shifted (not a bug)** — plotting IF-stage PC next to the ID-stage instruction made
  it look off-by-one. It was correct. → **lesson: always check which stage a signal belongs to.**

### 5.2 Forwarding (caught with a self-checking TB — E08, E16–E23)
Bugs found not on waveforms but with a **self-checking testbench** (independent ref_model + random).
- **E16 · un-forwarded operand latched + MEM/WB mutually exclusive** — a case that assigned only one
  branch inferred a latch, and once inside the MEM branch it never looked at WB. → rewrote to a
  **per-operand independent structure** (port_MUX).
- **E17 · B-block MEM condition typo (10 vs 11)** — copy-pasted from A-block and forgot to change `10`
  to `11`. → fixed, FAIL 0%.
- **E18 · JALR rs1 forwarding missing** — both the DUT and the ref_model were written as "ignore
  forwarding for JALR," so they **happily agreed.** → **lesson: a shared spec misunderstanding is a
  blind spot; the reference must be derived independently from the spec.**
- **E19–E23** — five bugs while unifying FP operands + store data (missing widths, wrong FSW source, …).

### 5.3 The FP in-flight hazard saga (OPEN-6) — four overlapping bugs
The `fadd f9 → fsub f10` case (using the **immediately preceding FP result**). It looked like one bug,
but four were stacked:
1. **Detection one cycle late** — the for-loop scanned only the shift register, not the producer now in
   EX (`EX_Rd`) → back-to-back missed. → add a combinational EX_Rd compare.
2. **Re-injection deadlock** — the FP stall froze EX → the producer re-injected every cycle → `FPU_6clk=1`
   permanent stall. → change `ID_EX_stall` (freeze) to `ID_EX_flush` (bubble).
3. **Countdown collapse** — the Rs1 for-loop had `<=` (backwards) → FPU_Left dropped 111→000 one cycle
   later. → fix to `>`, unify the count to `6-x`.
4. **FSW store fails** — the FSW branch also lacked the EX_Rd check → fsw entered EX before f10 was
   ready and got flushed away. → add the EX_Rd check to the FSW branch too.
- **Lesson: a single in-flight FP instruction needs detect + count + inject + stall aligned across all
  four places.**

### 5.4 Timing-collision bugs caught in integration tests 06–07 (E26–E29)
Bugs that fire only when **two features overlap in time** — invisible to unit tests. (This is the real
value of hardcore integration testing.)

- **E26 · instruction-memory overflow** — in a 61-instruction program, PC≥0x80 wrapped → PC=0x88 but
  fetched the 0x08 instruction. → `mem[0:31]`+`pc[6:2]` → `mem[0:63/127]`+`pc[7:2 / 8:2]`.
- **E27 · branch-shadow JAL priority** — on a taken branch (EX), a speculatively fetched JAL (a loop)
  sitting in the shadow fired Early_Jump in ID and overrode the branch. Priority was `ID_PCSrc >
  EX_PCSrc`. → **flip to EX-first.** Waveform: `CPU_JAL_retaddr_wrong.PNG`
- **E28 · FPU_6clk one cycle late** — `FPU_6clk <= Rd[5][0]` (registered) rose at the same time as
  `FPU_Valid` (combinational), so it couldn't clear the write-back slot in time → the FP result
  overwrote an integer `addi` write-back. → make it `assign FPU_6clk` (combinational).
- **E29 · JALR redirect swallowed by an FP stall** ⭐ — a nested-subroutine `jalr` returning right as an
  FP result was draining, so `PCWrite=0`. Even though the jalr computed the correct target
  (`final_next_pc=0xDC`), **the PC never took it** → the program ran off the end and **re-executed from
  the top** → **seven FAILs (x19/x20/x22/x26/x27/f11/f12) all cascaded from this one re-execution.**
  → **force PCWrite=1 on a redirect** (a redirect flushes the younger instructions anyway, so stalling
  is meaningless). Waveforms: `CPU_T06_7_JALR_PCwrite0_ROOT.PNG`, `CPU_T06_5_reexec_PCwrap_0x100.PNG`

### 5.5 Three pipeline-timing principles generalized from the bugs
Principles that run through several bugs — once I extracted them, I could **avoid the same class of bug
at design time.**
1. **A registered (`<=`/posedge) signal arrives one cycle later than a combinational one** — align the
   timing for that delay (OPEN-1 FPU_Valid, E28 FPU_6clk).
2. **PC priority: the older instruction (EX) must beat the younger one (ID)** — E27, E29.
3. **A control redirect beats a stall** (force PCWrite on redirect) — E29.

---

## 6. Lessons & Conclusion

- **Only hardcore integration tests catch "two features overlapping in time" bugs.** JALR × FP-stall,
  branch-shadow × JAL, integer × FP write-back — none of these ever show up in per-feature unit tests.
- **One symptom often has one root.** Seven FAILs were a single "re-execution" cascade. Start by checking
  whether the PC ran off the end of the program.
- **The ISS golden model is everything.** FP can't be hand-computed and complex branches can't be
  hand-traced. Deriving expected values independently (from the spec, not the DUT) is the core of
  verification — and to avoid even a shared misunderstanding (E18), the reference must come from the spec.
- **Splitting into small modules narrows down where a bug lives** (the 6-stage FADD, the FPU exception
  handling).

**Final: an RV32I + F (single-precision) 5-stage pipeline CPU, designed bottom-up from 80+ modules and
verified end-to-end against an independent ISS golden model across every feature — arithmetic, logic,
shift, memory, branches, loops, subroutines, forwarding, load-use, the 7-cycle FP in-flight hazard, the
FSW round-trip, IEEE exceptions, and control-flow × FP-stall collisions.**
