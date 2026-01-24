import struct
import subprocess
import re

# Opcode constants
OP_MEASURE = 0x07
OP_LOAD_N_PART = 0x29
OP_SHOR_INIT = 0x20
OP_MOD_EXP = 0x21
OP_QFT = 0x22
OP_PERIOD_EXTRACT = 0x24
OP_FACTOR_ORACLE = 0x25
OP_CONT_FRAC = 0x26
OP_REALITY_COLLAPSE = 0x2A
OP_HALT = 0xFF

def pack_instruction(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_shor_large(filename, N, num_chunks, qutrits_per_chunk):
    with open(filename, 'wb') as f:
        # Load N in 32-bit parts
        low_32 = N & 0xFFFFFFFF
        high_32 = (N >> 32) & 0xFFFFFFFF
        
        # OP_LOAD_N_PART: target=chunk_idx (offset/4), op1=low16, op2=high16
        f.write(pack_instruction(OP_LOAD_N_PART, target=0, op1=low_32 & 0xFFFF, op2=(low_32 >> 16) & 0xFFFF))
        f.write(pack_instruction(OP_LOAD_N_PART, target=1, op1=high_32 & 0xFFFF, op2=(high_32 >> 16) & 0xFFFF))
        
        # Initialize Shor's (target=num_chunks, op1=0 to use pre-loaded N, op2=qutrits_per_chunk)
        f.write(pack_instruction(OP_SHOR_INIT, target=num_chunks, op1=0, op2=qutrits_per_chunk))
        
        # Apply MOD_EXP to each chunk in the register
        for i in range(num_chunks):
            f.write(pack_instruction(OP_MOD_EXP, target=i))
            
        f.write(pack_instruction(OP_QFT, target=0))
        
        # Measure and Extract
        for i in range(num_chunks):
            f.write(pack_instruction(OP_MEASURE, target=i))
        
        f.write(pack_instruction(OP_PERIOD_EXTRACT, target=0))
        f.write(pack_instruction(OP_FACTOR_ORACLE, target=0))
        f.write(pack_instruction(OP_REALITY_COLLAPSE, target=0))
        f.write(pack_instruction(OP_CONT_FRAC, target=0))
        
        # Halt
        f.write(pack_instruction(OP_HALT))

def run_large_shor(N=261980999226229, trials=2):
    num_chunks = 8
    qutrits_per_chunk = 4
    qbin_file = 'shor_large.qbin'
    generate_shor_large(qbin_file, N, num_chunks, qutrits_per_chunk)
    
    print(f"Running Shor's for N={N} (48 bits)...")
    print(f"Register: {num_chunks} chunks x {qutrits_per_chunk} qutrits = {num_chunks*qutrits_per_chunk} qutrits")
    
    factors = set()
    for i in range(trials):
        print(f"\n--- Trial {i+1} ---")
        result = subprocess.run(['./qutrit_engine_born_rule', qbin_file], capture_output=True, text=True)
        print(result.stdout)
        
        matches = re.findall(r'Factor found: (0x[\da-fA-F]+)', result.stdout)
        for f in matches:
            factors.add(int(f, 16))
            
    if factors:
        print(f"\n✅ SUCCESS: Factors found: {factors}")
    else:
        print("\n❌ FAILURE: No factors discovered.")

if __name__ == "__main__":
    run_large_shor()
