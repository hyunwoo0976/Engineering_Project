# Forwarding Unit 설계 메모

RISC-V 5-stage 파이프라인 + FPU의 **데이터 포워딩** 유닛 정리.
정수 레지스터 파일과 FP 레지스터 파일 **두 개**를 다루는 것이 이 설계의 핵심 난점.

---

## 1. 포워딩이란 (한 줄 정의)

> 소비자(EX)가 읽을 값을, **레지스터 파일 대신 파이프라인 중간 단계에서 가로채 오는 것**

- 레지스터 파일에서 읽으면 **아직 안 써진 옛값**이 나옴
- 파이프라인 위치가 곧 최신순: **EX → MEM → WB** (뒤로 갈수록 오래된 명령어)
- 따라서 우선순위는 **MEM > WB**

포워딩은 **정확성이 아니라 성능**을 위한 것 — stall만 해도 결과는 맞지만 사이클을 버림.
단, **다중 사이클 FPU**에서는 stall 해제 타이밍상 포워딩이 **필수**가 됨 (§7 참조).

---

## 2. 모듈 구조

```
Forwarding_Unit  (top)
├── CPU_Forwarding_Unit    ← 정수 전용
├── FPU_Forwarding_Unit    ← FP + 정수 혼합 (FLW/FSW 포함)
└── Forwarding_Combine     ← 둘 중 하나 선택 (MUX)
```

`Hazard_Unit`(CPU_Hazard / FPU_Hazard / Hazard_Combine)과 **같은 계층 패턴**으로 맞춤.

| 파일 | 경로 |
|---|---|
| Forwarding_Unit.v | `src_mini_CPU/Forwarding/` |
| CPU_Forwarding_Unit.v | `src_mini_CPU/Forwarding/` |
| FPU_Forwarding_Unit.v | `src_mini_CPU/Forwarding/` |
| Forwarding_Combine.v | `src_mini_CPU/Forwarding/` |
| Testbench.v | `tb/` |
| F_file.f | `F_file/` |

---

## 3. 신호 체계

### 3-1. 출력 인코딩 (2비트)

| 코드 | 의미 |
|---|---|
| `2'b00` | 포워딩 없음 (레지스터 파일 값 사용) |
| `2'b01` | Rs1·Rs2 **둘 다** 이 단계에서 |
| `2'b10` | **Rs1**만 |
| `2'b11` | **Rs2**만 |

`MEMtoEX_forward`, `WBtoEX_forward` 각각 이 인코딩을 씀.

### 3-2. 소비자 신호 — `uses_*` (이 설계의 핵심)

**"EX 명령어가 그 오퍼랜드를 실제로 읽는가"**

| 신호 | 뜻 |
|---|---|
| `EX_uses_Rs1` / `EX_uses_Rs2` | **정수** 레지스터에서 읽음 |
| `EX_uses_FRs1` / `EX_uses_FRs2` | **FP** 레지스터에서 읽음 |

명령어별 값:

| 명령어 | uses_Rs1 | uses_Rs2 | uses_FRs1 | uses_FRs2 |
|---|---|---|---|---|
| R-type / SW / Branch | 1 | 1 | 0 | 0 |
| I-ALU(addi) / LW / JALR | 1 | 0 | 0 | 0 |
| **JAL** | **0** | **0** | 0 | 0 |
| **FLW** | **1**(주소) | 0 | 0 | 0 |
| **FSW** | **1**(주소) | 0 | 0 | **1**(데이터) |
| FP 산술(FADD/FSUB/FMUL) | 0 | 0 | 1 | 1 |
| FP 비교(FEQ/FLT/FLE)※ | 0 | 0 | 1 | 1 |

※ FP 비교는 현재 구현 범위에서 제외 (§9 참조)

**왜 `RegWrite`가 아니라 `uses`인가**
기존엔 소비자를 `EX_RegWrite`/`EX_MemRead`/`EX_MemWrite`로 구분했는데,
**분기(branch)는 `RegWrite=0`인데 rs1·rs2를 읽으므로 놓쳤음.**
포워딩은 "레지스터를 **쓰는가**"가 아니라 "**읽는가**"로 판단해야 함.
→ `uses` 신호 도입으로 명령어 타입별 분기가 전부 사라짐.

### 3-3. 생산자 신호

| 신호 | 뜻 |
|---|---|
| `MEM_RegWrite` / `WB_RegWrite` | 그 단계 명령어가 **정수** 레지스터에 씀 |
| `MEM_FRegWrite` / `WB_FRegWrite` | **FP** 레지스터에 씀 |

한 명령어는 **한 파일에만** 쓰므로 두 신호가 동시에 1이 되지 않음.

### 3-4. 매치 조건

> **같은 파일 + 같은 번호 = 그 값이 곧 소비자가 원하는 값**

유효한 조합은 2가지뿐:

| 생산자 | 소비자 | 유효 |
|---|---|---|
| `RegWrite`(정수) | `uses_Rs1`(정수) | O |
| `FRegWrite`(FP) | `uses_FRs1`(FP) | O |
| `RegWrite`(정수) | `uses_FRs1`(FP) | **X** |
| `FRegWrite`(FP) | `uses_Rs1`(정수) | **X** |

x5와 f5는 **번호만 같지 완전히 다른 레지스터**이기 때문.

### 3-5. x0 / f0 처리 (중요)

| | 게이팅 | 이유 |
|---|---|---|
| 정수 x0 | **`Rd != 0` 필요** | x0는 항상 0, 쓰기가 무시됨 |
| FP f0 | **게이팅 없음** | f0는 일반 레지스터, 값을 담음 |

→ `FPU_Forwarding_Unit`에서 `MEM_nz`를 **정수 항에만** AND. FP 항에 붙이면 f0 포워딩이 막힘.

---

## 4. 각 모듈 동작

### 4-1. CPU_Forwarding_Unit (정수 전용)

**wire 6개**로 판정:
```
MEMtoEX_fwd1 = MEM_RegWrite && (MEM_Rd==EX_Rs1) && MEM_Rd_nz && EX_uses_Rs1
MEMtoEX_fwd2 = ... EX_Rs2 ... EX_uses_Rs2
MEMtoEX_both_fwd = fwd1 && fwd2
(WB 버전 3개 동일)
```

**always는 독립된 두 체인:**

| 체인 | 로직 |
|---|---|
| MEM 체인 | `both → 01` / `fwd1 → 10` / `fwd2 → 11` |
| WB 체인 | 각 조건에 **`!MEM_fwdN`** 배제를 AND |

- MEM 체인은 WB를 **전혀 보지 않음** → MEM 우선이 자동 성립
- WB 체인의 배제는 **오퍼랜드별** → "MEM이 Rs1, WB가 Rs2" 이중 포워딩 가능
- 맨 위 `{MEMtoEX_forward, WBtoEX_forward} = 4'b0000;` **기본값 필수** (래치 방지)

### 4-2. FPU_Forwarding_Unit (FP + 정수 혼합)

구조는 CPU와 **완전히 동일**. 차이는 wire 정의뿐:

```
MEM_fwd_Rs1 = ( (MEM_RegWrite  && EX_uses_Rs1 && MEM_nz)   // 정수 항
             || (MEM_FRegWrite && EX_uses_FRs1) )          // FP 항
             && (MEM_Rd == EX_Rs1)
```

**정수 항과 FP 항을 OR로 합친 것이 핵심.**
`uses_Rs1`과 `uses_FRs1`은 배타적이라 충돌하지 않음.

이 하나로 **정수 / FP 산술 / FLW / FSW가 전부 자동 커버**됨:

| 소비자 | 성립하는 항 |
|---|---|
| 정수 명령어 | 정수 항만 |
| FP 산술 | FP 항만 |
| FLW | Rs1 = 정수 항 (주소) |
| FSW | Rs1 = 정수 항(주소), Rs2 = FP 항(데이터) |

### 4-3. Forwarding_Combine

```
is_FPU_family = EX_is_FPU || EX_is_FLW || EX_is_FSW
MEMtoEX_forward = is_FPU_family ? FPU_결과 : CPU_결과
WBtoEX_forward  = is_FPU_family ? FPU_결과 : CPU_결과
```

명령어 종류로 두 유닛 중 하나를 고름.

> **참고**: FPU_Forwarding이 정수까지 처리하게 된 뒤로 CPU_Forwarding과 기능이 중복됨.
> FPU_Forwarding 하나로 전부 대체 가능 (정수 명령어면 `uses_FRs*=0`이라 FP 항이 죽어 동일 결과).
> 현재는 동작하므로 유지, 추후 단순화 여지 있음.

---

## 5. 핵심 설계 원리 (헤맸던 지점)

### 원리 1 — 명령어가 아니라 **오퍼랜드** 단위로 생각

포워딩 유닛은 **명령어 이름을 몰라도 된다.**
매 사이클 "지금 EX에 있는 소비자의 Rs1·Rs2가 각각 어디서 오나?" 두 질문만 답하면 끝.

같은 FLW라도 시점에 따라 역할이 바뀌지만, 유닛 입장에선 신호일 뿐:

| 시점 | 유닛이 보는 것 | 계산하는 질문 |
|---|---|---|
| flw가 EX (소비자) | `MEM_RegWrite=1, MEM_Rd=5` | "Rs1은 어디서?" |
| flw가 MEM (생산자) | `MEM_FRegWrite=1, MEM_Rd=1` | "Rs1은 어디서?" |

→ 두 사이클 모두 **같은 질문, 같은 계산**. "FLW"라는 단어가 조건에 안 나옴.

### 원리 2 — 조합을 나열하지 말고 **불변식**을 찾기

케이스가 3개 이상 나열되면 멈추고 물을 것:
> "이 케이스들이 공통으로 답하려는 질문이 뭐지?"

여기선 **"이 오퍼랜드는 어디서 오나?"** 하나.
나열식으로 접근하면 12가지, 26가지로 폭발하고 반드시 누락이 생김.

### 원리 3 — MEM 우선은 "코드에 안 쓰는" 것으로 달성

MEM 체인에 WB 신호를 **넣지 않으면** 자동으로 MEM이 이김.
WB 체인에만 `!MEM_fwdN`을 다는 것으로 충분.

---

## 6. 오류 및 수정 기록

### CPU_Forwarding_Unit

| # | 증상 | 원인 | 수정 |
|---|---|---|---|
| C-1 | 이중 포워딩 실패 (Rs1←MEM, Rs2←WB) | 단일 `case(1'b1)`이 MEMtoEX/WBtoEX를 **배타적**으로 취급 → 하나만 발화 | MEM 체인 / WB 체인을 **독립 if 두 개**로 분리 |
| C-2 | store 포워딩 우선순위 역전 (옛 WB값 저장) | WB 분기가 MEM(store) 분기보다 **먼저** 검사됨 | 오퍼랜드별 `!MEM_fwdN` 배제로 재구성 |
| C-3 | Rs2 매치인데 Rs1 코드 출력 | `2'b11` 자리에 `2'b10` 복붙 | 코드 수정 |
| C-4 | `both`(01)가 절대 안 나옴 | `case(1'b1)`에서 both 조건이 **맨 뒤** → Rs1이 먼저 걸려 도달 불가 | both를 **맨 위**로 |
| C-5 | 시뮬 결과가 들쭉날쭉 | **옛 always 블록이 잔존**, 같은 reg를 두 always에서 대입 → 다중 드라이버 레이스 | 옛 블록 삭제 |
| C-6 | MEM에 매치가 없어도 WB 포워딩 누락 | WB 블록을 `else if`로 달아 MEM 진입 시 **평가조차 안 됨** | 독립 `if`로 |
| C-7 | 분기(branch) 포워딩 누락 | 소비자 게이팅이 `EX_RegWrite` → branch는 RegWrite=0 | **`uses_Rs1/Rs2` 신호 도입** |

### FPU_Forwarding_Unit

| # | 증상 | 원인 | 수정 |
|---|---|---|---|
| F-1 | 코드가 항상 0 또는 1 | `output reg MEMtoEX_forward` — **폭 `[1:0]` 누락** → 2비트 값이 1비트로 잘림 | `output reg [1:0]` |
| F-2 | 조건 해제 후에도 이전 값 유지 | 맨 위 **기본값 대입 없음** → 래치 추론 | `{MEMtoEX, WBtoEX} = 4'b0000;` 추가 |
| F-3 | FLW 주소 포워딩 안 됨 | 정수 주소인데 **`MEM_FRegWrite`로 게이팅** | `MEM_RegWrite`로 |
| F-4 | WB 조건인데 MEM 출력이 바뀜 | `WBtoEX` 자리에 `MEMtoEX` 대입 | 신호 수정 |
| F-5 | FLW 주소가 Rs2 코드로 출력 | Rs1인데 `2'b11` 대입 | `2'b10`으로 |
| F-6 | 케이스 누락·덮어쓰기 | FSW/FLW/산술을 **명령어별 블록 4개**로 나눠 순차 대입 → 뒤 블록이 앞을 덮음 | 정수 항·FP 항을 **wire에서 OR로 병합**, 블록 2개로 |
| F-7 | FLW 단독 케이스가 0 출력 | 정수 단독 포워딩 분기 자체가 없었음 | F-6 재구조화로 해소 |
| F-8 | FLW 주소가 x0인데 포워딩됨 | **x0 게이팅 없음** | `MEM_nz`를 **정수 항에만** AND (FP 항엔 금지) |

### Forwarding_Combine / 통합

| # | 증상 | 원인 | 수정 |
|---|---|---|---|
| B-1 | FLW 주소 포워딩 전멸 | Combine이 FLW를 FPU 경로로 보내는데, 당시 FPU 유닛은 FP 오퍼랜드만 봄 | **FPU_Forwarding이 정수 신호도 받도록** 확장 |
| B-2 | FSW의 주소/데이터 중 하나만 살아남음 | 위와 동일 (명령어 단위 선택의 한계) | 동일 |
| B-3 | `Unknown module type: Forwarding_Unit` | Pipeline_CPU가 옛 모듈명을 인스턴스화 | 새 계층으로 교체 필요 (**미완**, §8) |

### Testbench

| # | 증상 | 원인 | 수정 |
|---|---|---|---|
| T-1 | 전 케이스 FAIL | DUT의 `EX_uses_*` 포트를 **연결 안 함** → floating(z) | 포트 연결 |
| T-2 | 기대값과 항상 불일치 | 출력 wire를 **1비트로 선언** (DUT는 `[1:0]`) | `wire [1:0]` |
| T-3 | 카운터가 `x`로 출력 | `reg PASS, FAIL;` — **1비트 + 초기화 누락** (`x+1=x`) | `integer` + `=0` 초기화 |
| T-4 | 컴파일 에러 | `exp`를 **function 내부**에 선언하고 밖에서 사용 | 모듈 레벨로 이동 |
| T-5 | f0 케이스 오판정 | 참조 모델 `hit()`에서 `rd!=0`을 **전체에 AND** → DUT와 규칙 불일치 | 정수 항에만 AND |
| T-6 | 간헐적 오판정 | `s2 = NONE;` **초기화 누락** | 초기화 추가 |
| T-7 | FAIL 폭주 | 랜덤에 **제약 없음** → "정수 명령어인데 `uses_FRs1=1`" 같은 불가능 조합 생성 | 명령어 종류별 `case` 제약 |
| T-8 | 인자 없는 function 에러 | `-g2005` 기본값에서는 function에 input이 최소 1개 필요 | **`-g2012`** 옵션 사용 |

---

## 7. FPU 포워딩이 왜 필수인가 (타이밍)

FP 명령어가 사이클 T에 EX에 있었다면:

| 사이클 | 상태 |
|---|---|
| T+1 ~ T+7 | FPU 내부 (7clk) → `FPU_Left != 0` → **소비자 stall** |
| T+8 | 추적기에서 빠짐 → **stall 해제**, `FPU_Valid=1` |
| **T+9** | **소비자 EX 진입 / 생산자 MEM 도착** |
| T+10 | 생산자 WB |
| T+11 | 레지스터 파일에서 읽힘 |

소비자가 EX에 들어오는 **T+9에 생산자는 MEM에 있음** → **MEM→EX 포워딩이 정확히 필요**.
포워딩이 없으면 소비자가 레지스터 파일의 **옛값**을 읽음 (성능 문제가 아니라 **오동작**).

**역할 분담**
- FPU 내부 7clk 구간 → `FPU_Check`의 Rd 시프트 레지스터가 **stall**로 담당
- FPU를 빠져나온 뒤 → **포워딩**이 인수인계 (MEM_Rd/WB_Rd로 판정)

`FPU_shadow_reg`가 7clk 동안 Rd·제어신호를 붙들었다가 결과와 함께 내보내므로,
FP 명령어도 MEM 이후로는 **평범한 파이프라인 명령어**와 동일하게 취급 가능.

---

## 8. 검증 결과

| 대상 | 방식 | 결과 |
|---|---|---|
| CPU_Forwarding_Unit | directed 14케이스 | **14/14 PASS** |
| FPU_Forwarding_Unit | directed 13케이스 | **13/13 PASS** |
| Forwarding_Unit (top) | **constrained random 1000회 + 참조 모델** | **1000/1000 PASS** |

### 랜덤 커버리지 측정 (주소 범위 `% 4` 기준)

| 결과 분포 | 횟수 |
|---|---|
| 포워딩 없음 (`0000`) | 801 |
| MEM만 | 95 |
| WB만 | 99 |
| **이중 포워딩** | **5** |
| **both 코드(`01`)** | **7** |

> **"1000번 PASS"가 커버리지를 보장하지 않음.**
> 80%는 주소가 안 맞아 아무것도 검증하지 않음. 이중 포워딩은 5회뿐.
> 주소 범위를 `% 8 → % 4`로 좁혀 포워딩 발생을 **105 → 199회**로 2배 늘렸으나,
> 희귀 케이스는 **directed로 못 박아야** 함.

### 테스트벤치 구성 (`tb/Testbench.v`)

- `clr` task — 매 반복 초기화
- `hit()` function — "이 스테이지가 이 오퍼랜드를 공급하나" 판정
- `ref_model()` function — **2단계 참조 모델**
  1. 오퍼랜드별 출처 결정 (`NONE` / `FROM_MEM` / `FROM_WB`, MEM 우선)
  2. 출처 → 2비트 코드 인코딩
- DUT는 코드를 직접 결정, 모델은 출처를 먼저 정함 → **구조가 달라 같은 실수를 반복할 확률이 낮음**

### 실행

```
iverilog -g2012 -Wall -s Testbench -o test.out -f ./verilog/Project10_mini_CPU/F_file/F_file.f
vvp test.out
```
※ 프로젝트 루트에서 실행 (F_file.f 경로가 `./verilog/...` 상대경로)
※ `-g2012` 필수 (인자 없는 function)
※ 컴파일 실패 시 옛 `test.out`이 남아 **예전 코드가 실행**되므로, 성공 여부 확인 후 실행할 것

---

## 9. 남은 작업

### 포워딩 자체
- [ ] **directed 케이스 추가** — 이중 포워딩 / both 코드 / x0 금지 / f0 허용 / 경로 선택 4종
- [ ] TB에 최종 요약 출력 (`PASS=%0d FAIL=%0d`)
- [ ] CPU_Forwarding + Combine 단순화 검토 (FPU_Forwarding이 이미 전부 커버)

### 통합 (Pipeline_CPU)
- [ ] line 128의 옛 `Forwarding_Unit` 인스턴스를 새 계층으로 교체
- [ ] `EX_uses_*`, `MEM_FRegWrite`, `WB_FRegWrite` 배선
- [ ] **ALU_port_MUX를 오퍼랜드별 독립 구조로 재작성**
      (현재 단일 if/else-if라 이중 포워딩이 MUX에서 죽음, MEM Rs2를 A포트로 보내는 버그,
       포워딩 시 ALUsrc/is_JALR 무시 등 3건)
- [ ] **FP 오퍼랜드 MUX 신설** (`EX_F_A`/`EX_F_B`용) — 값 소스는 `MEM_FPU_Result` / `WB_F_data`
- [ ] **다운스트림 MUX는 각자 자기 `uses`로 게이팅** — 같은 코드를 두 MUX가 보되 자기 오퍼랜드만 적용

### 디코더
- [ ] 정수 opcode 7종에 `uses_Rs1/Rs2` 추가
- [ ] FP opcode 3종에 `uses_Rs1/Rs2` + `uses_FRs1/FRs2` 추가
- [ ] **FLW/FSW에 `ALUsrc=1`** ← 현재 주소가 `rs1+rs2`로 계산되는 버그
- [ ] `FPU_Control.v` line 28 — **FMUL funct5가 `00100`으로 오기, `00010`이 맞음**
- [ ] `FPU_Control.v` line 31 — 비교(`10100`)가 SUB와 같은 `2'b01` → 비교 하드웨어 없음.
      **비교는 구현 범위에서 제외하고 `default`(error)로 보낼 것**

### 해저드 (연관)
- [ ] `FPU_Check.v` line 39가 `if(ID_is_FPU)` — **FSW가 f[rs2]를 읽는데 검출에서 빠짐**

---

## 10. 교훈

1. **폭을 안 쓰면 무조건 1비트** — wire/reg/output 모두. 값을 담는 신호는 폭을 항상 의식할 것 (F-1, T-2, T-3)
2. **조합 always는 맨 위에 기본값 대입** — 없으면 래치 (F-2, C-4)
3. **`z`는 미연결, `x`는 충돌/미초기화** — 파형에서 색이 뜨면 논리가 아니라 배선을 의심
4. **리팩터 시 옛 블록을 반드시 삭제** — 같은 reg를 두 always에서 대입하면 레이스 (C-5)
5. **테스트 기대값은 사양에서 유도** — DUT를 보고 베끼면 버그까지 복사되어 항상 PASS
6. **랜덤에는 제약이 필요** — 존재할 수 없는 입력 조합은 가짜 FAIL을 만듦 (T-7)
7. **커버리지를 측정하기 전엔 "몇 번 돌렸다"는 의미 없음**
