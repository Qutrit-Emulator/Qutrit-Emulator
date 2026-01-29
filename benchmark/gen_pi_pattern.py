import struct
import math

# Opcode constants
OP_INIT = 0x01
OP_BRAID = 0x09
OP_SHIFT = 0x10
OP_REPAIR = 0x11
OP_SUMMARY = 0x0F
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def get_pi_base3(n_digits):
    """
    Generate the first n digits of Pi in base 3.
    Using a simple spigot-like approach or high precision float conversion.
    For 4096 digits, we need high precision.
    """
    from decimal import Decimal, getcontext
    getcontext().prec = n_digits + 10
    
    # Chudnovsky algorithm for Pi
    def chudnovsky_pi(n):
        getcontext().prec = n + 10
        num_iter = n // 14 + 1
        a_k = Decimal(10005).sqrt() * 426880
        k = 0
        l = 13591409
        x = 1
        m = 1
        s = Decimal(l)
        for i in range(1, num_iter):
            k += 1
            l += 545140134
            x *= -(262537412640768000)
            m *= (Decimal(12 * k - 11) * (6 * k - 5) * (2 * k - 1)) / (k**3 * 24)
            s += (Decimal(m) * l) / x
        return a_k / s

    pi = chudnovsky_pi(int(n_digits * 0.7)) # Roughly correct precision for base 10
    
    # Convert decimal Pi to base 3 digits
    digits = []
    val = pi - 3 # Integer part is 3 (10 in base 3, so skip it and start from fraction)
    # Actually, let's just use the fraction. 3.14... -> .14...
    # Base 3 digits of fraction:
    for _ in range(n_digits):
        val *= 3
        d = int(val)
        digits.append(d)
        val -= d
    return digits

def generate_pi_pattern(filename):
    n_chunks = 4096
    side = 64
    digits = get_pi_base3(n_chunks)
    
    with open(filename, 'wb') as f:
        print(f"Initializing {n_chunks} Chunks with Pi digits (Base 3)...")
        for i in range(n_chunks):
            f.write(pack_instr(OP_INIT, target=i, op1=1))
            # digit 0 -> State |0> (No shift)
            # digit 1 -> State |1> (1 shift)
            # digit 2 -> State |2> (2 shifts)
            for _ in range(digits[i]):
                f.write(pack_instr(OP_SHIFT, target=i))
                
        print(f"Weaving 2D Topological Grid ({side}x{side})...")
        for y in range(side):
            for x in range(side):
                idx = y * side + x
                # Link Right
                if x < side - 1:
                    f.write(pack_instr(OP_BRAID, target=idx, op1=idx + 1))
                # Link Down
                if y < side - 1:
                    f.write(pack_instr(OP_BRAID, target=idx, op1=idx + side))
                    
        print("Executing THE PI PATTERN (Resonance Scan)...")
        # Multiple repair passes to deepen the resonance
        for i in range(3):
            print(f"  Resonance Pass {i+1}...")
            f.write(pack_instr(OP_REPAIR))
            
        print("Pattern Detection: Summarizing Active Mass Clusters...")
        f.write(pack_instr(OP_SUMMARY, target=n_chunks))
        
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_pi_pattern('pi_pattern.qbin')
    print("pi_pattern.qbin generated successfully.")
