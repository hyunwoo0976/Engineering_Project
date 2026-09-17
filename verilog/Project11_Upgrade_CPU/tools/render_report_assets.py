from pathlib import Path
import html

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "_work"
ASSETS = ROOT / "docs" / "assets"
ASSETS.mkdir(parents=True, exist_ok=True)


def read_vcd(path):
    scopes = []
    ids = {}
    values = {}
    in_header = True
    time = 0
    with path.open(encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.strip()
            if in_header:
                if line.startswith("$scope"):
                    scopes.append(line.split()[2])
                elif line.startswith("$upscope"):
                    scopes.pop()
                elif line.startswith("$var") and len(scopes) == 1:
                    parts = line.split()
                    ids[parts[3]] = (parts[4], int(parts[2]))
                    values.setdefault(parts[4], [])
                elif line == "$enddefinitions $end":
                    in_header = False
                continue
            if not line:
                continue
            if line.startswith("#"):
                time = int(line[1:])
            elif line[0] in "01xz" and line[1:] in ids:
                name, _ = ids[line[1:]]
                values[name].append((time, line[0]))
            elif line[0] in "br" and " " in line:
                value, code = line[1:].split(None, 1)
                if code in ids:
                    name, _ = ids[code]
                    values[name].append((time, value))
    return values


def value_at(events, t):
    current = "x"
    for event_time, value in events:
        if event_time > t:
            break
        current = value
    return current


def waveform_svg(values, path):
    signals = [
        "clk",
        "reset",
        "FPU_en",
        "op",
        "IN_A",
        "IN_B",
        "valid_out",
        "result_out",
        "NV",
        "OF",
        "UF",
        "NX",
    ]
    start, stop = 0, 140000
    left, top, row, width = 155, 45, 34, 1050
    height = top + row * len(signals) + 45
    x = lambda t: left + (t - start) * width / (stop - start)
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="{height}" viewBox="0 0 1280 {height}">',
        '<rect width="100%" height="100%" fill="#fbfcfe"/>',
        '<style>text{font-family:Consolas,monospace;font-size:14px}.label{font-weight:700}.grid{stroke:#d9e0ea}.wave{stroke:#1261a0;stroke-width:2;fill:none}.bus{fill:#eef5ff;stroke:#3978b8}</style>',
    ]
    for ns in range(0, 141, 10):
        xx = x(ns * 1000)
        out.append(f'<line class="grid" x1="{xx:.1f}" y1="30" x2="{xx:.1f}" y2="{height-30}"/>')
        out.append(f'<text x="{xx+3:.1f}" y="22">{ns} ns</text>')
    for idx, name in enumerate(signals):
        y = top + idx * row
        out.append(f'<text class="label" x="12" y="{y+18}">{html.escape(name)}</text>')
        events = [(max(start, t), v) for t, v in values.get(name, []) if t <= stop]
        points = sorted(set([start, stop] + [t for t, _ in events]))
        is_bus = name in {"op", "IN_A", "IN_B", "result_out"}
        if is_bus:
            for a, b in zip(points, points[1:]):
                val = value_at(values.get(name, []), a)
                xx, ww = x(a), max(1, x(b) - x(a))
                out.append(
                    f'<rect class="bus" x="{xx:.1f}" y="{y+3}" width="{ww:.1f}" height="22"/>'
                )
                if ww > 48:
                    shown = (
                        val
                        if len(val) < 5
                        else f'{int(val,2):0{(len(val)+3)//4}x}' if set(val) <= {"0", "1"} else val
                    )
                    out.append(f'<text x="{xx+4:.1f}" y="{y+19}">{html.escape(shown)}</text>')
        else:
            last = start
            last_val = value_at(values.get(name, []), start)
            d = []
            for t in points[1:]:
                yy = y + (7 if last_val == "1" else 24)
                d.append(f'M {x(last):.1f} {yy} H {x(t):.1f}')
                next_val = value_at(values.get(name, []), t)
                next_y = y + (7 if next_val == "1" else 24)
                d.append(f'V {next_y}')
                last, last_val = t, next_val
            out.append(f'<path class="wave" d="{" ".join(d)}"/>')
    out.append(
        '<text x="155" y="{}">입력 4건은 연속 접수되고 7번째 상승 에지에서 같은 순서로 출력된다.</text>'.format(
            height - 12
        )
    )
    out.append('</svg>')
    path.write_text("\n".join(out), encoding="utf-8")


def architecture_svg(path):
    boxes = [
        (35, 115, 150, 70, "Instruction\nFetch"),
        (225, 115, 150, 70, "Decode +\nRegister File"),
        (415, 45, 170, 70, "Integer ALU\n5-stage path"),
        (415, 195, 170, 70, "FP_special\nclassify/resolve"),
        (625, 145, 180, 70, "FADD / FMUL\n7-stage path"),
        (845, 145, 160, 70, "Final MUX +\nflags/valid"),
        (1045, 115, 150, 70, "MEM /\nWrite Back"),
        (625, 285, 180, 58, "FPU shadow reg\nRd/control delay"),
    ]
    out = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1240" height="390" viewBox="0 0 1240 390">',
        '<rect width="100%" height="100%" fill="#fbfcfe"/>',
        '<defs><marker id="a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#345b7e"/></marker></defs>',
        '<style>text{font-family:Arial,sans-serif;font-size:16px;text-anchor:middle}.b{fill:#edf5ff;stroke:#23659b;stroke-width:2}.fp{fill:#fff3df;stroke:#b36b00;stroke-width:2}.l{stroke:#345b7e;stroke-width:2;fill:none;marker-end:url(#a)}</style>',
    ]
    for x, y, w, h, label in boxes:
        cls = "fp" if y >= 145 and x in (415, 625, 845) else "b"
        out.append(f'<rect class="{cls}" x="{x}" y="{y}" rx="8" width="{w}" height="{h}"/>')
        parts = label.split("\n")
        for i, part in enumerate(parts):
            out.append(f'<text x="{x+w/2}" y="{y+h/2-7+i*21}">{html.escape(part)}</text>')
    lines = [
        (185, 150, 225, 150),
        (375, 150, 415, 80),
        (375, 150, 415, 230),
        (585, 230, 625, 180),
        (805, 180, 845, 180),
        (1005, 180, 1045, 150),
        (585, 80, 1045, 135),
        (805, 314, 1045, 180),
    ]
    for x1, y1, x2, y2 in lines:
        out.append(f'<path class="l" d="M{x1} {y1} L{x2} {y2}"/>')
    out.append(
        '<text x="620" y="375">정수 경로와 7단 FPU 경로의 결과·목적지·제어 정보를 동일한 명령어 단위로 정합</text>'
    )
    out.append('</svg>')
    path.write_text("\n".join(out), encoding="utf-8")


waveform_svg(read_vcd(WORK / "report_waveform.vcd"), ASSETS / "report_waveform.svg")
architecture_svg(ASSETS / "architecture.svg")
print("generated", ASSETS / "architecture.svg")
print("generated", ASSETS / "report_waveform.svg")
