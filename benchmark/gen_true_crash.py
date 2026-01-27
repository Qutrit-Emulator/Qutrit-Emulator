import struct
import random

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
OP_SUMMARY  = 0x0F
OP_HALT     = 0xFF

program = b''
MAX_CHUNKS = 4096
MAX_LINKS = 4096 # Hard limit in ASM is 4096 links total?
# Let's check the code: %define MAX_BRAID_LINKS 4096
# If I try to add more, it might fail or overwrite.
# So I can't do TRUE all-to-all (N*(N-1)/2 links).
# I can do Random 4096 links.
# This creates a "Small World" network or random graph. 
# It will have cycles and highly connected components.

print(f"Generating True Crash Payload: {MAX_CHUNKS} Chunks with Random Topology...")

# 1. Initialize
for i in range(MAX_CHUNKS):
    program += make_instr(OP_INIT, target=i, op1=10)

# 2. Superposition everywhere? 
# Let's put superposition on Chunk 0 and see if it spreads.
program += make_instr(OP_SUP, target=0)

# 3. RANDOM CHAOS TOPOLOGY
# Add 4000 random links.
active_links = 0
while active_links < 4000:
    a = random.randint(0, MAX_CHUNKS-1)
    b = random.randint(0, MAX_CHUNKS-1)
    if a != b:
        program += make_instr(OP_BRAID, target=a, op1=b)
        active_links += 1

print(f"Injected {active_links} random braid links.")

# 4. MEASURE -> COLLAPSE
# This should traverse the random graph.
# Since I implemented `visited_chunks` check, it SHOULD handle cycles safely.
# If it crashes, it's due to recursion depth (stack overflow).
# 4000 recursion depth might blow the stack? 
# Default stack is usually 8MB. 4000 * frame_size.
# If frame is small, it passes.
program += make_instr(OP_MEASURE, target=0)

# 5. HALT
program += make_instr(OP_HALT)

with open('true_crash.qbin', 'wb') as f:
    f.write(program)

print("Created true_crash.qbin")
