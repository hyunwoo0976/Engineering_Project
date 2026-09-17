"""Run from any cwd: python tools/run_regression.py [--quick]. Artifacts in _work/."""

import argparse, hashlib, json, random, re, subprocess
from pathlib import Path
from reference import evaluate

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '_work'


def run(args, name):
    p = subprocess.run(
        [str(x) for x in args],
        cwd=WORK,
        capture_output=True,
        text=True,
        errors='replace',
        timeout=600,
    )
    (WORK / (name + '.log')).write_text(p.stdout + p.stderr, encoding='utf-8')
    if p.returncode or '[FAIL]' in p.stdout or 'ERROR:' in p.stdout:
        raise RuntimeError(name + '\n' + p.stdout[-4000:] + p.stderr[-4000:])
    return p.stdout


def cpu_sources():
    result = []
    for line in (ROOT / 'F_file/CPU.f').read_text().splitlines():
        if not line.strip() or line.startswith('//'):
            continue
        result.append(ROOT / line.strip())
    return list(dict.fromkeys(result))


def vectors(count, activity=False):
    rng = random.Random(20260913)
    values = [
        0,
        0x80000000,
        1,
        0x80000001,
        0x7FFFFF,
        0x807FFFFF,
        0x800000,
        0x80800000,
        0x3F800000,
        0xBF800000,
        0x3F800001,
        0x3F000000,
        0x33800000,
        0x33000000,
        0x7F7FFFFF,
        0xFF7FFFFF,
        0x7F800000,
        0xFF800000,
        0x7FC00000,
        0x7F800001,
    ]
    rows = []
    cases = ((a, b, op, rm) for a in values for b in values for op in range(3) for rm in range(5))
    if activity:
        cases = (
            (
                rng.choice([0, 0x80000000, 0x7F800000, 0x7FC00000]),
                rng.getrandbits(32),
                rng.randrange(3),
                0,
            )
            for _ in range(500)
        )
    else:
        cases = list(cases) + [
            (rng.getrandbits(32), rng.getrandbits(32), rng.randrange(3), rng.randrange(5))
            for _ in range(count)
        ]
        # Cancellation at the minimum exponent, and wide-gap sticky/borrow.
        for exponent in (1, 2, 3, 10, 126, 127, 253, 254):
            for fraction in (0, 1, 2, 0x3FFFFF, 0x7FFFFE, 0x7FFFFF):
                a = (exponent << 23) | fraction
                for b in (max(1, a - 1), a, 1, 0x800001, 0x3F800000):
                    for rm in range(5):
                        cases.extend((a, b, op, rm) for op in range(3))
                        cases.append((a | 0x80000000, b, 0, rm))
        cases += [(0x3F800000, 0x3F800000, op, rm) for op, rm in [(3, 0), (0, 5), (1, 6), (2, 7)]]
    for index, (a, b, op, rm) in enumerate(cases):
        result, flags, error = evaluate(a, b, op, rm)
        rows.append(f'0 1 {a:08x} {b:08x} {op:x} {rm:x} {result:08x} {flags:x} {error:x}\n')
        if not activity and index % 103 == 0:
            rows.append('0 0 deadbeef abcdef01 0 0 0 0 0\n')
        if not activity and index % 997 == 996:
            rows.append('1 0 0 0 0 0 0 0 0\n')
    return ''.join(rows)


def transitions(path):
    # Sample RTL arithmetic input register transitions. This is NOT a power estimate.
    scopes = []
    ids = {}
    previous = {}
    counts = {'plain': 0, 'isolated': 0}
    for line in path.read_text().splitlines():
        p = line.split()
        if not p:
            continue
        if p[0] == '$scope':
            scopes.append(p[2])
        elif p[0] == '$upscope':
            scopes.pop()
        elif p[0] == '$var' and p[4] in ('a1', 'b1'):
            side = next((s for s in scopes if s in counts), None)
            if side:
                ids[p[3]] = side
        elif p[0].startswith('b') and len(p) == 2 and p[1] in ids:
            bits = p[0][1:]
            if any(c not in '01' for c in bits):
                continue
            value = int(bits, 2)
            ident = p[1]
            if ident in previous:
                counts[ids[ident]] += (value ^ previous[ident]).bit_count()
            previous[ident] = value
    return counts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--quick', action='store_true')
    args = ap.parse_args()
    WORK.mkdir(exist_ok=True)
    sources = cpu_sources()
    fp_sources = [p for p in sources if 'tb' not in p.relative_to(ROOT).parts]
    run(
        [
            'iverilog',
            '-g2012',
            '-s',
            'fp_rounding_checks',
            '-o',
            WORK / 'round.vvp',
            *fp_sources,
            ROOT / 'tb/fp_rounding_checks.sv',
        ],
        'compile_round',
    )
    unit = run(['vvp', WORK / 'round.vvp'], 'round')
    print(unit.strip())
    # RTL mutation: reproduce the original directed-rounding bug in _work only.
    rounding = ROOT / 'src_mini_CPU/FPU_common/FP_rounding.v'
    mutant = WORK / 'FP_rounding_mutant.v'
    original = rounding.read_text(encoding='utf-8')
    if 'SIGN && inexact' not in original:
        raise RuntimeError('Mutation target missing')
    mutant.write_text(original.replace('SIGN && inexact', 'SIGN', 1), encoding='utf-8')
    mutant_sources = [mutant if p == rounding else p for p in fp_sources]
    run(
        [
            'iverilog',
            '-g2012',
            '-s',
            'fp_rounding_checks',
            '-o',
            WORK / 'mutant.vvp',
            *mutant_sources,
            ROOT / 'tb/fp_rounding_checks.sv',
        ],
        'compile_mutant',
    )
    mutation = subprocess.run(
        ['vvp', str(WORK / 'mutant.vvp')], cwd=WORK, capture_output=True, text=True, timeout=60
    )
    (WORK / 'rtl_mutation.log').write_text(mutation.stdout + mutation.stderr, encoding='utf-8')
    if mutation.returncode == 0 or 'round boundary' not in mutation.stdout:
        raise RuntimeError('RTL mutation not detected')
    print('RTL mutation PASS: unconditional negative rounding detected')
    (WORK / 'vectors.txt').write_text(vectors(1000 if args.quick else 20000), encoding='ascii')
    run(
        [
            'iverilog',
            '-g2012',
            '-s',
            'fp32_regression',
            '-o',
            WORK / 'fp.vvp',
            *fp_sources,
            ROOT / 'tb/fp32_regression.sv',
        ],
        'compile_fp',
    )
    fp = run(['vvp', WORK / 'fp.vvp', '+VECTORS=vectors.txt'], 'fp')
    print(fp.strip())
    # Negative control: deliberately corrupt a late expected result. The checker must fail.
    # A short stream suffices to prove checker failure; avoid replaying the full regression.
    mutated = (WORK / 'vectors.txt').read_text().splitlines()[:32]
    fields = mutated[-1].split()
    fields[6] = f'{int(fields[6],16)^1:08x}'
    mutated[-1] = ' '.join(fields)
    (WORK / 'mutated.txt').write_text('\n'.join(mutated) + '\n', encoding='ascii')
    neg = subprocess.run(
        ['vvp', str(WORK / 'fp.vvp'), '+VECTORS=mutated.txt'],
        cwd=WORK,
        capture_output=True,
        text=True,
        timeout=600,
    )
    if neg.returncode == 0 or 'FP mismatch' not in neg.stdout:
        raise RuntimeError('Negative control did not fail correctly')
    (WORK / 'negative_control.log').write_text(neg.stdout + neg.stderr, encoding='utf-8')
    print('Negative control PASS: corrupted expected value detected')
    (WORK / 'activity.txt').write_text(vectors(0, True), encoding='ascii')
    run(['vvp', WORK / 'fp.vvp', '+VECTORS=activity.txt', '+VCD'], 'activity')
    activity = transitions(WORK / 'activity.vcd')
    print('Input register bit transitions:', activity)
    if activity['isolated'] >= activity['plain']:
        raise RuntimeError('No input activity reduction')
    # Memory images are generated under the simulator cwd, leaving source images untouched.
    runtime = WORK / 'runtime' / 'memo'
    runtime.mkdir(parents=True, exist_ok=True)
    for src, dst, size in [
        ('program.txt', 'program.txt', 128),
        ('data.mem', 'data.mem', 1024),
    ]:
        words = [
            line.split('//')[0].strip()
            for line in (ROOT / 'tb/data' / src).read_text(encoding='utf-8-sig').splitlines()
        ]
        words = [w for w in words if w]
        words += ['00000013' if dst == 'program.txt' else '00000000'] * (size - len(words))
        (runtime / dst).write_text('\n'.join(words) + '\n', encoding='ascii')
    run(
        ['iverilog', '-g2012', '-s', 'Testbench_CPU', '-o', WORK / 'cpu.vvp', *sources],
        'compile_cpu',
    )
    cpu = run(['vvp', WORK / 'cpu.vvp', '-none'], 'cpu')
    checks = cpu.count('[PASS]')
    if checks != 59:
        raise RuntimeError(f'Expected 59 CPU comparisons, got {checks}')
    print('CPU PASS 59')
    run(
        [
            'iverilog',
            '-g2012',
            '-s',
            'cpu_fp_special',
            '-o',
            WORK / 'cpu_special.vvp',
            *sources,
            ROOT / 'tb/cpu_fp_special.sv',
        ],
        'compile_cpu_special',
    )
    extra = run(['vvp', WORK / 'cpu_special.vvp'], 'cpu_special')
    print(extra.strip())
    manifest = {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in fp_sources
    }
    summary = {
        'round_normalize': unit.strip(),
        'fp': fp.strip(),
        'cpu_checks': checks,
        'cpu_special_checks': 6,
        'negative_control': 'expected-bit corruption detected',
        'rtl_mutation': 'unconditional negative rounding detected',
        'activity_input_bit_transitions': activity,
        'seed': 20260913,
        'rtl_sha256': manifest,
        'limitations': [
            'No full F ISA, DYN/fcsr or ISA traps',
            'RTL activity is not watts or placed timing',
            'Finite sampled regression, not formal proof',
        ],
    }
    (WORK / 'results.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
