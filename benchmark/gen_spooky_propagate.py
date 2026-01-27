import struct

def make_instr(opcode, target=0, op1=0, op2=0):
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

# 1. Initialize
for i in range(NUM_CHUNKS):
    program += make_instr(OP_INIT, target=i, op1=1)

# 2. Superposition Chunk 0
program += make_instr(OP_SUP, target=0)

# 3. Chain Braid 0..1499
for i in range(NUM_CHUNKS - 1):
    program += make_instr(OP_BRAID, target=i, op1=i+1)

# 4. Verify Entanglement 1 <-> 1300 BEFORE measurement
program += make_instr(OP_BELL_TEST, target=1, op1=1300)

# 5. Measure Chunk 1 (Collapse "spooky action" source)
program += make_instr(OP_MEASURE, target=1)

# 6. Verify Entanglement 1 <-> 1300 AFTER measurement
# If propagation works, 1300 should have collapsed to the same state as 1, keeping correlation high
program += make_instr(OP_BELL_TEST, target=1, op1=1300)

# 7. Measure Chunk 1300
program += make_instr(OP_MEASURE, target=1300)

program += make_instr(OP_HALT)

with open('spooky_propagate.qbin', 'wb') as f:
    f.write(program)

print("Created spooky_propagate.qbin")
