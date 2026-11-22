# 07 Dual Bank Transaction System - Debug Handoff

## 작업 대상

- 소스: `07_dual_bank_transaction_system.sv`
- 실행: `D:\My_project\Engineering_Project\systemverilog\wave.bat Project3\07_dual_bank_transaction_system.sv`
- 작성 기준: 2026-09-30 20:18 실행 로그 및 당시 저장 소스

## 목표

4개 계좌를 가지는 거래 처리 DUT와 class 기반 검증환경을 작성한다. 계좌 초기값은 `100, 200, 300, 400`이다.

| cmd | 동작 |
|---|---|
| `000` | 입금 |
| `001` | 출금 |
| `010` | 계좌 이체 |
| `011` | 계좌 잠금 |
| `100` | 계좌 잠금 해제 |
| `101` | 잔액 조회 |
| `110` | 잠기지 않은 모든 계좌에 `balance >> 4`만큼 이자 지급 |
| `111` | 지원하지 않는 명령 |

검증환경은 Generator → Driver → DUT → Monitor → Scoreboard 구조이며 Transaction과 Observation을 mailbox로 Scoreboard에 전달한다.

## 사용자가 의도한 DUT 구조

사용자는 `detailed_account_bank`의 `always_comb` 내부 `account` 배열을 계산 및 latch 상태로 사용하고, `current_account`로 계산 결과를 상위 `account_bank`에 전달한 뒤 상위 `always_ff`에서 출력하도록 설계했다.

현재 구조를 임의로 단일 `always_ff` 구조로 변경하지 말고 먼저 latch 의도를 존중하여 실제 피드백과 타이밍을 검토한다. 단, `account ↔ current_account` 경로에 조합 피드백 또는 valid가 유지되는 동안 반복 계산이 발생하는지는 파형으로 확인해야 한다.

## 해결된 컴파일 문제

- Top의 실제 interface 인스턴스 `bus`를 `.bus_in(bus), .bus_out(bus)`로 연결
- `virtual` 오타 수정
- Monitor 생성자에 `this.vir = vir` 추가
- `$fatal` format specifier와 인자 개수 일치
- Scoreboard가 clocking block `output reset`을 읽던 문제 제거

## 마지막 실행 결과

컴파일과 elaboration은 통과했고 첫 비교에서 Fatal로 종료됐다.

```text
valid: 1, cmd: 110, src_id: 10, dst_id: 11, amount: 38841
1 passed
Fatal: actual: src_balance = 0, dst_balance = 400, error_code = 000
       expect: src_balance = 300, dst_balance = 400, error_code = 000
Time: 45 ns
```

이 거래의 올바른 결과:

```text
account[0] = 100 + (100 >> 4) = 106
account[1] = 200 + (200 >> 4) = 212
account[2] = 300 + (300 >> 4) = 318
account[3] = 400 + (400 >> 4) = 425

expected src_balance = 318  // src_id=2
expected dst_balance = 425  // dst_id=3
expected error_code  = 000
```

`amount`는 이자 지급 명령에서 사용하지 않는다.

## 확인된 문제

1. **Monitor 종료 문제**: `while(received < count)` 내부에서 Observation을 넣은 후 `received++`가 없다. Fatal 제거 후 `fork...join`이 끝나지 않는다.
2. **Scoreboard의 cmd 110 미구현**: 이자 명령이 `default`로 빠져 expected가 `300, 400`으로 남았다. 잠기지 않은 각 계좌에 `account[j] + (account[j] >> 4)`를 적용해야 한다.
3. **DUT interest 부분 초기화**: `interest[bus_in.src_id]` 하나만 계산하고 `interest[0:3]` 전체를 사용하여 X가 발생할 수 있다. 각 계좌마다 계산해야 한다.
4. **Observation이 2-state bit**: DUT의 X가 0으로 변환되어 숨겨질 수 있다. actual 출력 필드는 `logic`을 사용하는 것이 적절하다.
5. **reset 시 current_account 미갱신**: 내부 `account`만 초기화하며 상위 모듈이 읽는 `current_account`는 reset 직후 미정일 수 있다.
6. **result_valid 오정렬**: reset이 아니면 항상 1이므로 이전 출력이나 reset 직후 출력이 현재 거래 결과로 캡처될 수 있다.
7. **Transaction–Observation 시간 정렬**: 상위 출력은 `always_ff`, clocking block은 `input #1step output #0`이다. Driver Transaction과 Monitor Observation이 같은 거래인지 파형 확인이 필요하다.

## 추가 로직 문제

- DUT 잠금 해제 성공 경로가 `locked[src_id] = 1`이다. 잠금 해제라면 `0`이어야 한다.
- DUT 이체에서 목적 계좌 잠금, 잔액 부족, 목적 계좌 overflow 및 거래 원자성을 확인해야 한다.
- 입금/이체 overflow 실패 시 계좌는 거래 전 값을 유지해야 한다.
- Scoreboard는 거래마다 expected `error_code`를 `000`으로 초기화해야 한다.
- Scoreboard 일부 분기에서 expected `error_code`가 아니라 actual인 `obs.error_code`를 변경한다. Observation은 수정하면 안 된다.
- Scoreboard의 `15'hff`는 `16'hffff`가 아니다. 또한 입금 overflow 명세는 포화가 아니라 실패 및 이전 값 유지다.
- DUT/Scoreboard에 `cmd=111` 미지원 명령 오류 처리가 필요하다.
- `transaction_id`는 성공한 상태 변경 거래에서만 증가하고 조회 또는 실패 거래에서는 유지해야 한다.

## 권장 디버깅 순서

1. Monitor에 `received++` 추가
2. Observation actual 필드를 `logic`으로 변경
3. Scoreboard에 `cmd=110` 기준 모델 추가
4. DUT의 각 계좌 interest 계산 수정
5. reset 직후 `account/current_account/src_balance/dst_balance` 파형 확인
6. `result_valid`와 출력 데이터의 거래 단위 정렬
7. 첫 directed test를 `cmd=101` 조회로 고정하여 초기 잔액 확인
8. 입금, 출금, 이체, 잠금, 이자 순서로 검증
9. directed test 통과 후 random test 재개

현재 random test부터 실행하고 있어 첫 오류 추적이 어렵다. DUT와 Scoreboard가 안정될 때까지 고정된 directed transaction부터 검증하는 것이 좋다.
