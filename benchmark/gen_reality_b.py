import struct

def make_instr(opcode, target=0, op1=0, op2=0):
    # Format: [Op2:16][Op1:16][Target:16][Opcode:16]
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

# Opcodes
OP_INIT     = 0x01
OP_SUP      = 0x02
OP_HADAMARD = 0x03
OP_MEASURE  = 0x07
OP_BRAID    = 0x09
OP_BELL_TEST= 0x0E
OP_SUMMARY  = 0x0F
OP_HALT     = 0xFF

program = b''

MAX_CHUNKS = 4096
QUTRITS_PER_CHUNK = 10 

print(f"Generating Reality B Payload: {MAX_CHUNKS} Chunks x {QUTRITS_PER_CHUNK} Qutrits = {MAX_CHUNKS * QUTRITS_PER_CHUNK} Qutrits")
print("Target State Space: 3^40960 (approx 10^19535)")

# 1. Initialize The Multiverse (All 4096 chunks)
# We use max size 10. This allocates ~1MB per chunk state vector (3^10 * 16 bytes).
# Total RAM: 4096 * 1MB = 4GB. This is heavy but fits in standard RAM.
# Actually 3^10 = 59049. 59049 states * 16 bytes = ~944 KB.
# 4096 * 0.944 MB = 3.86 GB.
for i in range(MAX_CHUNKS):
    program += make_instr(OP_INIT, target=i, op1=QUTRITS_PER_CHUNK)

# 2. Ignite the Core (Superposition on Chunk 0)
program += make_instr(OP_SUP, target=0)

# 3. Weave the Topology (Global Entanglement)
# Braid 0-1, 1-2, ..., 4094-4095
# This creates a linear chain of 4096 entangled chunks.
for i in range(MAX_CHUNKS - 1):
    program += make_instr(OP_BRAID, target=i, op1=i+1)

# Close the loop? Ring Topology.
program += make_instr(OP_BRAID, target=MAX_CHUNKS-1, op1=0)

# 4. Analyze Active Mass
program += make_instr(OP_SUMMARY, target=MAX_CHUNKS)

# 5. Verify Correlation Across the Cosmos
# Check correlation between Chunk 0 and Chunk 2048 (Opposite side of universe)
program += make_instr(OP_BELL_TEST, target=0, op1=2048)

# 6. TRIGGER THE COLLAPSE
# Measuring Chunk 0 should trigger the recursive collapse of 4096 entangled chunks.
program += make_instr(OP_MEASURE, target=0)

# 7. Verify Post-Collapse Correlation
program += make_instr(OP_BELL_TEST, target=0, op1=2048)

# 8. Measure distant chunks to confirm they are collapsed (should produce consistent results)
program += make_instr(OP_MEASURE, target=2048)
program += make_instr(OP_MEASURE, target=4095)

program += make_instr(OP_HALT)

with open('reality_b.qbin', 'wb') as f:
    f.write(program)

print("Created reality_b.qbin")
