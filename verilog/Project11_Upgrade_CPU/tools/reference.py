"""Independent exact-integer FP32 oracle. No host floating-point rounding.

Decode finite inputs in units of 2**-149, evaluate exactly, round quotient/remainder.
This deliberately differs from RTL alignment/GRS pipeline implementation.
"""


def kind(x):
    e, f = (x >> 23) & 255, x & 0x7FFFFF
    return (
        'nan'
        if e == 255 and f
        else 'inf' if e == 255 else 'zero' if not (x & 0x7FFFFFFF) else 'finite'
    )


def units(x):
    e, f = (x >> 23) & 255, x & 0x7FFFFF
    n = f if not e else ((1 << 23) | f) << (e - 1)
    return -n if x >> 31 else n


def evaluate(a, b, op, rm):
    if op > 2 or rm > 4:
        return 0x7FC00000, 0, 1
    ka, kb = kind(a), kind(b)
    sa, sb = a >> 31, (b >> 31) ^ (op == 1)
    nan = 0x7FC00000
    if 'nan' in (ka, kb):
        nv = (ka == 'nan' and not (a & 0x400000)) or (kb == 'nan' and not (b & 0x400000))
        return nan, 16 if nv else 0, int(nv)
    if op == 2:
        s = sa ^ sb
        if (ka, kb) in [('zero', 'inf'), ('inf', 'zero')]:
            return nan, 16, 1
        if 'inf' in (ka, kb):
            return (s << 31) | 0x7F800000, 0, 0
        n, scale = units(a) * units(b), -298
    else:
        if ka == kb == 'inf' and sa != sb:
            return nan, 16, 1
        if ka == 'inf':
            return (sa << 31) | 0x7F800000, 0, 0
        if kb == 'inf':
            return (sb << 31) | 0x7F800000, 0, 0
        n, scale = units(a) + (-units(b) if op == 1 else units(b)), -149
        s = sa if ka == kb == 'zero' and sa == sb else int(rm == 2)
    if not n:
        return s << 31, 0, 0
    s, n = int(n < 0), abs(n)
    exponent = n.bit_length() - 1 + scale
    quantum = max(exponent - 23, -149)
    shift = quantum - scale
    q, rem = divmod(n, 1 << shift) if shift > 0 else (n << -shift, 0)
    den = 1 << max(shift, 0)
    inc = (
        (rm == 0 and (2 * rem > den or (2 * rem == den and q & 1)))
        or (rm == 2 and s and rem)
        or (rm == 3 and not s and rem)
        or (rm == 4 and 2 * rem >= den)
    )
    q += bool(inc)
    if q >= 1 << 24:
        q >>= 1
        quantum += 1
    e = quantum + 23
    if e > 127:
        inf = rm in (0, 4) or rm == 2 and s or rm == 3 and not s
        return (s << 31) | (0x7F800000 if inf else 0x7F7FFFFF), 5, 0
    encoded = e + 127 if q >= 1 << 23 else 0
    result = (s << 31) | (encoded << 23) | (q & 0x7FFFFF)
    flags = int(bool(rem)) | (2 if rem and not encoded else 0)
    return result, flags, 0
