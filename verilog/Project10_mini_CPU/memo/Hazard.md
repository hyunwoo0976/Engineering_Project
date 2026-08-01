# Hazard Unit 설계 메모

RISC-V 5-stage 파이프라인 + 다중 사이클 FPU의 **해저드 검출 / stall·flush 제어** 정리.

관련 문서: [Forwarding.md](Forwarding.md) — 포워딩은 해저드의 짝이므로 같이 볼 것.

---

## 1. 해저드란 (한 줄 정의)

> 파이프라인에서 **다음 명령어를 그대로 진행시키면 틀린 결과가 나오는 상황**

대응 수단은 두 가지:

| 수단 | 언제 | 비용 |
|---|---|---|
| **Forwarding** | 값이 파이프라인 어딘가에 **이미 있을 때** | 없음 (MUX 한 단) |
| **Stall / Flush** | 값이 **아직 없을 때**, 또는 잘못된 명령어를 취소해야 할 때 | 사이클 손실 |

**Forwarding = "값이 있으면 끌어온다", Hazard = "없으면 멈춘다".**
두 축이 다르므로 유닛도 분리되어 있음 (합치지 않는 이유).

---

## 2. 해저드 종류

| 종류 | 원인 | 이 설계의 대응 |
|---|---|---|
| **Data hazard** | 앞 명령어 결과를 뒤가 필요 | 대부분 Forwarding, load-use만 stall |
| **Control hazard** | 분기/점프로 잘못된 명령어를 이미 fetch함 | Flush |
| **Structural hazard** | 자원 충돌 (같은 파이프 레지스터를 두 명령어가 사용) | FPU 복귀 시 1클럭 버블 |

---

## 3. stall / flush 의 정확한 의미

파이프 레지스터([Pipe_reg_1clk_control.v](../src_mini_CPU/Register/Pipe_reg_1clk_control.v)) 기준:

```verilog
if(reset || flush)  Q <= 0;      // flush 우선
else if(!stall)     Q <= D;      // stall=1이면 홀드
```

| 신호 | 극성 | 효과 |
|---|---|---|
| `stall` | 1 = **홀드** | 레지스터가 D를 안 받고 이전 Q 유지 |
| `flush` | 1 = **클리어** | Q를 0으로 (버블 삽입) |
| `PCWrite` | 1 = **전진** | 0이면 PC 정지 |

**flush가 stall보다 우선**(같은 사이클에 둘 다 1이면 flush 승). 이 우선순위는 처음부터 유지됨.

### load-use에서 stall과 flush의 역할 분담 (중요)

`lw x5` 다음 `add x?, x5, x6` 상황:

| 신호 | 하는 일 |
|---|---|
| `IF_ID_stall = 1` | ID의 **소비자를 ID에 붙잡아 둠** (한 번 더 돌게 함) + IF도 대기 |
| `ID_EX_flush = 1` | EX로 **버블 삽입** (낡은 소비자 복사본이 EX에서 실행되는 것 방지) |
| `PCWrite = 0` | PC 정지 |

**핵심**: `ID_EX_stall`이 아니라 **`ID_EX_flush`**여야 함.
`stall`을 쓰면 생산자(lw)가 EX에 갇혀 MEM으로 못 나가고 → 데이터가 영영 안 나옴 → **데드락**.
`flush`는 "생산자는 보내고 그 자리에 버블"이므로 정상 동작.

---

## 4. 모듈 구조

```
Hazard_Unit  (top)
├── CPU_Hazard        ← 분기/점프 flush + 정수 load-use
├── FPU_Hazard        ← FPU 7clk stall + FLW load-use
│   └── FPU_Check     ← FPU 내부 in-flight 추적 (Rd 시프트 레지스터)
└── Hazard_Combine    ← 두 유닛 출력 병합
```

[Forwarding_Unit](Forwarding.md#2-모듈-구조)과 **동일한 계층 패턴**.

| 파일 | 경로 |
|---|---|
| Hazard_Unit.v / CPU_Hazard.v / FPU_Hazard.v / FPU_Check.v / Hazard_Combine.v | `src_mini_CPU/Hazard/` |

---

## 5. 각 모듈 동작

### 5-1. CPU_Hazard — 우선순위 체인

단일 `if / else if` 체인. **위쪽이 우선**.

| 순위 | 조건 | 동작 | 의미 |
|---|---|---|---|
| 1 | `ID_PCSrc` | `IF_ID_flush` | JAL (ID에서 조기 점프) — 뒤 1개만 취소 |
| 2 | `EX_PCSrc` | `IF_ID_flush` + `ID_EX_flush` | 분기 성립 — 뒤 2개 취소 |
| 3 | `EX_is_JALR` | `IF_ID_flush` + `ID_EX_flush` | JALR — 뒤 2개 취소 |
| 4 | load-use | `ID_EX_flush` + `IF_ID_stall` + `PCWrite=0` | 1클럭 stall |

**flush 개수 차이**: JAL은 ID에서 결정되므로 잘못 fetch된 게 1개, 분기·JALR은 EX에서 결정되므로 2개.

**load-use 조건**
```
EX_MemRead && ID_RegWrite && (EX_Rd != 0) && (EX_Rd == ID_Rs1 || EX_Rd == ID_Rs2)
```
- `EX_MemRead` — EX에 로드가 있음 (값이 MEM 끝에야 나옴)
- `EX_Rd != 0` — x0 예외
- 우선순위 체인 맨 아래 → 분기·점프가 있으면 그쪽이 이김 (어차피 취소될 명령어라 stall 불필요)

### 5-2. FPU_Check — in-flight 추적기

FPU 내부를 지나는 명령어의 **목적지 레지스터를 7단 시프트 레지스터로 추적**.

```
Rd[0] <= EX_is_FPU ? {EX_Rd, 1'b1} : 0     // [5:1]=Rd, [0]=valid
Rd[i+1] <= Rd[i]                            // 매 클럭 시프트
FPU_Valid <= Rd[6][0]                       // 마지막 단 통과 = 결과 나옴
FPU_6clk  <= Rd[5][0]                       // 한 단 앞 = 곧 나옴
```

**출력**

| 신호 | 뜻 |
|---|---|
| `FPU_Valid` | FPU 결과가 준비됨 (shadow_reg가 이걸로 제어신호를 내보냄) |
| `FPU_6clk` | 결과가 곧 나옴 → **구조적 해저드용 버블 준비** |
| `FPU_Left` | 소비자가 기다려야 할 남은 클럭 수 (`7-x`의 최댓값) |
| `Rs1`, `Rs2` | 어느 오퍼랜드가 걸렸는지 |

**`FPU_Left` 계산**: `Rd[0]~Rd[6]`를 훑어 `ID_Rs1`/`ID_Rs2`와 일치하는 항목을 찾고,
`7 - x` 중 **최댓값**을 취함 (여러 개 걸리면 가장 오래 걸리는 것 기준).

### 5-3. FPU_Hazard

```
if (FPU_6clk)                         → 무조건 1클럭 stall  (구조적 해저드)
else case(1'b1)
    FPU_Left != 0                     → stall (데이터 의존)
    FPU_Valid                         → 진행
    EX_is_FLW && 소비자 매치           → IF_ID_stall + ID_EX_flush (load-use)
```

**`FPU_6clk` 무조건 stall의 이유 (구조적 해저드)**
FP 명령어는 7클럭 뒤 `shadow_reg`를 통해 **EX/MEM 레지스터로 되돌아옴**.
그 사이 일반 명령어들이 계속 EX→MEM으로 흐르고 있으므로, 그대로 두면 **같은 사이클에 두 명령어가 EX/MEM에 쓰려는 충돌**이 발생.
→ 미리 1클럭 버블을 만들어 자리를 비워둠.

### 5-4. Hazard_Combine

```
IF_ID_stall = CPU | FPU        // 둘 중 하나라도 멈추라면 멈춤
ID_EX_stall = CPU | FPU
ID_EX_flush = CPU | FPU
PCWrite     = CPU & FPU        // 둘 다 허용해야 전진
```

stall/flush는 **OR**(보수적), PCWrite는 **AND**(보수적). 극성이 반대인 것에 주의.

---

## 6. FPU 타이밍 — stall과 포워딩의 인수인계

FP 명령어가 사이클 T에 EX에 있었다면:

| 사이클 | 상태 | 담당 |
|---|---|---|
| T+1 ~ T+7 | FPU 내부 (7clk) | `FPU_Left != 0` → **stall** |
| T+8 | 추적기에서 빠짐, `FPU_Valid=1` | **stall 해제** |
| **T+9** | 소비자 EX 진입 / **생산자 MEM 도착** | **포워딩** (MEM→EX) |
| T+10 | 생산자 WB | 포워딩 (WB→EX) |
| T+11 | 레지스터 파일 반영 | — |

**stall이 T+8에 풀리므로, 소비자가 EX에 왔을 때 생산자는 아직 MEM에 있음.**
→ 포워딩이 없으면 레지스터 파일의 **옛값**을 읽음 = 오동작.
→ **FPU 포워딩은 성능 최적화가 아니라 정확성에 필수**. (자세한 내용은 [Forwarding.md](Forwarding.md) §7)

**역할 분담 요약**

| 구간 | 담당 |
|---|---|
| FPU 내부 (계산 중) | FPU_Check → stall |
| FPU 밖 (MEM/WB) | Forwarding |

---

## 7. 현재 발견된 오류 (미수정)

### 🔴 컴파일 에러

| 위치 | 내용 |
|---|---|
| **Hazard_Unit.v line 31** | `.IS_is_FSW(ID_is_FSW)` — **오타**. 포트명은 `ID_is_FSW`. 컴파일 실패 + 해당 포트 floating |

### 🔴 논리 버그

| 위치 | 내용 |
|---|---|
| **FPU_Check.v line 57~64** | FSW 분기에 **`for` 루프가 없음**. `x`는 위쪽 `ID_is_FPU` 블록의 루프 변수라, FSW로 진입하면 이전 값(7) 또는 미초기화 상태. `Rd`는 `[0:6]`이므로 **`Rd[7]`은 범위 밖** → 결과가 `x`. **FSW 의존성 검출이 동작하지 않음.** 위 두 루프처럼 `for(x=0; x<7; x=x+1)`로 감싸야 함 |

### 🟡 설계 미비

| 위치 | 내용 |
|---|---|
| **FPU_Hazard.v line 17** | `FPU_6clk` 암시적 wire (선언 없음). `wire FPU_6clk;` 필요 |
| **FPU_Hazard.v line 43** | FLW load-use 조건이 `ID_is_FPU`만 검사 → **FLW→FSW 의존 누락** (`flw f1` 다음 `fsw f1`). `(ID_is_FPU \|\| ID_is_FSW)`여야 함 |
| **FPU_Hazard.v line 38~42** | `FPU_Valid` 분기가 FLW load-use(line 43)보다 **앞**에 있어, 둘이 동시 성립 시 FLW가 무시됨 |
| **CPU_Hazard.v line 28** | FLW도 `EX_MemRead=1`이므로 **정수 소비자와 가짜 매치**. FLW는 f[rd]에 쓰는데 번호만 비교하기 때문. 결과는 보수적(불필요한 stall)이라 틀리진 않지만 성능 손해. 근본 해결은 포워딩에서 쓴 **파일 구분(`uses_*` / `FRegWrite`)을 해저드에도 적용** |

### ⚪ 경고 (무해)

| 위치 | 내용 |
|---|---|
| FPU_Check.v line 41/49/58 | `@* is sensitive to all 7 words in array 'Rd'` — 배열 전체가 감도 리스트에 들어간다는 안내. 의도한 동작이라 문제없음 |

---

## 8. 과거 오류 기록 (수정 완료)

| # | 증상 | 원인 | 수정 |
|---|---|---|---|
| H-1 | 주소가 `00 → 04 ↔ 08` 무한 반복 | `Early_Jump_Unit`의 `assign PCSrc = (Early_Target) ? 1:0` → **항상 참** → 매 사이클 점프/flush | `if(is_JAL)`로 게이팅 (commit 7a81d42 → 7b3d9a1) |
| H-2 | BEQ 점프 위치 오류 | PC_MUX가 단일 `PCSrc?Target:next_pc` → ID점프(JAL)와 EX점프(분기)를 구분 못 함 | `ID_PCSrc→Early_Target`, `EX_PCSrc→Target`으로 분리 (commit 7a81d42) |
| H-3 | JAL 미수행 / 명령어가 0으로 flush됨 | H-1 + ImmGen의 J-type imm 오류(LSB `1'b0` 누락, `inst[31]` 중복)가 겹침 | 양쪽 수정 (commit 7b3d9a1) |
| H-4 | 명령어 밀림처럼 보임 | **오류 아님** — 모니터가 IF단계 pc와 ID단계 명령어를 함께 출력해서 한 칸 어긋나 보인 것 | — |
| H-5 | FLW load-use 데드락 | FPU_Hazard의 FLW 분기가 `ID_EX_stall=1` → 생산자(FLW)가 EX에 갇혀 MEM으로 못 나감 → 조건이 영원히 유지 | **`ID_EX_flush`로 변경** (§3 참조) |
| H-6 | `EX_is_FLW`가 죽은 신호 | 디코더→ID_EX 파이프→Hazard_Unit 경로가 끊겨 있어 조건이 절대 성립 안 함 | ID_EX 레지스터에 `ID_is_FLW` 추가(폭 228→229), Hazard_Unit 포트 추가 |
| H-7 | FPU 결과가 x | `Pipeline_CPU`의 FPU 인스턴스에 **`.clk`/`.reset` 미연결** → 내부 레지스터가 클럭을 못 받음 | 연결 |

### 검토했으나 원인이 아니었던 가설

과거 다른 도구가 제시한 3가지 후보를 실제 코드와 대조한 결과, **셋 다 이미 올바르게 구현되어 있었음**:

| 가설 | 실제 |
|---|---|
| stall 신호 극성 반전 → 영구 정지 | `stall` 1=hold, `PCWrite` 1=전진으로 **일치**. stall 조건도 자기해제형 |
| load-use 조건에 x0 예외 누락 | CPU_Hazard line 28에 `(EX_Rd != 5'b0)` **존재** |
| flush/stall 우선순위 꼬임 | `if(reset\|\|flush)`가 먼저 검사되어 **flush 우선**. commit 4f238ea 이후 불변 |

> **교훈**: 증상만 보고 일반적인 실패 유형을 나열하면 실제 코드와 안 맞을 수 있음.
> 당시 진짜 단서는 파형의 `wb_FPU_OF/UF = x` → **논리가 아니라 배선 문제**(H-7)였음.

---

## 9. 남은 작업

### 즉시 (컴파일/동작)
- [ ] Hazard_Unit.v line 31 포트명 오타 수정
- [ ] FPU_Check.v FSW 분기에 `for` 루프 추가
- [ ] FPU_Hazard.v `wire FPU_6clk;` 선언

### 설계 보완
- [ ] FPU_Hazard FLW load-use 조건에 `ID_is_FSW` 포함
- [ ] FLW load-use 분기를 `FPU_Valid`보다 **앞**으로 이동
- [ ] CPU_Hazard의 load-use에 **파일 구분** 적용 (FLW ↔ 정수 소비자 가짜 매치 제거)

### 검증
- [ ] Hazard_Unit 단독 테스트벤치 작성
      — Forwarding처럼 directed + constrained random + 참조 모델 구조 권장
      — 필수 케이스: 각 flush 조건 / load-use / FPU_Left stall 해제 타이밍 /
        **stall이 스스로 풀리는지(데드락 검사)** / FLW load-use / 우선순위 충돌
- [ ] 특히 **데드락 검사**를 반드시 포함할 것 (H-5가 그 유형)

---

## 10. 교훈

1. **stall과 flush는 역할이 다르다** — "소비자를 붙잡는 것"은 `IF_ID_stall`, "EX에 버블 넣는 것"은 `ID_EX_flush`. load-use에서 `ID_EX_stall`을 쓰면 생산자가 갇혀 데드락
2. **stall 조건은 스스로 풀려야 한다** — 카운터나 진행 상태가 조건에 반영되지 않으면 영구 정지. 새 stall 조건을 추가할 때마다 "이건 어떻게 해제되나"를 먼저 확인
3. **파형에 `x`가 보이면 논리가 아니라 배선을 의심** — `z`는 미연결, `x`는 충돌/미초기화
4. **신호를 새로 추가하면 배선 체인 전체를 확인** — 디코더 → 파이프 레지스터(폭 포함) → 상위 모듈 포트 → 하위 모듈. 한 군데만 빠져도 조건이 죽은 코드가 됨 (H-6)
5. **루프 변수를 블록 밖에서 쓰지 말 것** — FPU_Check FSW 분기가 그 사례. 배열 범위 밖 접근으로 조용히 `x`가 됨
6. **정수와 FP는 레지스터 번호를 공유한다** — x5와 f5는 다른 레지스터. 번호만 비교하면 가짜 매치가 발생하므로 파일 구분이 필요
