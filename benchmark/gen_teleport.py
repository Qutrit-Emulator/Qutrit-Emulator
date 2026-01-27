import struct

def make_instr(opcode, target=0, op1=0, op2=0):
    # Format: [Op2:16][Op1:16][Target:16][Opcode:16]
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

# Opcodes
OP_INIT     = 0x01
OP_SUP      = 0x02 # (Not used here, using Hadamard directly)
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
OP_IF       = 0x15 # New Conditional
OP_HALT     = 0xFF

# Custom oracles
ORACLE_MARK = 0x82
ORACLE_Z    = 0x83
ORACLE_X01  = 0x84
ORACLE_SUM  = 0x85 # CNOT: Control=Op1(rdx), Target=Op2(rcx)? No, check call_addon logic.
# call_addon: opcode=rbx, chunk=r14, operand1=rbx?? No.
# execute_instruction:
#   r14 = Target
#   rbx = Op1
#   rcx = Op2
# .op_addon: rdi=opcode, rsi=target, rdx=op1, rcx=op2
# sum_gate inputs: rdi=vec, rsi=n, rdx=control, rcx=target
# So: Opcode=0x85, Target=(ignored/chunk?), Op1=Control, Op2=Target
# Wait, addon takes `rsi=target` (Chunk Index), `rdx=Op1`, `rcx=Op2`.
# `sum_gate` uses `rdx` as Control, `rcx` as Target.
# But `sum_gate` is defined as iterating over ONE state vector?
# Yes, `sum_gate` operates on a single chunk (virtual qutrits).
# BUT I want entanglement across *chunks*.
# Teleportation usually entangles spatially separated qubits.
# My `sum_gate` is INTRA-chunk.
# `OP_BRAID` is INTER-chunk.
# Problem: I need CNOT across chunks for Teleportation.
# `OP_BRAID` creates a specific entangled state but not the standard Bell State via CNOT.
#
# Workaround:
# I can simulate teleportation *within* a larger chunk (e.g. 3 qutrits in Chunk 0).
# Let's do that. Teleportation between Qutrit 0 and Qutrit 2 in Chunk 0.
# Qutrit 1 is the ancilla (Bell pair with 2).
#
# Chunk 0 size = 3 qutrits.
# q0: Alice's state |psi>
# q1: Alice's half of Bell pair
# q2: Bob's half of Bell pair

program = b''

# 1. Initialize Chunk 0 with 3 qutrits
program += make_instr(OP_INIT, target=0, op1=3)

# 2. Prepare |psi> on q0. Let's make it |+> = H|0>
program += make_instr(OP_HADAMARD, target=0, op1=0)
# Debug: Print state
program += make_instr(OP_PRINT, target=0)

# 3. Prepare Bell Pair on q1, q2
# |00> -> H on q1 -> |+0> -> CNOT(1->2) -> |00>+|11>+|22>
program += make_instr(OP_HADAMARD, target=0, op1=1)
# CNOT(Control=1, Target=2). Op1=1, Op2=2.
# Target=0 (Chunk Index). Opcode=ORACLE_SUM (0x85)
# BUT call_addon passes: rsi=Chunk, rdx=Op1, rcx=Op2.
# sum_gate expects: rdx=Control, rcx=Target.
# So: Target=Chunk0, Op1=1, Op2=2.
program += make_instr(ORACLE_SUM, target=0, op1=1, op2=2)

# 4. Teleportation Step 1: Alice CNOT(0->1) (inverse sum)
# To do inverse CNOT(0->1), apply CNOT(0->1) twice.
program += make_instr(ORACLE_SUM, target=0, op1=0, op2=1)
program += make_instr(ORACLE_SUM, target=0, op1=0, op2=1)

# 5. Teleportation Step 2: Alice Hadamard on q0
program += make_instr(OP_HADAMARD, target=0, op1=0)

# 6. Measurement
# To measure specific qutrits, we need a "Measure Qutrit" opcode.
# `OP_MEASURE` measures the *entire* chunk and collapses it to a single basis state.
# This destroys the superposition on Bob's end if they are in the same chunk!
#
# CRITICAL ISSUE:
# Functional limitation: `OP_MEASURE` collapses the entire chunk.
# To do Teleportation, I need to measure q0 and q1 while leaving q2 uncollapsed (but projected).
#
# Can I "spill" q2 to another chunk? `OP_BRAID` links chunks.
# If I use `OP_BRAID` to entangle Chunk 1 and Chunk 2...
# `OP_BRAID` does controlled-phase entanglement.
# Teleportation works with CPHASE too (Cluster State Teleportation).
# Protocol: 
# 1. |+>_A, |+>_B. 
# 2. CPHASE(A, B).
# 3. Measure A in X-basis ($M_x$).
# 4. B acts as Z^{M_x} X B (something like that).
#
# Let's try Cluster State Teleportation (One-bit teleportation).
# 1. Init Chunk 0 (Alice) in |+>.
# 2. Init Chunk 1 (Bob) in |+>.
# 3. Braid (Entangle CZ).
# 4. Measure Chunk 0 (Alice) in X-basis.
#    - To measure in X-basis, apply H dagger (or H), then Measure Z (standard).
#    - H inverse for qutrits... H*H != I. H^4 = I.
#    - Let's apply H three times? Or just H once if we define measurement basis appropriately.
#    - If we Measure Chunk 0 -> gets result m.
#    - Bob's state is projected.
#
# This is cleaner because we have separate chunks.
#
# Protocol: Qutrit Cluster Teleportation
# |psi>_0 = alpha|0> + beta|1> + gamma|2>
# |+>_1 = H|0>
# CZ(0,1) via BRAID.
# Measure 0 in X-basis: Apply H^-1 (or H^3), then Measure.
# Result 'm'.
# Bob's state becomes X^m Z^k |psi> ... correction is needed.
#
# Implementation Plan:
# 1. Chunk 0: |psi> = H|0> (State |+>).
# 2. Chunk 1: |+> = H|0>. (Using H opcode).
# 3. Entangle 0 & 1 (BRAID).
# 4. Rotate 0 to measure basis: H on 0. (Actually H on |+> goes to |0>).
# 5. Measure 0. Should be 0.
# 6. Bob (1) should be |+> (or related).
#
# Let's test a simpler verification:
# "Logic Control Test":
# 1. Init Chunk 0.
# 2. H on 0 -> Measure.
# 3. IF result == 0 -> Apply X to Chunk 1.
# 4. IF result == 1 -> Apply Z to Chunk 1.
# 5. Verify Chunk 1 changed conditionally.
#
# This proves `OP_IF` works, which is the missing key for Teleportation.

program = b''
# Test OP_IF logic
# Chunk 0: Deterministic |1>
program += make_instr(OP_INIT, target=0, op1=1)
# Apply X01 to flip |0> -> |1>
program += make_instr(ORACLE_X01, target=0)
program += make_instr(OP_MEASURE, target=0) # Should be 1

# Chunk 1: Target
program += make_instr(OP_INIT, target=1, op1=1)

# Logic:
# If Meas(0)==0: Do nothing
# If Meas(0)==1: Apply X01 Swap (Chunk 1 becomes |1>) -> THIS SHOULD TRIGGER
# If Meas(0)==2: Apply X01 Swap (Chunk 1 becomes |1>)

# If Meas(0) == 1 (Op2=1)
program += make_instr(OP_IF, target=0, op1=0, op2=1) 
# Next instr: X01 on Chunk 1
program += make_instr(ORACLE_X01, target=1)

# If Meas(0) == 2 (Op2=2)
program += make_instr(OP_IF, target=0, op1=0, op2=2)
# Next instr: X01 on Chunk 1 (just to show action)
program += make_instr(ORACLE_X01, target=1)

program += make_instr(OP_PRINT, target=0)
program += make_instr(OP_PRINT, target=1)
program += make_instr(OP_HALT)

with open('teleport_test.qbin', 'wb') as f:
    f.write(program)

print("Created teleport_test.qbin")
