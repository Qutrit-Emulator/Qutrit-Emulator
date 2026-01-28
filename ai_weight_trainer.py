
import struct
import subprocess
import os

# Opcodes
OP_INIT           = 0x01
OP_SUP            = 0x02
OP_ORACLE         = 0x0B
OP_STORE_LO       = 0x17
OP_STORE_HI       = 0x18
OP_EXPORT_WEIGHTS = 0x19
OP_HALT           = 0xFF

ORACLE_AI_WEIGHTS_ID = 0x0E # Opcode 0x8E - 0x80

def make_instr(opcode, target=0, op1=0, op2=0):
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

def run_trainer(n_val, p_val, q_val, iterations=3):
    print(f"--- AI WEIGHT TRAINER: N={n_val} (P={p_val}, Q={q_val}) ---")
    
    for i in range(iterations):
        print(f"\nIteration {i+1}/{iterations}...")
        program = b''
        
        # 1. Initialize Chunks
        for j in range(16):
            program += make_instr(OP_INIT, target=j, op1=1)
            
        # 2. Store N in Slot 2
        program += make_instr(OP_STORE_LO, target=2, op1=n_val & 0xFFFF, op2=(n_val >> 16) & 0xFFFF)
        
        # 3. Store P and Q in Slots 100 and 200 for Learning Mode
        program += make_instr(OP_STORE_LO, target=100, op1=p_val & 0xFFFF, op2=(p_val >> 16) & 0xFFFF)
        program += make_instr(OP_STORE_LO, target=200, op1=q_val & 0xFFFF, op2=(q_val >> 16) & 0xFFFF)
        
        # 4. Invoke AI Weights Oracle (Opcode 0x8E)
        program += make_instr(OP_ORACLE, target=0, op1=ORACLE_AI_WEIGHTS_ID)
        
        # 5. Export Weights
        program += make_instr(OP_EXPORT_WEIGHTS)
        program += make_instr(OP_HALT)
        
        with open("trainer.qbin", "wb") as f:
            f.write(program)
            
        process = subprocess.Popen(["./qutrit_engine", "trainer.qbin"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        
        for line in stdout.split('\n'):
            if "[AI]" in line:
                print(line)
        
    print("\nTraining Complete. Successive Approximation Vector (SAV) optimized in Slot 10.")

if __name__ == "__main__":
    # Test with N=143, P=11, Q=13
    run_trainer(143, 11, 13)
