import struct
import subprocess

# Opcode constants
OP_GENESIS = 0x16
OP_MEASURE = 0x07
OP_PRINT_STATE = 0x0D
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_genesis_test(filename, seed):
    with open(filename, 'wb') as f:
        # Genesis from seed
        f.write(pack_instr(OP_GENESIS, target=0, op1=seed))
        
        # Test 3 distant points for consistency
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_PRINT_STATE, target=2048))
        f.write(pack_instr(OP_PRINT_STATE, target=4095))
        
        f.write(pack_instr(OP_MEASURE, target=0))
        f.write(pack_instr(OP_MEASURE, target=2048))
        f.write(pack_instr(OP_MEASURE, target=4095))
        
        f.write(pack_instr(OP_HALT))

def run_and_capture(filename):
    print(f"Executing {filename}...")
    result = subprocess.run(['./qutrit_engine', filename], capture_output=True, text=True)
    return result.stdout

if __name__ == "__main__":
    seed = 12345
    file1 = 'genesis_trial_1.qbin'
    file2 = 'genesis_trial_2.qbin'
    
    generate_genesis_test(file1, seed)
    generate_genesis_test(file2, seed)
    
    output1 = run_and_capture(file1)
    output2 = run_and_capture(file2)
    
    print("\n--- COMPARISON ---")
    if output1 == output2:
        print("SUCCESS: Both universes are identical. Genesis is 100% deterministic.")
        # Print a snippet to prove it
        print("\nUniverse 1 Output Sample:")
        print('\n'.join(output1.split('\n')[-10:]))
    else:
        print("FAILURE: Universes diverged. Determinism failed.")
        # Find the difference
        import difflib
        diff = difflib.ndiff(output1.splitlines(), output2.splitlines())
        print('\n'.join(diff))
