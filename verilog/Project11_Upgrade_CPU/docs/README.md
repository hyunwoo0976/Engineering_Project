# Project11 문서와 폴더 안내

| 문서 | 내용 |
|---|---|
| [01_design.md](01_design.md) | 입력 규칙·파이프라인·특수값·연산 격리 |
| [02_verification.md](02_verification.md) | 검증 구성·결과·한계 |
| [07_submission_report.md](07_submission_report.md) | CPU–FPU 통합 보고서 |
| [results.json](results.json) | 회귀 요약과 RTL 해시 |

## 파일 배치

- `src_mini_CPU/`: RTL. 현재 실행 목록은 `F_file/CPU.f`다.
- `tb/`: [활성 테스트벤치](../tb/README.md).
- `tools/`: [실행 도구](../tools/README.md).
- `img_m_CPU/`: 설계보고서에 사용한 실제 Vivado xsim 캡처.
- `_work/`: 생성물과 실행 로그. Git에서 제외한다.

[xsim_fpu_boundary_waveform.png](../img_m_CPU/xsim_fpu_boundary_waveform.png)는 실제 Vivado GUI 캡처다. 신청서 원본과 개인 작업 메모는 저장소에 포함하지 않는다.
