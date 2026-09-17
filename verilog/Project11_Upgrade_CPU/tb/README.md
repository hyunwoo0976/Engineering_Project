# Project11 활성 테스트벤치

| 파일 | 용도 | 실행 경로 |
|---|---|---|
| `Testbench_CPU.v` | 파이프라인 CPU 통합 회귀검증 | `tools/run_regression.py`, `tools/run_xsim.ps1` |
| `fp32_regression.sv` | FADD/FSUB/FMUL FP32 벡터 회귀검증 | `tools/run_regression.py`, `tools/run_xsim.ps1` |
| `fp_rounding_checks.sv` | 정규화·반올림 경계값 검사 | `tools/run_regression.py`, `tools/run_xsim.ps1` |
| `cpu_fp_special.sv` | CPU 경로의 FP 특수값 및 f0 검사 | `tools/run_regression.py`, `tools/run_xsim.ps1` |
| `report_waveform.sv` | 제출 보고서용 대표 실제 파형 생성 | `docs/assets/report_waveform.*` 생성용 |

Project10 시절의 미사용 TB와 파일 목록은 공개 프로젝트에서 분리하여 로컬 백업에 보관한다. 현재 활성 테스트벤치는 위의 다섯 개다.
