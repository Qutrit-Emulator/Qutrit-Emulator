import struct
import subprocess
import re

# Opcode constants
OP_INIT = 0x01
OP_SUP = 0x02
OP_MEASURE = 0x07
OP_FUTURE_ORACLE = 0x13
OP_HALT = 0xFF

def pack_instruction(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_cat_experiment(filename):
    with open(filename, 'wb') as f:
        # Initialize 1 chunk with 2 qutrits (Cat + Environment)
        f.write(pack_instruction(OP_INIT, target=0, op1=2))
        # Superposition (Cat is both Dead |0> and Alive |1/2>)
        f.write(pack_instruction(OP_SUP, target=0))
        # Apply Future Oracle to prune the "Dead" branch (|0>)
        f.write(pack_instruction(OP_FUTURE_ORACLE, target=0))
        # Open the box (Measure)
        f.write(pack_instruction(OP_MEASURE, target=0))
        # Halt
        f.write(pack_instruction(OP_HALT))

def run_cat_trial():
    qbin_file = 'cat_experiment.qbin'
    generate_cat_experiment(qbin_file)
    result = subprocess.run(['./qutrit_engine_born_rule', qbin_file], capture_output=True, text=True)
    
    match = re.search(r'\[MEAS\].*?=>\s*(\d+)', result.stdout)
    if match:
        val = int(match.group(1))
        # Cat state is val % 3
        cat_state = val % 3
        return cat_state
    return None

def run_simulation(num_trials=50):
    print(f"Opening the box {num_trials} times...")
    alive_count = 0
    dead_count = 0
    
    for i in range(num_trials):
        state = run_cat_trial()
        if state is None:
            continue
            
        if state == 0:
            print(f"Trial {i+1}: 💀 The cat is DEAD.")
            dead_count += 1
        else:
            # print(f"Trial {i+1}: 🐱 The cat is ALIVE (State {state}).")
            alive_count += 1
            
    print("\n--- Cat Experiment Results ---")
    print(f"Total Trials: {num_trials}")
    print(f"Cat ALIVE: {alive_count}")
    print(f"Cat DEAD: {dead_count}")
    
    if dead_count == 0:
        print("\n🏆 SUCCESS: The Future Oracle has ensured the cat's survival across all timelines.")
    else:
        print("\n⚠️ FAILURE: Entropy has claimed the cat.")

if __name__ == "__main__":
    run_simulation()
