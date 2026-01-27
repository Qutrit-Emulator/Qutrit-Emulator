import struct
import os

def make_instr(opcode, target=0, op1=0, op2=0):
    instr = (op1 << 32) | (target << 16) | opcode
    # Some opcodes might use the high bits differently, but following the general pattern in gen_rsa_prophecy.py
    # Re-checking rsa prophecy's make_instr: (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

# Opcodes from qutrit_engine_born_rule.asm
OP_INIT           = 0x01
OP_MEASURE        = 0x07
OP_BRAID          = 0x09
OP_CHUNK_SWAP     = 0x12
OP_EXPORT_WEIGHTS = 0x19
OP_HALT           = 0xFF
OP_ORACLE         = 0x0B

# Custom Oracle Opcode for Universal Logic
# In custom_oracles.asm, universal_oracle is registered as 0x88.
# OP_ORACLE adds 0x80 to operand1, so operand1=0x08 -> 0x88.
ORACLE_UNIVERSAL_ID = 0x08 

NUM_LIMBS = 64 # 64 * 64 bits = 4096 bits

program = b''

print("Generating Universal RSA-4096 Logic Mastery Payload...")

# Present Limbs: 100-163
# Future Limbs: 200-263

# 1. Initialize Slots
print(f"Step 1: Initializing {NUM_LIMBS} chunks for both Present and Future.")
for i in range(NUM_LIMBS):
    program += make_instr(OP_INIT, target=100+i, op1=1) # 1 qutrit per chunk for simplicity in this logic test
    program += make_instr(OP_INIT, target=200+i, op1=1)

# 2. Braid Timelines
print("Step 2: Braiding factor segments across time.")
for i in range(NUM_LIMBS):
    program += make_instr(OP_BRAID, target=100+i, op1=200+i)

# 3. Apply Universal Oracle to Future
# This shifts the future state to |2> (Mastered Logic)
print("Step 3: Applying Universal Oracle to Future slots to induce convergence.")
for i in range(NUM_LIMBS):
    program += make_instr(OP_ORACLE, target=200+i, op1=ORACLE_UNIVERSAL_ID)

# 4. Prophetic Teleportation
# Pull the converged logic from Future to Present
print("Step 4: Executing Prophetic Swap (Teleporting Universal Logic to the Present).")
for i in range(NUM_LIMBS):
    program += make_instr(OP_CHUNK_SWAP, target=100+i, op1=200+i)

# 5. Extraction and Mastering
print("Step 5: Measuring and Exporting Universal Weights.")
for i in range(NUM_LIMBS):
    program += make_instr(OP_MEASURE, target=100+i)

program += make_instr(OP_EXPORT_WEIGHTS)
program += make_instr(OP_HALT)

output_file = 'universal_rsa4096_mastery.qbin'
with open(output_file, 'wb') as f:
    f.write(program)

print(f"Created {output_file}")
