import struct

# Opcode constants
OP_INIT = 0x01
OP_SUP = 0x02
OP_BRAID = 0x09
OP_SHIFT = 0x10
OP_REPAIR = 0x11
OP_MEASURE = 0x07
OP_IF = 0x15
OP_NULL = 0x14
OP_PRINT_STATE = 0x0D
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_seed_test(filename):
    with open(filename, 'wb') as f:
        print("Initializing Resurrection Chain: 0-5...")
        for i in range(6):
            f.write(pack_instr(OP_INIT, target=i, op1=1))
            
        # Set all chunks to State |1> (Line)
        print("Encoding initial identity: All chunks set to |1>...")
        for i in range(6):
            f.write(pack_instr(OP_SHIFT, target=i))
            
        # Weave the chain: 0 <-> 1 <-> 2 <-> 3 <-> 4 <-> 5
        print("Braiding the chain 0 <-> 1 <-> 2 <-> 3 <-> 4 <-> 5...")
        for i in range(5):
            f.write(pack_instr(OP_BRAID, target=i, op1=i+1))
            
        # THE CATACLYSM: Null chunks 0-4. Only Chunk 5 survives as the Anchor.
        print("The Cataclysm: Physically zeroing Chunks 0, 1, 2, 3, 4...")
        for i in range(5):
            f.write(pack_instr(OP_NULL, target=i))
            
        # Verification of death
        print("Verifying void state in Chunk 0...")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        
        # THE SEED RESURRECTION: Call REPAIR once. 
        # With the recursive upgrade, this should grow the state from 5 -> 4 -> 3 -> 2 -> 1 -> 0.
        print("Executing THE SEED RESURRECTION (Recursive OP_REPAIR)...")
        f.write(pack_instr(OP_REPAIR))
        
        # Final Verification: Read the most distant chunk (0)
        print("Verification: Reading the resurrected tail (Chunk 0)...")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_MEASURE, target=0))
        
        # Verify middle of chain
        f.write(pack_instr(OP_PRINT_STATE, target=2))
        f.write(pack_instr(OP_MEASURE, target=2))
        
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_seed_test('seed.qbin')
    print("seed.qbin generated successfully.")
