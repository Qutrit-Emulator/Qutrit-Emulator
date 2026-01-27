import struct

def make_instr(opcode, target=0, op1=0, op2=0):
    # Format: [Op2:16][Op1:16][Target:16][Opcode:16]
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

# Opcodes
OP_INIT     = 0x01
OP_SUP      = 0x02
OP_MEASURE  = 0x07
OP_BRAID    = 0x09
OP_BELL_TEST= 0x0E
OP_HALT     = 0xFF
OP_SUMMARY  = 0x0F

program = b''

NUM_CHUNKS = 1500

print(f"Generating program for {NUM_CHUNKS} chunks...")

# 1. Initialize all chunks
for i in range(NUM_CHUNKS):
    program += make_instr(OP_INIT, target=i, op1=1) # size 1 qutrit for speed

# 2. Create Superposition on Chunk 0
program += make_instr(OP_SUP, target=0)

# 3. Chain Braid: 0->1, 1->2, ..., N-2->N-1
# This propagates the superposition and entanglement phases down the chain
for i in range(NUM_CHUNKS - 1):
    program += make_instr(OP_BRAID, target=i, op1=i+1)

# 4. Global Summary to show active state
program += make_instr(OP_SUMMARY, target=NUM_CHUNKS)

# 5. Verify Entanglement at the start of the chain
program += make_instr(OP_BELL_TEST, target=0, op1=1)

# 6. Verify Entanglement at the end of the chain
program += make_instr(OP_BELL_TEST, target=NUM_CHUNKS-2, op1=NUM_CHUNKS-1)

# 7. Verify Entanglement across the entire chain (0 vs Last)
# If the state copied perfectly, this should also show correlation
program += make_instr(OP_BELL_TEST, target=0, op1=NUM_CHUNKS-1)

# 8. Measure the last chunk
program += make_instr(OP_MEASURE, target=NUM_CHUNKS-1)

# 9. Halt
program += make_instr(OP_HALT)

with open('spooky_scale.qbin', 'wb') as f:
    f.write(program)

print("Created spooky_scale.qbin")
