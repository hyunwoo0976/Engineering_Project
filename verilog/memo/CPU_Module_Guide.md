# Project10에서 Project11까지: CPU 모듈 해설

휴대폰으로 읽는 RTL 구조·동작·변경점 안내서

작성 기준: 2026-10-28의 로컬 소스. 두 프로젝트의 `src_mini_CPU`와 빌드 목록 `F_file/CPU.f`를 대조했다. 이 문서는 설명 자료이며 RTL은 수정하지 않았다. 다만 Project11 회귀는 작성 중 현재 소스로 한 번 다시 실행해 결과를 20장에 적었다. GitHub의 과거 버전과 로컬 변경본은 다를 수 있다.

구성: 1~13장은 Project10의 모든 모듈, 14~21장은 Project11에서 추가·변경된 기능과 그 이유·예시·검증, 22장은 P10 테스트벤치, 23장은 면담 대비 설명, 24장은 두 프로젝트의 전체 파일 대조표다.

## 01. 먼저 전체 그림 잡기

**Project10은 정수 5단 파이프라인 CPU에 여러 클럭이 걸리는 부동소수점 연산기를 연결한 설계다. Project11은 이 구조를 이어받아 FPU의 수 표현·반올림·특수값 처리와 검증 환경을 확장한 설계다.**

읽는 순서: 전체 흐름 → PC와 디코더 → 레지스터와 ALU → 해저드와 포워딩 → FPU 내부 → Project11 변경점. 처음에는 각 모듈 제목의 한 줄 역할만 읽고, 두 번째에 원리와 예시를 읽어도 된다.

### 같은 이름을 가진 모듈과 인스턴스

`Register_file`은 회로의 설계도 이름이다. `u_Regfile`과 `u_FPU_Regfile`은 그 설계도로 만든 서로 다른 두 회로다. 둘 다 `mem[0:31]`이라는 내부 이름을 사용하더라도 저장 공간은 공유되지 않는다. 정수 x3와 부동소수점 f3는 별개다.

`W=32`는 주로 데이터 폭이다. 하지만 이 프로젝트에는 32비트 명령어·FP32·고정 비트 위치가 많아서 W만 바꾼다고 64비트 CPU가 되지는 않는다.

### 정수 명령어 한 개의 여행

1. **IF: 가져오기.** PC가 Instruction_Memory에서 명령어를 선택한다. PC_Adder는 순차 주소 PC+4를 준비한다.
2. **ID: 해석하기.** Main_Decoder가 명령 종류와 레지스터 번호를 구분한다. Register_file에서 값을 읽고 ImmGen에서 즉시값을 만든다.
3. **EX: 실행하기.** port_MUX가 최신 피연산자를 고르고 ALU가 연산·주소 계산을 한다. 분기와 JALR의 목적지도 결정한다.
4. **MEM: 메모리 접근.** load는 Data_Memory를 읽고 store는 쓴다. 일반 ALU 결과는 이 단계를 통과한다.
5. **WB: 되쓰기.** CPU_MUX가 메모리 데이터 또는 연산 결과를 골라 목적 레지스터에 기록한다.

예를 들어 `add x3,x1,x2`에서 x1=7, x2=5라면 최종적으로 x3=12가 된다. 같은 순간 다른 명령어들은 각각 다른 단계에 있을 수 있다. 5단이라는 말은 다섯 명령어가 같은 레지스터 값을 마음대로 동시에 바꾼다는 뜻이 아니다. 각 단계 사이 레지스터가 자기 명령어의 데이터와 제어 신호를 함께 보관한다.

### 명령어 종류별 경로

- **ADD:** 정수 레지스터 → 포워딩·입력 선택 → ALU → MEM 통과 → 정수 레지스터.
- **LW:** 정수 Rs1+즉시값으로 주소 계산 → Data_Memory 읽기 → 정수 Rd.
- **SW:** 정수 Rs1+즉시값은 주소, 정수 Rs2 값은 저장 데이터 → Data_Memory 쓰기. WB 레지스터 쓰기는 없다.
- **FLW:** 주소는 정수 Rs1로 계산하지만 읽은 데이터는 FP 레지스터에 기록한다.
- **FSW:** 주소는 정수 Rs1로 계산하고 저장 데이터는 FP Rs2에서 가져온다.
- **FADD/FSUB/FMUL:** FP 레지스터 → FPU 파이프라인 → 지연시킨 Rd·쓰기 제어와 재결합 → FP 레지스터.
- **BEQ 등:** ALU 비교 결과 → PCSrc 판단 → PC_MUX 주소 선택. 이미 가져온 잘못된 경로의 명령은 flush한다.

### 제어 신호를 읽는 법

- `RegWrite` / `FRegWrite`: 정수 / FP 레지스터에 쓸 것인가.
- `MemRead` / `MemWrite`: 데이터 메모리를 읽을 것인가 / 쓸 것인가.
- `MemtoReg`: WB에서 메모리 읽기값을 선택할 것인가.
- `ALUsrc`: ALU B 입력에 즉시값을 사용할 것인가.
- `uses_Rs1/Rs2`, `uses_FRs1/FRs2`: 명령어가 해당 정수·FP 피연산자를 실제로 사용하는가.
- `PCWrite`: PC를 갱신할 수 있는가. 0이면 PC를 유지한다.
- `stall`: 단계 레지스터의 기존 값을 유지한다. `flush`: 제어·데이터를 0으로 만들어 그 단계의 작업을 무효화한다.
- `valid`: 해당 결과가 실제 요청에 대응하는 유효한 값인가. 데이터가 0인지와는 별개다.

### 조합회로와 순차회로

조합회로는 입력이 바뀌면 계산 결과가 바뀐다. PC_Adder, ALU, 대부분의 MUX가 해당한다. 순차회로는 클럭에서 값을 저장한다. PC_reg와 파이프라인 레지스터가 해당한다. `always @(posedge clk)`에서 enable이 0일 때 대입하지 않고 값을 유지하는 것은 플립플롭의 유지 동작이다. 조합 always 블록에서 일부 경우 대입을 빠뜨려 생기는 래치와 구분한다.

`<=`로 같은 클럭에서 갱신하는 레지스터들은 이전 값을 읽는다. 따라서 IF/ID, ID/EX 등을 한 always 블록처럼 생각해도 값이 한 클럭에 끝까지 관통하지 않는다. 이것이 파이프라인을 만드는 핵심이다.

## 02. Project10: 최상위 모듈

### Pipeline_CPU → 모든 CPU 단계와 FPU를 연결하는 실제 최상위 회로

> 소스: P10/src_mini_CPU/TOP_module/Pipeline_CPU.v · L2-533 · 활성 연결

**입출력·위치:** clk/reset을 받아 current_pc, current_inst, wb_data, wb_rd, 정수·FP 쓰기 여부와 OF/UF 관찰 신호를 내보낸다. CPU.f가 선택하는 실제 CPU는 이 모듈이다.

**원리:** IF/ID에는 PC와 명령어를, ID/EX에는 디코딩 결과·피연산자·주소·제어를 저장한다. EX/MEM과 MEM/WB에도 결과만 아니라 Rd와 쓰기 신호를 함께 넘긴다. FPU는 일반 ALU보다 늦게 끝나므로 FPU_Check와 FPU_shadow_reg가 유효 시점과 목적지 정보를 맞춘다.

**읽을 포인트:** 데이터가 맞아도 Rd나 RegWrite가 다른 명령어의 것이면 잘못된 레지스터에 기록된다. 그래서 데이터 경로와 제어 경로를 항상 한 쌍으로 따라가야 한다. 관찰용 current_pc는 IF의 PC이고 wb_data는 WB의 결과이므로 같은 순간의 두 값이 같은 명령어 소속이라고 보면 안 된다.

### FPU → FP32 덧셈·뺄셈·곱셈을 파이프라인으로 계산하는 상위 회로

> 소스: P10/src_mini_CPU/TOP_module/FPU.v · L1-129 · 활성 연결

**입출력·위치:** IN_A/IN_B, op, rm, FPU_en, clk/reset → result_out, sign, ZF, OF, UF, error. EX에서 호출된다.

**원리:** 입력을 등록하고 sign/exponent/fraction으로 분리한다. FADD_core와 FMUL_core가 각각 계산한 뒤 지연된 op에 따라 결과를 고른다. rm도 계산 데이터와 함께 지연해야 다른 명령어의 반올림 모드가 섞이지 않는다.

**시간:** 입력 등록 1개, 코어 내부 s2~s6의 등록 5개, 최종 출력 등록 1개가 있다. 요청을 받은 에지를 1번째로 세면 7번째 에지 직후 결과가 나온다. 첫 에지와 마지막 에지 사이 시간은 6주기다. '7단'과 '6주기 후'는 기준점을 명시해야 비교할 수 있다. Project10에도 이 등록 구조가 있으므로 Project11을 단순히 '한 단 더 추가한 FPU'라고 설명하면 부정확하다.

**범위:** P10은 정상수 중심의 기본 연산 경로다. NaN·subnormal·모든 반올림 모드를 완전하게 처리하는 설계로 설명하면 안 된다.

## 03. Project10: PC와 점프

### PC_Adder → 현재 PC에 4를 더해 순차 실행할 다음 주소를 만든다

> 소스: P10/src_mini_CPU/PC/PC_Adder.v · L1-6 · 활성 연결

**입력 → 출력:** current_pc → next_pc. 핵심 식은 `next_pc = current_pc + 32'd4`다. 저장 기능이 없는 조합 가산기다.

**왜 4인가:** 현재 설계의 명령어 하나가 32비트=4바이트이고 PC는 바이트 주소다. PC가 0x20이면 순차 다음 주소는 0x24다. 분기 여부는 여기서 판단하지 않는다. 만든 후보를 PC_MUX에 전달한다.

### PC_reg → 현재 명령어 주소를 저장하고 허용된 클럭에서 갱신한다

> 소스: P10/src_mini_CPU/PC/PC_reg.v · L1-15 · 활성 연결

**입력 → 출력:** next_pc, PCWrite, clk/reset → pc. reset 상승 시 비동기적으로 0이 된다. reset이 아니면 clk 상승에서 PCWrite=1일 때만 next_pc를 저장한다.

**예:** PC=0x20인데 load-use 해저드가 나서 PCWrite=0이면 PC가 그대로 유지된다. PC_Adder가 0x24를 계산하고 있어도 저장 허가가 없으므로 다음 명령어로 진행하지 않는다.

### PC_Target → 분기 명령어의 PC에 즉시값을 더해 분기 목적지를 만든다

> 소스: P10/src_mini_CPU/PC/PC_Target.v · L1-7 · 활성 연결

**입력 → 출력:** EX의 pc, imm → Target. `Target = pc + imm`인 조합회로다.

**예:** 분기 명령어 주소가 0x40이고 오프셋이 -8이면 목적지는 0x38이다. PC_Adder는 +4 고정 후보, PC_Target은 명령어에 따라 달라지는 오프셋 후보를 만든다는 차이가 있다. 조건 충족 판단은 PCSrc가 한다.

### PCSrc → ALU 비교 신호로 조건 분기를 할지 결정한다

> 소스: P10/src_mini_CPU/PC/PCSrc.v · L1-9 · 활성 연결

**입력 → 출력:** ZF, sign, is_BEQ/BNE/BLT/BGE → PCSrc. BEQ는 ZF, BNE는 !ZF, BLT는 sign, BGE는 !sign을 사용한다.

**예:** 두 값의 차이가 0이면 ZF=1이므로 BEQ가 분기한다. 이 모듈은 주소 계산이 아니라 '그 주소를 선택할 것인가'를 판단한다.

**현재 코드의 한계:** BLT/BGE가 뺄셈 결과의 부호만 사용한다. signed overflow가 발생하는 경계값에서는 정확한 signed 비교와 다를 수 있다. 완전한 signed 비교에는 피연산자 부호 또는 overflow 보정이 필요하다.

### PC_MUX → 순차 주소·분기·점프 후보 중 실제 다음 PC를 고른다

> 소스: P10/src_mini_CPU/MUX/PC_MUX.v · L1-23 · 활성 연결

**입력 → 출력:** next_pc, Target, Early_Target, JALR_Target와 제어 신호 → final_next_pc.

**현재 우선순위:** EX 조건 분기 → ID의 JAL → EX의 JALR → 순차 PC+4. 선택한 값은 PC_reg로 간다. 주소를 계산하는 세 가산기를 이 모듈과 혼동하지 않는다.

**읽을 포인트:** 서로 다른 단계의 점프 후보가 동시에 켜질 때는 코드의 우선순위가 실제 동작이다. 나이가 더 오래된 EX 명령을 항상 우선한다고 막연히 설명하면 안 된다. ID JAL과 EX JALR의 동시 상황은 별도 검토할 지점이다.

### Early_Jump_Unit → JAL의 목적지를 ID에서 미리 계산한다

> 소스: P10/src_mini_CPU/Early_Jump_Unit.v · L1-25 · 활성 연결

**입력 → 출력:** is_JAL, ID pc, Imm → Target, PCSrc. JAL이면 pc+Imm와 선택 신호 1을 만든다. 아니면 선택 신호를 내린다.

**원리:** JAL은 레지스터 비교 결과를 기다릴 필요가 없다. 명령어의 PC와 즉시값만 있으면 목적지를 알 수 있어 ID에서 방향을 바꿀 수 있다. 되돌아올 주소 PC+4의 Rd 기록은 별도 데이터 경로가 담당한다.

### JALR_Jump_Unit → 레지스터 기반 점프 주소를 만들고 최하위 비트를 0으로 한다

> 소스: P10/src_mini_CPU/JALR_Jump_Unit.v · L1-10 · 활성 연결

**입력 → 출력:** 포워딩된 Rs1_data, Imm → JALR_Target. 핵심은 `(Rs1_data + Imm) & ~32'd1`이다.

**예:** 합이 0x105라면 목적지는 0x104다. Rs1 최신값이 필요하므로 EX의 포워딩 결과를 사용한다. 목적지 계산과 링크값 PC+4 기록은 다른 일이다. 현재 port_MUX의 JALR 경로는 Rs1+imm를 ALU에도 넣으므로, JALR 링크값 기록까지 맞는지는 별도 확인해야 한다.

## 04. Project10: 명령어와 디코딩

### Instruction_Memory → PC가 가리키는 32비트 명령어를 읽는다

> 소스: P10/src_mini_CPU/Instruction_Memory.v · L1-13 · 활성 연결

**구조:** `mem[0:127]`에 128개 명령어를 저장한다. 초기 블록의 `$readmemh`가 P10의 memo/program.txt에서 16진수 값을 읽는다. 읽기는 `instruction = mem[pc[8:2]]`인 조합 경로다.

**비트 자르는 이유:** PC=0,4,8은 각각 mem[0], mem[1], mem[2]를 뜻한다. 4바이트 단위 인덱스로 바꾸려고 하위 2비트를 버린다. 텍스트 16진수 8자리×4비트=32비트라는 사실은 한 명령어의 폭을 설명하고, PC를 2비트 자르는 직접 이유는 바이트 주소를 워드 인덱스로 바꾸기 위해서다.

**주의:** pc[8:2]만 쓰므로 512바이트 범위를 넘는 상위 주소 비트는 구분하지 않는다. initial 파일 로드는 시뮬레이션 초기화이며 일반적인 매 클럭 파일 읽기가 아니다. FPGA 메모리 초기화 지원은 합성 도구·메모리 구현에 달려 있다.

### Main_Decoder → 명령어 비트를 나누고 실행 경로와 쓰기 제어를 정한다

> 소스: P10/src_mini_CPU/Main_Decoder.v · L1-150 · 활성 연결

**입력 → 출력:** instruction → rs1/rs2/rd, funct3/funct7, ALUOp, 메모리·레지스터 제어, 명령 종류와 피연산자 사용 표시.

**구조:** opcode=[6:0], rd=[11:7], funct3=[14:12], rs1=[19:15], rs2=[24:20], funct7=[31:25]로 나눈다. SW의 [11:7]은 실제 Rd가 아니므로 RegWrite를 내리고 immediate 생성에서 재조합한다. 필드가 그 위치에 있다는 것과 실제로 그 레지스터를 읽고 쓴다는 것은 다르다.

**예:** FLW는 정수 레지스터를 주소원으로 쓰고 결과는 FP 레지스터에 쓴다. 따라서 uses_Rs1과 FRegWrite가 중요하다. FSW는 정수 주소원과 FP 저장값을 함께 쓴다.

**범위:** opcode를 인식하는 것만으로 해당 ISA의 모든 funct 조합이 지원되는 것은 아니다. FP comparison을 표시하는 분기가 있어도 FPU_Control·FPU에 해당 연산이 없으면 완성된 비교 명령 지원이 아니다.

### ImmGen → 흩어져 있는 즉시값 비트를 모아 32비트 부호 확장 값을 만든다

> 소스: P10/src_mini_CPU/ImmGen.v · L1-27 · 활성 연결

**입력 → 출력:** inst → imm_out. I형·S형·B형·J형의 서로 다른 인코딩을 처리한다.

**원리:** I형은 inst[31:20], S형은 inst[31:25]와 inst[11:7]을 이어 붙인다. B/J형은 규칙에 맞게 재배열하고 최하위에 0을 붙인다. 최상위 부호비트를 복제해 음수 오프셋도 32비트 덧셈에서 올바르게 쓸 수 있도록 한다.

**예:** 12비트 -4는 0xFFC이고 32비트 부호 확장하면 0xFFFFFFFC다. 주소 0x20에 이를 더하면 0x1C가 된다. 이 RTL에는 U형 즉시값의 완전한 처리 경로가 없다.

## 05. Project10: 저장장치와 단계 레지스터

### Register_file → 레지스터 32개의 값을 보관하고 피연산자를 읽는다

> 소스: P10/src_mini_CPU/Register/Register_file.v · L1-28 · 활성 연결

**입출력:** we/we_addr/we_data로 1개 레지스터를 쓰고, Rs1_addr/Rs2_addr/Rt_addr로 읽는다. clk 상승에 쓰고 reset 상승에 모든 원소를 0으로 만든다. 읽기는 조합 경로다.

**P10 동작:** 주소 0은 항상 0을 읽고 쓰기가 금지된다. Rs1/Rs2는 같은 사이클에 쓰는 주소와 읽는 주소가 같으면 저장 배열 대신 we_data를 바로 반환한다. 이것은 WB→ID 우회다. Rt 읽기에는 같은 우회식이 없다.

**중요:** 이 모듈을 정수용과 FP용으로 두 번 만들었다. P10에서는 두 인스턴스 모두 0번 쓰기를 막으므로 FP f0도 0으로 고정되는 제약이 있다. P11의 ZERO_REGISTER가 이 차이를 해결한다. 두 레지스터 파일을 하나의 저장 공간으로 합친 것이 아니다.

### Data_Memory → load/store의 32비트 데이터를 저장한다

> 소스: P10/src_mini_CPU/Register/Data_Memory.v · L1-22 · 활성 연결

**구조:** 1024개 워드 배열이다. memo/data.mem을 초기 로드한다. clk 상승에서 MemWrite가 켜지면 `mem[addr >> 2]`에 write_data를 저장한다. MemRead=1이면 해당 워드를 조합 읽기하고 아니면 0을 출력한다.

**예:** 바이트 주소 12는 3번 워드다. SW의 주소 계산값과 저장 데이터는 서로 다른 신호다. ALU에는 주소 오프셋을 넣지만 메모리 write_data에는 원래 Rs2의 최신값을 보내야 한다.

**범위:** byte enable이나 byte/halfword 선택·정렬 예외가 구현된 일반 RAM 컨트롤러가 아니다. 주소가 배열 범위를 벗어나거나 비정렬이면 현재 코드가 이를 자동으로 올바르게 처리한다고 가정할 수 없다.

### Pipe_reg_1clk → 입력 묶음을 다음 클럭의 출력으로 저장한다

> 소스: P10/src_mini_CPU/Register/Pipe_reg_1clk.v · L1-15 · 활성 연결

**동작:** clk 상승마다 Q<=D, 비동기 reset 시 Q=0. W는 묶음 전체의 폭이다.

**예:** `{sign, exponent, fraction}` 같은 묶음을 같은 레지스터로 넘기면 세 필드가 서로 같은 연산에 속한 채 진행한다. 한 단계 지연이라는 것은 입력을 샘플하는 에지 직후 Q가 그 값으로 바뀐다는 뜻이다.

### Pipe_reg_1clk_en → enable이 켜질 때만 한 단계 데이터를 저장한다

> 소스: P10/src_mini_CPU/Register/Pipe_reg_1clk_en.v · L1-14 · 활성 연결

**동작:** 비동기 reset이 최우선이며 en=1인 clk 상승에서만 Q<=D다. en=0이면 Q를 유지한다.

**역할:** 값이 필요 없는 사이클의 레지스터 갱신을 줄인다. P11의 operand isolation에서 중요하다. 입력이 그대로 유지되면 뒤 조합회로의 불필요한 변화도 줄일 수 있지만, 이 코드 자체가 물리적 클럭 트리를 차단하는 clock gating은 아니다.

### Pipe_reg_1clk_control → stall과 flush가 가능한 CPU 단계 레지스터

> 소스: P10/src_mini_CPU/Register/Pipe_reg_1clk_control.v · L1-17 · 활성 연결

**우선순위:** reset 또는 flush → 0 저장, 그다음 !stall → D 저장, 나머지 → 유지. reset은 비동기지만 flush는 감지 목록에 없어서 정상적으로 clk 상승에서 적용한다.

**예:** load 결과를 기다릴 때 IF/ID는 stall로 명령을 보관하고 ID/EX는 flush로 bubble을 넣는다. '둘 다 멈춤'이 아니다. 앞 명령은 MEM/WB로 계속 가서 필요한 결과를 만들어야 한다.

### FPU_shadow_reg → FPU의 늦은 결과에 맞춰 명령어의 목적지·제어를 지연한다

> 소스: P10/src_mini_CPU/Register/FPU_shadow_reg.v · L1-51 · 활성 연결

**구조:** W비트 묶음을 7칸 배열로 이동시킨다. EX_is_FPU가 1이면 D를 첫 칸에 넣고 아니면 bubble 0을 넣는다. FPU_Valid가 1일 때 마지막 칸의 정보를 출력한다.

**원리:** FPU 결과가 나올 때 EX의 Rd는 이미 다른 명령어의 것일 수 있다. 그러므로 FP 요청 당시의 Rd, RegWrite/FRegWrite 등 '이 결과를 어디에 쓸지'를 함께 지연해야 한다. 일반 정수 경로는 D 직접 전달과 A 보관 레지스터를 이용해 별도로 선택한다.

**현재 연결에서 볼 점:** 이 묶음에는 EX_FPU_OF/UF도 들어 있다. 이 두 신호는 이미 FPU 계산 완료 쪽 출력이므로 요청 메타데이터와 동일하게 지연시키는 연결이 올바른 결과·플래그 정렬을 보장하는지는 별도 검증이 필요하다. Rd 지연의 목적과 계산 결과 플래그 지연의 목적을 구분한다.

## 06. Project10: 정수 ALU

### ALU_Control → 명령어의 연산 종류를 ALU 내부 선택 코드로 바꾼다

> 소스: P10/src_mini_CPU/ALU/ALU_Control.v · L1-62 · 활성 연결

**입력 → 출력:** ALUOp, Funct3, funct7_bit30 → 4비트 ALU_Control. load/store·주소 계산은 ADD, 분기 비교는 SUB, R형은 funct3와 bit30으로 세부 연산을 고른다.

**코드표:** AND=0000, OR=0001, XOR=0011, ADD=0010, SUB=0110, SLL=1000, SRL=1001, SRA=1010. 현재 I형 세부 지원은 ADDI와 ANDI 중심이다. opcode가 I형이라고 모든 즉시값 ALU 연산이 처리되는 것은 아니다.

### ALU → 논리·덧셈/뺄셈·시프트 연산기를 묶어 최종 정수 결과를 만든다

> 소스: P10/src_mini_CPU/ALU/ALU.v · L1-40 · 활성 연결

**입력 → 출력:** A, B, ALU_Control → Result, ZF, sign. logical_group, calculate_group, shift_group가 계산하고 ALU_MUX가 선택한다.

**원리:** 하드웨어는 여러 후보 연산을 병렬로 만들고 선택할 수 있다. 소프트웨어처럼 반드시 AND를 끝낸 다음 ADD를 수행하는 순서가 아니다. ZF와 sign은 뺄셈을 이용한 분기 판단에도 사용된다.

### logical_group → 비트별 AND·OR·XOR를 계산한다

> 소스: P10/src_mini_CPU/ALU/logical_group.v · L1-21 · 활성 연결

**원리:** 같은 비트 위치끼리 연산한다. 결과는 W비트다. `&`와 `|`를 `&&`, `||` 같은 전체 참/거짓 연산과 혼동하지 않는다.

**예:** A=1100, B=1010이면 AND=1000, OR=1110, XOR=0110이다. 최종적으로 어떤 결과를 CPU가 사용할지는 ALU_Control과 ALU_MUX가 결정한다.

### calculate_group → 덧셈·뺄셈과 0·부호 판정을 만든다

> 소스: P10/src_mini_CPU/ALU/calculate_group.v · L1-25 · 활성 연결

**원리:** W+1비트 중간값으로 A+B 또는 A-B를 계산한 뒤 하위 W비트를 결과로 쓴다. 결과가 0이면 ZF=1, 결과 최상위 비트가 sign이다.

**예:** 9-9=0이면 BEQ에 필요한 ZF=1이 된다. 결과 sign=1이라는 사실만으로 모든 signed 비교가 정확한 것은 아니다. 정해진 W비트 범위에서 overflow가 생길 수 있기 때문이다.

### shift_group → 논리 왼쪽·논리 오른쪽·산술 오른쪽 시프트를 수행한다

> 소스: P10/src_mini_CPU/ALU/shift_group.v · L1-24 · 활성 연결

**입력 → 출력:** A와 B[4:0]의 이동량, ALU_Control → shift_result. 32비트 데이터이므로 이동량은 하위 5비트다.

**예:** 0x80000000을 1비트 SRL하면 0x40000000이고 SRA하면 0xC0000000이다. SRA는 `$signed(A) >>> shamt`로 왼쪽 빈자리를 부호비트로 채운다. `>>>`만 쓰고 왼쪽 피연산자의 signed 속성을 빼먹으면 기대와 달라질 수 있다.

### ALU_MUX → 세 연산 그룹 중 ALU_Control에 해당하는 결과를 고른다

> 소스: P10/src_mini_CPU/ALU/ALU_MUX.v · L1-23 · 활성 연결

**원리:** 논리 연산 코드는 logic_result, ADD/SUB는 calculate_result, 시프트는 shift_result를 선택한다. 정의되지 않은 코드는 0을 출력한다.

**구분:** ALU_Control은 '어떤 연산인가'를 결정하고 ALU_MUX는 '그 연산 결과 선을 연결'한다. MUX는 새 연산을 수행하는 장치가 아니라 선택기다.

## 07. Project10: 피연산자와 결과 선택

### port_MUX → 정수·FP·포워딩·즉시값을 조합해 EX 입력과 저장 데이터를 고른다

> 소스: P10/src_mini_CPU/MUX/port_MUX.v · L1-40 · 활성 연결

**입력 → 출력:** EX_A/B, EX_F_A/B, MEM/WB 값, forwarding 코드, 즉시값, pc, 명령 종류 → EX_in_A/B와 EX_read_data_B.

**순서:** 먼저 정수/FP 원본을 고르고 MEM·WB 우회값을 적용한다. 이후 ALUsrc나 점프에 따라 ALU B를 imm 또는 4로 바꾼다. store 데이터는 주소용 imm와 분리해 최신 B 값을 유지한다. JAL은 A=PC, B=4로 링크값을 만든다.

**예:** `fsw f2,8(x1)`은 EX_in_A=x1, EX_in_B=8, EX_read_data_B=f2다. 이 셋을 모두 FP 값이나 모두 정수 값으로 선택하면 틀린다. 현재 JALR은 B=imm이므로 링크값 PC+4 지원은 별도 검토 지점이다.

### FPU_MUX → FPU 결과가 유효한 사이클에만 결과를 통과시킨다

> 소스: P10/src_mini_CPU/MUX/FPU_MUX.v · L1-15 · 활성 연결

**식:** `EX_FPU_Result = FPU_Valid ? FPU_Result : 0`이다. 파이프라인 도중 떠 있는 값을 유효한 결과처럼 쓰지 않도록 한다.

**주의:** 이 모듈은 계산이 끝났는지 스스로 알아내지 않는다. FPU_Valid가 정확한 시점에 와야 한다. 결과가 0이라는 것과 valid가 0이라는 것은 다른 의미다.

### Result_MUX → EX/MEM으로 보낼 정수 결과와 FPU 결과를 고른다

> 소스: P10/src_mini_CPU/MUX/Result_MUX.v · L1-8 · 활성 연결

**식:** FPU_Valid=1이면 FPU_Result, 아니면 ALU_Result를 선택한다. 이때 ALU_Result와 제어 정보는 FPU_shadow_reg를 거친 경로와 맞아야 한다.

**필요성:** 정수와 FP 계산기는 별개지만 뒤쪽 MEM/WB 경로를 함께 사용한다. 같은 사이클에 둘의 결과를 한 선으로 모두 전달할 수 없으므로 선택과 해저드 제어가 필요하다.

### CPU_MUX → WB에서 메모리 읽기값 또는 연산 결과를 선택한다

> 소스: P10/src_mini_CPU/MUX/CPU_MUX.v · L1-17 · 활성 연결

**식:** MemtoReg=1이면 mem_read_data, 아니면 Result를 OUT으로 보낸다.

**예:** LW/FLW는 메모리에서 읽은 값을, ADD/FADD는 계산 결과를 사용한다. 어느 레지스터 파일에 기록할지는 이 MUX가 아니라 RegWrite/FRegWrite가 결정한다.

## 08. Project10: 해저드 제어

**먼저 원리:** `lw x1,0(x2)` 바로 뒤에 `add x3,x1,x4`가 오면, ADD가 EX에 도달할 때 load 데이터가 아직 준비되지 않을 수 있다. 반면 바로 앞 ADD의 ALU 결과는 MEM 단계에 있어 우회할 수 있다. '기다릴 문제'와 '이미 있는 값을 바로 가져올 문제'를 구분한다.

### Hazard_Unit → 정수와 FP 해저드 판단을 묶어 파이프라인 제어를 만든다

> 소스: P10/src_mini_CPU/Hazard/Hazard_Unit.v · L1-52 · 활성 연결

**구성:** CPU_Hazard와 FPU_Hazard의 판단을 Hazard_Combine으로 합친다. PCWrite, IF/ID·ID/EX의 stall/flush, FP 완료 유효 신호를 CPU에 보낸다.

**역할:** 직접 연산하거나 데이터를 저장하는 곳이 아니다. 어떤 단계가 진행해도 되는지를 결정하는 제어 묶음이다. 버그를 볼 때는 최종 stall만 보지 말고 CPU측 조건인지 FP측 조건인지 나누어 본다.

### CPU_Hazard → 분기·점프의 잘못된 경로를 비우고 정수 load-use를 정지시킨다

> 소스: P10/src_mini_CPU/Hazard/CPU_Hazard.v · L1-34 · 활성 연결

**현재 동작:** EX 분기/JALR이면 앞 단계들을 flush하고, ID JAL이면 IF/ID를 flush한다. EX_MemRead와 ID_RegWrite, 목적·소스 번호 일치 등을 검사해 load-use라 판단하면 PC와 IF/ID를 멈추고 ID/EX에 bubble을 넣는다.

**제약:** ID_RegWrite를 조건에 사용하고 실제 피연산자 사용 마스크를 모두 활용하지 않으므로 store나 branch처럼 정수 레지스터를 읽지만 쓰지 않는 소비자의 load-use를 놓칠 수 있다. '모든 RAW 해저드를 해결한다'고 설명할 수는 없다.

### FPU_Check → 진행 중인 FP 명령어의 목적지와 완료 시점을 추적한다

> 소스: P10/src_mini_CPU/Hazard/FPU_Check.v · L1-80 · 활성 연결

**구조:** `{Rd,valid}` 6비트 항목 7개를 매 클럭 이동시킨다. EX_is_FPU이면 새 항목을 넣고 아니면 0을 넣는다. Rd[5]의 valid가 FPU_6clk, Rd[6]의 valid가 FPU_Valid다.

**원리:** ID의 FP 소스 또는 FSW의 FP 저장 소스와 진행 중인 Rd를 비교한다. 필요한 값이 아직 계산 중이면 FPU_Left에 남은 대기량을 반영한다. 여러 일치가 있으면 큰 대기량을 택한다. 이 장치는 데이터 그 자체가 아니라 '어느 레지스터의 결과가 언제 나오는가'를 추적한다.

### FPU_Hazard → FP 의존성과 결과 합류 시점에 맞춰 CPU 진행을 조절한다

> 소스: P10/src_mini_CPU/Hazard/FPU_Hazard.v · L1-59 · 활성 연결

**동작:** FPU_Check의 남은 대기량이 있으면 앞단을 정지시키고 ID/EX를 비운다. FPU_6clk에서도 결과가 합류할 공간을 확보하기 위해 stall/flush를 요청한다. FLW 바로 뒤의 FP 연산 의존성도 검사한다.

**예:** `fadd f3,f1,f2` 다음에 `fmul f4,f3,f5`가 오면 f3가 나오기 전에 FMUL을 시작하면 안 된다. 계산이 끝나기를 기다린 후 forwarding 경로로 최신 f3를 받을 수 있다.

**범위:** 모든 명령 종류·레지스터 뱅크·WAW 상황을 일반적으로 처리하는 동적 스케줄러가 아니다. 현재 비교 조건으로 다루는 의존성 범위를 읽어야 한다.

### Hazard_Combine → CPU·FPU의 stall/flush 요구를 최종 제어로 합친다

> 소스: P10/src_mini_CPU/Hazard/Hazard_Combine.v · L1-19 · 활성 연결

**원리:** stall/flush는 양쪽 요청을 OR해 한쪽이라도 필요하면 적용한다. 일반 PCWrite는 CPU·FP 허가를 함께 고려하고, 코드의 점프 조건에서는 PC 갱신을 허용하는 우선 처리가 있다.

**예:** CPU는 진행 가능해도 FP 의존성이 남으면 앞단은 기다린다. 분기와 stall이 동시에 켜질 때는 합치는 식과 우선순위를 함께 확인해야 하며, 단순히 'stall이 언제나 최우선'인 구조가 아니다.

## 09. Project10: 포워딩

**예:** `add x3,x1,x2` 다음의 `sub x4,x3,x5`는 x3가 레지스터 파일에 써지기 전에 필요할 수 있다. MEM에 있는 최신 ADD 결과를 EX로 바로 보내면 WB까지 기다리지 않아도 된다. 같은 번호라도 x3와 f3는 서로 다른 뱅크다.

### Forwarding_Unit → 정수·FP 우회 판단기를 묶어 MEM/WB 선택 코드를 만든다

> 소스: P10/src_mini_CPU/Forwarding/Forwarding_Unit.v · L1-40 · 활성 연결

**구성:** CPU_Forwarding_Unit, FPU_Forwarding_Unit, Forwarding_Combine. 실제 데이터 선택은 port_MUX가 수행한다.

**읽는 법:** 이 모듈이 'MEM 값을 선택하라'고 알려주면 port_MUX가 MEM_value를 EX 입력에 연결한다. 판정기와 데이터 MUX는 역할이 다르다.

### CPU_Forwarding_Unit → 정수 소스가 MEM/WB 목적지와 같으면 최신값 우회를 요청한다

> 소스: P10/src_mini_CPU/Forwarding/CPU_Forwarding_Unit.v · L1-43 · 활성 연결

**조건:** 해당 단계의 RegWrite, Rd!=0, EX가 해당 Rs를 실제로 사용하는지, 레지스터 번호 일치를 본다. MEM 값이 WB보다 최신이면 MEM을 우선한다.

**코드:** 00=없음, 01=A와 B 모두, 10=A만, 11=B만. MEMtoEX_forward와 WBtoEX_forward를 각각 만든다. 이 비트값은 일반 표준이 아니라 이 설계의 약속이다.

### FPU_Forwarding_Unit → 정수 주소와 FP 데이터를 구분하여 우회한다

> 소스: P10/src_mini_CPU/Forwarding/FPU_Forwarding_Unit.v · L1-42 · 활성 연결

**원리:** FP 연산은 FP 쓰기 결과를, FLW 주소는 정수 쓰기 결과를, FSW는 정수 주소와 FP 저장값을 따로 매칭한다. EX_uses_Rs/FRs 표시와 MEM/WB의 뱅크별 쓰기 신호가 필요하다.

**예:** x2에 쓰는 명령과 f2를 읽는 명령은 번호가 같아도 의존성이 아니다. FP 레지스터 0은 유효한 데이터 레지스터이므로 정수 x0처럼 항상 우회를 제외하면 안 된다. P10 저장 배열의 f0 제한과 이 포워딩 정책은 구분한다.

### Forwarding_Combine → 현재 EX 명령의 종류에 맞는 우회 판단을 선택한다

> 소스: P10/src_mini_CPU/Forwarding/Forwarding_Combine.v · L1-12 · 활성 연결

**동작:** FPU/FLW/FSW이면 FP 관련 판단을, 나머지는 CPU 판단을 출력한다.

**필요성:** FP 메모리 명령은 주소는 정수, 데이터는 FP라는 혼합 형태다. 단순히 FRegWrite 한 비트로만 일반 정수 경로와 구분하기 어렵기 때문에 명령 종류를 기준으로 선택한다.

## 10. Project10: FP32를 읽는 기초와 공통 모듈

**32비트 배치:** [31] 부호 S, [30:23] 지수 E 8비트, [22:0] fraction F 23비트. 정상수는 `(-1)^S × (1 + F/2^23) × 2^(E-127)`이다. 저장되지 않은 앞자리 1을 hidden bit라고 한다.

**예:** 1.0=0x3F800000, 2.0=0x40000000, 3.0=0x40400000이다. FP 비트 패턴에 정수 +1을 한다고 실수 1.0을 더하는 것이 아니다. 정수 0x3F800001은 FP로 보면 1.0보다 조금 큰 값이다.

**덧셈:** 지수 맞추기 → 유효숫자 더하기/빼기 → 정규화 → 반올림 → 조립. **곱셈:** 부호 XOR → 유효숫자 곱 → 지수 합-127 → 정규화 → 반올림 → 조립.

### FPU_unpack → FP32 비트열을 부호·지수·fraction으로 분리한다

> 소스: P10/src_mini_CPU/FPU_common/FPU_unpack.v · L1-12 · 활성 연결

**입력 → 출력:** IN, FPU_en → SIGN, EXPO, FRAC. enable이 0이면 필드들을 0으로 만든다. 이 모듈 자체는 분류나 산술을 수행하지 않는다.

**예:** 0x3FC00000은 SIGN=0, EXPO=127, FRAC=0x400000이다. 정상수 해석에서 hidden bit를 붙이면 1.5다. hidden bit를 붙이는 작업은 뒤 코어에서 수행한다.

### FPU_Control → FP 명령어 필드를 ADD·SUB·MUL 코드와 rm으로 변환한다

> 소스: P10/src_mini_CPU/FPU_common/FPU_Control.v · L1-43 · 활성 연결

**입력 → 출력:** Funct7, Funct3, is_FPU → FPU_Control, rm, error. funct5=00000/00001/00010을 각각 ADD/SUB/MUL로 매핑하고 단정밀도 fmt를 검사한다. rm은 Funct3에서 전달한다.

**주의:** P10 Rounding에 실제로 구현된 반올림 동작은 별개다. rm 신호가 3비트라고 8개 모드가 지원되는 것은 아니다. error가 나더라도 상위 CPU가 이를 trap으로 처리하는 연결은 없다.

### MUX → P10의 ADD/SUB 결과와 MUL 결과·플래그를 고른다

> 소스: P10/src_mini_CPU/FPU_common/MUX.v · L1-29 · 활성 연결

**입력 → 출력:** ADD/MUL 결과와 OF/UF, 지연된 연산 선택 → Final_out 및 관련 표시. 단순 이름 MUX이지만 이 파일은 FPU_common의 최종 산술 경로 선택기다.

**예:** FMUL 요청의 데이터가 끝에 도달할 때 동일하게 지연한 op를 써야 MUL 출력을 선택한다. 현재 입력단 op를 그대로 쓰면 연속 ADD→MUL 같은 요청에서 결과를 뒤섞을 수 있다. P11 FPU에서는 이 파일을 직접 연결하지 않고 새 상위 선택 논리를 쓴다.

## 11. Project10: 부동소수점 덧셈·뺄셈

### FADD_core → 지수 정렬부터 반올림까지 FP 덧셈·뺄셈 단계를 연결한다

> 소스: P10/src_mini_CPU/FADD/FADD_core.v · L2-295 · 활성 연결

**원리:** P10은 fraction에 hidden 1과 하위 여유 24비트를 붙여 48비트로 계산한다. s2에서 지수 정렬, s3에서 가산/감산, s4에서 정규화 방향·이동량 결정, s5에서 이동과 지수 보정, s6에서 반올림·조립을 한다. sign·지수·모드도 함께 지연한다.

**예:** 1.5+0.25는 `1.1×2^0 + 1.0×2^-2`다. 작은 수를 `0.01×2^0`으로 정렬한 뒤 1.11×2^0=1.75를 얻는다. 지수를 맞추지 않고 저장 fraction만 더하면 전혀 다른 값이 된다.

### EXPO_SUB → 두 지수의 차이와 어느 피연산자를 이동할지 구한다

> 소스: P10/src_mini_CPU/FADD/EXPO_SUB.v · L1-30 · 활성 연결

**입력 → 출력:** EXPO_a/b → count, direction, doing_A/B, EXPO_big. 작은 지수 쪽 유효숫자를 오른쪽으로 지수 차이만큼 이동하도록 요청한다. 같은 지수이면 이동하지 않는다.

**예:** E_A=130, E_B=127이면 B를 3비트 오른쪽으로 이동하고 공통 지수는 130을 사용한다. 지수 자체를 작은 값에 맞추는 방식이 아니다.

### barrel_shifter → 지정된 비트 수만큼 유효숫자를 한 번에 이동한다

> 소스: P10/src_mini_CPU/FADD/barrel_shifter.v · L1-20 · 활성 연결

**입력 → 출력:** shift, count, direction, doing → SHIFT. doing=0이면 그대로, direction=1이면 오른쪽, 0이면 왼쪽이다. W=48 정렬과 W=49 정규화 양쪽에서 재사용한다.

**원리:** 한 클럭에 한 비트씩 움직이는 shift register와 다르다. 이는 조합 가변 이동기다. P10의 오른쪽 이동은 떨어져 나가는 비트를 잃는다. P11은 버린 비트의 OR를 최하위 sticky 정보로 보존하도록 바뀐다.

### Mode_Detector → 부호와 ADD/SUB 요청으로 실제 유효숫자 연산을 정한다

> 소스: P10/src_mini_CPU/FADD/Mode_Detector.v · L1-9 · 활성 연결

**식:** `eff_sub = sign_A ^ sign_B ^ mode`. mode는 ADD=0, SUB=1이다.

**예:** (+3)+(-2)는 크기끼리 빼야 한다. (+3)-(-2)는 크기끼리 더해야 한다. 명령 이름이 ADD라고 유효숫자 가산기에서 항상 덧셈을 하는 것은 아니다.

### Cond_Inverter → 뺄셈일 때 피연산자를 반전해 2의 보수 연산을 준비한다

> 소스: P10/src_mini_CPU/FADD/Cond_Inverter.v · L1-17 · 활성 연결

**원리:** eff_sub=1이면 입력 fraction을 비트 반전한다. 2의 보수 뺄셈은 A+~B+1이므로 CLA의 Cin에도 1이 필요하다. 덧셈이면 원본과 Cin=0을 사용한다.

**연결:** 코어에는 A-B와 B-A를 만들기 위한 두 경로가 있다. 이 모듈의 Cin 포트 대신 코어가 eff_sub를 CLA Cin에 직접 연결하는 부분도 있으므로 포트 선언만 보지 말고 인스턴스 연결을 본다.

### CLA → carry lookahead 방식으로 넓은 유효숫자를 더한다

> 소스: P10/src_mini_CPU/FADD/CLA.v · L1-25 · 활성 연결

**입력 → 출력:** A, B, Cin → Sum, Cout. 비트 propagate와 generate로 캐리를 계산하고 4비트 블록을 연결한다.

**원리:** `g=A&B`, `p=A^B`, `c_next=g|(p&c)`다. 여러 비트의 carry 식을 펼치면 각 비트가 이전 full adder의 결과를 차례로 기다리는 경로를 줄일 수 있다. 이 구현은 블록 내부 lookahead와 블록 간 carry 연결을 갖는다. 코드 이름만으로 실제 합성 주파수 향상을 수치로 단정할 수 없다.

### Magnitude_Restoration → 감산 결과가 음수 방향이면 반대쪽 감산값으로 크기를 복원한다

> 소스: P10/src_mini_CPU/FADD/Magnitude_Restoration.v · L1-25 · 활성 연결

**입력 → 출력:** A-B와 B-A의 Sum, carry, eff_sub → 양의 크기 SUM와 Cout. 감산에서는 첫 번째 경로의 carry로 방향을 판단해 적절한 크기를 고른다.

**예:** 크기 2-5를 수행했다면 저장할 유효숫자 크기는 3이고 부호는 별도 SIGN이 정한다. signed 정수의 음수 비트열을 FP fraction에 그대로 넣을 수 없다. 덧셈 때는 첫 합과 carry를 그대로 사용한다.

### comparator → 두 FP 입력의 부호를 제외한 크기를 비교한다

> 소스: P10/src_mini_CPU/FADD/comparator.v · L1-10 · 활성 연결

**원리:** 지수와 fraction을 연결한 값을 비교해 어느 쪽 크기가 큰지 bigger에 표시한다. A가 크거나 같으면 0, B가 더 크면 1인 약속이다.

**용도:** 감산·서로 다른 부호의 덧셈에서 결과 부호를 정하는 보조 정보다. 이 모듈을 CPU의 FP 비교 명령 전체 구현으로 오해하면 안 된다. NaN을 포함한 명령어 비교 규칙을 구현한 모듈은 아니다.

### SIGN → ADD/SUB 종류와 더 큰 크기의 부호로 결과 부호를 정한다

> 소스: P10/src_mini_CPU/FADD/SIGN.v · L1-24 · 활성 연결

**입력 → 출력:** SIGN_A/B, mode, bigger → result_SIGN. 뺄셈은 B의 유효 부호를 뒤집어 생각하고 크기 우세 쪽의 부호를 선택한다.

**예:** +2+(-5)는 음수, +5+(-2)는 양수다. 정확히 상쇄된 0의 부호와 ±0의 규칙까지 다루려면 별도 처리가 필요하며 P11에서 이를 보완한다.

### Normalization_Controller → 결과 유효숫자의 정규화 방향과 이동량을 결정한다

> 소스: P10/src_mini_CPU/FADD/Normalization_Controller.v · L1-52 · 활성 연결

**입력 → 출력:** Sum, Cout, eff_sub → nor_FRAC, count, direction, doing, EXPO_break. LZD로 앞쪽 0을 센다.

**예:** 더해서 `10.x`가 되면 오른쪽 1비트 이동하고 지수를 1 올린다. 빼서 `0.001x`가 되면 왼쪽 이동으로 유효숫자 맨 앞을 맞추고 지수를 내린다. 정확한 0은 별도로 표시한다. P10은 최소 정상 지수 아래로 내려가는 subnormal 경계 처리가 부족하며 P11에서 이동량을 제한한다.

### LZD → 유효숫자 맨 앞에서 연속된 0의 개수를 센다

> 소스: P10/src_mini_CPU/FADD/LZD.v · L1-45 · 활성 연결

**입력 → 출력:** Sum → count, all_zero. 32/16/8/4/2/1비트 단위 판정을 조합해 leading-zero 수를 구한다.

**예:** 0001xxxx이면 3칸 왼쪽으로 이동해야 맨 앞에 1이 온다. 전부 0이면 단순 이동량보다 all_zero 처리가 중요하다. 현재 구현은 48비트 입력을 64비트 검사 구조로 확장하는 코드가 있어 W를 임의로 바꾸는 범용 모듈로 가정하지 않는다.

### EXPO_CAL → 정규화 이동량에 맞춰 지수를 보정한다

> 소스: P10/src_mini_CPU/FADD/EXPO_CAL.v · L1-21 · 활성 연결

**식:** 이동 안 함 → 지수 유지. 오른쪽 정규화 → +1. 왼쪽 정규화 → -count. 오른쪽 분기는 일반적인 +count가 아니라 현재 정규화에서 필요한 1비트 carry 보정용 +1이다.

**원리:** 같은 실제 값을 유지하려면 유효숫자를 2로 나눌 때 지수를 1 올리고, 2배 할 때 지수를 1 내려야 한다. fraction만 이동하고 지수를 그대로 두면 값 자체가 달라진다.

### Rounding → P10 덧셈 결과의 남는 하위 비트로 반올림을 결정한다

> 소스: P10/src_mini_CPU/FADD/Rounding.v · L1-32 · 활성 연결

**비트:** 유지할 24비트=FRAC[47:24], LSB=24번, G=23번, R=22번, S=하위 [21:0]의 OR. RNE는 `G && (R || S || LSB)`일 때 유지부에 1을 더한다. RTZ는 더하지 않는다. 다른 모드는 기본적으로 추가 반올림을 하지 않는다.

**원리:** 정확히 절반이면 끝자리가 짝수가 되도록 정하는 것이 ties-to-even이다. 반올림으로 1.111…가 10.000…가 되면 지수도 1 올라가야 하므로 count를 출력한다. 이 모듈의 error를 IEEE NV와 같은 뜻이라고 해석하면 안 된다.

### EXPO_MUX → 반올림 carry와 정확한 0 표시를 지수에 반영한다

> 소스: P10/src_mini_CPU/FADD/EXPO_MUX.v · L1-12 · 활성 연결

**원리:** EXPO_CAL의 지수에 Rounding carry를 더한다. EXPO_break이면 지수를 0으로 만든다. 유효숫자와 지수의 마지막 정렬을 위한 보조 선택·보정 모듈이다.

**예:** 유효숫자 반올림 때문에 1.111…에서 10.000…가 되었다면 fraction뿐 아니라 지수도 같이 고쳐야 한다. P11에서는 이 역할을 FP_rounding으로 통합해 이 모듈은 활성 경로에서 빠진다.

### Exception_Handler_ADD → P10 덧셈 결과를 조립하고 overflow/underflow를 단순 처리한다

> 소스: P10/src_mini_CPU/FADD/Exception_Handler_ADD.v · L1-29 · 활성 연결

**원리:** 일반 경우 sign·exponent·fraction을 묶는다. 지수가 너무 크면 무한대로, 너무 작거나 0인 경우에는 signed zero 쪽으로 처리하고 OF/UF를 만든다.

**제약:** gradual underflow나 NaN 입력 분류를 완성한 모듈이 아니다. 넓어진 지수의 부호·비교 우선순위도 제한이 있어 경계값 전체의 정확성을 보장할 수 없다. P11에서는 FP_special과 FP_rounding이 활성 처리 경로를 대신한다.

## 12. Project10: 부동소수점 곱셈

### FMUL_core → FP 부호·지수·유효숫자 곱을 만들고 덧셈 경로와 시간을 맞춘다

> 소스: P10/src_mini_CPU/FMUL/FMUL_core.v · L2-153 · 활성 연결

**원리:** hidden 1을 붙인 두 24비트 유효숫자를 곱해 48비트 곱을 만든다. 지수 합에서 bias 127을 한 번 빼고, 정규화와 반올림으로 생긴 보정을 더한다. 계산이 일찍 끝나는 부분은 레지스터로 더 지연해 ADD와 동일한 선택 시점에 맞춘다.

**예:** 1.5×2.0은 `1.1×2^0 × 1.0×2^1 = 1.1×2^1 = 3.0`이다. P10은 hidden bit를 항상 1로 붙여 subnormal 입력을 정상수처럼 처리하는 제약이 있다.

### Multiplier → 24비트 유효숫자 두 개를 곱해 48비트 값을 만든다

> 소스: P10/src_mini_CPU/FMUL/Multiplier.v · L1-7 · 활성 연결

**입력 → 출력:** FRAC_A/B → FRAC_mul. 입력에는 hidden bit를 포함한다. 24×24 결과를 충분한 48비트 폭으로 보존한다.

**원리:** 곱의 하위 비트가 반올림 근거가 된다. 처음부터 상위 23비트만 잘라내면 정확히 절반인지, 조금 초과했는지 구분할 수 없어진다. 실제 DSP 블록 사용 여부는 합성 결과를 확인해야 한다.

### MUL_SIGN → 곱의 부호를 두 입력 부호의 XOR로 정한다

> 소스: P10/src_mini_CPU/FMUL/MUL_SIGN.v · L1-7 · 활성 연결

**식:** SIGN_A ^ SIGN_B. 같은 부호끼리는 양수, 다른 부호끼리는 음수다.

**예:** -1.5×2.0=-3.0이다. P11 FMUL_core에서는 같은 XOR 식을 코어 내부에서 직접 사용하므로 이 별도 파일은 활성 경로에서 빠진다. 기능이 사라진 것이 아니라 위치가 이동한 것이다.

### MUL_EXPO_ADD → 두 저장 지수를 더한다

> 소스: P10/src_mini_CPU/FMUL/MUL_EXPO_ADD.v · L1-7 · 활성 연결

**입력 → 출력:** 8비트 EXPO_A/B → 9비트 EXPO_ADD. 아직 bias를 최종 보정하지 않은 합이다.

**원리:** E_A=e_A+127, E_B=e_B+127이므로 두 E를 더한 값에는 bias가 두 번 들어 있다. 결과의 저장 지수는 bias가 한 번만 필요하므로 뒤 MUL_EXPO에서 127을 뺀다. P11에서는 유효 지수와 signed 확장 계산을 코어에 직접 넣는다.

### MUL_EXPO → bias와 정규화·반올림 carry를 반영해 곱의 지수를 만든다

> 소스: P10/src_mini_CPU/FMUL/MUL_EXPO.v · L1-21 · 활성 연결

**식:** EXPO_ADD-127+count+round_carry. 넓은 중간값으로 overflow/underflow를 검사하고 8비트 저장 지수를 만든다.

**예:** 1.0×1.0은 127+127-127=127이다. 유효숫자 곱이 2 이상이면 정규화 count 때문에 지수에 1을 더한다. P10의 UF 판정과 강제 0 경로는 subnormal을 정밀하게 보존하는 방식이 아니다.

### Normalization_MUL → P10 곱의 소수점 위치를 맞추고 유지할 fraction을 반올림한다

> 소스: P10/src_mini_CPU/FMUL/Normalization_MUL.v · L1-43 · 활성 연결

**원리:** 48비트 곱의 최상위 비트가 1인지에 따라 유지할 비트 구간과 G/R/sticky의 위치가 달라진다. 위치 보정 count와 반올림 carry를 지수 쪽으로 보낸다.

**예:** `1.5×1.5=2.25`는 이진수로 `10.01`이라 `1.001×2^1`로 바꿔야 한다. P11에서는 이 모듈이 반올림까지 하지 않고, subnormal을 고려한 정규화 결과를 FP_rounding에 전달하도록 역할이 바뀐다.

### Exception_Handler → P10 곱셈의 최종 비트열을 조립한다

> 소스: P10/src_mini_CPU/FMUL/Exception_Handler.v · L1-10 · 활성 연결

**원리:** 부호와 보정 지수를 조립하고 OF/UF이면 fraction을 0으로 만든다. MUL_EXPO가 지수를 이미 0xFF 또는 0으로 보정한 값과 결합한다.

**범위:** 이름이 포괄적이어도 0×Inf, sNaN 같은 모든 IEEE 예외를 이 모듈이 검사하는 것은 아니다. P11의 활성 곱셈 경로는 FP_special과 FP_rounding을 사용하고 이 파일은 보존만 한다.

## 13. Project10: 파일은 있지만 현재 CPU에 연결되지 않은 모듈

아래도 파일 목록에서 빠뜨리지 않도록 포함했다. '미사용'은 Pipeline_CPU에서 인스턴스 연결을 따라갔을 때 도달하지 않는다는 뜻이다. 단위 테스트에서 사용하거나 빌드 목록에 넣어 둔 것과는 다른 기준이다.

### Top_CPU → 과거 단일 사이클 CPU 연결 예제

> 소스: P10/src_mini_CPU/TOP_module/Top_CPU.v · L1-155 · 현재 top 미연결

**내용:** PC→디코딩→ALU→메모리→WB를 단계 레지스터 없이 연결한 흔적이다. 현재 실행 최상위 Pipeline_CPU와 다르며 CPU.f에도 포함되지 않는다.

**상태:** 현재 소스에 없는 ALUsrc_MUX를 참조하고 일부 현행 모듈과 포트가 맞지 않는다. 이것을 현재 파이프라인 CPU의 다른 이름으로 소개하거나 바로 실행 가능한 대체 top으로 취급하면 안 된다.

### ALU_port_MUX → 과거 정수 ALU 포워딩 입력 선택기

> 소스: P10/src_mini_CPU/ALU/ALU_port_MUX.v · L1-57 · 현재 top 미연결

**내용:** MEM/WB 선택 코드를 받아 A/B 피연산자를 우회시키는 예전 경로다. 현재는 port_MUX가 정수·FP·store·점프를 함께 처리한다.

**상태:** 현재 CPU 인스턴스에는 연결되지 않는다. 파일에 남은 동작이나 결함을 현재 CPU 경로의 동작과 섞지 않는다.

### ALU_A_MUX → 과거 ALU A 입력에서 PC와 일반 피연산자를 선택한다

> 소스: P10/src_mini_CPU/MUX/ALU_A_MUX.v · L1-15 · 현재 top 미연결

**내용:** 선택 신호에 따라 PC 또는 EX_A를 통과시키는 보조 MUX다. 현재 경로는 port_MUX 안에서 같은 종류의 입력 선택을 처리한다.

**상태:** 활성 CPU에서는 미사용이다. 파일명만으로 현재 JAL/JALR 데이터 경로를 추정하지 말고 port_MUX 연결을 읽는다.

### ALU_B_MUX → 과거 ALU B 입력에서 즉시값·4·일반 피연산자를 고른다

> 소스: P10/src_mini_CPU/MUX/ALU_B_MUX.v · L1-19 · 현재 top 미연결

**내용:** ALUsrc이면 immediate, 그다음 별도 선택이면 상수 4, 나머지는 B를 고르는 보조 MUX다. 현재 port_MUX에 기능이 모여 있다.

**상태:** 활성 CPU에서는 미사용이다. 상수 4는 점프 링크값 PC+4 계산에 필요한 후보라는 관점으로 이해한다.

### Pipe_reg_2clk → 데이터를 두 개의 직렬 레지스터로 지연한다

> 소스: P10/src_mini_CPU/Register/Pipe_reg_2clk.v · L1-20 · 현재 top 미연결

**원리:** D→중간 레지스터→Q. 매 clk 상승에서 이동하고 reset 시 0으로 초기화한다. 한 에지에서 새 D가 두 칸을 한꺼번에 통과하지 않는다.

**상태:** 현재 Pipeline_CPU 연결에는 없다. 여러 경로의 계산 완료 시점을 맞추기 위한 재사용 가능한 지연 블록이다.

### Pipe_reg_3clk → 데이터를 세 개의 직렬 레지스터로 지연한다

> 소스: P10/src_mini_CPU/Register/Pipe_reg_3clk.v · L1-22 · 현재 top 미연결

**원리:** 두 중간 저장소와 출력 저장소가 차례로 데이터를 전달한다. 부호·모드 등 가벼운 제어 신호도 느린 계산 경로만큼 지연할 때 쓸 수 있다.

**상태:** CPU.f에 이름이 있어도 현재 top에서 실제로 인스턴스화되지 않는다. '컴파일 목록에 있다'와 '합성되는 top 내부에서 사용된다'를 구분하는 예다.

### Pipe_reg_4clk → 데이터를 네 개의 직렬 레지스터로 지연한다

> 소스: P10/src_mini_CPU/Register/Pipe_reg_4clk.v · L1-24 · 현재 top 미연결

**원리:** 세 중간 저장소와 출력 저장소를 사용한다. 각각 같은 clk에서 이전 단계 값을 받는다.

**상태:** 현재 활성 연결에는 없다. 단순 지연은 연산량을 늘리는 것이 아니라 이미 구한 값의 도착 시점을 늦추는 것이다.

### FPU_classifier → P10에 남아 있는 미완성 FP 분류기 초안

> 소스: P10/src_mini_CPU/FPU_common/FPU_classifier.v · L1-41 · 현재 top 미연결

**목적:** 부호·지수·fraction으로 zero, subnormal 등의 종류와 hidden bit를 구분하려던 파일이다.

**상태:** P10 CPU.f와 FPU 연결에는 포함되지 않고, 출력 구동·선언 등도 미완성이다. 따라서 P10이 이미 classifier를 이용해 특수값을 처리한다고 설명하면 틀린다. P11에서 완성된 classifier가 실제 FP_special 경로에 연결된다.

## 14. Project11 한눈에 보기: 왜, 무엇을 바꿨나

**Project11은 Project10을 복사해서 시작한 파생 설계다. 정수 5단 파이프라인·해저드·포워딩의 뼈대는 그대로 두고, FPU를 '정상수만 대충 맞는 연산기'에서 'IEEE 754 경계값과 반올림 규칙을 지키고 그 결과를 명령어 단위로 정확히 정렬하는 연산기'로 바꾼 것이 핵심이다.** 동시에 Python 기준 모델과 자동 회귀 도구를 새로 만들어 '맞다'는 주장을 숫자로 뒷받침하게 했다.

한 문장으로 요약하면: P10은 "FP 덧셈·곱셈이 CPU 안에서 돌아간다"까지, P11은 "어떤 FP32 입력이 와도 규칙대로 답과 플래그가 나오고, 그것을 자동으로 증명한다"까지다.

### P10에서 남아 있던 문제와 P11의 해결

- **subnormal을 몰랐다:** P10 FADD/FMUL은 hidden bit를 항상 1로 붙였다. 지수 E=0인 아주 작은 수(subnormal)가 `1.F×2^-127`처럼 엉뚱한 정상수로 계산됐다. → P11은 E=0이면 hidden 0, 유효 지수 1을 쓰는 `0.F×2^-126` 해석으로 바꿨다.
- **0·Inf·NaN 규칙이 없었다:** P10은 NaN 입력, Inf−Inf, 0×Inf를 일반 산술로 흘려보냈다. → P11은 FP_special이 산술 전에 답을 정하고, 그 답을 같은 7단 시간축으로 지연해 최종 선택한다.
- **반올림이 RNE·RTZ뿐이었다:** P10 Rounding은 rm이 RDN/RUP/RMM이어도 사실상 절단처럼 동작했다. → P11 FP_rounding은 RNE·RTZ·RDN·RUP·RMM 다섯 모드를 모두 구현하고 ADD와 MUL이 같은 모듈을 공유한다.
- **sticky를 잃었다:** P10 barrel_shifter는 오른쪽으로 밀려나간 비트를 그냥 버렸다. 정확한 절반(tie)과 '절반보다 조금 큼'을 구분할 수 없어 RNE와 NX가 틀릴 수 있었다. → P11은 버려진 비트의 OR를 최하위에 붙인다(shift-right-jam).
- **플래그가 OF/UF뿐이고 정의가 느슨했다:** → P11 FPU는 NV·OF·UF·NX 네 개를 제공하고, UF는 'tininess after rounding + inexact' 규칙을 따른다. DZ 자리는 형식상 존재하지만 나눗셈이 없으므로 항상 0이다.
- **결과가 유효한지 알려주는 신호가 없었다:** P10 FPU는 매 클럭 무엇인가를 출력했고, 유효 여부는 CPU의 FPU_Check가 따로 추적했다. → P11 FPU는 자체 valid_pipe와 valid_out을 가진다. valid가 아닌 사이클의 플래그는 0으로 내린다.
- **미지원 연산이 덧셈으로 둔갑했다:** P10 FPU_Control의 기본값은 ADD(00)였다. 모르는 funct가 와도 error만 켜고 ADD 코드를 냈다. → P11은 기본값을 11(미지원)으로 바꾸고, FP_special이 op=3 또는 rm>4를 illegal로 잡아 canonical qNaN을 돌려준다.
- **FP 레지스터 f0를 쓸 수 없었다:** P10은 정수·FP 레지스터 파일 둘 다 0번 쓰기를 막아 f0가 항상 0이었다. RISC-V에서 f0는 일반 레지스터다. → P11은 ZERO_REGISTER 파라미터로 정수 파일만 0번을 고정한다.
- **검증이 손으로 고른 프로그램 몇 개였다:** → P11은 독립 정수 기준 모델(reference.py)과 30,626건 FPU 회귀, 23개 경계 단위 검사, CPU 59+6개 검사, 오류 주입(negative control·RTL mutation)을 한 명령으로 실행한다.
- **실행 위치에 따라 메모리 파일을 못 찾았다:** P10은 메모리 초기화 경로가 특정 폴더에 묶여 있었다. → P11은 `./runtime/memo/` 상대 경로를 쓰고, 회귀 도구가 `_work/runtime/memo/`에 이미지를 만들어 원본을 건드리지 않는다.

### 변경 규모를 숫자로 보면

모듈 정의 수는 P10 70개 → P11 73개다. 늘어난 3개가 FP_special, FP_rounding, Final_MUX다. Pipeline_CPU에서 도달하는 활성 모듈은 P10 62개 → P11 58개로 오히려 줄었다. 새 모듈 3개가 들어오고 P10의 FPU_classifier 초안이 완성되어 활성화된 대신, Rounding·EXPO_MUX·Exception_Handler_ADD·Exception_Handler·MUL_SIGN·MUL_EXPO_ADD·MUL_EXPO·MUX 8개가 역할을 넘기고 활성 경로에서 빠졌기 때문이다(62+3+1−8=58).

- **신규 3개:** FP_special, FP_rounding, Final_MUX.
- **완성·활성화 1개:** FPU_classifier.
- **동작이 바뀐 모듈:** FPU, FADD_core, FMUL_core, barrel_shifter, Normalization_Controller, Normalization_MUL, FPU_Control, Register_file, Pipeline_CPU(인스턴스 파라미터), Instruction_Memory·Data_Memory(파일 경로).
- **표기만 바뀐 모듈:** FPU_unpack(비트 위치를 고정 표기), FPU_Hazard(암시적 wire 명시). 동작은 같다.
- **활성 경로에서 빠진 8개:** 파일은 보존. 역할은 FP_special·FP_rounding·FMUL_core·FPU 상위 논리로 이동했다.
- **나머지:** PC·디코더·정수 ALU·해저드·포워딩·파이프 레지스터 등은 주석과 공백을 지우고 비교하면 P10과 같은 RTL이다. 18장 생성 스크립트가 이를 자동 대조한다.

### Project11에서 새로 생긴 기능 전체 목록

1. **FP32 수 종류 분류:** ±0, subnormal, normal, ±Inf, qNaN, sNaN을 입력마다 판정한다.
2. **특수값 결과 생성:** NaN 전파(canonical qNaN `0x7FC00000`), Inf 연산, 0 연산, Inf−Inf와 0×Inf의 invalid 처리, 0의 부호 규칙.
3. **subnormal 입력·출력:** 입력 subnormal을 올바른 크기로 계산하고, 결과가 normal 범위 아래로 내려가면 subnormal로 표현한다(gradual underflow). subnormal 결과가 반올림으로 최소 normal로 승격되는 경우도 처리한다.
4. **다섯 반올림 모드:** RNE(000), RTZ(001), RDN(010), RUP(011), RMM(100). 명령어 funct3의 rm 값을 그대로 사용한다.
5. **overflow 결과의 모드별 선택:** 반올림 방향에 따라 ±Inf 또는 ±최대 유한값(`0x7F7FFFFF`)을 고른다.
6. **예외 플래그 4종:** NV(invalid), OF(overflow), UF(underflow), NX(inexact). `UF=1이면 NX=1`이 항상 성립한다.
7. **illegal 요청 표시:** op=3, rm=5·6·7(DYN 포함)을 illegal로 보고 qNaN과 error를 낸다.
8. **valid_out:** 7번째 에지 직후 결과가 유효함을 FPU가 직접 알려준다.
9. **operand isolation(ISOLATE 파라미터):** 특수값·무효 사이클에 산술 입력 레지스터 갱신을 막는다. 기능은 ISOLATE=0/1에서 동일하다.
10. **f0 일반 레지스터화:** FP 레지스터 0번에 값을 쓰고 읽고 포워딩할 수 있다.
11. **자동 회귀 환경:** reference.py, run_regression.py, run_xsim.ps1, 테스트벤치 4종(+파형용 1종), 결과 기록 results.json.
12. **FPGA 비교 실험 스크립트:** compare_vivado.tcl과 환경 진단 스크립트. 단, 합성 환경 문제로 수치는 아직 없다.

### 바뀌지 않은 것도 정확히 알아두기

정수 명령어 지원 범위, PC 선택 우선순위, load-use 판단 조건, MEM/WB 포워딩 코드, FPU_Check의 7칸 추적 구조, FPU_shadow_reg의 Rd 지연 방식은 P10과 같다. 즉 P10 3~9장에서 적은 '현재 코드의 한계'(BLT/BGE의 overflow 경계, JALR 링크값, store·branch 소비자의 load-use 등)는 P11에서도 그대로 남아 있다. P11을 "CPU 전체를 고친 버전"이라고 소개하면 과장이다. 정확한 표현은 "FPU와 FP 레지스터 정책, 검증 환경을 업그레이드한 버전"이다.

## 15. Project11을 읽기 위한 FP32 추가 개념

P10은 정상수 공식 하나로 충분했지만 P11 코드를 읽으려면 아래 개념이 필요하다. 10장의 FP32 배치(S 1비트, E 8비트, F 23비트)를 먼저 떠올린다.

### 다섯 가지 수 종류와 대표 비트열

- **zero:** E=0, F=0. `0x00000000`=+0, `0x80000000`=−0. 값은 같지만 부호가 다르고, 1/x 같은 연산이나 반올림 모드 규칙에서 차이가 난다.
- **subnormal:** E=0, F≠0. 값은 `(-1)^S × 0.F × 2^-126`. 가장 작은 양수 `0x00000001`=2^-149, 가장 큰 subnormal `0x007FFFFF`.
- **normal:** 1≤E≤254. 값은 `(-1)^S × 1.F × 2^(E-127)`. 최소 normal `0x00800000`=2^-126, 1.0=`0x3F800000`, 최대 유한값 `0x7F7FFFFF`≈3.4×10^38.
- **infinity:** E=255, F=0. `0x7F800000`=+Inf, `0xFF800000`=−Inf.
- **NaN:** E=255, F≠0. F[22]=1이면 quiet NaN(qNaN, 예 `0x7FC00000`), F[22]=0이면 signaling NaN(sNaN, 예 `0x7F800001`).

**왜 E=0이 '유효 지수 1'인가:** 최소 normal은 `1.0×2^-126`이고 가장 큰 subnormal은 `0.111…1×2^-126`이다. 두 수가 끊김 없이 이어지려면 subnormal도 2^-126 눈금을 써야 한다. 그래서 저장 E는 0이지만 계산할 때는 E=1처럼 다루고 hidden bit만 0으로 둔다. P11 코드 곳곳의 `(EXPO == 0) ? 8'd1 : EXPO`가 바로 이 규칙이다.

### subnormal과 gradual underflow

정상수만 있으면 2^-126보다 작은 결과는 바로 0이 된다. 그러면 `a−b=0`인데 `a≠b`인 이상한 상황이 생긴다. subnormal은 정밀도를 조금씩 잃으면서 0까지 부드럽게 내려가게 해 준다. 이것을 gradual underflow라고 한다.

**예:** `0x00800000 − 0x00000001`(최소 normal − 최소 subnormal)의 정확한 답은 `0x007FFFFF`다. subnormal이 없다면 0 또는 최소 normal로 망가진다. P11은 이 답을 플래그 없이(정확하므로 UF=0, NX=0) 낸다.

### G·R·S 비트와 sticky

반올림하려면 '남길 부분' 바로 아래 정보가 필요하다. LSB는 남는 부분의 마지막 비트, G(guard)는 그 바로 아래, R(round)는 그 아래, S(sticky)는 그보다 아래 모든 비트의 OR다.

- G=0: 버리는 부분이 절반 미만.
- G=1, R=0, S=0: 정확히 절반(tie).
- G=1이고 R 또는 S가 1: 절반 초과.
- G·R·S 중 하나라도 1: 결과가 부정확(inexact) → NX.

**sticky가 왜 1비트로 충분한가:** 반올림 판단에 필요한 것은 '아래쪽에 0이 아닌 것이 하나라도 있었나'뿐이다. 그래서 정렬 이동으로 밀려난 수십 비트를 모두 들고 다닐 필요 없이 OR 한 비트로 접는다. 대신 한 번이라도 버리면 그 정보는 되살릴 수 없으므로 P11 barrel_shifter와 Normalization_MUL이 버리는 순간마다 sticky를 합친다.

### 다섯 반올림 모드 비교

`1.0 + 2^-24`의 정확한 값은 1.0과 바로 다음 FP32 수(1.0+2^-23) 사이의 정확한 절반이다. 모드별 결과는 아래와 같다(reference.py로 확인).

- **RNE(000, 가장 가까운 값·tie는 짝수):** `0x3F800000`(1.0). 끝자리가 짝수인 쪽을 고른다. NX=1.
- **RTZ(001, 0 방향):** `0x3F800000`. 항상 버린다. NX=1.
- **RDN(010, −∞ 방향):** 양수이므로 버림 → `0x3F800000`. 음수였다면 절댓값이 커지는 쪽으로 올린다. NX=1.
- **RUP(011, +∞ 방향):** `0x3F800001`. 양수이고 버릴 것이 있으므로 올린다. NX=1.
- **RMM(100, 가장 가까운 값·tie는 0에서 먼 쪽):** `0x3F800001`. NX=1.

반대로 `1.0 + (2^-24보다 아주 조금 큰 수)`는 절반 초과이므로 RNE에서도 `0x3F800001`이 된다. sticky가 없으면 이 두 경우를 구분할 수 없다는 것이 P10→P11 sticky 수정의 이유다.

### 예외 플래그 다섯 자리

P11 FP_special의 flags[4:0] 순서는 RISC-V fflags와 같은 NV, DZ, OF, UF, NX다.

- **NV(invalid):** 수학적으로 정의되지 않는 연산. sNaN 입력, Inf−Inf(같은 부호 Inf의 뺄셈 포함), 0×Inf. qNaN 입력만으로는 NV가 아니다.
- **DZ(divide by zero):** 나눗셈이 없으므로 항상 0.
- **OF(overflow):** 반올림 후 지수가 254를 넘음. 항상 NX도 함께 1.
- **UF(underflow):** 반올림 후에도 normal 범위 아래(tiny)이면서 부정확. 정확한 subnormal 결과는 UF=0이다.
- **NX(inexact):** 버린 비트가 있거나 overflow.

### canonical NaN과 ±0 규칙

**canonical qNaN:** 어떤 NaN이 들어와도 P11은 항상 `0x7FC00000` 하나를 돌려준다. 입력 NaN의 payload를 보존하지 않는 것은 RISC-V의 규칙과 같다.

**덧셈의 0 부호:** 같은 부호 0끼리 더하면 그 부호(−0 + −0 = −0). 서로 다른 부호의 0이 만나거나 0이 아닌 같은 크기가 정확히 상쇄되면 RDN에서는 −0, 나머지 네 모드에서는 +0이다. 예: `1.0 − 1.0`은 RNE에서 `0x00000000`, RDN에서 `0x80000000`.

**곱셈의 0 부호:** 항상 두 입력 부호의 XOR. `−0 × 5.0 = −0`(`0x80000000`).

## 16. Project11 FPU 상위 구조와 7단 시간축

### 두 갈래로 나뉜 데이터 흐름

P11 FPU에 들어온 요청은 같은 클럭에 두 갈래로 나뉜다.

1. **특수값 갈래:** 입력 IN_A/IN_B가 레지스터를 거치기 전, 조합회로 FP_special이 바로 분류·판정한다. 결과 `{special, illegal, flags[4:0], result[31:0]}` 39비트를 special_packet[0]에 저장하고 매 클럭 한 칸씩 [5]까지 민다.
2. **산술 갈래:** 입력을 a1/b1 레지스터에 저장하고 FPU_unpack으로 필드를 나눈 뒤 FADD_core와 FMUL_core에 동시에 넣는다. 두 코어 모두 계산하지만 마지막에 op로 하나만 고른다.

마지막 단계에서 special_packet[5]의 special 비트가 1이면 특수값 결과와 그 플래그를, 0이면 산술 결과와 산술 플래그를 고른다. 결과값만이 아니라 플래그·error도 같은 비트로 함께 고르기 때문에 "답은 특수값인데 플래그는 산술 쪽"인 혼합이 생기지 않는다.

**왜 특수 결과를 바로 내보내지 않나:** FP_special은 첫 클럭에 이미 답을 안다. 하지만 CPU의 FPU_shadow_reg와 FPU_Check는 'FP 결과는 7번째 에지에 나온다'고 가정하고 Rd를 지연한다. 특수값만 빨리 나오면 다른 명령어의 Rd에 써진다. 그래서 일부러 같은 길이만큼 늦춘다. 고정 지연은 하드웨어 비용이 조금 들지만 CPU 쪽 해저드 로직을 하나도 바꾸지 않아도 되는 장점이 있다.

### 7개 레지스터 단계

요청을 받는 상승 에지를 1번이라고 센다.

1. **에지 1 — 입력 접수:** a1/b1 저장(ISOLATE 조건부), valid_pipe[0], op_pipe[0], rm_pipe[0], special_packet[0] 저장.
2. **에지 2:** FADD는 hidden bit를 붙이고 유효 지수 차이로 작은 쪽을 오른쪽 정렬(sticky 포함). FMUL은 hidden bit·유효 지수 합 `effA+effB−127`·부호 XOR을 저장한다.
3. **에지 3:** FADD는 정렬된 유효숫자를 두 CLA 경로로 더하거나 뺀 결과를 저장. FMUL은 24×24 곱(48비트)을 저장한다.
4. **에지 4:** FADD는 합과 carry를 저장하고 정규화 방향·이동량을 계산한다. FMUL은 곱을 한 번 더 저장한 뒤, 그 출력에서 Normalization_MUL과 FP_rounding을 조합으로 수행한다(rm_pipe[3] 사용).
5. **에지 5:** FADD는 이동량을 저장하고 유효숫자 이동·지수 보정을 한다. FMUL은 반올림된 결과와 OF/UF/NX를 저장한다.
6. **에지 6:** FADD는 정규화된 유효숫자를 저장하고 FP_rounding으로 반올림·패킹·플래그를 만든다(rm_pipe[5] 사용). FMUL은 결과·플래그를 한 번 더 지연한다.
7. **에지 7 — 최종 등록:** op_pipe[5]로 ADD/MUL을 고르고, special_packet[5]로 특수/산술을 골라 result_out, error, NV, OF, UF, NX, valid_out을 함께 등록한다.

에지 1과 에지 7 사이는 6클럭이다. 매 클럭 새 요청을 받을 수 있으므로 처리량은 1요청/클럭, 지연은 7단이다.

**P10과 같은 점:** P10 FPU도 입력 레지스터 1 + 코어 5 + 출력 1의 같은 7단 구조였다. 그래서 CPU 쪽 FPU_Check의 7칸 추적과 FPU_shadow_reg 길이를 바꿀 필요가 없었다. P11을 '6단에서 7단으로 늘렸다'고 설명하면 틀린다.

### op·rm·valid를 데이터와 함께 지연하는 방식

- **op_pipe:** P10은 op 2비트 중 bit0(ADD/SUB)만 FADD로 보내고, bit1(MUL 여부) 한 비트만 6단 지연해 MUX에 썼다. P11은 2비트 전체를 6칸 배열로 지연하고 마지막에 `op_pipe[5] == 2`로 MUL을 판정한다. op=3(미지원)도 끝까지 정보가 남는다.
- **rm_pipe:** 3비트 rm을 6칸 지연한다. MUL은 4단계에서 반올림하므로 rm_pipe[3], ADD는 6단계에서 반올림하므로 rm_pipe[5]를 쓴다. 같은 배열의 다른 칸을 쓰는 이유가 '반올림이 일어나는 단계가 다르기 때문'이라는 점이 중요하다. 반대로 꽂으면 연속 요청에서 앞뒤 명령어의 rm이 섞인다.
- **valid_pipe:** FPU_en을 6비트 시프트 레지스터로 민다. valid_pipe[5]가 1인 다음 에지에 valid_out=1이 된다. 코어 enable(core_en)도 valid_pipe[0]에서 시작한다.

### 출력 레지스터의 규칙

- **valid_pipe[5]=1:** result_out, error, NV/OF/UF/NX를 그 요청의 값으로 갱신한다.
- **valid_pipe[5]=0:** result_out은 이전 값을 유지하고 error·NV·OF·UF·NX는 0으로 내린다. 따라서 '플래그가 1로 남아서 다음 명령어의 것처럼 보이는' 일이 없다.
- **error:** `illegal || NV`. 특수 경로의 illegal과 선택된 플래그의 NV를 합친다.
- **ZF·sign:** P10은 별도 레지스터에 저장했지만, P11은 result_out에서 조합으로 만든다(`ZF = result_out[30:0]==0`, `sign = result_out[31]`). valid_out=0이면 이전 결과를 반영하므로 valid_out과 함께 읽어야 한다.
- **reset:** 비동기 active-high. 진행 중인 요청을 모두 버린다(valid_pipe·packet 모두 0).

### 연속 네 요청을 시간순으로 따라가기

보고서 파형(report_waveform.sv)이 넣는 네 요청을 매 클럭 하나씩 넣는다고 하자.

1. **1번 요청 `1.5 + 2.25`:** special=0 → 산술 경로. 7번째 에지 뒤 result=`0x40700000`(3.75), 플래그 0.
2. **2번 요청 `+Inf − +Inf`:** special=1, flags=NV, result=qNaN. ISOLATE=1이면 a1/b1은 1번 값 그대로 유지된다. 1클럭 뒤 결과 `0x7FC00000`, NV=1, error=1.
3. **3번 요청 `max + max`(RNE):** 유한수끼리라 special=0 → 산술 경로. FP_rounding에서 지수 255 이상 → OF. 결과 `0x7F800000`(+Inf), OF=1, NX=1.
4. **4번 요청 `최소 subnormal + 최소 subnormal`:** 산술 경로. 결과 `0x00000002`, 정확하므로 플래그 0.

출력 순서는 입력 순서와 같고, 매 결과가 자기 플래그와 같은 에지에 나온다. 특수값 요청이 끼어들어도 앞뒤 산술 요청의 시간축이 밀리지 않는다는 것이 이 파형의 요점이다.

## 17. Project11 신규·변경 모듈 상세

여기부터 모듈 카드다. 제목의 'P11'은 Project11 소스 기준이라는 표시다. P10 카드와 비교하며 읽는다.

### P11 FPU_classifier → 입력을 zero·subnormal·normal·Inf·NaN으로 정확히 구분한다

> 소스: P11/src_mini_CPU/FPU_common/FPU_classifier.v · L1-35 · 활성 연결

**조건:** E=0,F=0은 zero. E=0,F≠0은 subnormal. 1≤E≤254는 normal. E=255,F=0은 Inf. E=255,F≠0은 NaN이다. NaN 중 F[22]=0이면 sNaN으로 분류한다. 부호로 +0/−0(is_Pzero/is_Nzero)도 구분한다.

**추가 출력:** normal에서만 hidden_bit=1이다. E=0이면 산술용 effective_exponent=1, 나머지는 E를 그대로 쓴다. subnormal은 `0.F×2^-126`, 최소 normal은 `1.0×2^-126`이므로 같은 유효 지수에서 hidden bit만 다르게 쓰는 것이다.

**P10 초안과의 차이:** P10 파일은 출력 일부가 구동되지 않고 CPU.f와 FPU 연결 어디에도 없었다. P11은 모든 출력을 assign/always로 구동하고 FP_special 안에서 입력마다 하나씩, 총 두 개의 인스턴스(ca, cb)로 사용한다.

**예:** `0x00000001`은 0이 아니라 가장 작은 양의 subnormal이다. `0x00800000`은 최소 양의 normal이다. `0x7F800001`은 sNaN, `0x7FC00000`은 qNaN이다. '지수 0이면 무조건 0'으로 처리하면 작은 수를 잃는다.

### P11 FP_special → 일반 산술로 처리하지 않을 특수 결과와 예외를 먼저 결정한다

> 소스: P11/src_mini_CPU/FPU_common/FP_special.v · L1-103 · 활성 연결

**입출력:** a/b, op, rm, FPU_en → special, result, flags[4:0], illegal, 유효 지수 두 개. 내부 classifier 두 개로 입력을 분류한다. 조합회로이므로 같은 클럭에 답이 나온다.

**판정 우선순위(위가 먼저):**

1. **illegal:** op=3 또는 rm>4 → qNaN, illegal=1. flags는 0.
2. **NaN 입력:** a 또는 b가 NaN → qNaN. 둘 중 하나라도 sNaN이면 NV.
3. **MUL:** Inf×0 또는 0×Inf → qNaN+NV. Inf가 하나라도 있으면 → 부호 XOR의 Inf. 0이 하나라도 있으면 → 부호 XOR의 0. 나머지는 special=0(산술 경로로).
4. **ADD/SUB:** 먼저 B의 유효 부호 `sb = b[31] ^ (op==SUB)`를 만든다. Inf와 Inf의 유효 부호가 다르면 → qNaN+NV. a가 Inf → a. b가 Inf → 부호 sb의 Inf. 둘 다 0 → 같은 부호면 그 부호, 다르면 RDN일 때 −0. a만 0 → `{sb, b[30:0]}`(부호만 바꾼 b). b만 0 → a. 나머지는 special=0.

**왜 이 순서인가:** NaN을 먼저 봐야 `NaN×0`이 0으로 처리되지 않는다. illegal을 가장 먼저 봐야 모르는 요청이 우연히 '정상 답'처럼 보이지 않는다.

**한쪽만 0인 경우를 특수 처리하는 이유:** `0 + x = x`는 반올림 없이 정확하다. 산술 경로로 보내도 같은 답이 나와야 하지만, 특수 경로에서 바로 끝내면 ISOLATE=1에서 산술 레지스터가 움직이지 않는다. subnormal x도 그대로 통과하므로 정확하다.

**FPU_en 포트:** effective_EXPO 출력만 0으로 만든다. special·result 판정 자체는 FPU_en과 무관하게 계속 계산되며, 그 결과가 실제 요청인지는 상위 valid_pipe가 판단한다.

### P11 FP_rounding → ADD와 MUL이 함께 쓰는 반올림·최종 패킹·플래그 모듈

> 소스: P11/src_mini_CPU/FPU_common/FP_rounding.v · L5-71 · 활성 연결

**입력 형식:** SIGN, 9비트 biased EXPO, 48비트 FRAC, rm. FRAC[47]은 hidden 위치, [46:24]는 fraction 23비트, [24]는 LSB, [23] G, [22] R, [21:0]은 sticky OR 대상이다. EXPO가 0으로 들어와도 1로 바꿔 해석한다.

**반올림 결정(round_up):** RNE는 `G && (R || S || LSB)`. RTZ는 0. RDN은 `SIGN && inexact`. RUP은 `!SIGN && inexact`. RMM은 `G`. 여기서 inexact = `G | R | S`.

**carry 처리:** `temp_FRAC = {0, FRAC[47:24]} + round_up`을 25비트로 계산한다. 최상위 carry가 나면(1.111…+1 = 10.000…) 유효숫자를 한 칸 오른쪽으로 보고 지수에 1을 더한다.

**subnormal 판정:** 반올림 후 hidden 위치 비트(rounded[23])가 0이면 저장 지수를 0으로 쓴다. 즉 'EXPO=1인데 hidden=0'인 입력은 subnormal로 포장된다. 반올림으로 hidden 위치가 1이 되면 자연스럽게 지수 1(최소 normal)로 승격된다.

**overflow:** 반올림 후 지수가 255 이상이면 OF. RNE·RMM, 그리고 음수의 RDN·양수의 RUP은 Inf로 간다(to_inf). RTZ, 양수의 RDN, 음수의 RUP은 최대 유한값 `±0x7F7FFFFF`로 간다. OF이면 NX도 1.

**UF:** `!OF && encoded==0 && inexact`. 반올림한 뒤의 지수로 tiny 여부를 보므로(tininess after rounding) 최소 normal로 승격된 결과는 UF=0이다. 정확한 subnormal도 UF=0이다.

**예:** 1.0과 그 다음 FP32 수의 정확한 중간을 반올림하면 RNE는 끝자리가 짝수인 1.0, RMM은 `0x3F800001`을 고른다. 정확한 −1.0(버릴 것 없음)을 RDN으로 반올림해도 −1.0이어야 한다. 회귀 도구의 RTL mutation이 바로 이 `SIGN && inexact`를 `SIGN`으로 망가뜨려 검출 여부를 시험한다.

**P10과의 차이:** P10은 덧셈용 Rounding, EXPO_MUX, Exception_Handler_ADD와 곱셈용 Normalization_MUL 내부 반올림, MUL_EXPO, Exception_Handler가 따로 있었다. 두 경로의 반올림 규칙이 서로 다를 수 있었다. P11은 한 모듈이 반올림·지수 carry·overflow 선택·subnormal 패킹·플래그를 모두 맡아 ADD와 MUL이 반드시 같은 규칙을 쓴다.

### P11 Final_MUX → 일반 산술 결과와 특수값 결과 중 최종 답을 선택한다

> 소스: P11/src_mini_CPU/FPU_common/Final_MUX.v · L1-10 · 활성 연결

**식:** `Answer = special ? result : Final_out`. result는 FP_special이 만든 답(6클럭 지연), Final_out은 ADD/MUL 중 op로 고른 산술 결과다.

**원리:** Inf−Inf 같은 요청은 유한수 가산기로 올바른 답을 만들 필요가 없다. 특수 경로가 답을 준비하되 일반 연산과 같은 출력 에지까지 지연해 이 MUX에서 선택한다. MUX 자체는 32비트 결과만 선택하고, 플래그·illegal의 일치 선택은 FPU 상위의 `selected_flags`, `selected_error` 식이 같은 special 비트로 담당한다.

### P11 FPU → 결과·특수처리·유효성·플래그를 같은 시간축으로 정렬한다

> 소스: P11/src_mini_CPU/TOP_module/FPU.v · L3-159 · 활성 연결

**인터페이스 변화:** 출력에 NV, NX, valid_out이 추가됐고 파라미터 ISOLATE(기본 1)가 생겼다. result_out·error·OF·UF는 reg 출력이 됐다. ZF·sign은 result_out에서 만든 wire다.

**구조 변화:** P10은 Pipe_reg_1clk 인스턴스를 여러 개 이어 붙인 형태였다. P11은 한 always 블록에서 a1/b1, valid_pipe, special_packet[0:5], rm_pipe[0:5], op_pipe[0:5], 출력 레지스터를 함께 갱신한다. 배열 칸 번호가 곧 단계 번호라서 '이 신호가 몇 단계 늦었나'를 읽기 쉽다.

**산술 결과 선택:** `is_mul = op_pipe[5]==2`. MUL이면 `{0,0,mul_of,mul_uf,mul_nx}`, 아니면 ADD 플래그를 산술 플래그로 쓴다. 산술 경로는 NV를 만들지 않는다(NV는 특수 경로 전담).

**연속 입력:** 서로 독립적인 FPU 요청을 매 클럭 받을 수 있는 파이프라인이다. 다만 CPU 전체가 모든 FP 명령어 조합을 stall 없이 발행한다는 뜻은 아니다. 의존성·결과 합류 때문에 CPU의 FPU_Hazard가 추가로 개입한다.

### P11 ISOLATE → 필요 없는 산술 입력·레지스터 갱신을 억제한다

**ISOLATE=1:** `FPU_en && !special_in`일 때만 a1/b1을 갱신한다. 코어 enable은 `core_en = valid_pipe[0] && !special_packet[0][38]`이라 특수값 요청과 bubble에서는 FADD/FMUL 내부 Pipe_reg_1clk_en 레지스터들도 값을 유지한다. enable은 s2_en, s3_en…으로 데이터와 같은 방향으로 전달된다.

**ISOLATE=0:** a1/b1을 매 클럭 갱신하고 core_en은 valid만 본다. 비교 기준용 설정이다. 두 설정의 valid 출력은 비트 단위로 같아야 하며, fp32_regression이 두 인스턴스를 나란히 돌려 이를 검사한다.

**측정 결과:** 특수값만 500개 넣은 입력에서 a1/b1 비트 전환 수는 ISOLATE=0이 10,315회, ISOLATE=1이 0회였다.

**해석 범위:** register enable 기반 operand isolation이다. clock gating 셀을 넣은 것이 아니다. 특정 레지스터의 toggle 감소를 FPGA 전체 전력 감소율이라고 부르면 안 된다. 클럭 네트워크·분류기·special packet·enable 논리는 계속 동작한다. 또 현재 코드는 ADD 요청에서 FMUL만 끄는 연산별 차단이 아니다. 산술 요청이면 두 코어가 모두 움직인다. Pipeline_CPU는 FPU를 기본값 ISOLATE=1로 인스턴스화한다.

### P11 FADD_core → subnormal·sticky·공통 반올림을 처리하도록 덧셈 경로를 확장한다

> 소스: P11/src_mini_CPU/FADD/FADD_core.v · L2-517 · 활성 연결

**바뀐 줄을 단계별로:**

- **s1→s2 hidden bit:** P10은 `{1'b1, FRAC, 24'b0}`. P11은 `{(EXPO != 0), FRAC, 24'b0}`. subnormal이면 앞자리가 0이다.
- **s1 지수 차이:** EXPO_SUB에 원래 지수 대신 유효 지수(0이면 1)를 넣는다. subnormal과 최소 normal의 지수 차이가 1이 아니라 0으로 올바르게 계산된다.
- **s2 정렬 이동:** P11 barrel_shifter가 sticky를 보존한다.
- **s4 정규화:** Normalization_Controller에 s4_EXPO_big을 EXPO_in으로 넘겨 왼쪽 이동을 제한한다.
- **s6 마무리:** Rounding → EXPO_MUX → Exception_Handler_ADD의 세 모듈 대신 FP_rounding 하나를 쓴다. 출력에 s6_NX가 추가됐다.
- **0의 부호:** `round_SIGN = s6_EXPO_break ? (s6_rm == RDN) : s6_final_SIGN`. 정확히 상쇄되면 RDN에서만 −0.
- **s6_error:** 0으로 고정. NV/illegal은 FP_special 담당이다.

**유지한 부분:** EXPO_SUB, comparator, Mode_Detector, Cond_Inverter, 두 개의 CLA(A−B, B−A), Magnitude_Restoration, LZD, EXPO_CAL, SIGN 계층은 그대로다. 단계 수와 레지스터 배치도 같다. '덧셈기를 새로 만들었다'기보다 기존 데이터 경로의 경계값 처리를 보강한 것이다.

### P11 barrel_shifter → 오른쪽으로 버려지는 비트를 sticky로 보존한다

> 소스: P11/src_mini_CPU/FADD/barrel_shifter.v · L1-25 · 활성 연결

**변경:** 오른쪽 이동일 때 `i < count`인 입력 비트들을 모두 OR해 discarded를 만들고, 결과의 bit0에 OR한다. 왼쪽 이동과 doing=0의 동작은 P10과 같다.

**예:** 1.0에 2^-30을 더하면 작은 수를 30비트 오른쪽으로 밀어야 한다. 48비트 정렬 폭 안에서는 남지만, 지수 차이가 더 크면 1이 완전히 밀려나간다. P10은 그 1을 잃어 결과를 '정확히 1.0'으로 본다. P11은 bit0이 1로 남아 S=1 → NX=1, RUP이면 `0x3F800001`로 올린다.

**쓰이는 곳:** FADD 정렬(W=48)과 FADD 정규화(W=49, carry 정규화의 1비트 오른쪽 이동) 양쪽이다. 정규화의 오른쪽 이동에서도 잃는 비트가 sticky로 남는다.

### P11 Normalization_Controller → 지수가 1 아래로 내려가지 않도록 왼쪽 정규화를 제한한다

> 소스: P11/src_mini_CPU/FADD/Normalization_Controller.v · L1-45 · 활성 연결

**새 판단 순서:**

1. `all_zero && !Cout` → 정확한 0. EXPO_break=1, 이동 없음.
2. `Cout && !eff_sub` → 덧셈 carry. 오른쪽 1비트 이동, 지수 +1.
3. 그 외 → 왼쪽 이동량 `count = min(lzd_count, EXPO_in − 1)`. count가 0이면 doing=0.

**P10과의 차이:** P10은 eff_sub(뺄셈)일 때만 LZD 이동을 했고 이동량 제한이 없었다. 덧셈인데 carry가 없으면 이동하지 않았다. P11은 덧셈·뺄셈 구분 없이 'leading zero만큼, 단 지수가 1 아래로 내려가지 않을 만큼만' 이동한다.

**예(단위 테스트에 있는 사례):** 앞쪽 0이 3개인데 지수가 2라면 1칸만 이동하고 지수는 1이 된다. hidden 위치는 아직 0이므로 FP_rounding에서 subnormal로 포장된다. 지수가 10이었다면 3칸 이동하고 지수 7이 된다. 아주 작은 두 수의 결과를 억지로 hidden 1로 만들려고 계속 이동하면 지수가 음수가 되거나 8비트에서 wrap한다.

### P11 FMUL_core → subnormal 입력과 넓은 signed 지수 계산을 적용한다

> 소스: P11/src_mini_CPU/FMUL/FMUL_core.v · L2-178 · 활성 연결

**단계별 구성:**

- **s1 조합:** 유효 지수 `effA, effB`(0이면 1). `EXPO_base = effA + effB − 127`을 12비트 signed로 계산한다. 2^-149×2^-149처럼 결과 지수가 크게 음수여도 표현 가능해야 하기 때문이다.
- **s2 저장:** 유효숫자 `{(EXPO != 0), FRAC}` 24비트 두 개, EXPO_base, 부호 XOR.
- **s2 조합 → s3, s4 저장:** Multiplier가 48비트 곱을 만들고 두 번 등록한다.
- **s4 조합:** Normalization_MUL → FP_rounding(rm_pipe[3]).
- **s5, s6 저장:** 결과 32비트와 OF/UF/NX 3비트를 같은 enable로 함께 두 번 지연한다.

**사라진 하위 모듈:** MUL_SIGN(부호 XOR가 코어 안으로), MUL_EXPO_ADD·MUL_EXPO(EXPO_base 식과 FP_rounding으로), Exception_Handler(FP_rounding 패킹과 FP_special로). Multiplier만 계속 사용한다. 코드 길이도 P10 6.3KB → P11 4.6KB로 줄었다.

### P11 Normalization_MUL → 선행 1의 위치와 작은 지수에 맞춰 곱을 정렬한다

> 소스: P11/src_mini_CPU/FMUL/Normalization_MUL.v · L4-39 · 활성 연결

**알고리즘:**

1. 48비트 곱에서 가장 높은 1의 위치를 찾고 leading = 47 − 그 위치.
2. `normalized = FRAC_mul << leading`으로 선행 1을 bit47에 맞춘다.
3. `e = EXPO_base + 1 − leading`. 두 1.x의 곱은 bit46이 2^0 자리라서, bit47에 1이 있으면(곱이 2 이상) 지수 +1, bit46이면 그대로가 된다.
4. e ≥ 1이면 EXPO_out = e.
5. e < 1이면 부족분 deficit = 1 − e만큼 다시 오른쪽 이동하고, 버린 비트를 sticky로 bit0에 합친다. EXPO_out=1(→ FP_rounding에서 subnormal 후보).
6. 곱이 0이면 FRAC_out=0.

**왜 '선행 1 탐색'이 필요해졌나:** P10은 입력이 항상 1.x라고 가정했으므로 곱의 선행 1은 bit47 또는 bit46 둘 중 하나였다. subnormal 입력(0.x)이 들어오면 선행 1이 훨씬 아래에 있을 수 있다. 예를 들어 최소 subnormal×1.0의 곱은 bit23 근처에 1이 있다.

**예:** `2^-100 × 2^-30`은 EXPO_base = 27+97−127 = −3, 곱 1.0은 bit46에서 시작하므로 leading=1, e = −3+1−1 = −3. deficit=4만큼 오른쪽으로 밀어 hidden 위치가 0이 되고 결과는 `0x00080000`(=2^-130, 정확한 subnormal, 플래그 0)이다.

**역할 분리:** 출력은 48비트 FRAC와 9비트 EXPO이며, 반올림 모드별 최종 비트 선택과 OF/UF/NX는 FP_rounding이 맡는다.

### P11 Register_file → x0 고정과 f0 일반 저장을 파라미터로 구분한다

> 소스: P11/src_mini_CPU/Register/Register_file.v · L1-28 · 활성 연결

**변경:** `ZERO_REGISTER=1`이면 P10처럼 주소 0 읽기는 0, 쓰기는 차단한다. `ZERO_REGISTER=0`이면 주소 0도 일반 저장 레지스터가 된다. Rs1/Rs2의 쓰기 우회(같은 클럭에 쓰고 읽으면 we_data 반환)와 Rt 읽기에도 같은 정책을 적용한다.

**CPU 연결:** u_Regfile은 기본값 1, u_FPU_Regfile은 `.ZERO_REGISTER(0)`이다. 따라서 x0는 0을 유지하면서 f0에는 1.0·계산 결과 등을 저장할 수 있다.

**포워딩과의 관계:** FPU_Forwarding_Unit은 P10부터 FP Rd=0을 우회 대상에서 빼지 않았다. P10에서는 포워딩은 f0 값을 넘기는데 레지스터 파일은 f0 쓰기를 버리는 불일치가 있었다. P11에서 비로소 두 정책이 맞는다.

**흔한 오해:** 정수·FP 파일을 하나로 합친 것이 아니다. 같은 모듈 정의를 재사용하고 인스턴스별 정책만 다르게 한 것이다. 저장 배열은 여전히 두 개다.

### P11 FPU_Control → 미지원 요청이 기본 ADD로 흘러가지 않게 한다

> 소스: P11/src_mini_CPU/FPU_common/FPU_Control.v · L1-42 · 활성 연결

**변경 두 줄:** 기본값 `FPU_Control = 2'b11`(P10은 00). 지원 조건에 `Funct3 <= 3'b100`(rm 0~4) 검사를 추가했다. 단정밀도 fmt(Funct7[1:0]=00)이고 funct5가 00000/00001/00010일 때만 ADD/SUB/MUL 코드를 낸다.

**CPU에서 실제로 일어나는 일:** FPU_Control의 error 출력은 Pipeline_CPU에서 연결되지 않는다(P10도 동일). 대신 op=3 또는 rm>4가 FPU로 넘어가면 FP_special이 illegal로 잡아 canonical qNaN을 결과로 낸다. 디코더가 FP 연산으로 인식해 FRegWrite를 켠 명령이라면 목적 레지스터에는 qNaN이 기록된다. P10에서는 같은 상황에서 '모르는 FP 명령 = FADD'로 실행됐다.

**한계:** CPU가 illegal-instruction trap을 내는 것은 아니다. rm=111(DYN, fcsr의 frm 사용)도 지원하지 않고 illegal로 처리한다.

### P11 메모리 파일 경로와 기타 표기 변경

**Instruction_Memory/Data_Memory:** 초기 파일 경로가 P10 고정 경로에서 `./runtime/memo/program.txt`, `./runtime/memo/data.mem`으로 바뀌었다. RTL 파일이 있는 폴더가 아니라 시뮬레이터의 현재 작업 디렉터리 기준이다. 회귀 도구는 `_work/`를 작업 디렉터리로 쓰고 `tb/data/`의 원본을 128워드(빈칸은 NOP `00000013`)·1024워드(빈칸 0)로 채워 `_work/runtime/memo/`에 만든다.

**FPU_unpack:** P11 EXPO는 고정 `[30:23]`로 읽는다. W=32에서는 P10의 `[W-2 -:8]`과 같은 비트다. FP64 지원 같은 기능 변화로 설명하지 않는다.

**FPU_Hazard:** 암시적이던 FPU_6clk wire를 명시했다. `default_nettype none` 환경에서 암시적 net이 오류가 되지 않도록 한 정리이며, stall 알고리즘 변화는 아니다.

**코드 스타일:** P11 대부분의 파일은 포트 연결을 한 줄에 하나씩 쓰도록 포맷을 정리했다(.editorconfig 추가). 그래서 바이트 해시는 많이 달라졌지만 동작이 바뀐 파일은 위에 적은 것뿐이다.

### 역할이 옮겨지고 활성 경로에서 빠진 P10 모듈 8개

- **Rounding →** FP_rounding의 round_up 계산.
- **EXPO_MUX →** FP_rounding의 temp_EXPO(반올림 carry)와 encoded(0 처리).
- **Exception_Handler_ADD →** FP_rounding의 OF/UF·패킹, FP_special의 Inf/0 결과.
- **Exception_Handler(MUL) →** 같은 두 모듈.
- **MUL_SIGN →** FMUL_core의 `s1_SIGN_A ^ s1_SIGN_B`.
- **MUL_EXPO_ADD →** FMUL_core의 EXPO_base 식.
- **MUL_EXPO →** EXPO_base(−127)와 Normalization_MUL(정규화 보정)·FP_rounding(carry, OF/UF).
- **MUX(FPU_common) →** FPU 상위의 is_mul 선택과 Final_MUX.

이 파일들은 P11 CPU.f에 아직 들어 있어 컴파일은 되지만, Pipeline_CPU에서 인스턴스 트리를 따라가면 도달하지 않는다. 합성 도구는 top에서 쓰이지 않는 모듈을 회로로 만들지 않는다.

## 18. Project11 계산 예시 따라가기

아래 값은 모두 reference.py(정수 기반 기준 모델)로 확인한 결과다. 결과 16진수와 플래그(NV/OF/UF/NX)를 함께 적었다.

### 일반 산술

- **`1.5 + 2.25`(RNE):** `0x3FC00000 + 0x40100000 = 0x40700000`(3.75). 지수 차이 1, 정렬 후 1.1+10.01=11.11 → 1.111×2^1. 정확하므로 플래그 0.
- **`3.0 × 1.5`(RNE):** `0x40400000 × 0x3FC00000 = 0x40900000`(4.5). 유효숫자 1.1×1.1=10.01 → bit47에 선행 1 → 지수 +1.
- **`(1+2^-23) × (1+2^-23)`(RNE):** 정확한 값 1+2^-22+2^-46. 2^-46 부분은 버려지고 sticky=1이므로 결과 `0x3F800002`, NX=1.

### 반올림 경계

- **`1.0 + 2^-24`:** 정확한 tie. RNE·RTZ·RDN → `0x3F800000`, RUP·RMM → `0x3F800001`. 모든 모드에서 NX=1.
- **`1.0 + (2^-24보다 조금 큰 수 0x33800001)`(RNE):** tie 초과 → `0x3F800001`.
- **`1.0 − 1.0`:** 정확한 상쇄. RNE → `0x00000000`, RDN → `0x80000000`. 플래그 0.

### overflow

- **`max + max`:** 정확한 값 2^129는 표현 불가. RNE → `0x7F800000`(+Inf), RTZ → `0x7F7FFFFF`(최대 유한값). 둘 다 OF=1, NX=1.
- **`(−max) + (−max)`:** RDN → `0xFF800000`(−Inf), RUP → `0xFF7FFFFF`(−최대 유한값). 음수에서 RUP은 0 쪽으로 가는 방향이기 때문이다.

### subnormal과 underflow

- **`최소 subnormal + 최소 subnormal`:** `0x00000001 + 0x00000001 = 0x00000002`. 정확하므로 UF=0, NX=0.
- **`최대 subnormal + 최소 subnormal`:** `0x007FFFFF + 0x00000001 = 0x00800000`. subnormal끼리 더해서 최소 normal로 승격. 정확하므로 플래그 0.
- **`최소 normal − 최소 subnormal`:** `0x007FFFFF`. normal에서 subnormal로 내려옴. 정확하므로 플래그 0.
- **`2^-100 × 2^-30`:** `0x0D800000 × 0x30800000 = 0x00080000`(2^-130). 곱셈 결과가 subnormal. 정확하므로 플래그 0.
- **`최소 subnormal × 0.5`:** 정확한 값 2^-150은 0과 최소 subnormal의 정확한 중간. RNE → `0x00000000`(짝수 쪽), RMM → `0x00000001`. 둘 다 UF=1, NX=1.

### 특수값

- **`+Inf − +Inf`:** `0x7FC00000`, NV=1, error=1.
- **`0 × Inf`:** `0x7FC00000`, NV=1.
- **`sNaN(0x7F800001) + 1.0`:** `0x7FC00000`, NV=1.
- **`qNaN(0x7FC00000) + 1.0`:** `0x7FC00000`, NV=0. quiet NaN은 조용히 전파된다.
- **`−1.0 × +Inf`:** `0xFF800000`(−Inf), 플래그 0.
- **`+0 + −0`:** RNE → `0x00000000`, RDN → `0x80000000`.
- **`−0 × 5.0`:** `0x80000000`.
- **op=3 또는 rm=5:** `0x7FC00000`, error=1(illegal), NV=0.

## 19. Project11 CPU 통합에서 바뀐 점과 연결 범위

### Pipeline_CPU에서 실제로 바뀐 것

Pipeline_CPU.v는 포맷 정리를 제외하면 단 한 군데가 바뀌었다. FP 레지스터 인스턴스가 `Register_file #(.W(W), .ZERO_REGISTER(0)) u_FPU_Regfile`이 된 것이다. 나머지 IF/ID/EX/MEM/WB 연결, 해저드·포워딩 연결, FPU_shadow_reg 108비트 묶음, Result_MUX/CPU_MUX는 그대로다. 출력 포트 목록도 P10과 같다.

### FPU 새 포트는 CPU 안에서 어디까지 연결되나

- **연결됨:** IN_A/IN_B, op, rm, FPU_en(=EX_is_FPU), result_out, ZF, sign, OF, UF.
- **연결 안 됨:** NV, NX, valid_out, error. 인스턴스에 포트 이름조차 적혀 있지 않거나(NV/NX/valid_out) 빈 연결이다(error).
- **결과 유효 판단:** P11 FPU의 valid_out 대신 기존 FPU_Check의 FPU_Valid를 쓴다. 두 신호는 같은 7단을 세므로 정상 동작에서는 일치하지만, CPU가 FPU 자체 valid를 쓰는 구조는 아니다.
- **OF/UF:** P10과 같이 FPU_shadow_reg 묶음에 넣어 다시 지연한다. 21장의 '플래그 정렬' 주의점이 P11에도 그대로 적용된다.

결론: P11에서 새로 생긴 NV·NX·illegal 정보는 **FPU 단독 테스트에서는 관찰되지만 CPU 프로그램은 볼 수 없다.** fcsr/fflags CSR이 없기 때문이다. CPU 수준에서 P11이 달라진 점은 '결과 비트가 IEEE 규칙대로 나온다'와 'f0를 쓸 수 있다' 두 가지다.

### f0를 쓰는 CPU 프로그램 따라가기

cpu_fp_special 테스트는 아래 프로그램을 Instruction_Memory에 직접 넣는다. 데이터 메모리 0~3번 워드는 1.0, 2.0, +Inf, 최소 subnormal이다.

1. `flw f0, 0(x0)` → f0=1.0.
2. `fadd f1, f0, f0` → FLW 직후 f0를 바로 쓰는 의존 연산. f1=2.0.
3. `flw f2, 4(x0)` → f2=2.0.
4. `fmul f0, f1, f2` → f0를 다시 쓴다. f0=4.0.
5. `fadd f3, f0, f1` → 아직 FPU 안에서 계산 중인 f0를 기다려 사용. f3=6.0.
6. `flw f4, 8(x0)` → f4=+Inf.
7. `fsub f5, f4, f4` → Inf−Inf = qNaN `0x7FC00000`.
8. `flw f6, 12(x0)` → f6=최소 subnormal.
9. `fadd f7, f6, f6` → `0x00000002`.

검사 6개: f0=`0x40800000`, f1=`0x40000000`, f3=`0x40C00000`, f5=`0x7FC00000`, f7=`0x00000002`, 정수 x0=0.

**P10이었다면:** 1번에서 f0 쓰기가 막혀 f0=0으로 남는다. 그 결과 f1=0+0=0이고, 4번의 f0 쓰기도 버려져 f3도 0이 된다. 7번은 Inf−Inf를 판정하는 특수값 경로가 없어 canonical NaN을 보장하지 못하고, 9번은 hidden 1을 붙인 정상수 계산이 되어 `0x00000002`가 나오지 않는다. 이 하나의 프로그램이 P11의 CPU 수준 변화를 모두 보여준다.

### 빌드 목록(CPU.f)의 변화

- **경로:** P10 CPU.f는 `./verilog/Project10_mini_CPU/...`처럼 Engineering_Project 폴더 기준 경로라 그 위치에서 실행해야 했다. P11은 Project11 루트 기준 상대 경로만 쓴다. 프로젝트 폴더만 옮겨도 같은 명령으로 컴파일된다.
- **추가:** FP_special.v, FP_rounding.v, Final_MUX.v, FPU_classifier.v.
- **제외:** Top_CPU.v, ALU_port_MUX.v, ALU_A_MUX.v, ALU_B_MUX.v, Pipe_reg_2clk.v, Pipe_reg_4clk.v. P10에서도 미사용이던 과거 모듈이다. Pipe_reg_3clk.v는 목록 끝에 남아 있지만 여전히 인스턴스는 없다.
- **유지되지만 미사용:** 역할을 넘긴 8개 모듈(17장 끝).
- **테스트벤치:** CPU.f에는 Testbench_CPU.v만 포함한다. 나머지 SV 테스트벤치는 회귀 도구가 필요할 때 따로 추가한다.

### 폴더 구조의 변화

- **tb/:** P10의 TB 13개 중 Testbench_CPU.v만 남기고, SV 테스트벤치 4개(fp32_regression, fp_rounding_checks, cpu_fp_special, report_waveform)를 새로 만들었다. 프로그램·데이터 이미지는 `tb/data/`로 옮겼다.
- **tools/:** 기준 모델과 실행 도구 8개(reference.py, run_regression.py, run_xsim.ps1, compare_vivado.tcl, check_vivado_environment.tcl, synthesis_probe.v, render_report_assets.py, README).
- **docs/:** 설계 명세(01_design), 검증 기록(02_verification), 제출 보고서(07_submission_report), results.json, 구조도.
- **_work/:** 모든 실행 산출물(로그, vvp, VCD, 런타임 메모리 이미지). 원본과 분리되어 있어 지워도 다시 생성된다.

## 20. Project11 검증 환경 상세

### 기준 모델 reference.py는 어떻게 답을 아나

FP32 유한수를 모두 `2^-149` 단위의 정수로 바꾼다. 최소 subnormal이 1, 1.0이 2^149이다. 이렇게 하면 덧셈·뺄셈은 정수 덧셈, 곱셈은 정수 곱셈(단위 2^-298)으로 오차 없이 계산된다. 그 정확한 정수를 '남길 자릿수 단위'로 나눈 몫과 나머지를 구해, 나머지와 반올림 모드로 올림 여부를 정한다.

**왜 중요한가:** RTL처럼 지수 정렬·GRS 비트를 쓰지 않고 완전히 다른 방법으로 계산한다. RTL 알고리즘을 그대로 Python으로 옮긴 모델이면 같은 실수를 같이 하므로 오류를 못 잡는다. 또한 PC의 float 연산을 쓰지 않아 호스트의 반올림 모드 영향도 없다.

### 벡터 구성: 30,626건은 어디서 왔나

- **경계값 조합 6,000건:** 대표값 20개(±0, ±최소 subnormal, ±최대 subnormal, ±최소 normal, ±1.0, 1.0의 다음 수, 0.5, 2^-24, 2^-25, ±최대 유한값, ±Inf, qNaN, sNaN) × 20개 × 연산 3 × rm 5.
- **랜덤 20,000건:** 고정 seed 20260913의 32비트 랜덤 입력·연산·rm.
- **표적 4,800건:** 지수 1·2·3·10·126·127·253·254와 fraction 6종을 조합해, 바로 옆 수·같은 수·최소 subnormal 등과 연산. 최소 지수의 상쇄, 큰 지수 차이의 sticky/borrow를 노린다.
- **미지원 제어 4건:** op=3, rm=5·6·7.
- **bubble·reset:** 103행마다 en=0 행(검사 안 함), 997행마다 reset 행(진행 중 요청 폐기)을 끼운다. reset으로 버려진 요청을 빼고 실제 비교된 유효 출력이 30,626건이다.

### fp32_regression 검사기의 구조

ISOLATE=0(plain)과 ISOLATE=1(isolated) FPU 두 개에 같은 입력을 넣는다. 테스트벤치는 기대 결과·플래그·error를 7칸 큐에 넣고 매 클럭 민다. 매 클럭 검사 항목:

- valid_out이 정확히 7단 뒤에 1인가(LATENCY).
- 두 FPU의 결과·플래그·error가 기준 모델과 같은가(FP mismatch).
- `UF=1 → NX=1`이 성립하는가.
- ZF·sign 사이드밴드가 결과와 일치하는가.

두 RTL끼리만 비교하지 않고 항상 기준 모델과 비교하므로 '둘 다 같이 틀린' 경우도 실패한다.

### fp_rounding_checks: 23개 직접 검사

FP_rounding 19개와 정규화 4개다. 파이프라인 없이 모듈 입력을 직접 넣어 즉시 확인한다.

- **방향성 반올림 정확값 2개:** 정확한 −1.0 RDN, 정확한 1.0 RUP은 올리면 안 된다.
- **tie 3개:** 짝수 LSB RNE(유지), 같은 값 RMM(올림), 홀수 LSB RNE(올림).
- **sticky만 있는 경우 3개:** RNE는 유지, RUP 양수·RDN 음수는 올림.
- **carry·overflow 5개:** 끝자리 carry로 지수 +1, 지수 254에서 carry → Inf, 지수 255 입력의 RTZ·RDN·RUP별 Inf/최대 유한값.
- **subnormal 6개:** 정확한 subnormal, 최소 normal로 승격, tie로 0이 되는 경우(RNE), 같은 경우 RMM, 음수 tiny RDN·RTZ.
- **정규화 4개:** 지수 예산이 1뿐인 왼쪽 이동, 일반 왼쪽 이동, 정확한 상쇄 표시, carry 오른쪽 이동의 sticky 보존.

### 오류 주입: 검사기가 진짜로 잡는지 시험하기

- **negative control:** 벡터 32줄짜리 짧은 파일을 만들고 마지막 기대값의 한 비트를 뒤집는다. 검사기가 'FP mismatch'로 실패해야 PASS다. 검사기가 아무것도 안 보고 PASS만 찍는 버그를 막는다.
- **RTL mutation:** `_work`에 FP_rounding 복사본을 만들고 RDN의 `SIGN && inexact`를 `SIGN`으로 바꾼다(과거 실제로 있던 버그 형태). 이 변이로 fp_rounding_checks가 'round boundary' 실패를 내야 PASS다. 원본 소스는 건드리지 않는다.

### activity 실험

특수값만 섞은 500개 요청을 넣고 VCD에서 plain/isolated의 a1/b1 비트 전환 수를 센다. ISOLATE=1이 적어야 통과한다. 결과는 10,315 대 0이다. 이것은 전력(W) 측정이 아니다.

### CPU 검사

- **Testbench_CPU 59개:** 기존 통합 프로그램을 끝까지 실행하고 정수 레지스터 29개와 FP 레지스터 30개를 기대값과 비교한다. 정확히 59개의 [PASS]가 나와야 한다. 명령어별 commit trace 비교는 아니다.
- **cpu_fp_special 6개:** 19장의 f0·특수값 프로그램.

### 실행 방법과 결과 기록

Project11 루트에서 `python tools/run_regression.py`(빠른 확인은 `--quick`, 랜덤 1,000건). 필요 도구는 Python 3.10 이상과 PATH의 iverilog, vvp다. Vivado xsim으로 같은 벡터를 다시 돌리려면 `.\tools\run_xsim.ps1`. 결과 요약과 RTL SHA-256은 `_work/results.json`에 생기고, 공개용 사본이 `docs/results.json`이다.

**저장된 기록:** 2026-09-18 Icarus 전체 회귀에서 FPU 30,626건, 단위 23개, CPU 59+6개, negative control·mutation 모두 통과. 2026-09-15에는 xsim 2026.1에서도 같은 수치를 통과했다.

**이번 문서 작성 중 재실행(2026-10-28):** 현재 로컬 소스 그대로 `python tools/run_regression.py` 전체 회귀를 다시 돌렸다. ROUND/NORMALIZE PASS 23, RTL mutation 검출, FP PASS checked=30626, negative control 검출, a1/b1 전환 10,315 대 0, CPU PASS 59, CPU special/f0 PASS 6으로 모두 통과했다. 9월 기록 이후 포맷 정리로 많은 파일의 해시가 바뀌었지만, 현재 소스 기준으로도 기능 결과가 같다는 것을 확인한 것이다. 새 결과와 해시는 `_work/results.json`에 있고 docs/results.json은 갱신하지 않았다. Vivado xsim은 다시 돌리지 않았다.

### FPGA 비교는 아직 없다

compare_vivado.tcl은 xc7a35tcpg236-1, 20ns 클럭, FPU만 OOC 합성·배치배선해 ISOLATE=0/1을 비교하도록 만들었다. 하지만 Vivado가 RTL elaboration 뒤 exit code 1로 종료되어 보고서가 생성되지 않았다. 플립플롭 1개짜리 synthesis_probe도 같은 지점에서 종료되었으므로 FPU 크기 문제로 단정하지 않는다. 따라서 LUT·FF·Fmax·전력 수치는 현재 말할 수 없다.

## 21. Project11을 설명할 때 꼭 구분할 경계

### FPU 단독 지원과 CPU 통합 지원

FPU는 NV/OF/UF/NX와 valid_out을 제공하지만 CPU 최상위 출력은 기존 wb_FPU_OF/UF 중심이다. NV/NX 누적 CSR이나 frm/fcsr, trap 경로는 없다. 따라서 'IEEE 예외가 CPU 소프트웨어에 모두 전달된다'고 말하면 실제 연결 범위를 넘어선다.

현재 Pipeline_CPU는 FPU가 완료 시점에 내놓은 OF/UF를 FPU_shadow_reg의 요청 메타데이터 묶음에 넣어 다시 지연한다. 이 연결은 현재 연산의 결과와 동일 시점의 flags를 직접 합치는 방식이 아니다. 결과값 테스트가 통과했더라도 WB 플래그의 명령어별 정렬까지 입증된 것은 아니므로 리뷰 때 따로 확인할 항목이다. 이번 문서 작성에서는 RTL을 변경하지 않았다.

### ISA 지원을 과장하지 않기

PC·메모리·명령어 형식은 RV32 계열을 따르지만 전체 RV32I/RV32F 준수 구현으로 표현할 수 없다. 현재 정수 ALU 세부 명령, load/store 크기, signed 분기 경계, JALR 링크값, 일부 load-use 조건에는 범위 제한이나 추가 검토 사항이 있다. FP는 FLW/FSW/FADD.S/FSUB.S/FMUL.S 중심이며 나눗셈·제곱근·FMA·변환·비교·정수↔FP 이동 명령은 구현되지 않았다.

AMBA/APB 인터페이스도 이 두 CPU의 현재 활성 모듈 목록에는 없다. Instruction_Memory와 Data_Memory에 내부 신호로 직접 연결되어 있다. 일반 CPU 공부에서 다룬 버스 개념과 현재 프로젝트에 실제 구현된 버스는 구분한다.

### IEEE 754 '적합'이라고 말하지 않기

P11은 binary32 ADD/SUB/MUL에 대해 다섯 반올림 모드와 특수값 규칙을 구현하고 표본 회귀로 확인했다. 공인 conformance suite나 formal proof를 통과한 것은 아니다. '지원 범위 안에서 독립 기준 모델과 30,626건 일치'가 정확한 표현이다.

### 오래된 모듈이 남는 이유

새 FP_rounding이 역할을 통합하면 예전 Rounding·EXPO_MUX·Exception_Handler_ADD가 top에서 더 이상 연결되지 않는다. 소스 파일이나 CPU.f에 남아 있다는 이유만으로 칩 안에 두 반올림 경로가 모두 사용된다고 말할 수 없다. 최상위에서 내려가는 인스턴스 트리가 기준이다.

## 22. Project10 테스트벤치 안내

테스트벤치는 입력을 만들고 결과를 검사하는 시뮬레이션 코드다. CPU의 기능 모듈과 구분해서 읽는다. 같은 폴더에 있어도 `$display`, `$fatal`, 시간 지연 등의 검증 코드는 일반적으로 실제 CPU 데이터 경로가 아니다. Project11 테스트벤치는 20장에서 다뤘다.

### Project10의 검증 파일 안내

- **Testbench_CPU:** CPU.f가 함께 포함하는 통합 검사. 명령어 실행 후 정수·FP 레지스터와 메모리의 기대값을 확인한다. P11에도 이어진다.
- **Pipeline_CPU_tb:** Pipeline_CPU를 구동하고 진행·출력을 관찰하는 별도 top 테스트다. Testbench_CPU와 같은 파일이 아니다.
- **FPU_tb:** FPU 상위를 구동하는 테스트다. **FPU_ADD_tb / FPU_MUL_tb:** 각각 ADD·MUL 코어 경로를 집중해서 확인한다.
- **CLA_tb / LZD_tb:** 가산기와 leading-zero 검출기 같은 하위 조합 연산의 단위 검사다.
- **FPU_Check_tb:** 진행 중 목적지 추적과 FP 완료·대기 판단을 검사한다.
- **Testbench_Forwarding_Unit / Testbench_port_MUX:** 우회 선택 제어와 실제 데이터 선택을 각각 검사한다. 둘은 다른 층의 검증이다.
- **Top_CPU_tb / Top_module_tb:** 이전 top을 대상으로 만든 테스트 흔적이다. 현재 active top·포트와의 호환을 먼저 확인해야 한다.
- **Testbench.v:** 독립 module 선언이 없는 빈 보존 파일이다. 파일명만 보고 실행할 top으로 지정하면 안 된다.

### P10과 P11 검증 방식의 차이

P10은 사람이 프로그램을 쓰고 기대값을 손으로 계산해 넣는 방식이었다(memo의 통합테스트_01~07). 손 계산은 경계값을 빠뜨리기 쉽고, 기대값 자체가 틀려도 알기 어렵다. P11은 기대값을 독립 모델이 만들고, 검사기가 정말 실패를 잡는지까지 오류 주입으로 확인한다. 결과는 PASS 개수와 함께 RTL 해시로 기록되어 '어떤 소스에서 통과했는가'를 추적할 수 있다.

성공률이나 PASS 개수는 커버리지 백분율이 아니다. 코드 커버리지·기능 커버리지·assertion·경계 조합을 정의하고 따로 측정해야 한다. FPGA 전체 PPA와 실측 전력도 이 자료에서 입증하지 않는다.

## 23. 면담 전에 말로 풀어볼 설명

### 30초 전체 소개

“Project10은 5단 정수 파이프라인에 FP32 덧셈·뺄셈·곱셈 파이프라인을 연결한 CPU입니다. 정수 결과와 FP 결과의 완료 시점이 달라서 목적 레지스터·제어 정보를 지연시키고, 해저드와 forwarding으로 의존성을 처리합니다. Project11에서는 이 구조를 바탕으로 FP 특수값, subnormal, 다섯 반올림 모드, 플래그 정렬과 자동 검증을 확장했습니다.”

이어 “FPU 자체의 지원 기능과 CPU 최상위에 연결된 기능은 구분하고, 전체 ISA·IEEE 적합성이나 FPGA 실측 전력까지 완료한 것은 아닙니다”라고 범위를 설명할 수 있어야 한다.

### 왜 이 모듈이 필요한지 질문받으면

- **PC_Adder:** “명령어가 4바이트여서 순차 다음 주소 PC+4를 만듭니다. 분기 선택은 PC_MUX가 합니다.”
- **ImmGen:** “명령어 종류별로 흩어진 비트를 모으고 부호 확장해서 주소·정수 연산에 쓸 수 있게 합니다.”
- **Forwarding:** “레지스터 파일에 써지기 전이라도 뒤 단계에 이미 계산된 최신값을 EX로 우회합니다.”
- **stall / flush:** “stall은 값 유지, flush는 작업 무효화입니다. load-use에서는 앞단을 보관하면서 실행 단계에 bubble을 넣습니다.”
- **FPU_shadow_reg:** “FP 결과가 늦게 나와도 요청 당시 Rd와 쓰기 제어가 같이 도착하게 합니다.”
- **sticky:** “잘라낸 하위 비트에 1이 있었는지 보존해 반올림과 NX 판단을 정확하게 합니다.”
- **ZERO_REGISTER:** “정수 x0는 고정 0이고 FP f0는 일반 저장소라서, 같은 모듈의 인스턴스별 정책을 구분합니다.”
- **ISOLATE:** “유효한 일반 산술이 없을 때 데이터 레지스터 갱신을 막아 불필요한 변화를 줄입니다. 실제 전력 절감률은 별도 측정입니다.”

### 코드 리뷰 순서

1. Pipeline_CPU에서 IF→ID→EX→MEM→WB와 제어 묶음을 따라간다.
2. ADD, LW, SW, FLW, FSW를 하나씩 골라 주소·데이터·쓰기 뱅크가 어디서 갈리는지 말한다.
3. 의존하는 두 명령어를 붙여 forwarding 또는 stall이 필요한 이유를 설명한다.
4. FPU에서 한 요청의 op/rm/valid/Rd가 결과와 같은 시간에 만나는지 본다.
5. P11의 0, subnormal, Inf, NaN, tie 반올림 사례를 각각 한 개 설명한다.
6. 미지원 기능과 현재 추가 검토 지점을 숨기지 않고 구체적으로 구분한다.

## 24. 전체 파일 대조표와 소스 기준

다음 목록은 문서 생성 시 실제 소스에서 자동으로 만든다. 활성 여부는 Pipeline_CPU 기준 인스턴스 도달성이다. 간단한 정적 분석 후 핵심 연결을 직접 대조했으며, 합성 도구의 면적 보고서나 elaboration 결과를 뜻하지 않는다. 같은 모듈이 여러 번 쓰여도 정의 종류 수는 한 개로 센다.

<!-- AUTO_INVENTORY -->

### 파일 수와 활성 연결 수

P10: 설계 모듈 정의 70개, 활성 62개. P11: 정의 73개, 활성 58개. 인스턴스 수나 플립플롭 수가 아니라 모듈 정의 종류 수다.

### P10 전체 목록: 이름과 역할

- **ALU** → 논리·덧셈/뺄셈·시프트 연산기를 묶어 최종 정수 결과를 만든다 / 활성 / `ALU/ALU.v`.
- **ALU_Control** → 명령어의 연산 종류를 ALU 내부 선택 코드로 바꾼다 / 활성 / `ALU/ALU_Control.v`.
- **ALU_MUX** → 세 연산 그룹 중 ALU_Control에 해당하는 결과를 고른다 / 활성 / `ALU/ALU_MUX.v`.
- **ALU_port_MUX** → 과거 정수 ALU 포워딩 입력 선택기 / 미연결 / `ALU/ALU_port_MUX.v`.
- **calculate_group** → 덧셈·뺄셈과 0·부호 판정을 만든다 / 활성 / `ALU/calculate_group.v`.
- **logical_group** → 비트별 AND·OR·XOR를 계산한다 / 활성 / `ALU/logical_group.v`.
- **shift_group** → 논리 왼쪽·논리 오른쪽·산술 오른쪽 시프트를 수행한다 / 활성 / `ALU/shift_group.v`.
- **Early_Jump_Unit** → JAL의 목적지를 ID에서 미리 계산한다 / 활성 / `Early_Jump_Unit.v`.
- **barrel_shifter** → 지정된 비트 수만큼 유효숫자를 한 번에 이동한다 / 활성 / `FADD/barrel_shifter.v`.
- **CLA** → carry lookahead 방식으로 넓은 유효숫자를 더한다 / 활성 / `FADD/CLA.v`.
- **comparator** → 두 FP 입력의 부호를 제외한 크기를 비교한다 / 활성 / `FADD/comparator.v`.
- **Cond_Inverter** → 뺄셈일 때 피연산자를 반전해 2의 보수 연산을 준비한다 / 활성 / `FADD/Cond_Inverter.v`.
- **Exception_Handler_ADD** → P10 덧셈 결과를 조립하고 overflow/underflow를 단순 처리한다 / 활성 / `FADD/Exception_Handler_ADD.v`.
- **EXPO_CAL** → 정규화 이동량에 맞춰 지수를 보정한다 / 활성 / `FADD/EXPO_CAL.v`.
- **EXPO_MUX** → 반올림 carry와 정확한 0 표시를 지수에 반영한다 / 활성 / `FADD/EXPO_MUX.v`.
- **EXPO_SUB** → 두 지수의 차이와 어느 피연산자를 이동할지 구한다 / 활성 / `FADD/EXPO_SUB.v`.
- **FADD_core** → 지수 정렬부터 반올림까지 FP 덧셈·뺄셈 단계를 연결한다 / 활성 / `FADD/FADD_core.v`.
- **LZD** → 유효숫자 맨 앞에서 연속된 0의 개수를 센다 / 활성 / `FADD/LZD.v`.
- **Magnitude_Restoration** → 감산 결과가 음수 방향이면 반대쪽 감산값으로 크기를 복원한다 / 활성 / `FADD/Magnitude_Restoration.v`.
- **Mode_Detector** → 부호와 ADD/SUB 요청으로 실제 유효숫자 연산을 정한다 / 활성 / `FADD/Mode_Detector.v`.
- **Normalization_Controller** → 결과 유효숫자의 정규화 방향과 이동량을 결정한다 / 활성 / `FADD/Normalization_Controller.v`.
- **Rounding** → P10 덧셈 결과의 남는 하위 비트로 반올림을 결정한다 / 활성 / `FADD/Rounding.v`.
- **SIGN** → ADD/SUB 종류와 더 큰 크기의 부호로 결과 부호를 정한다 / 활성 / `FADD/SIGN.v`.
- **Exception_Handler** → P10 곱셈의 최종 비트열을 조립한다 / 활성 / `FMUL/Exception_Handler.v`.
- **FMUL_core** → FP 부호·지수·유효숫자 곱을 만들고 덧셈 경로와 시간을 맞춘다 / 활성 / `FMUL/FMUL_core.v`.
- **MUL_EXPO** → bias와 정규화·반올림 carry를 반영해 곱의 지수를 만든다 / 활성 / `FMUL/MUL_EXPO.v`.
- **MUL_EXPO_ADD** → 두 저장 지수를 더한다 / 활성 / `FMUL/MUL_EXPO_ADD.v`.
- **MUL_SIGN** → 곱의 부호를 두 입력 부호의 XOR로 정한다 / 활성 / `FMUL/MUL_SIGN.v`.
- **Multiplier** → 24비트 유효숫자 두 개를 곱해 48비트 값을 만든다 / 활성 / `FMUL/Multiplier.v`.
- **Normalization_MUL** → P10 곱의 소수점 위치를 맞추고 유지할 fraction을 반올림한다 / 활성 / `FMUL/Normalization_MUL.v`.
- **CPU_Forwarding_Unit** → 정수 소스가 MEM/WB 목적지와 같으면 최신값 우회를 요청한다 / 활성 / `Forwarding/CPU_Forwarding_Unit.v`.
- **Forwarding_Combine** → 현재 EX 명령의 종류에 맞는 우회 판단을 선택한다 / 활성 / `Forwarding/Forwarding_Combine.v`.
- **Forwarding_Unit** → 정수·FP 우회 판단기를 묶어 MEM/WB 선택 코드를 만든다 / 활성 / `Forwarding/Forwarding_Unit.v`.
- **FPU_Forwarding_Unit** → 정수 주소와 FP 데이터를 구분하여 우회한다 / 활성 / `Forwarding/FPU_Forwarding_Unit.v`.
- **FPU_classifier** → P10에 남아 있는 미완성 FP 분류기 초안 / 미연결 / `FPU_common/FPU_classifier.v`.
- **FPU_Control** → FP 명령어 필드를 ADD·SUB·MUL 코드와 rm으로 변환한다 / 활성 / `FPU_common/FPU_Control.v`.
- **FPU_unpack** → FP32 비트열을 부호·지수·fraction으로 분리한다 / 활성 / `FPU_common/FPU_unpack.v`.
- **MUX** → P10의 ADD/SUB 결과와 MUL 결과·플래그를 고른다 / 활성 / `FPU_common/MUX.v`.
- **CPU_Hazard** → 분기·점프의 잘못된 경로를 비우고 정수 load-use를 정지시킨다 / 활성 / `Hazard/CPU_Hazard.v`.
- **FPU_Check** → 진행 중인 FP 명령어의 목적지와 완료 시점을 추적한다 / 활성 / `Hazard/FPU_Check.v`.
- **FPU_Hazard** → FP 의존성과 결과 합류 시점에 맞춰 CPU 진행을 조절한다 / 활성 / `Hazard/FPU_Hazard.v`.
- **Hazard_Combine** → CPU·FPU의 stall/flush 요구를 최종 제어로 합친다 / 활성 / `Hazard/Hazard_Combine.v`.
- **Hazard_Unit** → 정수와 FP 해저드 판단을 묶어 파이프라인 제어를 만든다 / 활성 / `Hazard/Hazard_Unit.v`.
- **ImmGen** → 흩어져 있는 즉시값 비트를 모아 32비트 부호 확장 값을 만든다 / 활성 / `ImmGen.v`.
- **Instruction_Memory** → PC가 가리키는 32비트 명령어를 읽는다 / 활성 / `Instruction_Memory.v`.
- **JALR_Jump_Unit** → 레지스터 기반 점프 주소를 만들고 최하위 비트를 0으로 한다 / 활성 / `JALR_Jump_Unit.v`.
- **Main_Decoder** → 명령어 비트를 나누고 실행 경로와 쓰기 제어를 정한다 / 활성 / `Main_Decoder.v`.
- **ALU_A_MUX** → 과거 ALU A 입력에서 PC와 일반 피연산자를 선택한다 / 미연결 / `MUX/ALU_A_MUX.v`.
- **ALU_B_MUX** → 과거 ALU B 입력에서 즉시값·4·일반 피연산자를 고른다 / 미연결 / `MUX/ALU_B_MUX.v`.
- **CPU_MUX** → WB에서 메모리 읽기값 또는 연산 결과를 선택한다 / 활성 / `MUX/CPU_MUX.v`.
- **FPU_MUX** → FPU 결과가 유효한 사이클에만 결과를 통과시킨다 / 활성 / `MUX/FPU_MUX.v`.
- **PC_MUX** → 순차 주소·분기·점프 후보 중 실제 다음 PC를 고른다 / 활성 / `MUX/PC_MUX.v`.
- **port_MUX** → 정수·FP·포워딩·즉시값을 조합해 EX 입력과 저장 데이터를 고른다 / 활성 / `MUX/port_MUX.v`.
- **Result_MUX** → EX/MEM으로 보낼 정수 결과와 FPU 결과를 고른다 / 활성 / `MUX/Result_MUX.v`.
- **PC_Adder** → 현재 PC에 4를 더해 순차 실행할 다음 주소를 만든다 / 활성 / `PC/PC_Adder.v`.
- **PC_reg** → 현재 명령어 주소를 저장하고 허용된 클럭에서 갱신한다 / 활성 / `PC/PC_reg.v`.
- **PC_Target** → 분기 명령어의 PC에 즉시값을 더해 분기 목적지를 만든다 / 활성 / `PC/PC_Target.v`.
- **PCSrc** → ALU 비교 신호로 조건 분기를 할지 결정한다 / 활성 / `PC/PCSrc.v`.
- **Data_Memory** → load/store의 32비트 데이터를 저장한다 / 활성 / `Register/Data_Memory.v`.
- **FPU_shadow_reg** → FPU의 늦은 결과에 맞춰 명령어의 목적지·제어를 지연한다 / 활성 / `Register/FPU_shadow_reg.v`.
- **Pipe_reg_1clk** → 입력 묶음을 다음 클럭의 출력으로 저장한다 / 활성 / `Register/Pipe_reg_1clk.v`.
- **Pipe_reg_1clk_control** → stall과 flush가 가능한 CPU 단계 레지스터 / 활성 / `Register/Pipe_reg_1clk_control.v`.
- **Pipe_reg_1clk_en** → enable이 켜질 때만 한 단계 데이터를 저장한다 / 활성 / `Register/Pipe_reg_1clk_en.v`.
- **Pipe_reg_2clk** → 데이터를 두 개의 직렬 레지스터로 지연한다 / 미연결 / `Register/Pipe_reg_2clk.v`.
- **Pipe_reg_3clk** → 데이터를 세 개의 직렬 레지스터로 지연한다 / 미연결 / `Register/Pipe_reg_3clk.v`.
- **Pipe_reg_4clk** → 데이터를 네 개의 직렬 레지스터로 지연한다 / 미연결 / `Register/Pipe_reg_4clk.v`.
- **Register_file** → 레지스터 32개의 값을 보관하고 피연산자를 읽는다 / 활성 / `Register/Register_file.v`.
- **FPU** → FP32 덧셈·뺄셈·곱셈을 파이프라인으로 계산하는 상위 회로 / 활성 / `TOP_module/FPU.v`.
- **Pipeline_CPU** → 모든 CPU 단계와 FPU를 연결하는 실제 최상위 회로 / 활성 / `TOP_module/Pipeline_CPU.v`.
- **Top_CPU** → 과거 단일 사이클 CPU 연결 예제 / 미연결 / `TOP_module/Top_CPU.v`.

### P11 전체 목록: 유지·추가·대체 대조

- **ALU** / 활성 / `ALU/ALU.v`. P10 핵심 RTL 동작 유지.
- **ALU_Control** / 활성 / `ALU/ALU_Control.v`. P10 핵심 RTL 동작 유지.
- **ALU_MUX** / 활성 / `ALU/ALU_MUX.v`. P10 핵심 RTL 동작 유지.
- **ALU_port_MUX** / 빌드 제외·미연결 / `ALU/ALU_port_MUX.v`. P10과 같이 활성 CPU 연결에서 미사용.
- **calculate_group** / 활성 / `ALU/calculate_group.v`. P10 핵심 RTL 동작 유지.
- **logical_group** / 활성 / `ALU/logical_group.v`. P10 핵심 RTL 동작 유지.
- **shift_group** / 활성 / `ALU/shift_group.v`. P10 핵심 RTL 동작 유지.
- **Early_Jump_Unit** / 활성 / `Early_Jump_Unit.v`. P10 핵심 RTL 동작 유지.
- **barrel_shifter** / 활성 / `FADD/barrel_shifter.v`. 오른쪽 이동 시 버려지는 비트 OR를 sticky로 보존.
- **CLA** / 활성 / `FADD/CLA.v`. P10 핵심 RTL 동작 유지.
- **comparator** / 활성 / `FADD/comparator.v`. P10 핵심 RTL 동작 유지.
- **Cond_Inverter** / 활성 / `FADD/Cond_Inverter.v`. P10 핵심 RTL 동작 유지.
- **Exception_Handler_ADD** / 빌드 포함·미연결 / `FADD/Exception_Handler_ADD.v`. 파일 보존·활성 경로 제외. FP_special·FP_rounding으로 역할 이동.
- **EXPO_CAL** / 활성 / `FADD/EXPO_CAL.v`. P10 핵심 RTL 동작 유지.
- **EXPO_MUX** / 빌드 포함·미연결 / `FADD/EXPO_MUX.v`. 파일 보존·활성 경로 제외. FP_rounding으로 역할 이동.
- **EXPO_SUB** / 활성 / `FADD/EXPO_SUB.v`. P10 핵심 RTL 동작 유지.
- **FADD_core** / 활성 / `FADD/FADD_core.v`. hidden bit·유효 지수·0 부호 보완, 최종 처리를 FP_rounding으로 교체.
- **LZD** / 활성 / `FADD/LZD.v`. P10 핵심 RTL 동작 유지.
- **Magnitude_Restoration** / 활성 / `FADD/Magnitude_Restoration.v`. P10 핵심 RTL 동작 유지.
- **Mode_Detector** / 활성 / `FADD/Mode_Detector.v`. P10 핵심 RTL 동작 유지.
- **Normalization_Controller** / 활성 / `FADD/Normalization_Controller.v`. EXPO_in 추가. 왼쪽 정규화를 최소 유효 지수 1에서 제한.
- **Rounding** / 빌드 포함·미연결 / `FADD/Rounding.v`. 파일 보존·활성 경로 제외. FP_rounding으로 역할 이동.
- **SIGN** / 활성 / `FADD/SIGN.v`. P10 핵심 RTL 동작 유지.
- **Exception_Handler** / 빌드 포함·미연결 / `FMUL/Exception_Handler.v`. 파일 보존·활성 경로 제외. FP_special·FP_rounding으로 역할 이동.
- **FMUL_core** / 활성 / `FMUL/FMUL_core.v`. 12비트 signed 지수·subnormal 유효숫자·새 정규화·공통 반올림·flags 지연.
- **MUL_EXPO** / 빌드 포함·미연결 / `FMUL/MUL_EXPO.v`. 파일 보존·활성 경로 제외. FMUL_core·FP_rounding으로 역할 이동.
- **MUL_EXPO_ADD** / 빌드 포함·미연결 / `FMUL/MUL_EXPO_ADD.v`. 파일 보존·활성 경로 제외. FMUL_core으로 역할 이동.
- **MUL_SIGN** / 빌드 포함·미연결 / `FMUL/MUL_SIGN.v`. 파일 보존·활성 경로 제외. FMUL_core 내부 XOR으로 역할 이동.
- **Multiplier** / 활성 / `FMUL/Multiplier.v`. P10 핵심 RTL 동작 유지.
- **Normalization_MUL** / 활성 / `FMUL/Normalization_MUL.v`. 선행 1 탐색·signed 지수·subnormal 우측 이동 후 FP_rounding에 전달.
- **CPU_Forwarding_Unit** / 활성 / `Forwarding/CPU_Forwarding_Unit.v`. P10 핵심 RTL 동작 유지.
- **Forwarding_Combine** / 활성 / `Forwarding/Forwarding_Combine.v`. P10 핵심 RTL 동작 유지.
- **Forwarding_Unit** / 활성 / `Forwarding/Forwarding_Unit.v`. P10 핵심 RTL 동작 유지.
- **FPU_Forwarding_Unit** / 활성 / `Forwarding/FPU_Forwarding_Unit.v`. P10 핵심 RTL 동작 유지.
- **Final_MUX** / 활성 / `FPU_common/Final_MUX.v`. 신규. 일반 산술값과 지연된 특수 결과 선택.
- **FP_rounding** / 활성 / `FPU_common/FP_rounding.v`. 신규. 다섯 반올림 모드·OF/UF/NX·subnormal 패킹 공통 처리.
- **FP_special** / 활성 / `FPU_common/FP_special.v`. 신규. NaN/Inf/zero와 미지원 요청의 결과·flags·illegal 생성.
- **FPU_classifier** / 활성 / `FPU_common/FPU_classifier.v`. P10의 미완성 미사용 초안에서 실제 특수값 분류기로 완성·연결.
- **FPU_Control** / 활성 / `FPU_common/FPU_Control.v`. 기본 op=3으로 미지원 요청 구분, fmt와 rm≤4 검사.
- **FPU_unpack** / 활성 / `FPU_common/FPU_unpack.v`. EXPO를 [30:23]으로 명시. W=32 동작은 동일.
- **MUX** / 빌드 포함·미연결 / `FPU_common/MUX.v`. 파일 보존·활성 경로 제외. FPU 상위 선택 논리·Final_MUX으로 역할 이동.
- **CPU_Hazard** / 활성 / `Hazard/CPU_Hazard.v`. P10 핵심 RTL 동작 유지.
- **FPU_Check** / 활성 / `Hazard/FPU_Check.v`. P10 핵심 RTL 동작 유지.
- **FPU_Hazard** / 활성 / `Hazard/FPU_Hazard.v`. FPU_6clk wire 명시. 주요 해저드 알고리즘은 유지.
- **Hazard_Combine** / 활성 / `Hazard/Hazard_Combine.v`. P10 핵심 RTL 동작 유지.
- **Hazard_Unit** / 활성 / `Hazard/Hazard_Unit.v`. P10 핵심 RTL 동작 유지.
- **ImmGen** / 활성 / `ImmGen.v`. P10 핵심 RTL 동작 유지.
- **Instruction_Memory** / 활성 / `Instruction_Memory.v`. 초기 파일 경로를 ./runtime/memo/program.txt로 변경.
- **JALR_Jump_Unit** / 활성 / `JALR_Jump_Unit.v`. P10 핵심 RTL 동작 유지.
- **Main_Decoder** / 활성 / `Main_Decoder.v`. P10 핵심 RTL 동작 유지.
- **ALU_A_MUX** / 빌드 제외·미연결 / `MUX/ALU_A_MUX.v`. P10과 같이 활성 CPU 연결에서 미사용.
- **ALU_B_MUX** / 빌드 제외·미연결 / `MUX/ALU_B_MUX.v`. P10과 같이 활성 CPU 연결에서 미사용.
- **CPU_MUX** / 활성 / `MUX/CPU_MUX.v`. P10 핵심 RTL 동작 유지.
- **FPU_MUX** / 활성 / `MUX/FPU_MUX.v`. P10 핵심 RTL 동작 유지.
- **PC_MUX** / 활성 / `MUX/PC_MUX.v`. P10 핵심 RTL 동작 유지.
- **port_MUX** / 활성 / `MUX/port_MUX.v`. P10 핵심 RTL 동작 유지.
- **Result_MUX** / 활성 / `MUX/Result_MUX.v`. P10 핵심 RTL 동작 유지.
- **PC_Adder** / 활성 / `PC/PC_Adder.v`. P10 핵심 RTL 동작 유지.
- **PC_reg** / 활성 / `PC/PC_reg.v`. P10 핵심 RTL 동작 유지.
- **PC_Target** / 활성 / `PC/PC_Target.v`. P10 핵심 RTL 동작 유지.
- **PCSrc** / 활성 / `PC/PCSrc.v`. P10 핵심 RTL 동작 유지.
- **Data_Memory** / 활성 / `Register/Data_Memory.v`. 초기 파일 경로를 ./runtime/memo/data.mem으로 변경.
- **FPU_shadow_reg** / 활성 / `Register/FPU_shadow_reg.v`. P10 핵심 RTL 동작 유지.
- **Pipe_reg_1clk** / 활성 / `Register/Pipe_reg_1clk.v`. P10 핵심 RTL 동작 유지.
- **Pipe_reg_1clk_control** / 활성 / `Register/Pipe_reg_1clk_control.v`. P10 핵심 RTL 동작 유지.
- **Pipe_reg_1clk_en** / 활성 / `Register/Pipe_reg_1clk_en.v`. P10 핵심 RTL 동작 유지.
- **Pipe_reg_2clk** / 빌드 제외·미연결 / `Register/Pipe_reg_2clk.v`. P10과 같이 활성 CPU 연결에서 미사용.
- **Pipe_reg_3clk** / 빌드 포함·미연결 / `Register/Pipe_reg_3clk.v`. P10과 같이 활성 CPU 연결에서 미사용.
- **Pipe_reg_4clk** / 빌드 제외·미연결 / `Register/Pipe_reg_4clk.v`. P10과 같이 활성 CPU 연결에서 미사용.
- **Register_file** / 활성 / `Register/Register_file.v`. ZERO_REGISTER 추가. 정수 x0는 고정, FP f0는 일반 저장 가능.
- **FPU** / 활성 / `TOP_module/FPU.v`. 상위 재구성: special 패킷·valid·NV/NX·ISOLATE 추가. 산술/특수 결과를 최종 등록에서 선택.
- **Pipeline_CPU** / 활성 / `TOP_module/Pipeline_CPU.v`. FP Register_file에 ZERO_REGISTER(0). 새 NV/NX/valid_out은 CPU 외부에 미연결.
- **Top_CPU** / 빌드 제외·미연결 / `TOP_module/Top_CPU.v`. P10과 같이 활성 CPU 연결에서 미사용.

### 소스 위치와 범위

P10은 verilog/Project10_mini_CPU, P11은 verilog/Project11_Upgrade_CPU다. 경로와 줄 번호는 작성 당시 로컬 소스 기준이며 이후 수정되면 바뀔 수 있다.

RTL과 각 F_file/CPU.f, P11 README.md, docs/results.json, tb·tools를 참고했다. 테스트벤치는 16장에 별도로 정리했다. 작성 시 RTL 해시는 CPU_Module_Guide.sources.json에 남겼다.
