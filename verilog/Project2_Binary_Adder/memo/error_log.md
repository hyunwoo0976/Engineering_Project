# Project 2 — 오류 기록

기록 형식: **증상 / 원인 / 수정 / 확인**

---

## E01 · iverilog가 파일 목록(`.f`)을 못 찾음

- **[화면]** `img_calculate_adder/binary_adder_error.png`

- **[증상]**
  ```
  PS C:\Users\USER\Desktop\verilog_test> iverilog -o cal_add.out -f calculate_add.f
  C:\iverilog\bin\iverilog.exe: cannot open command file calculate_add.f for reading.
  ```
  컴파일이 시작되지도 못하고 멈춤. Verilog 코드와는 무관한 오류.

- **[원인]**
  `-f`에 넘긴 `calculate_add.f`가 **현재 작업 디렉토리에 없었다.**
  파일은 `scripts/` 하위에 있었지만, 명령은 현재 폴더에 있는 것처럼 이름만 적었다.

  `-f` / `-c` 옵션의 경로는 **iverilog를 실행한 디렉토리를 기준**으로 해석된다.
  파일이 어디 있느냐가 아니라 **어디서 명령을 실행했느냐**가 기준이다.

- **[수정]** 상대경로를 명시
  ```
  PS C:\Users\USER\Desktop\verilog_test> iverilog -o cal_add.out -f ./scripts/calculate_add.f
  ```

- **[확인]** `img_calculate_adder/binary_adder_sol.png` — 오류 없이 컴파일 진행

---

## 관련 — 같은 원인의 재발 사례

**Project 10에서 같은 종류의 문제가 다시 발생했다.**
`$readmemh`가 명령어 파일을 못 읽어 `instruction`이 전부 `xxxxxxxx`로 나온 사건
(→ `Project10_mini_CPU/memo/error_log.md` E01).

두 사건의 원인이 동일하다:

| | Project 2 | Project 10 |
|---|---|---|
| 대상 | `iverilog -f` 의 파일 목록 | `$readmemh` 의 메모리 초기화 파일 |
| 원인 | **경로 기준 = 실행 디렉토리** | 동일 |
| 증상 | 컴파일 실패 (에러 메시지 명확) | **시뮬은 돌지만 값이 전부 `x`** ← 더 위험 |

Project 10 쪽이 더 나쁘다. 컴파일은 통과하고 **경고만 뜨기 때문에** 원인을 찾기까지
논리 버그를 의심하며 시간을 썼다.

**대응 원칙**
- `.f` 파일 안의 경로도 실행 디렉토리 기준이므로, **항상 프로젝트 루트에서 실행**한다
- `$readmemh` 경고(`Not enough words in the file` / `Unable to open`)를 무시하지 않는다
- → [도구 사용법](../../memo/도구_사용법.md)

---

## 교훈

1. **경로 기준은 "파일 위치"가 아니라 "실행 디렉토리"다.** `-f`, `$readmemh`, `$dumpfile` 모두 동일
2. **컴파일 실패는 오히려 안전하다.** 에러가 명확하니까. 위험한 건 **경고만 뜨고 돌아가는** 경우 (Project 10 사례)
3. 실행 위치를 고정하는 것이 예방책 — 스크립트(`run.bat`)로 감싸면 매번 같은 위치에서 실행된다
