# 01. 설계 명세와 변경 이유

## 경계

32비트 입력 A/B, op `0=ADD, 1=SUB, 2=MUL`, rm `0=RNE, 1=RTZ, 2=RDN, 3=RUP, 4=RMM`를 받는다. `W`는 호환성을 위해 남았지만 32만 지원한다. FPU_en이 1인 상승 에지에서 한 요청을 접수한다. reset은 active-high asynchronous이며 진행 중 요청을 폐기한다.

op=3, rm=5/6/7은 지원하지 않는다. standalone FPU는 canonical NaN과 error를 반환한다. 이는 RISC-V illegal-instruction trap 구현이 아니며 DYN도 지원하지 않는다.

## 특수값을 따로 보는 이유

normal은 `1.fraction × 2^(E−127)`, subnormal은 `0.fraction × 2^(1−127)`이다. E=0을 무조건 hidden bit=1로 만들면 0과 매우 작은 수가 잘못 계산된다. 분류기는 부호와 독립적으로 수의 종류를 판정하고, 연산기는 부호까지 사용해 결과를 결정한다.

qNaN은 canonical `7fc00000`을 반환하지만 그것만으로 NV를 올리지 않는다. sNaN, Inf−Inf, 0×Inf는 NV이다. 반대 부호의 정확한 0 합은 RDN일 때 −0, 나머지 모드에서는 +0이다. 곱셈의 0 부호는 XOR이다.

## 파이프라인

| 단계 | FADD/FSUB | FMUL | 특수값 경로 |
|---|---|---|---|
| 1 | 입력 저장 | 입력 저장 | 결과·flags·illegal 저장 |
| 2 | hidden bit 구성 후 지수 정렬 | hidden bit 구성 후 24×24 곱셈 | 지연 |
| 3 | 정렬된 가수의 CLA 덧셈/뺄셈 | 곱셈 결과 저장 | 지연 |
| 4 | 결과 저장, 정규화 이동량 결정 | 정규화·subnormal 이동·반올림 | 지연 |
| 5 | 이동량 저장, 가수 이동·지수 보정 | 결과·flags 저장 | 지연 |
| 6 | 정규화 결과 저장, 공용 반올림·pack | 결과·flags 지연 | 지연 |
| 7 | 최종 출력 선택 | 최종 출력 선택 | 최종 출력 선택 |

첫 접수 에지를 1번이라고 하면 7번 에지 직후 결과가 나온다. 에지 간 시간은 6T이다. 순서와 CPU 목적 레지스터 지연에 맞춰 특수결과도 같은 길이로 전달한다. valid_out이 0이면 결과는 직전 값을 유지하며 error/NV/OF/UF/NX는 0이다. sign/ZF는 유지된 결과를 반영하므로 유효 결과로 해석할 때 valid_out을 확인한다.

## isolation이 바꾸는 것

`ISOLATE=0`은 산술 입력 a1/b1을 매 클럭 갱신하며, 코어는 유효 요청에 대해 계산한다. `ISOLATE=1`은 특수값 요청과 invalid 구간에서 산술 입력을 유지하고, 특수값 요청을 코어 enable에서 제외한다. 두 버전의 valid 결과와 플래그는 같아야 한다. 이는 Project11의 두 모드를 비교하는 실험이다.

입력 레지스터의 변화 감소가 곧 전체 칩 소비전력 감소율은 아니다. 분류기, 메타데이터, clock tree는 여전히 동작하며 enable 논리의 면적도 추가된다.

## 수정한 CPU 연결

Register_file의 `ZERO_REGISTER` 기본값은 1이다. 정수 레지스터는 그대로 쓰고 FP 레지스터만 0으로 설정했다. FP의 f0는 상수 0 레지스터가 아니므로 load, writeback, 의존성 경로에서 실제 값이 유지되어야 한다.
