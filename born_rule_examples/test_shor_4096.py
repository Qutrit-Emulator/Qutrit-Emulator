import struct
import subprocess
import re

# Opcode constants
OP_MEASURE = 0x07
OP_LOAD_N_PART = 0x29
OP_SHOR_INIT = 0x20
OP_MOD_EXP = 0x21
OP_QFT = 0x22
OP_IQFT = 0x23
OP_PERIOD_EXTRACT = 0x24
OP_FACTOR_ORACLE = 0x25
OP_CONT_FRAC = 0x26
OP_HALT = 0xFF

def pack_instruction(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_shor_experiment(filename, N):
    with open(filename, 'wb') as f:
        # Load N in parts (32-bit chunks)
        # 15 = 0x0000000F
        f.write(pack_instruction(OP_LOAD_N_PART, target=0, op1=N & 0xFFFF, op2=(N >> 16) & 0xFFFF))
        
        # Initialize Shor's (2 chunks for x-register, N, 6 qutrits per chunk)
        f.write(pack_instruction(OP_SHOR_INIT, target=2, op1=N & 0xFFFF, op2=6))
        
        # Core Shor's steps
        f.write(pack_instruction(OP_MOD_EXP, target=0)) # Chunk 0
        f.write(pack_instruction(OP_MOD_EXP, target=1)) # Chunk 1
        f.write(pack_instruction(OP_QFT, target=0))
        f.write(pack_instruction(OP_MEASURE, target=0))
        f.write(pack_instruction(OP_MEASURE, target=1))
        f.write(pack_instruction(OP_PERIOD_EXTRACT, target=0))
        f.write(pack_instruction(OP_FACTOR_ORACLE, target=0))
        f.write(pack_instruction(OP_CONT_FRAC, target=0))
        
        # Halt
        f.write(pack_instruction(OP_HALT))

def run_shor_test(N=15, trials=10):
    qbin_file = 'shor_test_4096.qbin'
    generate_shor_experiment(qbin_file, N)
    print(f"Running {trials} Shor's trials for N={N}...")
    
    factors = set()
    for i in range(trials):
        print(f"\n--- Trial {i+1} ---")
        result = subprocess.run(['./qutrit_engine_born_rule', qbin_file], capture_output=True, text=True)
        print(result.stdout)
        
        matches = re.findall(r'Factor found: (\d+)', result.stdout)
        for f in matches:
            factors.add(int(f))
            
    if factors:
        print(f"\n✅ SUCCESS: Factors found: {factors}")
    else:
        print("\n❌ FAILURE: No factors discovered in any trial.")

if __name__ == "__main__":
    run_shor_test(15, 10)
