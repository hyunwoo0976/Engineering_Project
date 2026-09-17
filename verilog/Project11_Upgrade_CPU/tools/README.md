# 실행 도구

Project11 루트에서 실행한다. 생성물은 `_work/`에 저장한다.

| 파일 | 역할 |
|---|---|
| `reference.py` | 정확한 정수 연산 기반 FP32 기준 모델 |
| `run_regression.py` | Icarus 회귀·오류 주입·결과 요약 |
| `run_xsim.ps1` | 준비된 벡터·메모리를 사용하는 Vivado xsim 회귀 |
| `compare_vivado.tcl` | 동일 FPGA·제약의 ISOLATE 비교 실험 |
| `check_vivado_environment.tcl` | 최소 회로 합성 환경 진단 |
| `synthesis_probe.v` | 합성 환경 확인용 최소 회로 |
| `render_report_assets.py` | `_work/report_waveform.vcd`에서 설명용 SVG 생성 |

먼저 `python tools/run_regression.py`, 이어서 `.\tools\run_xsim.ps1`을 실행한다. PowerShell의 `$bin`을 설치된 Vivado 경로에 맞춘다.

`CPU.f`는 Project11 루트 기준 상대 경로만 사용한다. 실행에 필요한 메모리 이미지는 `_work` 안에 생성하므로 원본 파일을 변경하지 않는다.

그림 생성기는 SVG를 생성하며 PNG는 자동 갱신하지 않는다. 실제 GUI 캡처와 구분한다. 합성 비교의 기본 부품은 `xc7a35tcpg236-1`, 클럭은 20ns다. 현재 합성 환경 문제가 남아 있어 PPA 수치는 없다.
