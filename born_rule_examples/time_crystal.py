import struct
import subprocess
import re

# Opcode constants
OP_INIT = 0x01
OP_SUP = 0x02
OP_ADDON = 0x0C
OP_FUTURE_ORACLE = 0x13
OP_MEASURE = 0x07
OP_HALT = 0xFF
OP_GELLMANN = 0x81

def pack_instruction(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_time_crystal(filename, steps=5):
    with open(filename, 'wb') as f:
        # Initialize 1 chunk with 2 qutrits
        f.write(pack_instruction(OP_INIT, target=0, op1=2))
        
        # 1. Create initial superposition
        f.write(pack_instruction(OP_SUP, target=0))
        
        # 2. Use Future Oracle to prune the "Death" states (anything with 0)
        # This leaves us in the {11, 12, 21, 22} subspace.
        f.write(pack_instruction(OP_FUTURE_ORACLE, target=0))
        
        for i in range(steps):
            # 3. Apply Time Crystal Evolution (Gell-Mann rotation)
            # This oscillates |12> <-> |21>
            f.write(pack_instruction(OP_GELLMANN, target=0))
            
            # 4. Inject Noise (Re-introducing 0s via SUP)
            # This represents entropy trying to break the crystal
            f.write(pack_instruction(OP_SUP, target=0))
            
            # 5. Future-Pruning Stabilization
            # The oracle restores the crystal by pruning the noise branches
            f.write(pack_instruction(OP_FUTURE_ORACLE, target=0))
            
        # Final Measurement
        f.write(pack_instruction(OP_MEASURE, target=0))
        f.write(pack_instruction(OP_HALT))

def run_trial():
    qbin_file = 'time_crystal.qbin'
    generate_time_crystal(qbin_file, steps=20)
    result = subprocess.run(['./qutrit_engine_born_rule', qbin_file], capture_output=True, text=True)
    
    match = re.search(r'\[MEAS\].*?=>\s*(\d+)', result.stdout)
    if match:
        val = int(match.group(1))
        return val
    return None

def is_good(value):
    # d0 = value % 3, d1 = (value // 3) % 3
    d0 = value % 3
    d1 = (value // 3) % 3
    return d0 != 0 and d1 != 0

def run_simulation(num_trials=20):
    print(f"Simulating Stable Time Crystal over {num_trials} trials...")
    stable_count = 0
    collapsed_count = 0
    
    for i in range(num_trials):
        val = run_trial()
        if val is None:
            continue
            
        if is_good(val):
            stable_count += 1
        else:
            print(f"Trial {i+1}: CRYSTAL COLLAPSED (Measured {val} -> d1={ (val // 3) % 3}, d0={val % 3})")
            collapsed_count += 1
            
    print("\n--- Time Crystal Results ---")
    print(f"Total Trials: {num_trials}")
    print(f"Stable Over Time: {stable_count}")
    print(f"Decoherence Failures: {collapsed_count}")
    
    if collapsed_count == 0 and stable_count > 0:
        print("\n💎 SUCCESS: The Time Crystal was stabilized by the Future Oracle.")
    else:
        print("\n☣️ FAILURE: Entropy has dissolved the crystal.")

if __name__ == "__main__":
    run_simulation()
