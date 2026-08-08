# Project 10 — mini RISC-V CPU (RV32I + F) 상세 개발 문서 (한글)

> 이 문서는 **심화 기록본**입니다. 포트폴리오용 요약본은 [`../../README.md`](../../README.md)를 보세요.
> 여기엔 개발 스토리라인, 모듈별 상세 설명, 그리고 **오류 발생·수정의 전 과정**을 담았습니다.

---

## 1. 개발 스토리라인 — 왜 이 순서로 쌓았나

### Bottom-up 방법론
설계를 **한 층씩 쌓고, 각 층을 검증한 뒤 다음 층**으로 갔습니다. 이렇게 하면 새 버그가 나왔을 때
**"방금 추가한 층이 범인"**이라고 바로 특정할 수 있습니다. 순서는:

```
1. IEEE-754 FPU (단독)      → 파이프라인에 넣기 전 단독으로 완성·검증
2. 정수 코어 (5단 파이프라인) → 기본 RV32I 동작
3. Hazard 유닛 (stall/flush)
4. Forwarding (정수)
5. FPU 파이프라인 통합        → 7클럭 지연을 파이프라인에 녹이기
6. FP-aware forwarding & hazard → FPU 안에서 "날아다니는" 오퍼랜드 처리
```

### 왜 FPU를 제일 먼저?
FPU가 이 프로젝트에서 **가장 제약이 큰 블록**(다중사이클)이기 때문입니다. 먼저 **FADD와 FMUL을 하나의
FPU로 통합·최적화해 내부 파이프라인을 최대한 압축**한 뒤, **그 압축된 FPU 파이프라인의 타이밍에 맞춰
CPU 파이프라인을 설계**했습니다. FPU를 나중에 붙이면 이미 굳어진 CPU 타이밍에 다중사이클 FPU를
욱여넣어야 하지만, FPU를 먼저 완성하면 **가장 빡빡한 블록을 기준으로 나머지를 맞출 수 있어** 통합이
훨씬 깔끔합니다.

---

## 2. 아키텍처 상세

5단 파이프라인(IF·ID·EX·MEM·WB)에 **FPU가 EX에서 갈라지는 병렬 다중사이클 유닛**으로 붙습니다.

```
 IF        ID            EX                       MEM         WB
[PC]→[IM]→[Decoder]────→[ALU]────────────┐
          [RegFile]                      ├→[EX/MEM]→[DataMem]→[WB MUX]→ RegFile
          [ImmGen]    →[FPU 6단]··7클럭··→[shadow]─┘
             ↑ forwarding(정수+FP) / stall·flush(hazard) 가 파이프라인 전체를 감쌈
```

- **정수 연산**: EX에서 1클럭에 끝남.
- **FP 연산**: EX에서 FPU(내부 6단)로 진입 → 7클럭 뒤 결과가 나옴 → **shadow register**가 그 결과를
  파이프라인이 기대하는 클럭에 맞춰 **EX/MEM 파이프라인 레지스터로** 되돌려줌 → 이후 정수 결과와 똑같이
  MEM·WB를 타고 내려가 라이트백됨 (WB로 바로 가는 게 아니라 EX/MEM 경계로 합류).
- **정수 레지스터 파일과 FP 레지스터 파일은 독립** — 포워딩·라이트백 경로도 분리.

---

## 3. 모듈별 상세

### 3.1 FPU 서브시스템 (가장 큰 차별점)

#### `FPU.v` — FPU 최상위 (6단 파이프라인)
두 오퍼랜드를 `{sign, exponent, fraction}`으로 unpack하고, **FADD_core와 FMUL_core를 병렬로** 6단
파이프에 태운 뒤, 마지막 단에서 `op`로 결과를 고릅니다. 반올림 모드(`rm`)와 op는 데이터와 같은 속도로
파이프라인을 타고 내려가 마지막 단에 함께 도착합니다.

```verilog
FADD_core u_FADD_core(.clk, .reset, .s1_en, .s1_op(s1_op[0]),
                      .s1_SIGN_A, .s1_EXPO_A, .s1_FRAC_A, ...,
                      .s6_ADD_out, .s6_OF(s6_OF_ADD), .s6_UF(s6_UF_ADD), .s6_rm);

FMUL_core u_FMUL_core(.clk, .reset, .s1_en, ...,
                      .s6_MUL_out, .s6_OF(s6_OF_MUL), .s6_UF(s6_UF_MUL));

MUX s6_u_mux(.ADD_out, .MUL_out, .op(s6_op),
             .OF_ADD, .UF_ADD, .OF_MUL, .UF_MUL,
             .Final_out, .OF, .UF, .ZF, .sign);   // 오버플로→Inf, 언더플로→0 여기서 해결
```

#### `FADD_core.v` — 6단 부동소수점 덧셈기
세 갈래(FRAC 가수 / EXPO 지수 / SIGN 부호)가 나란히 6단을 통과합니다:

| 단 | 하는 일 | 관련 하위 모듈 |
|---|---|---|
| **S1** | 지수 차 계산, 크기 비교 | `EXPO_SUB`, `comparator` |
| **S2** | 작은 쪽 가수를 지수차만큼 우시프트(정렬), 뺄셈이면 조건부 반전 | `barrel_shifter`, `Cond_Inverter`, `Mode_Detector` |
| **S3** | `A+B`와 `B+A`를 CLA로 더하고 음수 안 나오는 쪽 선택 (A−A=0 깔끔 처리) | `CLA`, `Magnitude_Restoration` |
| **S4** | 선행 1 찾아 정규화 방향·양 결정 | `Normalization_Controller`, `LZD` |
| **S5** | 가수 정규화 시프트 + 지수 보정 | `barrel_shifter`, `EXPO_CAL` |
| **S6** | 반올림 + 예외(오버플로→Inf, 언더플로→0) | `Rounding`, `Exception_Handler_ADD` |

> **모듈을 잘게 쪼갠 덕분에** overflow가 NaN을 뱉는 버그(E24 계열)가 났을 때 "S6 Exception_Handler"로
> 딱 좁힐 수 있었습니다.

#### `FMUL_core.v` — 6단 부동소수점 곱셈기
가수는 곱셈기(`Multiplier`), 지수는 덧셈 후 바이어스 보정(`MUL_EXPO`, `MUL_EXPO_ADD`), 부호는 XOR
(`MUL_SIGN`), 이후 정규화(`Normalization_MUL`) → 반올림 → 예외(`Exception_Handler`).

#### FPU 공용 / 하위 모듈 (역할 요약)
- `FPU_unpack` — 32비트를 sign/expo/frac로 분해 (FPU_en=0이면 0)
- `FPU_Control` — op/rm 디코드
- `barrel_shifter` — 파라미터화 배럴 시프터 (정렬·정규화 양쪽에서 재사용)
- `LZD` — Leading-Zero Detector (정규화 시프트 양 계산)
- `CLA` — Carry-Lookahead Adder (가수 덧셈)
- `EXPO_SUB`/`EXPO_CAL`/`EXPO_MUX` — 지수 차·보정·선택
- `Rounding` — round-to-nearest, 자리올림 발생 여부(`count`) 리턴
- `Exception_Handler(_ADD)` — OF면 가수 0으로 클리어(→Inf), UF면 0

### 3.2 정수 데이터패스

- **`Main_Decoder.v`** — opcode로 제어신호(RegWrite/MemWrite/ALUsrc/…) + `is_*` 플래그 생성.
  `always @(*)` 맨 위에서 모든 신호를 기본값으로 초기화해 래치 방지. R/I/S/B/J + FLW/FSW/FPU 지원.
- **`ALU.v`** — `calculate_group`(가감산·부호·ZF), `logical_group`(AND/OR/XOR), `shift_group`(SLL/SRL/SRA)를
  병렬로 두고 `ALU_MUX`가 `ALU_Control`로 선택.
- **`ALU_Control.v`** — ALUOp + funct3 + funct7[30]으로 8종 연산 디코드.
- **`Register_file.v`** — 정수 레지스터 파일. **write-first bypass**(같은 클럭 write→read 시 새 값 반환)로
  distance-3 해저드 해결(E24).
- **`Data_Memory.v`** — LW/SW용 RAM.
- **`ImmGen.v`** — I/S/B/J + FLW/FSW immediate 조립. B/J타입 스크램블 + LSB `1'b0`(×2) 처리.
- **`Instruction_Memory.v`** — `mem[0:127]` + `pc[8:2]` (128칸; 긴 프로그램 wrap 방지).

### 3.3 파이프라인 & PC

- **`Pipeline_CPU.v`** — 최상위. ~80개 하위 모듈을 5단으로 배선. IF(PC/IM), ID(Decoder/RegFile/ImmGen),
  EX(ALU/FPU/shadow/포워딩 MUX), MEM(DataMem), WB(라이트백 MUX) + Hazard·Forwarding 유닛.
- **`Pipe_reg_1clk(_control/_en).v`** — 스테이지 레지스터. `_control`은 stall(hold)·flush(clear) 지원.
- **`PC_reg` / `PC_Adder` / `PC_Target` / `PCSrc`** — PC 레지스터, +4, 분기 타겟, 분기 성립 판정.
- **`PC_MUX.v`** — 다음 PC 선택. **우선순위 `EX_PCSrc(분기) > EX_is_JALR > ID_PCSrc(JAL)`** (E27 수정).
- **`Early_Jump_Unit.v`** — JAL을 ID단계에서 조기 점프. **`is_JAL`일 때만** 발화(E02 수정).
- **`JALR_Jump_Unit.v`** — JALR 타겟 = rs1 + imm.

### 3.4 Hazard & Forwarding (파이프라인의 핵심)

- **`Forwarding_Unit.v`** — **정수/FP 포워딩을 분리**한 뒤 명령어 타입으로 합침:
  `CPU_Forwarding_Unit`(정수) + `FPU_Forwarding_Unit`(FP) + `Forwarding_Combine`(EX_is_FPU/FLW/FSW로 선택).
- **`CPU_Hazard.v`** — load-use stall, 분기/점프 flush. **redirect 시 PCWrite=1 강제**(E29).
- **`FPU_Hazard.v`** — FP in-flight stall. 소비자는 ID에 붙잡고(IF_ID_stall), 프로듀서는 흘려보냄(ID_EX_flush).
- **`FPU_Check.v`** — **FP in-flight 검출기.** 7층 시프트레지스터로 날아다니는 FP 목적지를 추적:

```verilog
assign Rd0_next = (EX_is_FPU) ? {EX_Rd,1'b1} : 6'b0;   // 지금 EX의 프로듀서 주입
// Rd[0]→Rd[6] 매 클럭 시프트;  FPU_Valid = Rd[6][0] (결과 준비 완료)
assign FPU_6clk = Rd[5][0];                            // 조합(E28): Valid보다 1클럭 먼저
if (ID_is_FPU) begin
    if (EX_is_FPU && EX_Rd==ID_Rs1) FPU_Left = 3'd7;   // 프로듀서가 아직 EX → 7클럭 대기
    for (x=0;x<7;x=x+1)
        if (Rd[x][0] && Rd[x][5:1]==ID_Rs1) FPU_Left = 6-x;   // 이미 in-flight → 남은 클럭
end
```

- **`FPU_shadow_reg.v`** — FPU 명령어일 때, **그 명령어의 제어신호를 붙잡아 뒀다가 7클럭 뒤 FPU
  결과값과 같은 클럭에 함께** EX/MEM으로 내보내는 모듈. FPU 관련 신호가 아니면 그냥 통과시킴.

### 3.5 MUX & 기타 (역할)
`port_MUX`(오퍼랜드 포워딩+store 데이터), `Result_MUX`/`CPU_MUX`/`FPU_MUX`(결과 선택), `ALU_A/B_MUX`,
`FPU_common/MUX`(FPU 결과·플래그 병합) — 데이터패스 곳곳의 선택 로직.

---

## 4. 검증 방법론 — 독립 골든모델

FP 산술과 긴 분기 프로그램은 손으로 기대값을 못 구합니다. 그래서 **파이썬 ISS**(Instruction Set
Simulator)를 만들어, ISA 스펙대로 명령어를 순차 실행하고 최종 상태를 `check()` 줄로 출력합니다.
DUT(파이프라인 CPU)가 같은 프로그램을 돌려 대조 → 다르면 DUT 버그. 기대값이 **DUT가 아니라 스펙에서**
나오는 게 검증의 핵심입니다.

| 테스트 | 초점 |
|---|---|
| 01–03 | 정수 ALU, 메모리+포워딩, 분기+뒤로뛰는 루프 |
| 04 | FPU 통합, FP in-flight 해저드, FSW→FLW 왕복, 오버플로→Inf |
| 05 | jal/jalr + 정수·FP 혼합 + 서브루틴 |
| 06 | 전 명령어 + 중첩 jalr + 제어흐름×FP스톨 (하드코어) |
| 07 | **MEGA** — 120개 명령어, 전 케이스 한 프로그램 |

MEGA(120개)는 **첫 실행에 all-pass** — 정수 30개 + 실수 30개 레지스터가 골든과 비트단위 일치.

---

## 5. ⭐ 오류 발생 & 수정 — 전 과정

**각 버그의 증상 → 파형 → 원인 → 수정 → 교훈**을 기록했습니다.
(전체 원본은 [`../error_log.md`](../error_log.md).)

### 5.1 초기 — 명령어 메모리 · 분기 (E01~E07)
- **E01 · program.txt 안 읽힘** — `$readmemh` 경로 문제(F_file 폴더 꼬임). → 경로 정리.
- **E02 · Early Jump 항상 점프** — `assign PCSrc=(Early_Target)?1:0`이 항상 참. → `if(is_JAL)`로 게이팅.
- **E03 · BEQ 점프 위치 오류** — PC_MUX가 ID점프/EX분기 구분 못 함. → `ID_PCSrc→Early_Target`,
  `EX_PCSrc→Target` 분리 + PCSrc를 4종 분기로 확장.
- **E04 · B-type imm ×2 오류** — `inst[31]` 중복 + LSB `1'b0` 누락. → LSB `1'b0` 추가, 중복 제거.
- **E05 · JAL 미수행** — E02+E04 겹침. → 둘 다 수정.
- **E07 · BEQ 밀림 (오류 아님)** — IF단계 PC와 ID단계 명령어를 같이 찍어서 한 칸 어긋나 보인 것. 정상.
  → **교훈: 파형 신호가 어느 스테이지 것인지 확인.**

### 5.2 포워딩 (self-TB로 잡음, E08·E16~E23)
파형이 아니라 **직접 짠 self-checking 테스트벤치**(독립 ref_model + 랜덤)로 잡은 버그들.
- **E16 · 미포워딩 오퍼랜드 래치 + MEM/WB 배타선택** — case에서 한쪽만 대입해 래치 추론 + MEM 브랜치에
  들어가면 WB를 안 봄. → **오퍼랜드별 독립 구조**로 재작성(port_MUX).
- **E17 · B블록 MEM 조건 오타(10 vs 11)** — A블록 복붙하며 `10`을 `11`로 안 고침. → 수정, FAIL 0%.
- **E18 · JALR rs1 포워딩 누락** — DUT·ref_model 둘 다 "JALR이면 포워딩 무시"로 짜여 **사이좋게 통과**.
  → **교훈: 공유된 스펙 오해는 테스트의 사각지대. ref는 스펙에서 독립적으로 뽑아야.**
- **E19~E23** — FP 오퍼랜드·store 데이터 통합 중 5종(폭 누락, FSW 소스 오류 등).

### 5.3 FP in-flight 해저드 saga (OPEN-6) — 4버그 겹침
`fadd f9 → fsub f10`처럼 **바로 앞 FP 결과를 쓰는** 케이스. 하나처럼 보였지만 버그 4개가 겹쳐 있었음:
1. **검출 지각** — for문이 시프트레지스터만 보고 지금 EX의 프로듀서(`EX_Rd`)를 안 봄 → back-to-back 미검출.
   → EX_Rd 조합 비교 추가.
2. **재주입 데드락** — FP 스톨이 EX를 freeze → 프로듀서가 매 클럭 재주입 → `FPU_6clk=1` 영구 스톨.
   → `ID_EX_stall`→`ID_EX_flush`(버블).
3. **countdown 추락** — Rs1 for문 부등호 `<=`(거꾸로) → FPU_Left가 111 한 클럭 뒤 000.
   → `>`로 수정, 카운트 `6-x` 통일.
4. **FSW store 실패** — FSW 분기에도 EX_Rd 검출 누락 → fsw가 f10 준비 전 EX 진입 후 flush에 지워짐.
   → FSW 분기에도 EX_Rd 검출 추가.
- **교훈: in-flight FP 명령어 하나엔 검출·카운트·주입·스톨 4곳을 같이 맞춰야.**

### 5.4 통합테스트 06~07에서 잡은 타이밍 충돌 버그 (E26~E29)
**두 기능이 시간축에서 겹칠 때** 터지는, 단위 테스트로는 안 잡히는 버그들. (하드코어 통합테스트의 진가.)

- **E26 · 명령어 메모리 오버플로** — 61개 프로그램에서 PC≥0x80이 wrap → PC=0x88인데 0x08 명령어.
  → `mem[0:31]`+`pc[6:2]` → `mem[0:63/127]`+`pc[7:2 / 8:2]`.
- **E27 · 분기 그림자 JAL 우선순위** — taken 분기(EX)인데, 그림자에 speculative fetch된 JAL(loop)이
  ID에서 Early_Jump를 쏴서 분기를 덮음. 우선순위 `ID_PCSrc > EX_PCSrc`. → **EX 우선**으로 뒤집음.
  파형: `CPU_JAL_retaddr_wrong.PNG`
- **E28 · FPU_6clk 1클럭 지각** — `FPU_6clk <= Rd[5][0]`(등록)이 `FPU_Valid`(조합)와 동시에 떠서 미리
  자리를 못 비움 → FP 결과가 정수 addi 라이트백을 덮음. → `assign FPU_6clk`(조합화).
- **E29 · JALR redirect가 FP스톨에 증발** ⭐ — 중첩 서브루틴의 jalr이 복귀할 때 마침 FP 결과가 배수되며
  `PCWrite=0`. jalr이 타겟(`final_next_pc=0xDC`)을 정확히 계산해도 **PC가 안 실림** → 프로그램 끝을 지나
  **처음부터 재실행** → x19/x20/x22/x26/x27/f11/f12 **7개 FAIL이 이 재실행 하나에서** cascade.
  → **redirect 시 PCWrite=1 강제** (redirect는 뒤 명령어 어차피 flush하니 스톨 무의미).
  파형: `CPU_T06_7_JALR_PCwrite0_ROOT.PNG`, `CPU_T06_5_reexec_PCwrap_0x100.PNG`

### 5.5 버그들에서 일반화한 파이프라인 타이밍 원칙 3가지
여러 버그를 관통하는 공통 원리를 뽑아냈고, 이후로는 같은 부류의 버그를 **설계 단계에서 미리 피할 수**
있었습니다.
1. **등록(`<=`/posedge) 신호는 조합 신호보다 한 클럭 늦게 도착한다** — 지연을 감안해 타이밍 정렬
   (OPEN-1 FPU_Valid, E28 FPU_6clk).
2. **PC 우선순위는 오래된 명령어(EX)가 어린 명령어(ID)를 이겨야 한다** — E27, E29.
3. **제어 redirect는 스톨을 이긴다** (redirect 시 PCWrite 강제) — E29.

---

## 6. 배운 것 & 결론

- **하드코어 통합 테스트만이 "두 기능 겹치는 타이밍 버그"를 잡는다.** JALR×FP스톨, 분기그림자×JAL,
  정수×FP 라이트백 — 각 기능 개별 테스트로는 절대 안 나옴.
- **증상 하나가 뿌리 하나일 때가 많다.** 7개 FAIL이 "재실행 하나"에서 나온 cascade였음. PC가 프로그램
  밖으로 나가는지부터 봐야.
- **ISS 골든모델이 전부.** FP는 손계산 불가, 복잡 분기는 경로 추적 불가. DUT와 독립적으로(스펙에서)
  기대값을 만드는 게 검증의 핵심 — 공유된 오해(E18)까지 피하려면 ref는 스펙에서.
- **모듈을 잘게 쪼개면 버그가 어디 있는지 좁혀진다** (FADD 6단, FPU 예외 처리).

**최종: RV32I + F(single) 5단 파이프라인 CPU를 80+ 모듈로 bottom-up 설계하고, 독립 ISS 골든모델로
전 영역(연산·논리·시프트·메모리·분기·루프·서브루틴·포워딩·load-use·FP 7clk in-flight·FSW왕복·
IEEE예외·제어흐름×FP스톨)을 대조 검증 완료.**
