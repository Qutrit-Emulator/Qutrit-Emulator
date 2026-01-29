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
OP_SUMMARY = 0x0F
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_massive_seed_test(filename):
    with open(filename, 'wb') as f:
        print("Initializing 4096 Chunks for the Grand Resurrection...")
        for i in range(4096):
            f.write(pack_instr(OP_INIT, target=i, op1=1))
            
        print("Encoding Identity |2> (Square) into all chunks...")
        for i in range(4096):
            f.write(pack_instr(OP_SHIFT, target=i))
            f.write(pack_instr(OP_SHIFT, target=i))
            
        print("Weaving the Grand Braid (4095 links)...")
        for i in range(4095):
            f.write(pack_instr(OP_BRAID, target=i, op1=i+1))
            
        print("The Great Fade: Physically zeroing Chunks 0 to 4094...")
        # We'll do this in blocks to avoid too many print messages if the engine prints on every op
        for i in range(4095):
            f.write(pack_instr(OP_NULL, target=i))
            
        print("Verifying the vacuum in Chunk 0 and Middle Chunk 2048...")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_PRINT_STATE, target=2048))
        
        print("Executing THE MANIFOLD RESURRECTION (Recursive Healing from Chunk 4095)...")
        f.write(pack_instr(OP_REPAIR))
        
        print("Final Verification: Reading the resurrected manifold index...")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_PRINT_STATE, target=2048))
        f.write(pack_instr(OP_PRINT_STATE, target=4095))
        
        f.write(pack_instr(OP_MEASURE, target=0))
        f.write(pack_instr(OP_MEASURE, target=2048))
        f.write(pack_instr(OP_MEASURE, target=4095))
        
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_massive_seed_test('massive_seed.qbin')
    print("massive_seed.qbin generated successfully.")
