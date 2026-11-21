#!/usr/bin/env python3
"""Validate generated ROM images have valid formatting and expected lengths."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAMES = ('smoke', 'branches', 'memory', 'alu', 'branch_matrix',
         'illegal', 'misaligned', 'ecall', 'misaligned_jump', 'invalid_shift')
for name in NAMES:
    words = (ROOT / 'tests' / f'{name}.hex').read_text().splitlines()
    assert words and len(words) <= 256, (name, len(words))
    assert all(len(w) == 8 and all(c in '0123456789abcdef' for c in w) for w in words), name
    assert any(int(w, 16) in (0x00100073, 0x00000073, 0xffffffff) for w in words) or name in ('misaligned', 'misaligned_jump', 'invalid_shift'), name
    print(f'PASS: ROM format {name} ({len(words)} words)')
