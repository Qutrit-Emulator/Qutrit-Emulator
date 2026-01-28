
import struct
import math

OP_INIT       = 0x01
OP_IM_WEIGHTS = 0x1A
OP_ORACLE     = 0x0B
OP_STORE_LO   = 0x17
OP_STORE_HI   = 0x18
OP_HALT       = 0xFF

ID_BRAIN_DUMP = 0x20

def make_instr(opcode, target=0, op1=0, op2=0):
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

# 1 Chunk = 10 Qutrits = 59,049 states
# User wants 4096 Chunks = 4096 * 59049 = 241,864,704 states ~ 240M lines.
num_qutrits = 10
states_per_chunk = 3**10
total_chunks = 4096 # Configurable limit

print(f"Generating Chunked Brain Pull:")
print(f"  Chunk Size: {states_per_chunk} (10 Qutrits)")
print(f"  Total Chunks: {total_chunks}")
print(f"  Total Neurons: {total_chunks * states_per_chunk}")

program = b''
program += make_instr(OP_INIT, target=0, op1=num_qutrits)
program += make_instr(OP_IM_WEIGHTS)

# Loop Chunks
for i in range(total_chunks):
    offset = i * states_per_chunk
    
    # Store Offset in measured_values[1] (Offset 8 bytes)
    # Target 1.
    program += make_instr(OP_STORE_LO, target=1, op1=offset & 0xFFFF, op2=(offset >> 16) & 0xFFFF)
    program += make_instr(OP_STORE_HI, target=1, op1=(offset >> 32) & 0xFFFF, op2=(offset >> 48) & 0xFFFF)
    
    # Dump Chunk (Uses Offset)
    program += make_instr(OP_ORACLE, target=0, op1=ID_BRAIN_DUMP)

program += make_instr(OP_HALT)

out_file = 'brain_chunked.qbin'
with open(out_file, 'wb') as f:
    f.write(program)
print(f"Created {out_file}. Run with: ./qutrit_engine {out_file} > full_brain.dump")
