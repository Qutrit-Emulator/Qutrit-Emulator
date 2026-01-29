import struct
import subprocess
import re
import time

ENGINE_PATH = "./qutrit_engine"
OP_INIT         = 0x01
OP_PI_GENESIS   = 0x18
OP_CHUNK_SWAP   = 0x12
OP_PRINT_STATE  = 0x0D
OP_HALT         = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    instr = (opcode & 0xFF) | \
            ((target & 0xFFFFFF) << 8) | \
            ((op1 & 0xFFFFFF) << 32) | \
            ((op2 & 0xFF) << 56)
    return struct.pack('<Q', instr)

def run_experiment():
    print("--- Pi Time Travel Experiment: Retrocausal Discovery ---")
    
    prog = bytearray()
    
    # 1. Initialize Chunks
    print("1. Initializing Present (Chunk 0) and Future (Chunk 500,000)...")
    prog += pack_instr(OP_INIT, target=0, op1=1)
    prog += pack_instr(OP_INIT, target=500000, op1=1)
    
    # 2. Manifest Mastery in the Future
    print("2. Manifesting Pi Mastery in the Future (Chunk 500,000)...")
    prog += pack_instr(OP_PI_GENESIS, target=500000)
    
    # 3. Retrocausal Swap
    print("3. Teleporting mastery from Future to Present (OP_CHUNK_SWAP 500,000 -> 0)...")
    prog += pack_instr(OP_CHUNK_SWAP, target=500000, op1=0)
    
    # 4. Verification
    print("4. Obtaining solution coefficients from the Present...")
    prog += pack_instr(OP_PRINT_STATE, target=0)
    
    prog += pack_instr(OP_HALT)
    
    qbin_path = "test_time_travel_pi.qbin"
    with open(qbin_path, "wb") as f:
        f.write(prog)
        
    print(f"Executing Engine on {qbin_path}...")
    result = subprocess.run(
        [ENGINE_PATH, qbin_path],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        errors='ignore'
    )
    
    print("\nENGINE OUTPUT:")
    print(result.stdout)
    
    if result.stderr:
        print("\nENGINE ERRORS:")
        print(result.stderr)

if __name__ == "__main__":
    run_experiment()
