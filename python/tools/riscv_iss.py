"""
riscv_iss.py — RV32I(+F) 명령어 세트 시뮬레이터 (골든 모델)

Project10 mini CPU 통합 검증용. 파이프라인/포워딩/해저드 없이 명령어를 한 줄씩
순차 해석해서 올바른 아키텍처 상태(레지스터/메모리)를 뽑는다.
DUT(파이프라인 CPU) 결과를 이 ISS 결과와 대조 → 일치하면 CPU 정상.

사용법:
  riscv_iss.exe [program.txt] [data.mem]
  - 인자 없으면 현재 폴더의 program.txt / data.mem 을 읽음
  - program.txt: CPU가 쓰는 그 파일 그대로 (각 줄 첫 토큰이 16진수, // 주석 무시)
  - data.mem   : 워드 단위 초기값 (줄 N → 바이트주소 4N). FP는 비트패턴(3FC00000 등)
  → 실행 경로 + 정수/FP 레지스터를 check() 형태로 출력 (TB에 복붙)

지원: addi/andi, lw, sw, add/sub/and/or/xor/sll/srl/sra, beq/bne/blt/bge, jal/jalr, flw, fsw, fadd/fsub/fmul
"""
import struct, sys, os

MAX_STEPS = 1_000_000

# ── float32 (단정밀도) 변환 ──────────────────────────────
def bits_to_f32(u):
    return struct.unpack('>f', struct.pack('>I', u & 0xFFFFFFFF))[0]

def f32_to_bits(x):
    try:
        return struct.unpack('>I', struct.pack('>f', x))[0]
    except OverflowError:            # 오버플로 → ±Inf
        return 0x7F800000 if x > 0 else 0xFF800000

def f32(x):                          # 가장 가까운 float32로 반올림
    return bits_to_f32(f32_to_bits(x))


def sx(v):
    v &= 0xFFFFFFFF
    return v - 0x100000000 if v & 0x80000000 else v

def imm_i(i):
    x = (i >> 20) & 0xFFF
    return x - 0x1000 if x & 0x800 else x
def imm_s(i):
    x = (((i >> 25) & 0x7F) << 5) | ((i >> 7) & 0x1F)
    return x - 0x1000 if x & 0x800 else x
def imm_b(i):
    x = (((i >> 31) & 1) << 12) | (((i >> 7) & 1) << 11) \
        | (((i >> 25) & 0x3F) << 5) | (((i >> 8) & 0xF) << 1)
    return x - 0x2000 if x & 0x1000 else x
def imm_j(i):
    x = (((i >> 31) & 1) << 20) | (((i >> 12) & 0xFF) << 12) \
        | (((i >> 20) & 1) << 11) | (((i >> 21) & 0x3FF) << 1)
    return x - 0x200000 if x & 0x100000 else x


def parse_hexfile(path):
    """각 줄 첫 토큰을 16진수로. 빈 줄·// 주석 무시."""
    out = []
    with open(path, encoding="utf-8", errors="ignore") as fp:
        for line in fp:
            line = line.strip()
            if not line or line.startswith('//'):
                continue
            tok = line.split()[0]
            try:
                out.append(int(tok, 16))
            except ValueError:
                pass
    return out


def run(prog, mem):
    reg  = [0] * 32          # 정수 레지스터
    freg = [0.0] * 32        # FP 레지스터 (f0 은 x0 과 달리 일반 레지스터)
    pc = steps = 0
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

        if op == 0x13:                      # OP-IMM (addi, andi)
            if f3 == 0:
                reg[rd] = (reg[rs1] + imm_i(ins)) & 0xFFFFFFFF
            elif f3 == 7:                   # ANDI
                reg[rd] = reg[rs1] & (imm_i(ins) & 0xFFFFFFFF)
        elif op == 0x03:                    # LOAD (lw)
            a = (reg[rs1] + imm_i(ins)) & 0xFFFFFFFF
            if f3 == 2:
                reg[rd] = mem.get(a, 0) & 0xFFFFFFFF
        elif op == 0x23:                    # STORE (sw)
            a = (reg[rs1] + imm_s(ins)) & 0xFFFFFFFF
            if f3 == 2:
                mem[a] = reg[rs2] & 0xFFFFFFFF
        elif op == 0x33:                    # OP (add/sub/and/or/xor/sll/srl/sra)
            a, b = reg[rs1], reg[rs2]
            sh = b & 31
            if   f3 == 0: reg[rd] = ((a - b) if f7 == 0x20 else (a + b)) & 0xFFFFFFFF
            elif f3 == 7: reg[rd] = a & b                # AND
            elif f3 == 6: reg[rd] = a | b                # OR
            elif f3 == 4: reg[rd] = a ^ b                # XOR
            elif f3 == 1: reg[rd] = (a << sh) & 0xFFFFFFFF   # SLL
            elif f3 == 5:                                # SRL / SRA
                reg[rd] = ((sx(a) >> sh) & 0xFFFFFFFF) if f7 == 0x20 else (a >> sh)
        elif op == 0x63:                    # BRANCH
            a, b = sx(reg[rs1]), sx(reg[rs2])
            take = (f3 == 0 and reg[rs1] == reg[rs2]) \
                or (f3 == 1 and reg[rs1] != reg[rs2]) \
                or (f3 == 4 and a < b) \
                or (f3 == 5 and a >= b)
            if take:
                npc = (pc + imm_b(ins)) & 0xFFFFFFFF
        elif op == 0x6F:                    # JAL
            reg[rd] = (pc + 4) & 0xFFFFFFFF
            npc = (pc + imm_j(ins)) & 0xFFFFFFFF
        elif op == 0x67:                    # JALR
            t = (reg[rs1] + imm_i(ins)) & 0xFFFFFFFE
            reg[rd] = (pc + 4) & 0xFFFFFFFF
            npc = t
        elif op == 0x07:                    # FLW (float load)
            a = (reg[rs1] + imm_i(ins)) & 0xFFFFFFFF
            if f3 == 2:
                freg[rd] = bits_to_f32(mem.get(a, 0))
        elif op == 0x27:                    # FSW (float store)
            a = (reg[rs1] + imm_s(ins)) & 0xFFFFFFFF
            if f3 == 2:
                mem[a] = f32_to_bits(freg[rs2])
        elif op == 0x53:                    # OP-FP (fadd/fsub/fmul)
            if   f7 == 0x00: r = freg[rs1] + freg[rs2]
            elif f7 == 0x04: r = freg[rs1] - freg[rs2]
            elif f7 == 0x08: r = freg[rs1] * freg[rs2]
            else:            r = freg[rd]
            freg[rd] = f32(r)

        reg[0] = 0                          # x0 만 항상 0 (f0 은 아님)
        trace.append(idx)
        if npc == pc:                       # jal x0,0 자기점프 → 종료
            break
        pc = npc
    return reg, freg, mem, pc, steps, trace


def main():
    base = os.path.dirname(os.path.abspath(sys.argv[0]))
    prog_path = sys.argv[1] if len(sys.argv) > 1 else "program.txt"
    data_path = sys.argv[2] if len(sys.argv) > 2 else "data.mem"

    # CWD 에 없으면 exe 옆도 찾아봄
    if not os.path.exists(prog_path) and os.path.exists(os.path.join(base, prog_path)):
        prog_path = os.path.join(base, prog_path)
    if not os.path.exists(data_path) and os.path.exists(os.path.join(base, data_path)):
        data_path = os.path.join(base, data_path)

    if not os.path.exists(prog_path):
        print("program.txt not found:", prog_path)
        print("Run this from the folder that has program.txt (memo/), or pass the path as an argument.")
        try: input("\nPress Enter to exit...")
        except Exception: pass
        return

    prog = parse_hexfile(prog_path)
    mem = {}
    if os.path.exists(data_path):
        for i, v in enumerate(parse_hexfile(data_path)):
            mem[i * 4] = v & 0xFFFFFFFF

    reg, freg, mem, pc, steps, trace = run(prog, mem)

    def fp_pretty(x):
        if x != x:             return "NaN"
        if x == float('inf'):  return "+inf"
        if x == float('-inf'): return "-inf"
        if x == 0.0:           return "0"
        s = "%.6g" % x                     # 유효숫자 6자리 (float32 노이즈 숨김)
        if 'e' in s:                       # 2.4e+21 -> 2.4 x 10^21
            m, e = s.split('e')
            return "%s x 10^%d" % (m, int(e))
        return s

    print("=" * 54)
    print("RISC-V ISS  (program: %s)" % os.path.basename(prog_path))
    if steps >= MAX_STEPS:
        print("[!] hit MAX_STEPS - program did not terminate (infinite loop?)")
    print("steps=%d   end pc=%d (line %d)" % (steps, pc, pc // 4))
    print("path:", trace)
    print("-" * 54)
    print("[Integer registers]")
    for r in range(1, 32):
        if reg[r] != 0:
            print("  x%-2d = %d" % (r, sx(reg[r])))
    fp_lines = []
    for r in range(0, 32):
        u = f32_to_bits(freg[r])
        if u != 0:
            fp_lines.append("  f%-2d = %-14s  [0x%08X]" % (r, fp_pretty(freg[r]), u))
    if fp_lines:
        print("[FP registers]  (value  [hex bit-pattern])")
        for ln in fp_lines:
            print(ln)
    print("=" * 54)
    print("[Paste into TB - check() lines]")
    for r in range(1, 32):
        if reg[r] != 0:
            print("check(%d, %d);" % (r, sx(reg[r])))
    fp_any = False
    for r in range(0, 32):
        u = f32_to_bits(freg[r])
        if u != 0:
            if not fp_any:
                print("// FP (bit pattern; check against FP register file / f-shadow)")
                fp_any = True
            print("check(%d, 32'h%08X);   // f%d" % (r, u, r))
    print("=" * 54)
    try:
        input("\nPress Enter to exit...")     # keep window open when double-clicked
    except Exception:
        pass


if __name__ == "__main__":
    main()
