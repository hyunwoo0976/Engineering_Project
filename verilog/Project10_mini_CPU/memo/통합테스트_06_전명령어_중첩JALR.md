# 통합테스트 06 — 전 명령어 + 중첩 JALR + 제어흐름/FP스톨 충돌 (하드코어)

CPU가 지원하는 **모든 명령어**(논리·시프트 포함) + **2단 중첩 서브루틴**(JAL/JALR) +
오버플로 + 깊은 FP in-flight 체인 + 루프 속 FP + 정수/FP writeback 충돌을 한 프로그램(61개)에 몰아넣은 최종 테스트.
파이썬 어셈블러+ISS(JAL/JALR/논리/시프트 지원 추가본)로 골든 생성.

## 목적 — 이전 테스트가 못 건드린 것

- **전 명령어**: add/sub/**and/or/xor/sll/srl/sra**/addi/**andi**/lw/sw/flw/fsw/fadd/fsub/fmul/beq/bne/blt/bge/jal/**jalr**
- **2단 중첩 서브루틴** — main→SUB1→SUB2→복귀→복귀 (복귀주소 x20/x22 중첩 생존)
- **제어흐름 redirect가 FP 스톨과 겹치는 타이밍** (← 이번의 핵심 버그)
- 오버플로→Inf, 같은 in-flight 레지스터 양쪽 포트, 루프 속 FP+정수 누산

## 데이터 (`data.mem`)
```
7f7fc99e   // 3.4e38 (near max)
41200000   // 10.0
3f000000   // 0.5
```

## 기대값 (all-pass, ISS 대조)
```
x1=252 x2=63 x3=60 x4=255 x5=195 x6=12 x7=4 x8=4032 x9=15 x10=-256
x11=-16 x12=-189 x13=315 x14=255 x15=255 x17=42 x19=12 x20=168
x21=11 x22=220 x23=263 x24=99 x25=88 x26=315 x27=55
f3=Inf f6=10.5 f7=10 f8=100 f9=200 f10=200 f11=30 f12=210 f13=100 f14=10.5
```
(전체 hex는 `python/tools/riscv_iss.py`로 재생성)

## 잡은 버그 4개 — 통합테스트로는 절대 안 나올 것들

1. **명령어 메모리 오버플로** (`Instruction_Memory.v`) — `mem[0:31]`+`pc[6:2]`=32칸뿐. 61개 프로그램이 넘쳐 PC≥0x80이 wrap → PC/inst 불일치. → **`mem[0:63]`+`pc[7:2]`**로 확장. (파형: `CPU_T06_5_reexec_PCwrap_0x100`)

2. **분기 그림자 JAL 우선순위** (`PC_MUX.v`, `CPU_Hazard.v`) — taken 분기(EX)인데 그림자에 speculative fetch된 JAL(loop)이 ID에서 Early_Jump를 쏴서 분기를 덮음. 우선순위가 `ID_PCSrc > EX_PCSrc`라 어린 JAL이 오래된 분기를 이김. → **`EX_PCSrc` 우선**으로 뒤집음.

3. **FPU_6clk 1클럭 지각 → WB 충돌** (`FPU_Check.v`) — `FPU_6clk <= Rd[5][0]`(등록)이라 `FPU_Valid`(조합)와 동시에 떠서, FP 결과 나올 자리를 미리 못 비움 → FP결과가 정수 addi를 덮음. → **`assign FPU_6clk`(조합화)**로 Valid보다 1클럭 먼저.

4. **★ JALR redirect가 FP 스톨(PCWrite=0)에 증발** (`Hazard` PCWrite) — 중첩 SUB2의 `jalr`이 복귀할 때, 마침 SUB2의 `fadd f14`가 배수(drain)되며 스톨을 걸어 `PCWrite=0`. jalr이 타겟(`final_next_pc=0xDC`)을 정확히 계산해도 **PC가 안 실림** → 복귀 실패 → 흐름이 프로그램 끝을 지나 wrap → **처음부터 재실행** → 누산기(x19 등) 다중 실행, 복귀주소 x20 커짐(+0x300). → **redirect 시 `PCWrite=1` 강제**: `PCWrite = (EX_PCSrc||EX_is_JALR||ID_PCSrc) ? 1 : (스톨 결과)`. (파형: `CPU_T06_6_JALR_target_ok`, `CPU_T06_7_JALR_PCwrite0_ROOT`)

## 디버깅 여정 — 증상은 하나처럼 보였지만

- 처음엔 `x19=56`(=4×14)이 "루프 누산기 과다"로 보임 → EX freeze 의심(틀림, EX_Rd 안 반복)
- → "루프는 3번 정상, 루프 뒤 x19가 커짐" (`CPU_T06_1~3`)
- → **PC가 0x100에서 첫 명령어 재실행** 발견 (`CPU_T06_5`) — "안 멈추고 재시작"이 진짜 뿌리
- → 왜 안 멈추나 → SUB2의 jalr이 복귀 안 함 (`CPU_T06_6`: 타겟은 0xDC로 맞음!)
- → **PCWrite=0이라 그 타겟을 PC가 안 실음** (`CPU_T06_7`) = 최종 원인

**x19/x20/x22/x26/x27/f11/f12 7개 FAIL이 전부 "재실행 하나"에서 나온 cascade**였다.

## 배운 것

- **제어흐름 redirect(분기/점프)는 스톨보다 우선** — redirect는 어린 명령어를 flush하므로 PC는 무조건 타겟을 실어야. 스톨이 PCWrite=0을 걸어도 redirect가 이겨야 함
- **재실행/무한흐름은 "안 멈춤"으로 나타난다** — 개별 레지스터 버그로 보여도 뿌리는 제어흐름일 수 있음. PC가 프로그램 밖으로 나가는지부터 봐야
- **JALR+FP 스톨처럼 두 기능이 겹치는 타이밍**은 각각 테스트로는 안 걸림 — 하드코어 통합 테스트가 필수
- 명령어 하나(jalr)에 검출·타겟계산·PC로드 다 맞아야 — 타겟 맞아도 PC 안 실리면 무용

## 결과
- **정수 27개 + 실수 10개 all-pass** — 전 명령어 + 중첩 JALR + 제어/FP충돌 검증 완료
- RV32I(논리/시프트 포함) + F extension 5단 파이프라인 통합 검증 **완료**

## 다음
- 제어 redirect × FP스톨 충돌을 **분기(beq~bge)·JAL에도** 터뜨려 fix(PCWrite=1) 커버 확인
- 여태 케이스 전부 하나로 합친 mega 테스트
