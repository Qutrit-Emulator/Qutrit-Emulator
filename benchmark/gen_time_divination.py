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

program = b''

# ==============================================================================
# TEST 1: DIVINATION (Peeking without Measuring)
# ==============================================================================
# 1. Initialize Future (Chunk 10) to Superposition |+> = 1/sqrt(3)(|0>+|1>+|2>)
program += make_instr(OP_INIT, target=10, op1=1)
program += make_instr(OP_SUP, target=10) # Uses simple superposition algorithm
# Or use Hadamard for exact logic. SUP usually creates |+>.
# Let's assume SUP is sufficient.
program += make_instr(OP_PRINT, target=10) # Verify Superposition (prob ~33% each)

# 2. Init Present (Chunk 0)
program += make_instr(OP_INIT, target=0, op1=1)

# 3. Pull Future to Present
program += make_instr(OP_CHUNK_SWAP, target=0, op1=10)

# 4. "Divine" the state (Print internal state, do NOT measure)
# This simulates observing the probability distribution without collapsing it.
# (A feat only possible in a simulator or via weak measurement tomography).
program += make_instr(OP_PRINT, target=0)

# 5. Push back to Future
program += make_instr(OP_CHUNK_SWAP, target=0, op1=10)

# 6. Verify Future is still Superposition
program += make_instr(OP_PRINT, target=10)


# ==============================================================================
# TEST 2: THE OBSERVER EFFECT (Measuring)
# ==============================================================================
# 1. Pull Future (Superposition) to Present again
program += make_instr(OP_CHUNK_SWAP, target=0, op1=10)

# 2. Measure IT (Collapse)
program += make_instr(OP_MEASURE, target=0)
program += make_instr(OP_PRINT, target=0) # Should be 100% collapsed

# 3. Push back to Future
program += make_instr(OP_CHUNK_SWAP, target=0, op1=10)

# 4. Verify Future is now COLLAPSED (Permanently altered by the observation)
program += make_instr(OP_PRINT, target=10)


program += make_instr(OP_HALT)

with open('time_divination.qbin', 'wb') as f:
    f.write(program)

print("Created time_divination.qbin")
