# Project 6 — 오류 기록

기록 형식: **증상 / 원인(`file:line`) / 수정 / 확인**

---

## 미해결 (현재 컴파일 불가)

### E01 · 파일 목록 경로 오타 — 컴파일 실패

- **[증상]**
  ```
  ./Project3_subtractor/src-calculate_sub/adder.v: No such file or directory
  Preprocessor failed with 1 errors.
  ```

- **[원인]** `Top_module.f` 마지막 줄 근처의 경로가 **`src-calculate_sub`**(하이픈)으로 되어 있다.
  실제 디렉토리는 **`src_calculate_sub`**(밑줄).
  ```
  ./Project3_subtractor/src-calculate_sub/adder.v     ← 오타
  ./Project3_subtractor/src_calculate_sub/adder.v     ← 정상
  ```

- **[확인]** 경로를 밑줄로 바꾸면 컴파일·시뮬레이션이 정상 동작한다.

- **[미수정]** 아직 그대로 둠

- **[메모]** 이 `.f`는 경로가 `./Project6_...` 로 시작해 **`verilog/` 디렉토리에서 실행**해야 한다.
  다른 프로젝트(`./src_...`, `../ProjectN/...`)와 기준이 다르다. 통일하는 편이 좋다.

### E02 · `dual_port_reg.v` 문법 오류 — `else if` 위치

- **[증상]**
  ```
  dual_port_reg.v:17: syntax error
  dual_port_reg.v:18: Syntax in assignment statement l-value.
  dual_port_reg.v:21: syntax error
  dual_port_reg.v:22: error: invalid module item.
  ```

- **[원인]** `else if(we)` 가 **`if(reset) begin ... end` 블록 안**에 들어가 있다.
  reset 블록을 닫는 `end`가 빠졌다.
  ```verilog
  if(reset)begin
      for(i=0;i<4;i=i+1)begin
          mem[i]<=4'b0000;
      end
      else if(we)begin        // ← if 블록 내부. else가 올 수 없는 자리
          mem[w_add]<=din;
      end
  end
  ```

- **[조치안]** `register_file.v`와 같은 형태로 맞춘다. 그쪽은 정상이다.
  ```verilog
  if(reset)begin
      for(i=0;i<4;i=i+1)begin
          mem[i]<=4'b0000;
      end
  end else if(we)begin        // ← end 뒤에 else
      mem[w_add]<=din;
  end
  ```

- **[미수정]** 아직 그대로 둠. `Top_module.f`에 포함되지 않아 Top 시뮬에는 영향이 없지만,
  `dual_port_register_tb.v`를 돌리려면 고쳐야 한다.

---

## 조사 후 오류가 아니라고 판단한 것

### N01 · 출력이 입력보다 한 클럭 늦게 나온다 / 모드 전환 시 값이 튄다

- **[증상]** 입력을 바꾼 즉시 출력이 따라오지 않고 한 클럭 뒤에 반영된다.
  모드가 바뀌는 순간에는 중간값이 잠깐 찍힌다.
  ```
  Time:20000 | mode:00 | ... | OUTPUT= x
  Time:25000 | mode:00 | ... | OUTPUT=17     ← 첫 클럭 상승 후 확정
  ```

- **[결론]** 오류가 아니다. **파이프라인 구조에서 정상 동작이다.**

  ```
  [입력] → ALU0/ALU1 → 레지스터 → ALU2 → [출력]
  ```
  모든 입력이 레지스터를 반드시 거치므로, 출력은 입력보다 **항상 클럭 한 주기 뒤**에 나타난다.

  모드 전환 시 튀는 값은 `mode`가 ALU2에 먼저 도달하고 레지스터 값은 아직 이전 것이라,
  **새 모드 + 옛 데이터** 조합이 잠깐 계산되기 때문이다.
  다음 클럭 상승에서 레지스터가 갱신되면 정상값이 나온다.

- **[메모]** 조합 논리만 있던 Project 1~5와 달리, 여기서부터는 **파형을 볼 때 클럭 기준으로
  읽어야 한다.** 클럭 상승 직후의 값이 유효한 값이다.

---

## 재검토에서 확인한 사항

### R01 · `alu_Nbit`의 `cout`이 어디에도 연결되지 않음

`Top_module.v`의 ALU0·ALU1·ALU2 인스턴스 모두 `.cout`을 연결하지 않았다.
```verilog
alu_Nbit #(.N(4)) ALU0(
    .a(alu0_a), .b(alu0_b), .result(alu0_reg0), .mode(mode), .cin(1'b0)
);   // .cout 없음
```
`result`가 `[N:0]`(5비트)로 캐리를 포함하므로 기능상 문제는 없다.
다만 Project 5에서 `cout`이 래치로 남는 문제가 있었는데, 여기서는 그 신호를 쓰지 않아
문제가 드러나지 않는다.

### R02 · `register_Nbit`의 폭 관례가 다르다

```verilog
module register_Nbit #(parameter N=4)(
    input  [N:0] d,          // N=4 → 5비트
    output reg [N:0] q
);
```
`N=4`인데 실제 폭은 5비트다. 다른 모듈(`alu_Nbit`의 `a`, `b`)은 `[N-1:0]`이라 `N=4`가 4비트다.
**같은 `N`이 모듈에 따라 다른 폭을 의미한다.** 지금은 폭이 우연히 맞아떨어지지만
나중에 폭을 바꿀 때 혼란의 원인이 된다.

### R03 · `$random % 16`

```verilog
ALU0_a = $random % 16;
```
`$random`은 부호있는 32비트라 `% 16`은 **−15 ~ 15**를 낸다.
`reg [3:0]`에 대입하면서 하위 4비트만 남아 결과적으로 0~15가 되므로 동작은 맞지만,
의도가 드러나지 않는다. `$random & 4'hF` 또는 그냥 `$random`이 명확하다.

### R04 · 자동 판정이 없음

`$monitor`로 값만 출력한다. 파이프라인이 있어 기대값 계산에 한 클럭 지연을 고려해야 하지만,
이전 입력을 저장해두고 비교하면 self-checking이 가능하다.

---

## 교훈

1. **경로 오타는 컴파일 자체를 막는다.** `-` 와 `_` 를 눈으로 구분하기 어려우니
   파일을 옮기거나 이름을 바꾼 뒤에는 `.f`를 반드시 다시 확인한다 (E01)
2. **`.f` 파일의 경로 기준을 프로젝트마다 통일한다.** 실행 디렉토리가 달라지면 매번 헷갈린다
3. **`if`/`else`의 `begin`~`end` 짝을 확인한다.** `else`가 블록 안에 들어가면 문법 오류다 (E02)
4. **파이프라인이 들어가면 출력이 한 클럭 늦는 것이 정상이다.** 파형을 클럭 기준으로 읽는다 (N01)
5. **같은 파라미터 이름이 모듈마다 다른 폭을 뜻하지 않게 한다** (R02)
