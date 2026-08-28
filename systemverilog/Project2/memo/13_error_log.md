# Project2-13 · Integer Rd Queue / RAW Dependency — Error Log

[← Repository overview](../../../README.md) · [Source](../13_riscv_integer_rd_queue.sv)

> **현재 상태:** 1차 구현은 xsim 50회 검증을 통과했다. E17 이후 항목은 명령어와 의존성 메타데이터를 같은 mailbox로 전달하는 2차 개선 과제다.

`13_riscv_integer_rd_queue.sv`에서 최근 정수 Rd 큐를 만들고 거리 1~N RAW 의존성을 주입하면서 생긴 오류 기록.
각 항목은 **증상 / 원인 / 수정 / 확인 / 교훈** 순서. 2026-08-28 1차 기능 검증 완료.

---

## [Queue / DependencyTracker 기본 구조]

### E01 · `DependencyTracker` 클래스 대부분이 빨간 줄 — 실행문을 클래스 몸체에 바로 작성

- [증상] `$urandom_range`, `if`, `push_front()` 이후부터 코드 대부분이 빨간 줄. 컴파일도 정상적으로 되지 않음.
- [원인] 클래스 몸체에는 멤버 변수, constraint, function, task 같은 **정의**가 와야 하는데 실행문을 바로 적음.
- [수정] 과거 Rd 선택은 `choose_Rd()`, 새 Rd 기록은 `run()` task 내부로 이동.
- [교훈] 클래스는 붕어빵틀이다. 틀에 "지금 동전을 던져라"를 바로 적는 것이 아니라 나중에 호출할 동작을 function/task로 정의해야 한다.

### E02 · 큐에 데이터가 쌓이지 않음 — Tracker를 반복해서 `new()`

- [증상] 명령어를 계속 생성하는데 `recent_x_Rd`가 누적되지 않고 매번 처음 상태처럼 보임.
- [원인] Generator 실행 중 `DependencyTracker d_handle = new()`를 반복. `new()`는 기존 Tracker 초기화가 아니라 **새 객체 생성**이라 과거 큐를 버리고 빈 Tracker를 계속 만든 셈.
- [수정] Top에서 `DependencyTracker den = new()`를 한 번만 실행하고 같은 `den` 핸들을 Generator와 Scoreboard에 전달.
- [확인] 명령어가 생성될수록 큐가 유지되고 MAXQ까지 누적됨.
- [교훈] 같은 기록을 계속 써야 하면 같은 TV 객체를 여러 리모콘이 가리켜야 한다. 반복마다 새 TV를 사면 이전 기록이 없다.

### E03 · Generator↔Tracker 생성 관계가 꼬임

- [증상] Tracker 안에서 Generator를 `new()`하려 했으나 Generator 생성자는 mailbox를 요구하고 Generator도 Tracker를 사용해 관계가 원형으로 꼬임.
- [원인] "Tracker가 Generator의 값을 받는다"를 "Tracker가 Generator 객체를 소유해야 한다"로 해석함.
- [수정] Generator가 명령어 생성 후 필요한 Rd만 Tracker에 전달. Tracker는 최근 Rd 관리와 target 선택만 담당.
- [교훈] 데이터를 받는다고 상대 객체를 새로 만들 필요는 없다. 생산자가 기록 담당자에게 값만 알려주면 된다.

### E04 · `port 'mb' is not connected on function call 'new'`

- [증상] Generator 객체 생성 시 Vivado에서 mailbox 포트가 연결되지 않았다는 오류.
- [원인] 생성자는 `new(mailbox #(BaseTr) mb, ...)`처럼 필수 인자를 요구하는데 `new()`로 호출.
- [수정] Top의 shared mailbox와 shared Tracker 핸들을 생성자 인자로 전달.
- [교훈] 생성자 괄호는 장식이 아니다. 신입사원 객체에게 어느 컨베이어벨트와 기록판을 쓸지 출근할 때 알려주는 자리다.

---

## [Queue 순서 / 거리 계산]

### E05 · 현재 명령어가 자기 Rd에 의존할 수 있음 — push와 target 선택 순서

- [증상] 현재 생성 중인 명령어의 Rd가 target 후보에 포함될 가능성이 생김.
- [원인] 현재 Rd를 큐에 먼저 `push_front()`한 뒤 target을 선택하려고 함. RAW는 현재 명령어가 **과거 명령어** 결과를 읽는 것이므로 현재 Rd는 후보가 되면 안 됨.
- [수정] `과거 큐에서 target 선택 → target으로 현재 명령어 randomize → 생성 성공 후 현재 Rd 기록` 순서로 변경.
- [확인] 출력 큐는 현재 Rd가 들어가기 전 과거 큐이고 target이 그 큐 안에 존재함.
- [교훈] 새 물건을 과거 목록에 등록하기 전에 과거 물건과의 연결을 먼저 정한다.

### E06 · index와 distance 혼동

- [증상] 큐 첫 원소를 거리 0으로 생각하거나 거리 3 target을 잘못 찾음.
- [원인] 큐 index는 0부터 시작하지만 명령어 거리는 1부터 세기 때문.
- [수정] `push_front()` 기준 index 0=가장 최근=거리 1, `distance=index+1` 사용.
- [확인] `[x7,x12,x9]`일 때 index 0/1/2가 거리 1/2/3, target x7/x12/x9로 출력됨.
- [교훈] 배열 주소표는 0부터지만 사람이 세는 의존성 거리는 1부터다.

### E07 · 거리 정책 off-by-one

- [관찰] 현재 `MAXQ=6`이므로 선택 가능한 거리는 1~6이다.
- [주의] "거리 6 이상 금지"면 MAXQ=5, "거리 6까지 허용"이면 MAXQ=6이다.
- [현재 판정] 1차 구현은 **거리 6까지 허용**으로 기록.

---

## [randomize / LW·FLW·SW·FSW 분기]

### E08 · randomize 전에 opcode 검사 — LW/SW 의존성 분기가 실행되지 않음

- [증상] Tracker는 `Dependent!!`를 출력하지만 LW/SW의 Rs1/Rs2에 target이 들어가지 않음.
- [원인] 객체를 `new()`한 직후 아직 `randomize()`하지 않은 opcode를 검사. rand 변수의 종류가 결정되기 전에 기본값을 보고 분기함.
- [수정] LW/FLW, SW/FSW 종류를 별도 동전으로 먼저 선택한 뒤 선택한 opcode를 인라인 제약으로 고정해 randomize.
- [교훈] 주사위를 던지기 전에 결과가 LW인지 물어볼 수 없다. 먼저 종류를 정하거나 규칙판에 종류까지 넣어야 한다.

### E09 · 정상 동작을 `if(!randomize())` 안에 넣음

- [증상] randomize가 성공하면 opcode 검사와 target 주입 코드가 전혀 실행되지 않음.
- [원인] 반환값 의미를 반대로 이해. `randomize()`는 성공=1, 실패=0이므로 `!randomize()` 블록은 실패할 때만 실행됨.
- [수정] 실패 블록에는 `$fatal`만 두고 정상 opcode 분기와 후속 동작을 분리.
- [재발] `!`만 제거했더니 성공 시 `$fatal`이 실행되어 line 214에서 즉시 중단됨.
- [교훈] `if(!handle.randomize()) $fatal`은 한 덩어리의 **실패 검사 관용구**다. 안에 정상 처리 코드를 넣지 않는다.

### E10 · 두 번째 randomize에서 LW가 FLW로 다시 바뀔 수 있음

- [증상] 첫 randomize에서 LW를 확인한 뒤 `randomize() with {Rs1==target;}`를 다시 실행하면 opcode가 FLW로 바뀔 가능성.
- [원인] 두 번째 randomize가 Rs1만 바꾸는 것으로 착각. 실제로 모든 rand 필드를 다시 뽑음.
- [수정] 인라인 제약에 source target과 opcode를 동시에 고정.
  - LW: `Rs1==target` + `opcode==LW`
  - SW: 선택한 Rs1/Rs2 target + `opcode==SW`
  - FLW/FSW: 각 float opcode 고정, 현재 정수 RAW 정책에서는 `doing=0`
- [확인] 최종 로그에서 LW/SW target과 실제 source가 일치하고 FLW/FSW는 `NOT Dependent`.
- [교훈] `with`는 기존 값을 얼리는 기능이 아니라 가능한 결과를 좁히는 규칙판이다. 유지할 값도 규칙에 다시 써야 한다.

### E11 · FLW/FSW가 거짓으로 `Dependent!!` 출력

- [증상] 예전 실행에서 FLW가 target=`11001`을 표시했지만 실제 Rs1=`10010`. target이 피연산자에 없는데 의존 명령어로 표시됨.
- [원인] `choose_Rd()`가 `doing=1`을 만들었지만 FLW/FSW에는 정수 target을 주입하지 않았고 `doing`도 0으로 되돌리지 않음.
- [수정] FLW/FSW 분기에서 `doing=0`, opcode도 FLW/FSW로 고정.
- [확인] 최종 50회 실행에서 FLW/FSW는 모두 `NOT Dependent`.
- [교훈] "의존성을 만들기로 한 상태"와 "실제 명령어에 들어간 상태"는 다르다. 문구가 아니라 target과 Rs를 직접 비교해야 한다.

---

## [정수/FPU 레지스터와 생산자 구분]

### E12 · FLW의 Rd가 정수 recent queue에 들어감

- [증상] FLW 직후 그 Rd가 `recent_x_Rd` 앞에 나타남. 이후 정수 명령어가 같은 번호를 x레지스터 target으로 선택할 수 있음.
- [원인] F_LW 클래스 전체에 `write=1`을 두고 LW/FLW 구분 없이 Tracker를 실행. FLW의 Rd는 f-Rd이고 x-Rd가 아님.
- [수정] 실제 opcode가 LW일 때만 Rd 기록. FLW는 기록하지 않음.
- [확인] 최종 로그에서 FLW 전후 큐가 유지되고 FLW Rd가 추가되지 않음.
- [교훈] `x5 != f5`. 번호 폭이 같아도 레지스터 파일이 다르면 의존성 큐도 분리해야 한다.

### E13 · x0를 생산자로 큐에 기록할 가능성

- [증상] Rd=0인 R/I/LW가 생성되면 x0가 과거 생산자 target 후보에 들어갈 수 있음.
- [원인] 형식상 Rd 필드가 있다는 이유로 모두 실제 값을 생산한다고 처리.
- [수정] 기록 조건에 `Rd != 5'b0` 추가.
- [확인] 최종 실행에서 x0가 새 생산자로 큐에 추가되지 않음.
- [교훈] RISC-V x0는 항상 0이라 RAW 생산자가 아니다. 형식상의 Rd와 실제 write dependency를 구분한다.

### 생산자/소비자 기준

- R-type: x-Rd 생산 / x-Rs1, x-Rs2 소비
- I-type: x-Rd 생산 / x-Rs1 소비
- LW: x-Rd 생산 / x-Rs1 소비
- FLW: f-Rd 생산 / x-Rs1 소비, 현재 FPU 의존성 제외
- SW: x-Rs1, x-Rs2 소비 / Rd 생산 없음
- FSW: 현재 FPU 의존성 제외
- B-type: x-Rs1, x-Rs2 소비 / Rd 생산 없음

---

## [컴파일 / 복붙 실수]

### E14 · `l_handle` / `last_rd_handle` / `s_handle` 혼동

- [증상] Vivado 오류: `'l_handle' is not declared`, 이후 `'last_rd_handle' is not declared`.
- [원인] 긴 case 분기를 복사한 뒤 현재 분기의 객체 이름으로 전부 바꾸지 않음.
- [수정] 각 case 분기에서 실제로 `new()`한 핸들 이름으로 통일.
- [교훈] 개념 오류가 아니라 반복 실행 실수. 컴파일러의 첫 file:line부터 보고 뒤의 연쇄 오류는 먼저 쫓지 않는다.

### E15 · inline constraint 세미콜론 누락

- [증상] Vivado `syntax error near '}'`.
- [원인] `with {opcode == 7'b0000111}`에서 constraint 식 끝 세미콜론 누락.
- [수정] `with {opcode == 7'b0000111;}`.
- [교훈] `with {}` 안도 constraint 문법이므로 각 식을 세미콜론으로 끝낸다.

---

## [출력 / 동시 실행]

### E16 · Generator 50회와 Scoreboard 50회 출력이 분리됨

- [증상] 원한 것은 "명령어 하나 → 그 명령어 큐/의존성 확인 → 다음 명령어"인데 생산과 소비 출력이 덩어리로 보임.
- [원인] Generator와 Scoreboard가 각각 내부에서 50회 반복해 독립 속도로 실행. Tracker 상태는 계속 덮임.
- [수정·1차] Top에서 `gen.run()` 1회와 `scr.run()` 1회를 `fork...join`으로 묶고 그 세트를 50회 반복.
- [확인] 다음 Generator가 시작되기 전에 현재 Scoreboard가 끝나 현재 transaction과 target/distance가 맞게 출력됨.
- [교훈] 현재 출력 정렬은 우연이 아니라 `join`이 만든 lockstep 보장이다.

### E17 · 현재 출력은 맞지만 실무형으로는 취약함  ◐1차 통과 / 2차 개선 예정

- [현재 구조]
  - Generator: 과거 큐 출력
  - Generator: 현재 Rd 기록 후 transaction을 mailbox에 put
  - Scoreboard: 공유 Tracker의 `doing/target/index` 출력
  - Scoreboard: mailbox에서 받은 instruction 출력
- [판정] 현재 1회 `fork...join`에서는 다음 생산 전에 소비가 끝나므로 값이 맞다. 단순히 운 좋게 맞은 출력은 아니다.
- [한계] 명령어는 mailbox에 태우지만 의존성 정보는 공유 Tracker 칠판에서 읽는다. 연속 생산하면 A transaction 옆에 B의 target/distance가 출력될 수 있다.
- [다음 수정] `dep_applied`, `target`, `distance`, 필요 시 queue snapshot을 transaction 또는 묶음 객체에 저장해 같은 mailbox로 전달.
- [교훈] 데이터와 그 데이터의 설명표는 같은 컨베이어벨트에 태워야 한다.

### MINOR-1 · `q=[...]NOT Dependent`가 한 줄에 붙음

- [증상] `q = [ ... ]NOT Dependent`로 출력되어 경계가 보기 어려움.
- [원인] `print_q()` 마지막이 `$write("]")`라 줄바꿈 없음.
- [수정 예정] 큐 뒤에 줄바꿈 또는 구분자 추가.
- [판정] 기능 오류가 아닌 출력 가독성 문제.

---

## [1차 검증 결과 — PASS, 2026-08-28]

- Vivado xsim compile / elaborate / run 성공
- 50개 명령어 끝까지 실행
- R=10, I=15, B=11, LW=6, FLW=3, SW=1, FSW=4 → 합계 50
- R/I/B/LW/SW의 `Dependent!!`에서 target과 실제 Rs1 또는 Rs2 일치
- FLW/FSW는 `NOT Dependent`
- FLW의 f-Rd는 `recent_x_Rd`에 기록되지 않음
- R/I/LW의 0이 아닌 Rd만 기록
- 큐 크기 MAXQ=6 이하, 거리 1~6 선택 확인

검증 로그 예시:

- LW: target=`00111`, distance=3 → 실제 Rs1=`00111` ✓
- SW: target=`10100`, distance=2 → 실제 Rs2=`10100` ✓
- I-type: target=`01100`, distance=1 → 실제 Rs1=`01100` ✓

단순히 `Dependent!!` 문자열만 확인하지 않고 실제 명령어 필드와 target을 대조했다.

---

## [다음 2차 작업]

1차는 기능 확인용으로 통과. 다음에는 출력과 상태 전달을 mailbox 기반으로 변경한다.

- transaction에 `dep_applied`, `target`, `distance` 저장
- 필요하면 생성 당시 queue snapshot도 저장
- Scoreboard에서 공유 Tracker 최신값을 읽지 않고 받은 transaction만 출력
- `write/Rd 설정 → run()` 방식은 나중에 `record_Rd(rd)`처럼 인자를 직접 전달하는 API로 정리
