#!/usr/bin/env python3
"""Minimal RISC-V machine-code generator for self-contained smoke tests."""
from pathlib import Path
BASE = Path(__file__).resolve().parents[1] / 'tests'

def r(f7, rs2, rs1, f3, rd, op=0x33):
    return ((f7 & 127) << 25) | ((rs2 & 31) << 20) | ((rs1 & 31) << 15) | (f3 << 12) | (rd << 7) | op

def it(imm, rs1, f3, rd, op=0x13):
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op

def s(imm, rs2, rs1, f3):
    imm &= 0xfff
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 31) << 7) | 0x23

def b(offset, rs2, rs1, f3):
    assert offset % 2 == 0 and -4096 <= offset < 4096
    x = offset & 0x1fff
    return (((x >> 12) & 1) << 31) | (((x >> 5) & 63) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((x >> 1) & 15) << 8) | (((x >> 11) & 1) << 7) | 0x63

def u(imm20, rd, op):
    return ((imm20 & 0xfffff) << 12) | (rd << 7) | op

def j(offset, rd):
    assert offset % 2 == 0 and -(1 << 20) <= offset < (1 << 20)
    x = offset & 0x1fffff
    return (((x >> 20) & 1) << 31) | (((x >> 1) & 0x3ff) << 21) | (((x >> 11) & 1) << 20) | (((x >> 12) & 0xff) << 12) | (rd << 7) | 0x6f

def write(name, words):
    BASE.mkdir(exist_ok=True)
    (BASE / name).write_text(''.join(f'{word:08x}\n' for word in words), encoding='ascii')
    print(f'Wrote {name}: {len(words)} instructions')

smoke = [
    it(5, 0, 0, 1),              # 00: addi x1,x0,5
    it(7, 0, 0, 2),              # 04: addi x2,x0,7
    r(0, 2, 1, 0, 3),            # 08: add x3,x1,x2
    s(0, 3, 0, 2),              # 0c: sw x3,0(x0)
    it(0, 0, 2, 4, 0x03),       # 10: lw x4,0(x0)
    b(8, 3, 4, 0),              # 14: beq x4,x3,+8
    it(99, 0, 0, 5),            # 18: skipped
    it(42, 0, 0, 5),            # 1c: addi x5,x0,42
    j(8, 6),                    # 20: jal x6,+8 (x6=36)
    it(99, 0, 0, 7),            # 24: skipped
    it(11, 0, 0, 7),            # 28: addi x7,x0,11
    u(0x12345, 8, 0x37),        # 2c: lui x8,0x12345
    u(0, 9, 0x17),              # 30: auipc x9,0
    s(1, 1, 0, 0),              # 34: sb x1,1(x0)
    it(1, 0, 4, 10, 0x03),      # 38: lbu x10,1(x0)
    it(0, 0, 1, 11, 0x03),      # 3c: lh x11,0(x0)
    it(6, 1, 2, 12),            # 40: slti x12,x1,6
    it(2, 1, 1, 13),            # 44: slli x13,x1,2
    r(0, 2, 1, 4, 14),          # 48: xor x14,x1,x2
    0x00100073,                 # 4c: ebreak -> testbench halt
]
branches = [
    it(-1, 0, 0, 1),             # 00: x1=-1
    it(0, 1, 2, 2),              # 04: slti x2,x1,0 ->1
    it(1, 1, 3, 3),              # 08: sltiu x3,x1,1 ->0
    it(0x401, 1, 5, 4),          # 0c: srai x4,x1,1 ->-1
    it(1, 1, 5, 5),              # 10: srli x5,x1,1 ->0x7fffffff
    it(1, 0, 0, 6),              # 14: x6=1
    b(8, 6, 1, 1),              # 18: bne x1,x6,+8
    it(99, 0, 0, 7),            # 1c: skipped
    it(3, 0, 0, 7),             # 20: x7=3
    it(48, 0, 0, 8),            # 24: x8=48
    it(0, 8, 0, 9, 0x67),       # 28: jalr x9,x8,0 -> x9=44, pc=48
    it(99, 0, 0, 10),           # 2c: skipped
    it(8, 0, 0, 10),            # 30: x10=8
    r(0, 6, 1, 7, 11),          # 34: and x11,x1,x6
    0x00100073,                 # 38: ebreak
]

if __name__ == '__main__':
    write('smoke.hex', smoke)
    write('branches.hex', branches)

# Edge-case and regression programs; generated without a RISC-V cross-compiler.
# Each program terminates in EBREAK (or a deliberate instruction fault).
memory = [
    it(-128, 0, 0, 1), s(0, 1, 0, 2),
    it(0, 0, 0, 2, 0x03), it(0, 0, 4, 3, 0x03),
    it(0, 0, 1, 4, 0x03), it(0, 0, 5, 5, 0x03),
    it(0x123, 0, 0, 6), s(2, 6, 0, 1),
    it(2, 0, 1, 7, 0x03), it(2, 0, 5, 8, 0x03),
    s(1, 6, 0, 0), it(1, 0, 0, 9, 0x03),
    it(0, 0, 2, 10, 0x03), 0x00100073,
]

alu = [
    it(-8, 0, 0, 1), it(3, 0, 0, 2),
    r(0, 2, 1, 0, 3), r(0x20, 1, 2, 0, 4),
    r(0, 2, 2, 1, 5), r(0, 2, 1, 5, 6),
    r(0x20, 2, 1, 5, 7), r(0, 2, 1, 2, 8),
    r(0, 2, 1, 3, 9), r(0, 2, 1, 6, 10),
    r(0, 2, 1, 7, 11), r(0, 2, 1, 4, 12),
    it(0x55, 1, 4, 13), it(7, 1, 7, 14),
    it(0x40, 2, 6, 15), it(4, 2, 1, 16),
    it(2, 1, 5, 17), it(0x402, 1, 5, 18),
    it(-1, 1, 3, 19), 0x0000000f, 0x00100073,
]

branch_matrix = [
    it(0, 0, 0, 1), it(3, 0, 0, 2),
    it(1, 1, 0, 1), b(-4, 2, 1, 4),
    b(8, 2, 1, 5), it(99, 0, 0, 3),
    it(7, 0, 0, 3), b(8, 2, 0, 6),
    it(99, 0, 0, 4), it(8, 0, 0, 4),
    b(8, 1, 2, 7), it(99, 0, 0, 5),
    it(9, 0, 0, 5), b(8, 2, 1, 0),
    it(99, 0, 0, 6), it(10, 0, 0, 6),
    b(8, 2, 1, 1), it(11, 0, 0, 7),
    0x00100073,
]

illegal = [it(5, 0, 0, 1), 0xffffffff, it(99, 0, 0, 1)]
misaligned = [it(1, 0, 0, 1), it(0, 1, 2, 2, 0x03), it(99, 0, 0, 2)]
ecall = [0x00000073, it(99, 0, 0, 1)]
misaligned_jump = [it(6, 0, 0, 1), it(0, 1, 0, 2, 0x67), it(99, 0, 0, 2)]
invalid_shift = [it(3, 0, 0, 1), it(0x401, 1, 1, 2), it(99, 0, 0, 2)]

if __name__ == '__main__':
    for name, program in [
        ('memory.hex', memory), ('alu.hex', alu), ('branch_matrix.hex', branch_matrix),
        ('illegal.hex', illegal), ('misaligned.hex', misaligned),
        ('ecall.hex', ecall), ('misaligned_jump.hex', misaligned_jump),
        ('invalid_shift.hex', invalid_shift),
    ]:
        write(name, program)
