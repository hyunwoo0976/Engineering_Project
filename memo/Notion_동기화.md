# Notion 동기화 방법

## 원칙 — 로컬 마크다운이 원본, Notion은 뷰

| | 역할 |
|---|---|
| **로컬 `memo/*.md`** | **단일 원본(source of truth)**. 여기서만 수정 |
| **Notion** | 읽기·검색·태블릿 열람용 사본 |

**Notion에서 직접 수정하지 않는다.** 양쪽에서 고치면 어느 게 최신인지 알 수 없게 된다.
수정은 항상 로컬에서 하고, Notion은 다시 Import 한다.

### 왜 이 방향인가
- git이 "언제 무엇을 고쳤는지" 추적해준다 (Notion엔 없는 기능)
- 코드 바로 옆에 있어 맥락이 유지된다
- Notion 계정·서비스 변경과 무관하게 남는다
- 커넥터 없이도 편집 가능

---

## 폴더 → Notion 페이지 계층

현재 구조가 그대로 페이지 계층이 된다:

```
Engineering_Project
├── memo/                          → Engineering Project (최상위 페이지)
│   └── Notion_동기화.md
├── verilog/memo/                  → Verilog (공통)
│   ├── 도구_사용법.md
│   ├── 검증_방법론.md
│   └── Verilog_주의점.md
├── verilog/Project5_ALU/memo/     → Verilog / Project5 ALU
│   ├── 정리.md
│   ├── 배경지식.md
│   └── error_log.md
└── verilog/Project10_mini_CPU/memo/ → Verilog / Project10 mini CPU
    ├── 정리.md
    ├── 배경지식.md
    ├── error_log.md
    ├── Forwarding.md
    └── Hazard.md
```

---

## Import 방법

### 처음 한 번에 올릴 때

1. Notion 좌측 하단 **`Import`** 클릭
2. **`Markdown`** 선택 (또는 `Markdown & CSV`)
3. 올릴 `.md` 파일들을 **여러 개 동시 선택** 가능
4. 표·코드블록·헤더가 그대로 변환된다
5. `- [ ]` 체크박스는 Notion **to-do 항목**이 된다 → 남은 작업 목록을 그대로 활용

> **폴더 계층을 유지하려면**: 폴더를 zip으로 압축해서 Import 하면 하위 페이지 구조가 만들어진다.
> 파일만 개별 선택하면 평면으로 들어오므로, 미리 Notion에 부모 페이지를 만들고 그 안에서 Import 한다.

### 개별 파일만 빠르게 올릴 때

파일 내용 전체 복사 → Notion 페이지에 **붙여넣기**. 마크다운이 자동 변환된다.
표 한두 개짜리 문서면 이게 더 빠르다.

---

## 갱신할 때 주의

Notion Import는 **기존 페이지를 갱신하지 않고 새 페이지를 만든다.** 그대로 반복하면 중복이 쌓인다.

**권장 절차**
1. Notion에서 해당 페이지 내용을 **전체 선택 후 삭제**
2. 로컬 파일 내용을 복사해 **붙여넣기**

또는 페이지를 지우고 다시 Import. 어느 쪽이든 **"덮어쓴다"는 것을 의식**해야 한다.

---

## 파일명 규칙

Notion 페이지 이름이 파일명에서 나오므로, 파일명 자체가 읽히게 짓는다.

| 좋음 | 나쁨 |
|---|---|
| `정리.md`, `배경지식.md`, `error_log.md` | `memo1.md`, `note.md`, `temp.md` |
| `Forwarding.md`, `Hazard.md` | `f.md`, `h2.md` |

프로젝트 폴더 안에 있으므로 파일명에 프로젝트 이름을 중복해서 넣지 않는다
(`Project5_정리.md` ❌ → `정리.md` ✅).

---

## memo 파일 4종 구분

| 파일 | 무엇을 쓰나 |
|---|---|
| `정리.md` | 목표 / 모듈 구조 / 동작 원리 / 핵심 코드 / 검증 방법 / 배운 것 |
| `배경지식.md` | 교과서적 이론, 용어, "왜 이 방식인가", 인접 개념 |
| `error_log.md` | 증상 / 원인(`file:line`) / 수정 / 확인(파형) |
| `<모듈명>.md` | 규모가 커서 별도 문서가 필요할 때만 (예: `Forwarding.md`) |

**섹션 공통 지식**(도구 사용법, 문법 주의점 등)은 프로젝트가 아니라 상위 폴더의 `memo/`에 둔다.

---

## 건드리지 말아야 할 파일

`verilog/Project10_mini_CPU/memo/` 안에는 **시뮬레이션이 실제로 읽는 파일**이 섞여 있다:

| 파일 | 용도 |
|---|---|
| `program.txt` | `Instruction_Memory.v`의 `$readmemh` 대상 |
| `data.mem` | `Data_Memory.v`의 `$readmemh` 대상 |
| `Instruction.txt`, `RISC-V_Assembler.txt`, `test_loop.txt` | 명령어 인코딩 참고 자료 |

**이동하거나 이름을 바꾸면 시뮬레이션이 깨진다.** Notion에 올릴 필요도 없다.

---

## 커넥터를 연결한 경우

Notion MCP를 연결하면 Import 없이 자동 반영이 가능해진다. 그때도 **로컬이 원본**이라는 원칙은 유지한다 — 커넥터는 "옮기는 수단"일 뿐이다.

연결 방법은 OAuth 방식을 권한다 (토큰을 파일에 저장하지 않아 유출 위험이 없음):

```bash
claude mcp add --transport http notion https://mcp.notion.com/mcp --scope user
```

- 스코프는 **`user`** (프로젝트 무관하게 사용)
- **`project` 스코프는 금지** — `.mcp.json`이 저장소에 커밋된다
- 등록 후 세션을 새로 시작해야 도구가 로드된다
