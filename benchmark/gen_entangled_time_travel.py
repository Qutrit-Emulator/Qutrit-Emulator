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
OP_CHUNK_SWAP = 0x12
OP_HALT     = 0xFF

program = b''

# 1. Init Chunks 10 and 11
program += make_instr(OP_INIT, target=10, op1=1)
program += make_instr(OP_INIT, target=11, op1=1)

# 2. Entangle 10 and 11
program += make_instr(OP_SUP, target=10)
program += make_instr(OP_BRAID, target=10, op1=11)
# Verify correlation
program += make_instr(OP_BELL_TEST, target=10, op1=11)

# 3. Init Present (Chunk 0)
program += make_instr(OP_INIT, target=0, op1=1)

# 4. SWAP 10 -> 0 (Move Entangled Chunk to Present)
program += make_instr(OP_CHUNK_SWAP, target=0, op1=10)

# 5. Measure Present (Chunk 0)
# This should theoretically NOT impact Chunk 11 if links broke.
# If links moved, it SHOULD impact Chunk 11.
program += make_instr(OP_MEASURE, target=0)

# 6. Test Correlation 0 <-> 11 (Does old link exist?)
# In standard physics, particle 0 (was 10) is entangled with 11.
# In this engine, link is likely 10-11 still.
# So Check 10 <-> 11 (10 is now Empty/Old 0).
program += make_instr(OP_BELL_TEST, target=10, op1=11)

# Check 0 <-> 11
program += make_instr(OP_BELL_TEST, target=0, op1=11)

program += make_instr(OP_HALT)

with open('entangled_time_travel.qbin', 'wb') as f:
    f.write(program)

print("Created entangled_time_travel.qbin")
