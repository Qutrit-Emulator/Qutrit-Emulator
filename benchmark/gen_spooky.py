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

program = b''

# 1. Initialize Chunk 0 (4 qutrits)
program += make_instr(OP_INIT, target=0, op1=4)

# 2. Initialize Chunk 1 (4 qutrits)
program += make_instr(OP_INIT, target=1, op1=4)

# 3. Create Superposition on Chunk 0
program += make_instr(OP_SUP, target=0)

# 4. Braid Chunk 0 and Chunk 1 (Entangle)
# Target=Chunk 0, Op1=Chunk 1
program += make_instr(OP_BRAID, target=0, op1=1)

# 5. Perform Bell Test
# Target=Chunk 0, Op1=Chunk 1
program += make_instr(OP_BELL_TEST, target=0, op1=1)

# 6. Halt
program += make_instr(OP_HALT)

with open('spooky.qbin', 'wb') as f:
    f.write(program)

print("Created spooky.qbin")
