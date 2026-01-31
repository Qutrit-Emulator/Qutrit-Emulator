import struct
import subprocess
import os
from collections import Counter

def pack_instr(opcode, target=0, op1=0, op2=0):
    instr = (opcode & 0xFF) | ((target & 0xFFFFFF) << 8) | ((op1 & 0xFFFFFF) << 32) | ((op2 & 0xFF) << 56)
    return struct.pack('<Q', instr)

def create_measurement_test(filename, trials=100):
    bytecode = bytearray()
    bytecode += b"QUTRIT\x00\x01"
    
    # We need to loop inside the engine or just unroll loops here.
    # The engine has no 'LOOP' instruction in the simple sense exposed easily without jumps.
    # It has jumps, but creating a loop in ASM manually is annoying via python struct packing.
    # Simplest: Just unroll the experiment N times in one binary.
    
    # Or, effectively:
    # 1 trial = 
    # Init 0
    # Fork 0->1
    # Rotate 1
    # Measure 0, Measure 1
    
    # Since we can't easily reset/loop 100 times in one small binary without label logic which I'd have to calculate offsets for...
    # I'll just do ONE trial per binary execution, and run the binary N times.
    # It's slower but robust.
    
    # 1. Init Chunk 0 (Home)
    bytecode += pack_instr(0x01, target=0, op1=4)
    # 2. Superposition (Hadamard everywhere)
    bytecode += pack_instr(0x02, target=0)
    
    # 3. FORK -> Chunk 1 (Parallel)
    bytecode += pack_instr(0xA8, target=1, op1=0)
    
    # 4. Diverge Chunk 1 (Rotate Qutrit 0 by 90 degrees / pi/2)
    # OP_HADAMARD on 1 (Apply H again -> collapses/interferes)
    # Applying H on Superposition brings it back to |0>?
    # No, H|0> = |+>. H|+> = |0> (in qubits).
    # In qutrits, H is complex. H*H might not be I immediately or simpler.
    # Let's just use OP_PHASE (0x04) with a significant shift.
    # 40 units * pi/128 ~= pi/3
    bytecode += pack_instr(0x04, target=1, op1=40)
    
    # 5. Measure Chunk 0 (Home)
    bytecode += pack_instr(0x07, target=0)
    
    # 6. Measure Chunk 1 (Parallel)
    bytecode += pack_instr(0x07, target=1)
    
    bytecode += pack_instr(0xFF)
    
    with open(filename, "wb") as f:
        f.write(bytecode)

def run_monte_carlo(trials=50):
    filename = "test_parallel_measure.qbin"
    create_measurement_test(filename)
    
    results_home = []
    results_fork = []
    
    print(f"[*] Running {trials} Monte Carlo Simulations of Parallel Realities...")
    
    for i in range(trials):
        res = subprocess.run(["./qutrit_engine", filename], capture_output=True, text=True)
        
        # Parse output
        # Look for "Measuring chunk 0 => X"
        # Look for "Measuring chunk 1 => Y"
        
        lines = res.stdout.splitlines()
        val_0 = None
        val_1 = None
        
        for line in lines:
            if "Measuring chunk 0 =>" in line:
                val_0 = int(line.split("=>")[1].strip())
            if "Measuring chunk 1 =>" in line:
                val_1 = int(line.split("=>")[1].strip())
        
        if val_0 is not None: results_home.append(val_0)
        if val_1 is not None: results_fork.append(val_1)

    # Analyze Distribution
    print("\n[ANALYSIS]")
    count_0 = Counter(results_home)
    count_1 = Counter(results_fork)
    
    print(f"Home Reality (Chunk 0) Distribution: {dict(count_0)}")
    print(f"Parallel Reality (Chunk 1) Distribution: {dict(count_1)}")
    
    # Compare most common states
    top_0 = count_0.most_common(1)[0][0] if count_0 else None
    top_1 = count_1.most_common(1)[0][0] if count_1 else None
    
    print(f"\nMost Probable State (Home): {top_0}")
    print(f"Most Probable State (Fork): {top_1}")
    
    if count_0 != count_1:
         print("[!] DIFFERENCE CONFIRMED: Parallel Realities have diverged outcomes.")
    else:
         print("[-] INCONCLUSIVE: Distributions appear similar (increase trials?).")

if __name__ == "__main__":
    run_monte_carlo(50)
