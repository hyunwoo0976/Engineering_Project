# 02. 검증 기록

## 실행 방식

Icarus Verilog에서 두 FPU를 동시에 실행하고 독립적인 Python 정수 연산 모델과 비교한다. reference는 FP32 입력을 `2^-149` 단위 정수로 해석해 정확히 연산한 뒤 몫과 나머지로 반올림한다. RTL의 파이프라인/정렬 코드를 그대로 옮긴 모델이 아니다. 다만 외부 공인 conformance suite나 formal proof를 대신하지 않는다.

전체 실행은 경계값 20종의 조합 × 연산 3종 × 반올림 5종 = 6,000건, 고정 seed 랜덤 20,000건, 지수 경계·상쇄·큰 지수 차이의 sticky/borrow 4,800건, 미지원 제어 조합 4건을 생성한다. bubble과 reset을 삽입해 유효 신호와 flush도 검사한다. reset으로 폐기한 요청을 제외한 검사 건수는 30,626이다. 별도 단위 테스트는 반올림·정규화 경계 23개를 비교한다.

## 검사 항목

2026-09-18: 커밋 전 문서·파일 정리 후 `python tools/run_regression.py` 전체 회귀를 재실행했다. FPU 30,626건, 반올림·정규화 23개, CPU 59개, CPU 특수값/f0 6개가 통과했고 예상값 변조 및 RTL mutation 실패 검출도 통과했다. 입력 레지스터 전환은 기본 10,315회, 격리 0회였다. 이번 정리에서 RTL과 테스트 코드는 변경하지 않았으며, 아래 xsim 기록은 2026-09-15 실행 이력이다.

2026-09-15 실행 기록: Icarus 전체 회귀·RTL mutation·checker negative control 통과 후, Vivado 호환 수정본으로 xsim 2026.1에서도 FPU 30,626건, 단위 23개, CPU 59+6개를 통과했다. xsim은 미사용 출력 포트 경고를 남기며 특히 NV/NX는 아직 CPU CSR에 연결되지 않는다. 2026-09-18 재검토에서 기존 results.json 해시와 현재 파일의 불일치를 발견하여 이번 Icarus 전체 회귀가 생성한 결과와 해시로 갱신했다. 과거 xsim 실행 기록을 현재 바이트 단위 소스 해시의 검증으로 간주하지 않는다.

재현: 먼저 `python tools/run_regression.py`, 이어서 `.\tools\run_xsim.ps1`. xsim 로그는 `_work/xsim_fp_rounding_checks.log`, `xsim_fp32_regression.log`, `xsim_Testbench_CPU.log`, `xsim_cpu_fp_special.log`에 생성된다.

- 두 버전의 결과 비트, NV/OF/UF/NX, error, sign/ZF, 7단 valid 정렬.
- ±0, 최소/최대 subnormal, 최소 normal, 최대 finite, ±Inf, qNaN/sNaN.
- 정확한 상쇄, tie 반올림, overflow/underflow, 연속 요청과 bubble, reset flush.
- CPU 기존 테스트의 최종 레지스터 비교 59개. 명령어별 commit trace 전수 비교는 아니다.
- CPU 추가 검사 6개: f0 load/writeback과 의존 연산, Inf−Inf의 NaN, 최소 subnormal의 합, 정수 x0 유지.
- Negative control: 짧은 입력열의 마지막 예상값 한 비트를 틀리게 바꿔 `FP mismatch`와 비정상 종료를 확인한다.
- RTL mutation: `_work` 복사본에서 RDN의 `SIGN && inexact`를 `SIGN`으로 바꾸면 정확한 -1.0 테스트가 실패해야 한다. 실제 소스에는 변이를 적용하지 않는다.
- 모든 유효 FPU 출력에서 `UF=1 → NX=1`을 검사한다.

최신 실행 수치와 RTL hash는 [results.json](results.json)에 저장한다. 전체 PASS는 표본 테스트의 통과이며 완전한 ISA 검증 완료를 뜻하지 않는다.

## activity 실험의 제한

500개의 특수값 경로 요청으로 VCD를 만들고 산술 입력 레지스터 a1/b1의 비트 전환만 센다. 이 의도적인 특수값 집중 입력에서는 isolation 버전이 산술 레지스터를 유지하는지 확인할 수 있다. 실제 프로그램을 대표하는 workload가 아니며 이 비율을 FPU 전체 전력 절감률로 제시하면 안 된다.

## 실험용 FPGA 비교

사용자 동의 기준 부품은 `xc7a35tcpg236-1`이다. Vivado 2026.1에서 두 모드에 같은 20ns 클럭을 주고 OOC 합성·배치배선을 수행한다. reset 입력만 false path로 제외한다. 외부 입력/출력 delay 및 실제 보드 핀 조건은 없으므로 내부 register-to-register 타이밍 실험이다.

`report_power`는 SAIF를 적용하지 않은 vectorless 추정이다. 따라서 보고서의 W 수치가 있더라도 실제 workload의 실측 소비전력으로 표현하지 않는다. 실제 소비전력 개선 주장을 하려면 대표 workload, 구현 netlist activity annotation, clock/reset 조건과 측정 환경을 추가로 고정해야 한다.

### 이번 실행 결과: FPGA 비교 미완료

Vivado 2026.1에서 합성 라이선스 획득과 RTL elaboration 메시지 뒤 exit code 1로 종료됐다. 배치배선·자원·타이밍·전력 보고서는 생성되지 않았다. 권한 승인 후 실행, 1-thread 재실행, 정규화 구조 변경 후 재실행에서도 재현됐다.

FPU와 무관한 플립플롭 1개짜리 `synthesis_probe`도 같은 위치에서 종료됐다. 따라서 FPU 크기나 8GB RAM 부족을 원인으로 단정하지 않는다. 설치/런타임 환경 문제 가능성이 있으며 구체적인 원인은 미확정이다. 시스템 설정·보안 프로그램·Vivado 설치를 임의로 변경하지 않았다.

- [FPU 합성 종료 로그](vivado_attempt.txt)
- [최소 회로 합성 종료 로그](vivado_probe.txt)
- 재현: `vivado -mode batch -source tools/check_vivado_environment.tcl`

다음 FPGA 단계는 최소 회로가 먼저 합성되도록 실행 환경을 정상화한 뒤 두 모드 비교를 재실행하는 것이다. **현재 LUT 수, 최대 주파수, 전력 절감률은 보고할 수 없다.**
