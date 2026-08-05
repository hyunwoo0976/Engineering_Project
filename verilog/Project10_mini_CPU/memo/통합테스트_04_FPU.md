# 통합테스트 04 — FPU 통합 (flw/fsw/fadd/fsub/fmul, 7clk in-flight)

IEEE-754 단정밀도 FPU를 5단 파이프라인에 통합한 뒤, **FP 로드/스토어 + 산술 + in-flight 해저드**를
한 프로그램에 몰아넣은 종합 테스트. 정수 통합(테스트 01~03)과 동일하게 **파이썬 ISS를 golden model**로 대조.

## 목적

- **FP 명령어 전종**: flw / fsw / fadd / fsub / fmul
- **7클럭 FPU 타이밍** — 결과가 EX 7클럭 뒤 shadow에서 나옴, FPU_Valid로 인계
- **in-flight FP 포워딩 + stall** — 바로 앞 FP 결과를 읽는 back-to-back / 체인
- **FSW가 in-flight FP 값을 저장** + **FSW→FLW 메모리 왕복**
- **IEEE-754 예외** — 오버플로 → Inf (가수 0)
- **같은 in-flight 레지스터를 양쪽 포트에** (fadd f18, f16, f16)

## 검증 방법 — ISS 골든모델

레지스터를 TB에서 직접 못 봐서, WB 커밋을 그림자 레지스터에 복사해 최종 상태를 비교(테스트 01~03과 동일).
FP는 손계산이 거의 불가능(2.4×10²¹ + 1.3×10¹⁸ 같은 것)이라 **파이썬 ISS(`python/tools/riscv_iss.py`)**로
같은 프로그램을 돌려 비트패턴 정답을 뽑고, DUT의 f-레지스터/shadow와 대조. ISS는 `.exe`로도 빌드해 `memo/`에서 바로 사용.

## 데이터 (`data.mem`)

| 주소 | HEX | 값 | 로드처 |
|---|---|---|---|
| mem[0] | `63021AB1` | 2.4×10²¹ | f1 |
| mem[4] | `5D905439` | 1.3×10¹⁸ | f2 |
| mem[8] | `4039999A` | 2.9 | f7 |
| mem[12] | `40666666` | 3.6 | f8 |

## 프로그램

| # | HEX | 어셈블리 | 결과 | 노림수 |
|---|---|---|---|---|
| 0 | `00002087` | `flw f1, 0(x0)` | 2.4×10²¹ | FP 로드 |
| 1 | `00402107` | `flw f2, 4(x0)` | 1.3×10¹⁸ | |
| 2 | `002081d3` | `fadd f3, f1, f2` | 2.4013×10²¹ | |
| 3 | `08208253` | `fsub f4, f1, f2` | 2.3987×10²¹ | |
| 4 | `081102d3` | `fsub f5, f2, f1` | -2.3987×10²¹ | 부호 |
| 5 | `10208353` | `fmul f6, f1, f2` | **+Inf** | **오버플로→Inf(가수0)** |
| 6 | `00802387` | `flw f7, 8(x0)` | 2.9 | |
| 7 | `00c02407` | `flw f8, 12(x0)` | 3.6 | |
| 8 | `008384d3` | `fadd f9, f7, f8` | 6.5 | |
| 9 | `08748553` | `fsub f10, f9, f7` | 3.6 | **in-flight f9** (back-to-back) |
| 10 | `00a02827` | `fsw f10, 16(x0)` | mem[16]=3.6 | **in-flight f10을 store** |
| 11 | `10a485d3` | `fmul f11, f9, f10` | 23.4 | in-flight f9·f10 |
| 12 | `01002607` | `flw f12, 16(x0)` | 3.6 | **FSW→FLW 왕복** |
| 13 | `089606d3` | `fsub f13, f12, f9` | -2.9 | |
| 14 | `089687d3` | `fsub f15, f13, f9` | -9.4 | **in-flight f13** (체인) |
| 15 | `00778853` | `fadd f16, f15, f7` | -6.5 | **in-flight f15** (체인) |
| 16 | `107088d3` | `fmul f17, f1, f7` | 6.96×10²¹ | in-flight 없음 |
| 17 | `01080953` | `fadd f18, f16, f16` | -13 | **같은 in-flight f16 양쪽 포트** |
| 18 | `0000006f` | `jal x0, 0` | 종료 | |

## 기대값 = 최종 상태 (18/18 PASS, ISS 대조)

```
check(1,  32'h63021AB1);  check(2,  32'h5D905439);  check(3,  32'h63022CBC);
check(4,  32'h630208A6);  check(5,  32'hE30208A6);  check(6,  32'h7F800000);  // +Inf
check(7,  32'h4039999A);  check(8,  32'h40666666);  check(9,  32'h40D00000);
check(10, 32'h40666666);  check(11, 32'h41BB3333);  check(12, 32'h40666666);
check(13, 32'hC039999A);  check(15, 32'hC1166666);  check(16, 32'hC0CFFFFF);
check(17, 32'h63BCA6B4);  check(18, 32'hC14FFFFF);
```

## 커버리지

- **FP 전종** flw/fsw/fadd/fsub/fmul
- **IEEE-754 오버플로 → Inf** (f6 = 2.4e21 × 1.3e18, 가수 0으로 클리어)
- **in-flight FP 포워딩 + stall** (f9→f10, f9·f10→f11)
- **FSW가 in-flight FP 저장** (fsw f10) + **FSW→FLW 메모리 왕복** (mem[16])
- **in-flight 체인** (f13→f15→f16, 각 링크가 앞 결과를 back-to-back으로 소비)
- **같은 in-flight 레지스터 양쪽 포트** (f18 = f16 + f16)
- **반올림 검증**: f16=`C0CFFFFF`(-6.4999995), f18=`C14FFFFF`(-12.9999995) — 수학적 -6.5/-13이 아니라 float32 반올림값. DUT가 이 LSB까지 맞아야 PASS

## 잡은 버그 — in-flight 해저드 4개가 겹침 (→ error_log OPEN-6)

`fadd f9 → fsub f10 → fsw f10` 한 줄에 버그 4개가 얽혀 있었다:

1. **검출 지각** — FPU_Check for문이 `Rd[]`(시프트레지스터)만 보고 지금 EX의 프로듀서(`EX_Rd`)를 안 봄 → back-to-back 의존을 못 잡음
2. **재주입 데드락** — FP 스톨이 EX를 freeze → 프로듀서가 매 클럭 재주입 → `FPU_6clk=1` 영구 스톨. `ID_EX_stall`→`ID_EX_flush`(버블)로 해결
3. **countdown 안 내려감** — Rs1 for문 부등호가 `<=`(거꾸로) → FPU_Left가 111 한 클럭 뒤 000 추락. `>`로 수정
4. **FSW store 실패** — FSW 분기에도 검출 지각(EX_Rd 누락) → fsw f10이 f10 준비 전 EX 진입 후 flush에 지워짐 → mem[16]=0 → **f12=0 → f13,f15,f16,f18 전부 cascade FAIL**

특히 4번은 ISS 대조가 진가를 발휘: DUT의 f13~f18이 "틀린 f12=0"으로 **정확히 계산된 값**이라, FP 산술은 멀쩡하고 **뿌리는 단 하나(f12)**임이 바로 보였다.

## 배운 것

- **in-flight FP 명령어 하나엔 검출·카운트·주입·스톨 4곳을 같이 맞춰야** — 하나만 어긋나도 깨진다
- **FPU 분기와 FSW 분기는 별개** — 같은 수정을 두 군데 다 해야 함 (4번 버그)
- **cascade FAIL은 뿌리 하나**일 때가 많다 — DUT 값이 "틀린 입력으로 정확히 계산"됐는지 보면 root가 보임 (f12)
- **등록(posedge/`<=`) 신호는 한 클럭 지각** — 해저드 검출은 조합으로 (OPEN-1과 같은 계열)
- **스톨은 소비자(ID)만 붙잡고, 프로듀서(EX→FPU)는 흘려보내야** — freeze하면 재주입/증발
- FP는 **손계산이 불가능** → ISS 골든모델이 필수. 반올림 LSB까지 대조

## 결과

- **정수 + FP 통합 x1~x18 all-pass** — DUT가 ISS와 비트패턴 완전 일치
- RV32I + F(single) 5단 파이프라인 통합 검증 완료: 연산·메모리·분기·루프·포워딩·load-use·**FP 7clk in-flight 해저드·FSW 왕복·IEEE 예외**

## 다음

- inst_Generator(C++ 어셈블러)에 flw/fsw 추가 (현재 수동 HEX)
- bug-injection/mutation으로 TB teeth 검증 → SV/UVM 이관
