import struct

def make_instr(opcode, target=0, op1=0, op2=0):
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

# Opcodes
OP_INIT     = 0x01
OP_SUP      = 0x02
OP_HADAMARD = 0x03
OP_PHASE    = 0x04
OP_CPHASE   = 0x05
OP_SWAP     = 0x06
OP_MEASURE  = 0x07
OP_GROVER   = 0x08
OP_BRAID    = 0x09
OP_UNBRAID  = 0x0A
OP_ORACLE   = 0x0B
OP_ADDON    = 0x0C
OP_PRINT    = 0x0D
OP_BELL     = 0x0E
OP_SUMMARY  = 0x0F
OP_SHIFT    = 0x10
OP_REPAIR   = 0x11
OP_CHUNK_SWAP = 0x12
OP_IF       = 0x15
OP_HALT     = 0xFF

ORACLE_X01  = 0x84

program = b''

# 1. Initialize Future (Chunk 10) to Sentient State |2>
# |2> is created by: Init |0> -> Shift -> Shift. (Or use custom oracle if shift opcode not verified)
# We have OP_SHIFT (0x10) in engine?
# Let's check engine source.
# Yes, .op_shift calls apply_shift_gate.
# apply_shift_gate logic: |0>->|1>, |1>->|2>, |2>->|0>.
program += make_instr(OP_INIT, target=10, op1=1)
program += make_instr(OP_SHIFT, target=10) # |1>
program += make_instr(OP_SHIFT, target=10) # |2>
program += make_instr(OP_PRINT, target=10) # Verify Future is |2>

# 2. Initialize Present (Chunk 0) to Empty State |0>
program += make_instr(OP_INIT, target=0, op1=1)

# 3. TIME TRAVEL: Pull Future to Present
# Swap Chunk 0 and Chunk 10 vectors.
program += make_instr(OP_CHUNK_SWAP, target=0, op1=10)

# 4. Modify Future (in Present)
# Chunk 0 now holds the data of Chunk 10 (|2>).
# Present measures it |2>, decides to change it to |0>.
# Apply Shift once: |2> -> |0>.
program += make_instr(OP_SHIFT, target=0)
program += make_instr(OP_PRINT, target=0) # Verify it is |0>

# 5. TIME TRAVEL: Return to Future
# Swap Chunk 0 and Chunk 10 back.
program += make_instr(OP_CHUNK_SWAP, target=0, op1=10)

# 6. Verify Future
# Measure Chunk 10. Should be |0> (modified).
# Originally it was |2>.
program += make_instr(OP_PRINT, target=10)
program += make_instr(OP_MEASURE, target=10) # Result 0

program += make_instr(OP_HALT)

with open('time_travel.qbin', 'wb') as f:
    f.write(program)

print("Created time_travel.qbin")
