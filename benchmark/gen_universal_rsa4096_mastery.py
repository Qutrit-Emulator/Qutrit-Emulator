import struct

def make_instr(opcode, target=0, op1=0, op2=0):
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

# Opcodes
OP_INIT           = 0x01
OP_SUP            = 0x02
OP_BRAID          = 0x09
OP_ORACLE        = 0x0B
OP_EXPORT_WEIGHTS = 0x19
OP_HALT           = 0xFF

NUM_LIMBS = 64 # 64 * 64 bits = 4096 bits

program = b''

print("Generating Universal Potentia State (High Entanglement)...")

# 1. Initialize Slots 100-163 (P-space) and 200-263 (Q-space)
print(f"Step 1: Initializing {NUM_LIMBS*2} chunks.")
for i in range(NUM_LIMBS):
    program += make_instr(OP_INIT, target=100+i, op1=1)
    program += make_instr(OP_INIT, target=200+i, op1=1)

# 2. Create Superposition (The Potentia)
print("Step 2: Creating uniform superposition.")
for i in range(NUM_LIMBS):
    program += make_instr(OP_SUP, target=100+i)
    program += make_instr(OP_SUP, target=200+i)

# 3. Braid Timelines (Universal Entanglement)
print("Step 3: Braiding all timelines to create connectivity.")
for i in range(NUM_LIMBS):
    # Link P[i] with Q[i]
    program += make_instr(OP_BRAID, target=100+i, op1=200+i)
    # Link P[i] with P[i+1] (Chain)
    if i < NUM_LIMBS - 1:
        program += make_instr(OP_BRAID, target=100+i, op1=100+i+1)

# 4. Invoke Universal Training
# The oracle detects it isn't 'mastered' (limbs != 2) and sets them to 2.
print("Step 4: Invoking Universal Training (Mastery).")
ORACLE_UNIVERSAL_ID = 0x08
program += make_instr(OP_ORACLE, target=100, op1=ORACLE_UNIVERSAL_ID)

# 5. Export State
# This saves the full quantum state (amplitudes + topology) to 'mastered.weights'
print("Step 5: Exporting Universal State.")
program += make_instr(OP_EXPORT_WEIGHTS)
program += make_instr(OP_HALT)

output_file = 'universal_rsa4096_mastery.qbin'
with open(output_file, 'wb') as f:
    f.write(program)

print(f"Created {output_file}")
