# Engineering Project — Digital Design & Verification

RTL design and verification work, built toward a career in **digital IC design or design verification (DV)**. I'm developing both sides in depth — architecting the hardware, then verifying it rigorously — and keeping both paths open.

The centrepiece is a **32-bit RISC-V pipelined CPU with an IEEE-754 floating-point unit** — designed from the microarchitecture up, then verified with self-checking, constrained-random, and reference-model (ISS) testbenches.

> **Where to start:** [`verilog/Project10_mini_CPU`](verilog/Project10_mini_CPU) — the main project.
> Projects 1–9 are the building blocks that lead into it.

---

## ⭐ Featured — RISC-V 5-Stage Pipelined CPU with FPU

📂 [`verilog/Project10_mini_CPU`](verilog/Project10_mini_CPU)

A 32-bit RISC-V processor written from scratch: RV32I subset plus single-precision
floating-point arithmetic, with full hazard and forwarding logic across **two register files**.

### Architecture

```
IF ──► ID ──► EX ──► MEM ──► WB
              │
              ├── ALU (arithmetic / logic / shift)
              └── FPU  ──► 7-cycle pipeline ──► shadow register ──┐
                           (FADD / FSUB / FMUL)                   │
                                                    re-enters at MEM
```

| Block | Contents |
|---|---|
| **Integer datapath** | ALU, immediate generation, register file, data memory |
| **Control flow** | `BEQ` `BNE` `BLT` `BGE`, `JAL` (resolved early in ID), `JALR` (resolved in EX) |
| **FPU** | IEEE-754 single precision `FADD.S` / `FSUB.S` / `FMUL.S`, built from carry-lookahead adder, leading-zero detector, barrel shifter, normalization and rounding stages |
| **Hazard unit** | branch/jump flush, load-use stall, FPU in-flight tracking via a 7-stage shift register |
| **Forwarding unit** | operand-level resolution across integer **and** FP register files |

### Engineering problems solved

**Integrating a multi-cycle FPU into a single-cycle-per-stage pipeline.**
The FPU takes 7 cycles while the rest of the pipeline advances every cycle. A shadow
register holds the destination register and control signals for the duration, so the
FP instruction re-enters the pipeline at MEM as an ordinary instruction. A structural
hazard on the EX/MEM register is avoided by inserting a bubble one cycle before the
result returns.

**Forwarding across two register files.**
`x5` and `f5` share a register number but are different registers, so comparing numbers
alone produces false matches. `FSW` makes this concrete: it reads an **integer** register
for the address and an **FP** register for the store data, simultaneously. Resolving
forwarding per *instruction type* cannot express this — it has to be resolved per
**operand**, which reduced a 12-case enumeration to four wires.

**Exact cancellation in floating-point subtraction.**
`A − A` produced a non-zero result: the mantissa was zeroed but the exponent survived.
Fixed by propagating an `all_zero` flag to the exponent stage.

### Verification

| Target | Method | Result |
|---|---|---|
| FADD / FSUB / FMUL | directed, including exact cancellation (`A − A = 0`) | pass |
| FPU latency | measured against waveform | 7 cycles, stable |
| CPU forwarding unit | 14 directed cases | **14 / 14** |
| FPU forwarding unit | 13 directed cases | **13 / 13** |
| Forwarding (top level) | constrained-random, 1000 cases, reference model | **1000 / 1000** |
| Integer pipeline | program-level simulation | runs, no `x`/`z` propagation |

Coverage was measured rather than assumed: of the 1000 random cases, only ~20 % actually
exercised a forwarding path and the dual-forwarding case occurred 5 times — which is why
directed tests remain part of the suite.

### Status

Complete: integer pipeline, FPU arithmetic, hazard logic, forwarding units.
In progress: `FLW` / `FSW` datapath, hazard/forwarding integration, full FP program simulation.

📄 Design notes and full bug history (Korean): [`memo/`](verilog/Project10_mini_CPU/memo/)
· [Forwarding](verilog/Project10_mini_CPU/memo/Forwarding.md)
· [Hazard](verilog/Project10_mini_CPU/memo/Hazard.md)
· [Bug log](verilog/Project10_mini_CPU/memo/error_log.md)

---

## Project Progression (1 → 10)

Each project builds a block that the next one needs. Projects 1–9 are the components
integrated in Project 10: adders and the ALU become the integer datapath, registers and
shift registers become the pipeline stages, and FSM control becomes the instruction decoder.

| # | Project | Block built | Used later in |
|---|---|---|---|
| 1 | [Combinational logic](verilog/Project1_Combinational_logic_gate) | gates, truth tables | everything |
| 2 | [Binary adder](verilog/Project2_Binary_Adder) | half / full adder | ALU, FPU mantissa path |
| 3 | [Subtractor](verilog/Project3_subtractor) | two's complement | ALU, FP exponent compare |
| 4 | [N-bit adder](verilog/Project4_N_bit_Adder) | parameterized width, carry propagation | CLA in the FPU |
| 5 | [ALU](verilog/Project5_ALU) | arithmetic / logic / shift groups | CPU execute stage |
| 6 | [Register top system](verilog/Project6_Top_module_using_register) | registers in a system | pipeline registers |
| 7 | [Shift register](verilog/Project7_Shift_register) | latch, flip-flop, shift register | FPU in-flight tracker |
| 8 | [Register system integration](verilog/Project8_Register_Topsystem) | multi-module integration | CPU top level |
| 9 | [FSM mini processor](verilog/Project9_mini_processer_using_FSM) | FSM-based control | instruction decoding |
| **10** | **⭐ [RISC-V pipelined CPU + FPU](verilog/Project10_mini_CPU)** | **integrates all of the above** | **main project — details at the top of this page** |

Section overview: [`verilog/README.md`](verilog/README.md)

---

## Roadmap — SystemVerilog & UVM

The next stage. The intent is to verify the **same** RISC-V CPU with a UVM environment,
so one design is covered from both the design and the verification side.

| Stage | Topic | Status |
|---|---|---|
| 1 | [C++](c++) — OOP foundation (classes, inheritance, virtual, polymorphism) for SystemVerilog | in progress |
| 2 | [`systemverilog/`](systemverilog) — classes, randomization, assertions (SVA), coverage | planned |
| 3 | [`UVM/`](UVM) — agent / driver / monitor / scoreboard | planned |
| 4 | AMBA (AXI / AHB) protocol verification IP | planned |

C++ is studied for the object-oriented concepts that UVM is built on — not as a language
specialisation — and will later be reused as a **golden reference model** for FPU
verification through DPI-C.

Utility scripting lives in [`python/`](python).

---

## Environment

| Category | Tool |
|---|---|
| HDL | Verilog-2001 / SystemVerilog (IEEE 1800) |
| Simulation | Icarus Verilog (`iverilog`, `vvp`) |
| Waveform | GTKWave |
| C++ | Visual Studio |
| Editor | Visual Studio Code |
| Build | file lists (`*.f`), batch scripts |

```bash
iverilog -g2012 -Wall -s <top_module> -o sim.out -f <filelist>.f
```

```bash
vvp sim.out
```

---

## Verification Approach

Verification is treated as a first-class activity, not an afterthought.

- **Self-checking testbenches.** The simulator decides pass/fail. Waveforms are for
  debugging, not for judging correctness.
- **Expected values derived from the specification**, never copied from the design under
  test — copying the design duplicates its bugs and produces tests that always pass.
- **Directed tests** for boundary and corner cases, including *negative* tests where
  forwarding must **not** occur (`x0` writes, cross-register-file matches).
- **Constrained random** with a **reference model** written at a different level of
  abstraction than the design, so encoding and priority mistakes are caught.
- **Coverage measured explicitly.** A passing random run is not evidence of coverage.

Shared notes: [tool usage](verilog/memo/도구_사용법.md) ·
[verification methodology](verilog/memo/검증_방법론.md) ·
[Verilog pitfalls](verilog/memo/Verilog_주의점.md)

---

## Documentation Convention

```
ProjectN/
├── README.md      design summary (English)
├── memo/          design notes, background theory, bug log (Korean)
└── img_*/         waveform captures referenced from the bug log
```

Bugs are logged with symptom, root cause at `file:line`, the fix, and the waveform that
confirmed it — rather than silently corrected. A design that was never broken was never
seriously tested.
