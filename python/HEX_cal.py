import struct

def h2f(h):
    return struct.unpack('f', struct.pack('I', int(h, 16)))[0]

def f2h(f):
    return format(struct.unpack('I', struct.pack('f', f))[0], '08X')

# 연산 1: SUB
a1 = h2f('4069999A')
b1 = h2f('3FA6CA66')
print(f"SUB: {a1} - {b1} = {a1-b1} → {f2h(a1-b1)}")

# 연산 2: ADD  
a2 = h2f('4069999A')
b2 = h2f('3FA6CA66')
print(f"ADD: {a2} + {b2} = {a2+b2} → {f2h(a2+b2)}")

# 연산 3: MUL
a3 = h2f('4069999A')
b3 = h2f('3FA6CA66')
print(f"MUL: {a3} * {b3} = {a3*b3} → {f2h(a3*b3)}")

