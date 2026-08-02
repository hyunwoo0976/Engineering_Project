"""
riscv_iss.py — RV32I 명령어 세트 시뮬레이터 (골든 모델)

Project10 mini CPU 통합 검증용. 파이프라인/포워딩/해저드 없이 명령어를 한 줄씩
'순차 해석'해서 올바른 아키텍처 상태(레지스터/메모리)를 뽑는다.
DUT(파이프라인 CPU) 결과를 이 ISS 결과와 대조 → 일치하면 CPU 정상.
port_MUX 유닛검증 때 만든 ref_model의 CPU 버전이다.

왜 필요한가:
  분기가 많은 프로그램은 기대값을 손으로 못 구한다(경로가 도미노로 얽힘).
  ISS가 정답 상태와 실행 경로를 대신 계산해 준다. (통합테스트 03이 이걸로 완성됨)

사용법:
  1. prog 에 기계어(hex) 리스트를 넣는다 (program.txt 순서)
  2. mem  에 데이터 메모리 초기값을 넣는다 (data.mem 에 해당, 워드 주소 기준)
  3. python riscv_iss.py
     → 실행 경로 + 최종 레지스터 상태를 check(r, v); 형태로 출력 (TB에 복붙)

지원 명령어: addi, lw, sw, add, sub, beq/bne/blt/bge, jal
  (필요하면 andi/ori/xori/sll/srl/sra/slt 등 아래 실행부에 추가)
"""

# ── 검증할 프로그램 (기계어 hex) ─────────────────────────────
prog = [
    0x00900093, 0x00002103, 0x002081b3, 0x00100213, 0x402182b3,
    0x00128663, 0x00729c63, 0x00234663, 0x40220333, 0xfe531ce3,
    0x005303b3, 0xfe7256e3, 0x40330433, 0x408004b3, 0x02945663,
    0x00218533, 0x007505b3, 0x02959063, 0xffe00613, 0x00c506b3,
    0x00c68733, 0x404686b3, 0xfed71ee3, 0x00b48663, 0x0c800793,
    0x0000006f, 0x00d02223, 0x06400813, 0x00402883, 0x01088933,
    0x0000006f,
]

# ── 데이터 메모리 초기값 (바이트 주소 → 32비트 워드) ──────────
mem = {0: 11}   # data.mem[0] = 11

MAX_STEPS = 1_000_000   # 무한루프 방지 (넘으면 프로그램이 안 끝나는 것)


def sx(v):
    """32비트 → 부호 있는 정수"""
    v &= 0xFFFFFFFF
    return v - 0x100000000 if v & 0x80000000 else v


# 명령어 형식별 즉시값(immediate) 추출 + 부호확장
def imm_i(i):   # I-type: imm[11:0] = bits[31:20]
    x = (i >> 20) & 0xFFF
    return x - 0x1000 if x & 0x800 else x

def imm_s(i):   # S-type: imm[11:5]=[31:25], imm[4:0]=[11:7]
    x = (((i >> 25) & 0x7F) << 5) | ((i >> 7) & 0x1F)
    return x - 0x1000 if x & 0x800 else x

def imm_b(i):   # B-type: imm[12]=b31, imm[11]=b7, imm[10:5]=[30:25], imm[4:1]=[11:8], imm[0]=0
    x = (((i >> 31) & 1) << 12) | (((i >> 7) & 1) << 11) \
        | (((i >> 25) & 0x3F) << 5) | (((i >> 8) & 0xF) << 1)
    return x - 0x2000 if x & 0x1000 else x

def imm_j(i):   # J-type: imm[20]=b31, imm[19:12]=[19:12], imm[11]=b20, imm[10:1]=[30:21], imm[0]=0
    x = (((i >> 31) & 1) << 20) | (((i >> 12) & 0xFF) << 12) \
        | (((i >> 20) & 1) << 11) | (((i >> 21) & 0x3FF) << 1)
    return x - 0x200000 if x & 0x100000 else x


def run(prog, mem):
    reg = [0] * 32
    pc = 0
    steps = 0
    trace = []
    while steps < MAX_STEPS:
        steps += 1
        idx = pc // 4
        if idx < 0 or idx >= len(prog):
            break
        ins = prog[idx]
        op  = ins & 0x7F
        rd  = (ins >> 7)  & 0x1F
        f3  = (ins >> 12) & 0x7
        rs1 = (ins >> 15) & 0x1F
        rs2 = (ins >> 20) & 0x1F
        f7  = (ins >> 25) & 0x7F
        npc = pc + 4

        if op == 0x13:            # OP-IMM (addi ...)
            if f3 == 0:           # addi
                reg[rd] = (reg[rs1] + imm_i(ins)) & 0xFFFFFFFF
        elif op == 0x03:          # LOAD
            addr = (reg[rs1] + imm_i(ins)) & 0xFFFFFFFF
            if f3 == 2:           # lw
                reg[rd] = mem.get(addr, 0) & 0xFFFFFFFF
        elif op == 0x23:          # STORE
            addr = (reg[rs1] + imm_s(ins)) & 0xFFFFFFFF
            if f3 == 2:           # sw
                mem[addr] = reg[rs2] & 0xFFFFFFFF
        elif op == 0x33:          # OP (R-type)
            if f3 == 0:           # add / sub
                reg[rd] = ((reg[rs1] - reg[rs2]) if f7 == 0x20
                           else (reg[rs1] + reg[rs2])) & 0xFFFFFFFF
        elif op == 0x63:          # BRANCH
            a, b = sx(reg[rs1]), sx(reg[rs2])
            take = (f3 == 0 and reg[rs1] == reg[rs2]) \
                or (f3 == 1 and reg[rs1] != reg[rs2]) \
                or (f3 == 4 and a < b) \
                or (f3 == 5 and a >= b)
            if take:
                npc = (pc + imm_b(ins)) & 0xFFFFFFFF
        elif op == 0x6F:          # JAL
            reg[rd] = (pc + 4) & 0xFFFFFFFF
            npc = (pc + imm_j(ins)) & 0xFFFFFFFF

        reg[0] = 0                # x0 은 항상 0
        trace.append(idx)
        if npc == pc:             # jal x0,0 자기 점프 → 종료
            break
        pc = npc

    return reg, mem, pc, steps, trace


if __name__ == "__main__":
    reg, mem, pc, steps, trace = run(prog, mem)
    if steps >= MAX_STEPS:
        print("⚠️ MAX_STEPS 도달 — 프로그램이 끝나지 않음(무한루프 의심)")
    print("steps=%d  종료 pc=%d(줄%d)" % (steps, pc, pc // 4))
    print("실행 경로(줄번호):", trace)
    print("-" * 40)
    for r in range(1, 19):        # x1~x18 (필요시 범위 조정)
        print("check(%-2d, %d);   // 0x%08x" % (r, sx(reg[r]), reg[r]))
