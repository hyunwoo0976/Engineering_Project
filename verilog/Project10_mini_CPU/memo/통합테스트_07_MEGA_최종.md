# 통합테스트 07 — MEGA 최종 (120 명령어, 전 케이스 총집합)

여태 만든 모든 케이스를 **한 프로그램(120개)**에 다 몰아넣은 최종 검증. **첫 실행에 all-pass** —
그동안 잡은 버그 fix들이 서로 충돌 없이 맞물리고, 회귀 없음을 증명.

- 재현 파일: `통합테스트_07_program.txt` / `_data.mem` / `_check.txt` (memo/)
- 골든 생성: `python/tools/riscv_iss.py` (JAL/JALR/논리/시프트 지원본)
- ⚠️ 실행 전 `Instruction_Memory.v`를 **`mem[0:127]` + `pc[8:2]`(128칸)**로 확장 필요

## 담긴 것 — CPU 지원 전부

| 그룹 | 명령어/기능 |
|---|---|
| 산술 | add, sub, addi |
| 논리 | and, or, xor, andi |
| 시프트 | sll, srl, sra |
| 메모리 | lw, sw (왕복 다수) |
| FP 메모리 | flw, fsw (왕복 다수) |
| FP 산술 | fadd, fsub, fmul |
| 분기 | beq, bne, blt, bge (taken + not-taken) |
| 점프 | jal, jalr |

**해저드/제어 케이스:**
- 포워딩(dist-1/2), load-use, register write-first
- **FP in-flight 해저드** (7clk), 같은 레지스터 양쪽 포트, 깊은 체인
- **오버플로 → +Inf** (f4, f25), **완전상쇄 A−A=0**
- fsw→flw / sw→lw 왕복, **정수↔FP writeback 충돌**
- **뒤로 뛰는 루프 + 중첩 루프**(outer2×inner3, x30)
- **3단 중첩 서브루틴** (JAL 복귀주소 x24/x29/x5, JALR 복귀)
- **branch-shadow-JAL** 회귀
- **제어 redirect × FP스톨 충돌** — beq/bne/blt/bge/jal/jalr 전부 FP 배수 중 redirect

## 결과

- **정수 30개 + 실수 30개 all-pass** (DUT ≡ ISS)
- **첫 실행 통과** = 통합테스트 01~06에서 잡은 버그 fix들(메모리 크기, 분기 우선순위, FPU_6clk, JALR-PCWrite 등)이 **회귀 없이 공존**

## 이 대장정에서 잡은 버그 총정리 (통합테스트 04~07)

| # | 버그 | 파일 | 계열 |
|---|---|---|---|
| OPEN-6 | FP in-flight 검출/카운트/주입/스톨 4곳 | FPU_Check, FPU_Hazard | 타이밍 정합 |
| E26 | 명령어 메모리 32칸 오버플로 | Instruction_Memory | 크기 |
| E27 | 분기 그림자 JAL 우선순위 (ID>EX) | PC_MUX, CPU_Hazard | 우선순위 |
| E28 | FPU_6clk 등록 지각 → WB 충돌 | FPU_Check | 등록 지각 |
| E29 | JALR redirect가 FP스톨(PCWrite=0)에 증발 | Hazard(PCWrite) | 제어×스톨 |

**반복된 실수 패턴 3개**: ① 등록(`<=`/posedge) 신호는 한 클럭 지각 (OPEN-1·E28), ② 오래된 명령어(EX)가 어린 것(ID) 이긴다 (E27·E29), ③ 명령어 하나에 여러 모듈/단계를 같이 맞춰야 한다.

## 배운 것

- **하드코어 통합 테스트만이 두 기능 겹치는 타이밍 버그를 잡는다** — JALR+FP스톨, 분기그림자+JAL, 정수+FP WB. 각 기능 개별 테스트로는 안 걸림
- **증상 하나가 뿌리 하나** — x19=56, x20=+0x300 등 7개 FAIL이 "재실행 하나"에서 나온 cascade였음. PC가 프로그램 밖으로 나가는지부터 봐야
- **ISS 골든모델이 전부** — FP는 손계산 불가, 복잡 분기는 경로 추적 불가. DUT와 독립적으로(ISA 스펙에서) 기대값 생성하는 게 검증의 핵심
- **제어 redirect는 스톨보다 우선** — redirect는 어린 명령어를 flush하니 PC는 무조건 타겟

## 결론

**Project10 mini CPU — RV32I + F(single) 5단 파이프라인 통합 검증 완료.**
연산·논리·시프트·메모리·분기·루프·서브루틴·포워딩·load-use·FP 7clk in-flight·FSW왕복·IEEE예외·제어흐름×FP스톨까지 전 영역 대조 검증.
