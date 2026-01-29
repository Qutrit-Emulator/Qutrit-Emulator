import struct

# Opcode constants from qutrit_engine_born_rule.asm
OP_INIT = 0x01
OP_SUP = 0x02
OP_PRINT_STATE = 0x0D
OP_SHIFT = 0x10
OP_CHUNK_SWAP = 0x12
OP_MEASURE = 0x07
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    """Packs a qutrit engine instruction into a 64-bit little-endian format."""
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_retrocausal_test(filename):
    with open(filename, 'wb') as f:
        # 1. Initialize all 4096 chunks to establish the manifold
        # For efficiency, we just initialize chunk 3000 and chunk 0 specifically,
        # but the user asked for 4096 chunks.
        print(f"Generating initialization for 4096 chunks...")
        for i in range(4096):
            # i = chunk index, op1 = num_qutrits (1)
            f.write(pack_instr(OP_INIT, target=i, op1=1))
        
        # 2. Setup the "Future" state in chunk 3000
        # Put it in superposition, then shift it to ensure it's not the ground state
        f.write(pack_instr(OP_SUP, target=3000))
        f.write(pack_instr(OP_SHIFT, target=3000))
        
        # 3. Print the state of chunk 3000 before swap (for debug)
        f.write(pack_instr(OP_PRINT_STATE, target=3000))
        
        # 4. Perform the Retrocausal Pull: Swap Chunk 3000 with Chunk 0
        print("Adding OP_CHUNK_SWAP (3000 <-> 0)...")
        f.write(pack_instr(OP_CHUNK_SWAP, target=3000, op1=0))
        
        # 5. Read info from Chunk 0 (which now holds chunk 3000's state)
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_MEASURE, target=0))
        
        # 6. Halt
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_retrocausal_test('retrocausal.qbin')
    print("retrocausal.qbin generated successfully.")
