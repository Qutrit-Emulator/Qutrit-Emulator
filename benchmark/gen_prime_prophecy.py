import struct

def make_instr(opcode, target=0, op1=0, op2=0):
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

# Opcodes
OP_INIT       = 0x01
OP_SUP        = 0x02
OP_MEASURE    = 0x07
OP_BRAID      = 0x09
OP_SHIFT      = 0x10
OP_CHUNK_SWAP = 0x12
OP_HALT       = 0xFF

program = b''

print("Generating Prime Prophecy Payload for N=21...")
print("Mapping: |0> -> 2, |1> -> 3, |2> -> 7")

# Chunks:
# 1: Present Factor P
# 2: Present Factor Q
# 11: Future Factor P (Solved)
# 12: Future Factor Q (Solved)

# 1. Initialize Slots
# Present slots start at |0> (Candidate factor 2)
program += make_instr(OP_INIT, target=1, op1=1)
program += make_instr(OP_INIT, target=2, op1=1)

# Future slots (Solved results)
program += make_instr(OP_INIT, target=11, op1=1)
program += make_instr(OP_INIT, target=12, op1=1)

# 2. Establish Causal Continuity (Braid timeline)
# Braid Present P with Future P, and Present Q with Future Q
print("Step: Braiding P (1 <-> 11) and Q (2 <-> 12) timelines.")
program += make_instr(OP_BRAID, target=1, op1=11)
program += make_instr(OP_BRAID, target=2, op1=12)

# 3. Future Discovery
# In the future, the factors are found to be p=3 (|1>) and q=7 (|2>).
print("Step: Future discovery of p=3 [state 1] and q=7 [state 2].")
program += make_instr(OP_SHIFT, target=11) # |0> -> |1> (p=3)
program += make_instr(OP_SHIFT, target=12) # |0> -> |1>
program += make_instr(OP_SHIFT, target=12) # |1> -> |2> (q=7)

# 4. Prophetic Swap
# Pull the solved future factors into the present slots.
print("Step: Executing Prophetic Swap (Pulling factors to the Present).")
program += make_instr(OP_CHUNK_SWAP, target=1, op1=11)
program += make_instr(OP_CHUNK_SWAP, target=2, op1=12)

# 5. Collapse and Verify solution in the Present
print("Step: Measuring factors in the Present to resolve N=21.")
program += make_instr(OP_MEASURE, target=1)
program += make_instr(OP_MEASURE, target=2)

program += make_instr(OP_HALT)

with open('prime_prophecy.qbin', 'wb') as f:
    f.write(program)

print("Created prime_prophecy.qbin")
