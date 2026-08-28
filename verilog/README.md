# Verilog RTL Project Progression

Digital design projects built bottom-up from combinational logic to an RV32I + F
five-stage pipelined CPU. Each project keeps RTL, testbenches, design notes, and the
errors found during verification together.

## Projects

| # | Project | Main topic | Feeds into |
|---:|---|---|---|
| 1 | [Combinational logic](Project1_Combinational_logic_gate) | gates and truth tables | every later block |
| 2 | [Binary adder](Project2_Binary_Adder) | half/full adder | ALU and FPU mantissa path |
| 3 | [Subtractor](Project3_subtractor) | two's complement subtraction | ALU and FP exponent comparison |
| 4 | [N-bit adder](Project4_N_bit_Adder) | parameterization and carry propagation | reusable arithmetic blocks |
| 5 | [ALU](Project5_ALU) | arithmetic, logic, and shift groups | CPU execute stage |
| 6 | [Register top system](Project6_Top_module_using_register) | registers inside a system | pipeline registers |
| 7 | [Shift register](Project7_Shift_register) | latch, flip-flop, shift register | FP in-flight tracking |
| 8 | [Register system integration](Project8_Register_Topsystem) | multi-module integration | CPU top-level wiring |
| 9 | [FSM mini processor](Project9_mini_processer_using_FSM) | FSM-based control | instruction decoding |
| 10 | **[RV32I + F pipelined CPU](Project10_mini_CPU)** | **CPU, FPU, hazards, forwarding, ISS verification** | **featured project** |

## Featured result

Project 10 integrates the earlier blocks into an 80+ module processor with:

- a five-stage integer pipeline;
- a from-scratch six-stage IEEE-754 single-precision FPU;
- separate integer and floating-point register files;
- operand-level integer/FP forwarding;
- load-use and seven-cycle in-flight FP hazard handling;
- branch, `jal`, and `jalr` control-flow recovery; and
- an independent Python ISS used across seven integration programs.

The final 120-instruction MEGA test matches the golden model across 30 integer and
30 floating-point registers. Start with the
[Project 10 overview](Project10_mini_CPU/README.md), then use its
[full bug log](Project10_mini_CPU/memo/error_log.md) to follow symptom → waveform →
root cause → fix.

## Verification convention

```text
ProjectN/
├── README.md   design summary
├── src_*/      RTL
├── tb/         testbenches
├── memo/       background, design decisions, and error log
└── img_*/      waveform evidence
```

Expected values are derived independently from the specification. Waveforms are used
to locate failures; self-checking tests and the ISS decide pass/fail.

