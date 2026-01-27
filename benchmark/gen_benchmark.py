import struct

def make_instr(opcode, target=0, op1=0, op2=0):
    # Format: [Op2:16][Op1:16][Target:16][Opcode:16]
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
OP_HALT     = 0xFF

# Custom Oracle Opcodes (from custom_oracles.asm)
ORACLE_MARK = 0x82 # Grover Mark
ORACLE_Z    = 0x83
ORACLE_X01  = 0x84

program = b''

# ==============================================================================
# TEST 1: SUPERPOSITION & INTERFERENCE
# ==============================================================================
# Goal: Create superposition, apply phase, reverse superposition (Hadamarddagger)
# to see interference.
# ------------------------------------------------------------------------------
# Chunk 0: Interference Test
program += make_instr(OP_INIT, target=0, op1=1) # 1 qutrit
program += make_instr(OP_SUP, target=0)         # Create Superposition: |+>
program += make_instr(OP_PRINT, target=0)       # Show state (should be uniform)

# Apply Phase (Z-rotation via custom oracle or built-in)
# Let's use custom Z-gate which adds phase to |1> and |2>
program += make_instr(ORACLE_Z, target=0) 

# Apply Hadamard (which is its own inverse for qutrits? No, H^4=I usually or H^dag. 
# Our apply_hadamard implements standard DFT matrix.
# DFT * Z * DFT might probably not return to |0> directly but let's see change.
program += make_instr(OP_HADAMARD, target=0, op1=0) 
program += make_instr(OP_PRINT, target=0)       # Show interference result

# ==============================================================================
# TEST 2: ENTANGLEMENT & PROPAGATION
# ==============================================================================
# Goal: Braid two chunks, measure one, verify collapse in other.
# ------------------------------------------------------------------------------
program += make_instr(OP_INIT, target=1, op1=1)
program += make_instr(OP_INIT, target=2, op1=1)
program += make_instr(OP_SUP, target=1)
program += make_instr(OP_BRAID, target=1, op1=2) # Entangle 1 & 2
program += make_instr(OP_BELL, target=1, op1=2)  # Verify Entanglement

# Measure Chunk 1 -> Should collapse Chunk 2
program += make_instr(OP_MEASURE, target=1)
program += make_instr(OP_PRINT, target=2)        # Check Chunk 2 state (should be collapsed)
program += make_instr(OP_BELL, target=1, op1=2)  # Correlation check (should be 100%)

# ==============================================================================
# TEST 3: QUTRIT LOGIC (SWAP)
# ==============================================================================
# Goal: Initialize different states and swap them.
# ------------------------------------------------------------------------------
program += make_instr(OP_INIT, target=3, op1=1)
program += make_instr(OP_INIT, target=4, op1=1)

# Set Chunk 3 to |0> (default)
# Set Chunk 4 to |0>, then flip to |1> using X01 Swap Custom Oracle
program += make_instr(ORACLE_X01, target=4) # Now 4 should be |1> (if started at |0>)
# Wait, X01 swap swaps amps of |0> and |1>.
# Since init is |0>=1.0, |1>=0.0 -> X01 -> |0>=0.0, |1>=1.0. Correct.

program += make_instr(OP_PRINT, target=3)
program += make_instr(OP_PRINT, target=4)

# Now Swap Chunk 3 and Chunk 4?
# OP_SWAP exchanges *qutrits within a chunk*.
# To swap *chunks*, we don't have a direct opcode, but we can braid/unbraid logic.
# Let's test Intra-Chunk Swap.
program += make_instr(OP_INIT, target=5, op1=2) # 2 qutrits
# State |10> (qutrit0=0, qutrit1=1)
# Apply X01 to qutrit 1? Custom oracle applies to whole chunk logic usually.
# Let's just use built-in SWAP on index 0 and 1.
# Initial |00>. 
# We need to set one qutrit to different state. 
# Let's use Hadamard on qutrit 0.
program += make_instr(OP_HADAMARD, target=5, op1=0) 
program += make_instr(OP_PRINT, target=5)
program += make_instr(OP_SWAP, target=5, op1=0, op2=1) # Swap q0 and q1
program += make_instr(OP_PRINT, target=5)

# ==============================================================================
# TEST 4: GROVER'S SEARCH ALGORITHM
# ==============================================================================
# Goal: Find Marked State |2> in a single qutrit search space.
# ------------------------------------------------------------------------------
program += make_instr(OP_INIT, target=6, op1=1)
program += make_instr(OP_SUP, target=6) # Superposition

# Mark State |2> (using custom oracle 0x82)
# Opcode 0x82 takes 'operand1' as the target state to mark.
# We want to mark state index 2 (|2>).
program += make_instr(ORACLE_MARK, target=6, op1=2) 

# Apply Diffusion
program += make_instr(OP_GROVER, target=6)

# Measure - should be |2> with high probability
program += make_instr(OP_PRINT, target=6)
program += make_instr(OP_MEASURE, target=6) # Result should be 2

# ==============================================================================
# FINISH
# ==============================================================================
program += make_instr(OP_HALT)

with open('benchmark.qbin', 'wb') as f:
    f.write(program)

print("Created benchmark.qbin")
