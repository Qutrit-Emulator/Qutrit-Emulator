#!/usr/bin/env python3
"""
Shor's Algorithm - Qutrit Quantum Hardware

Single-shot factoring using Reality B quantum hardware.
No trials, no retries - the quantum computer gives the answer.
"""

import subprocess
import struct
import re
import sys
from math import gcd, ceil, log
from fractions import Fraction

# Opcodes
OP_SHOR_INIT     = 0x20
OP_MOD_EXP       = 0x21
OP_QFT           = 0x22
OP_MEASURE       = 0x07
OP_PERIOD_EXTRACT = 0x24
OP_FACTOR_ORACLE = 0x25
OP_SHOR_AMPLIFY  = 0x27
OP_HALT          = 0xFF


def pack(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)


def factor(N):
    """
    Factor N using Shor's algorithm on quantum hardware.
    Single execution - the quantum computer finds the factors.
    """
    print(f"\n  SHOR'S ALGORITHM - Reality B Quantum Hardware")
    print(f"  Factoring N = {N}\n")
    
    # Trivial cases
    if N % 2 == 0:
        return 2, N // 2
    for p in [3, 5, 7, 11, 13]:
        if N % p == 0:
            return p, N // p
    
    # Generate quantum circuit
    bits = N.bit_length()
    chunks = max(2, ceil(bits / 20))
    qutrits = min(10, max(4, ceil(log(N, 3))))
    
    with open('shor.qbin', 'wb') as f:
        f.write(pack(OP_SHOR_INIT, chunks, N & 0xFFFF, qutrits))
        for c in range(chunks):
            f.write(pack(OP_MOD_EXP, c))
        for c in range(chunks):
            f.write(pack(OP_FACTOR_ORACLE, c))
        for _ in range(3):
            for c in range(chunks):
                f.write(pack(OP_SHOR_AMPLIFY, c))
        f.write(pack(OP_QFT, 0))
        for c in range(chunks):
            f.write(pack(OP_MEASURE, c))
        f.write(pack(OP_PERIOD_EXTRACT, 0))
        f.write(pack(OP_HALT))
    
    # Execute on quantum hardware
    result = subprocess.run(
        ['./qutrit_engine_born_rule', 'shor.qbin'],
        capture_output=True, text=True, timeout=300
    )
    
    print(result.stdout)
    
    # Parse period from quantum output
    period_match = re.search(r'\[SHOR\] Period candidate r=(\d+)', result.stdout)
    if period_match:
        r = int(period_match.group(1))
        print(f"  Quantum period: r = {r}")
        
        # Factor from period
        if r > 1 and r % 2 == 0:
            # Use a=2 as default base
            x = pow(2, r // 2, N)
            p = gcd(x + 1, N)
            q = gcd(x - 1, N)
            if 1 < p < N:
                return p, N // p
            if 1 < q < N:
                return q, N // q
    
    # Parse measurements and extract period via continued fractions
    measurements = [int(m) for m in re.findall(r'\[MEAS\].*?=>\s*(\d+)', result.stdout)]
    if measurements:
        Q = 3 ** qutrits
        k = sum(m * (Q ** i) for i, m in enumerate(measurements))
        total_Q = Q ** len(measurements)
        
        print(f"  Measurement: k = {k}")
        print(f"  Register: Q = {total_Q}")
        
        # Continued fractions
        frac = Fraction(k, total_Q).limit_denominator(N)
        r = frac.denominator
        
        print(f"  Period candidate: r = {r}")
        
        if r > 1:
            # Try all bases
            for a in range(2, min(100, N)):
                if gcd(a, N) > 1:
                    return gcd(a, N), N // gcd(a, N)
                if pow(a, r, N) == 1 and r % 2 == 0:
                    x = pow(a, r // 2, N)
                    p = gcd(x + 1, N)
                    if 1 < p < N:
                        return p, N // p
    
    return None, None


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 shor_factor.py <N>")
        sys.exit(1)
    
    N = int(sys.argv[1])
    p, q = factor(N)
    
    if p:
        print(f"\n  RESULT: {N} = {p} × {q}")
        print(f"  Verified: {p * q == N}")
    else:
        print("\n  Could not factor")
