# 통합테스트 05 — JAL/JALR + 정수·실수 혼합 + 서브루틴 + branch-shadow

정수·실수를 **촘촘히 섞고**, JAL/JALR로 **서브루틴 호출·복귀**, 뒤로 뛰는 루프, 그리고
**분기 그림자에 JAL이 걸리는** 회귀 케이스까지 한 프로그램에 몰아넣은 종합 테스트.
ISS(파이썬 어셈블러+시뮬레이터, JAL/JALR 포함)로 골든 생성 후 DUT와 대조.

## 목적

- **JAL 복귀주소 저장** (x20 = PC+4) + **JALR 복귀** (jalr x0, x20, 0)
- **서브루틴** (FP 연산 포함) 호출→실행→복귀
- **정수 ↔ 실수 촘촘한 인터리빙** — FP 결과(7clk 지연)가 정수 writeback과 충돌하는지
- **분기 4종** taken + not-taken(죽은 코드) + **뒤로 뛰는 루프**
- **branch-shadow-JAL 회귀** — 분기 그림자에 JAL이 speculative fetch될 때
- FP in-flight 해저드, fsw→flw / sw→lw 왕복, 포워딩, load-use

## 데이터 (`data.mem`)

| 주소 | 값 |
|---|---|
| mem[0] | 100 |
| mem[4] | 25 |
| mem[8] | 1.5 (`3FC00000`) |
| mem[12] | 2.5 (`40200000`) |

## 프로그램 (42 instr)

```
00a00093 addi x1,x0,10        00318463 beq x3,x3,L1  (taken)
00300113 addi x2,x0,3         06300413 addi x8,x0,99  SKIP
002081b3 add  x3,x1,x2 (fwd)  00209463 L1: bne x1,x2,L2 (taken)
40208233 sub  x4,x1,x2        06300493 addi x9  SKIP
00002283 lw   x5,0(x0) =100   00114463 L2: blt x2,x1,L3 (taken)
00128333 add  x6,x5,x1 (LU)   06300513 addi x10 SKIP
00802087 flw  f1,8(x0)        0020d463 L3: bge x1,x2,SHADOW (taken)
00c02107 flw  f2,12(x0)       06300593 addi x11 SKIP
002081d3 fadd f3,f1,f2        00108463 SHADOW: beq x1,x1,AFTER (taken)
08118253 fsub f4,f3,f1 (IF)   0440006f jal x0,TRAP   ★그림자 jal(flush!)
102202d3 fmul f5,f4,f2 (IF)   02a00613 AFTER: addi x12,x0,42
00502827 fsw  f5,16(x0)       02c00a6f jal x20,SUBR  (호출)
01002307 flw  f6,16(x0) 왕복   002086b3 add x13,x1,x2 (JALR 복귀지점)
00302a23 sw   x3,20(x0)       0020ce63 blt x1,x2,DEAD (not taken)
01402383 lw   x7,20(x0) 왕복   00700713 addi x14,x0,7
00300793 addi x15,x0,3        00580813 LOOP: addi x16,x16,5
fff78793 addi x15,x15,-1      fe079ce3 bne x15,x0,LOOP (3바퀴)
0080006f jal x0,HALT          06f00713 DEAD: addi x14,x0,111 (죽은코드)
0000006f HALT: jal x0,HALT    00500a93 SUBR: addi x21,x0,5
006283d3 fadd f7,f5,f6 (sub FP) 001a8b33 add x22,x21,x1
000a0067 SUBR_R: jalr x0,x20,0 00100613 TRAP: addi x12,x0,1
fe9ff06f jal x0,HALT
```

## 기대값 = 최종 상태 (all-pass, ISS 대조)

```
check(1,0xA)  check(2,0x3)  check(3,0xD)  check(4,0x7)  check(5,0x64)
check(6,0x6E) check(7,0xD)  check(12,0x2A) check(13,0xD) check(14,0x7)
check(16,0xF) check(20,0x6C) check(21,0x5) check(22,0xF)
// FP: f3=40800000(4.0) f4=40200000(2.5) f5=40C80000(6.25)
//     f6=40C80000(6.25,왕복) f7=41480000(12.5,sub)
```

**핵심 검증 3개:** `x12=42`(그림자 jal flush됨, 1 아님) · `x13=13`(JALR 복귀 정상) · `x16=15`(루프 3바퀴) · `x14=7`(죽은코드 안 옴, 111 아님)

## 커버리지

| 항목 | 확인 |
|---|---|
| 정수 포워딩 / load-use | x3, x6 |
| FP in-flight 해저드 | f4, f5 |
| fsw→flw / sw→lw 왕복 | f6, x7 |
| 분기 4종 taken | L1~L3, SHADOW |
| 분기 not-taken + 죽은코드 | x14=7 |
| 뒤로 뛰는 루프 | x16=15 |
| JAL 복귀주소 저장 | x20=108 |
| JALR 복귀 | x13=13 |
| 서브루틴(FP 포함) | x21, x22, f7 |
| branch-shadow-JAL 회귀 | x12=42 |
| **정수↔FP writeback 충돌** | x14=7 (FPU_6clk 버그로 여기서 터짐) |

## 잡은 버그 3개

1. **명령어 메모리 오버플로** — `Instruction_Memory.v` mem[0:31]+pc[6:2] = 32칸뿐. 42개 프로그램이 넘쳐서 PC≥0x80이 wrap → PC/inst 불일치, loop 도달 못 함. → mem[0:63]+pc[7:2]로 확장.
2. **분기 그림자 JAL 우선순위** — 분기(EX)가 taken인데, 그림자에 speculative fetch된 JAL(loop)이 ID에서 Early_Jump를 쏘고, `PC_MUX`·`CPU_Hazard` 우선순위가 **ID_PCSrc > EX_PCSrc**라 JAL이 분기를 덮음. → **EX_PCSrc 우선**으로 뒤집음 (오래된 명령어가 어린 걸 이긴다).
3. **FPU_6clk 1클럭 지각 → WB 충돌** — `FPU_Check.v`에서 `FPU_6clk <= Rd[5][0]`(등록)이라 `FPU_Valid`(조합)와 **동시에** 떠서, FP 결과 나올 자리를 미리 못 비움 → FP 결과(shadow)가 그 슬롯의 정수 addi를 덮어 x14=0. → `assign FPU_6clk = Rd[5][0]`(조합화)로 Valid보다 1클럭 먼저 발화. (OPEN-1과 같은 "등록 신호 지각" 계열)

## 배운 것

- **정수+FP를 촘촘히 섞어야** 드러나는 버그가 있다 — FP 7clk 결과가 정수 writeback과 겹치는 타이밍(FPU_6clk). FP만/정수만 테스트로는 안 잡힘
- **분기 그림자에 jump가 있으면** 우선순위가 결정적 — 오래된 명령어(EX)가 어린 것(ID)을 이겨야
- **"등록(`<=`) vs 조합(`assign`)" 타이밍 정합**이 반복 실수 포인트 (FPU_Valid에 이어 FPU_6clk도)
- JAL/JALR로 서브루틴·복귀가 실제 동작 — 복귀주소 저장(x20)과 간접점프(jalr) 검증

## 결과

- **정수 16 + 실수 7 all-pass** — DUT가 ISS와 완전 일치
- JAL/JALR/서브루틴/분기그림자/정수·FP혼합WB까지 검증 완료
