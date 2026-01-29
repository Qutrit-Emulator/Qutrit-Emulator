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

def generate_ghost_test(filename):
    with open(filename, 'wb') as f:
        print("Initializing Steganographic Chunks 0, 1, 2, 3...")
        # 1 qutrit per chunk
        for i in range(4):
            f.write(pack_instr(OP_INIT, target=i, op1=1))
            
        # Set specific pattern: |1>, |2>, |1>, |2>
        print("Encoding 'Ghost' pattern: |1>, |2>, |1>, |2>...")
        f.write(pack_instr(OP_SHIFT, target=0))
        
        f.write(pack_instr(OP_SHIFT, target=1))
        f.write(pack_instr(OP_SHIFT, target=1))
        
        f.write(pack_instr(OP_SHIFT, target=2))
        
        f.write(pack_instr(OP_SHIFT, target=3))
        f.write(pack_instr(OP_SHIFT, target=3))
        
        # Weave them into a persistent topological web
        print("Braiding the web 0 <-> 1 <-> 2 <-> 3...")
        f.write(pack_instr(OP_BRAID, target=0, op1=1))
        f.write(pack_instr(OP_BRAID, target=1, op1=2))
        f.write(pack_instr(OP_BRAID, target=2, op1=3))
        
        # Verification of original
        print("Verifying original physical states...")
        for i in range(4):
            f.write(pack_instr(OP_PRINT_STATE, target=i))
            
        # THE FADE: Manually destroy ALL physical memory
        print("Executing THE FADE: Nulling all 4 chunks...")
        for i in range(4):
            f.write(pack_instr(OP_NULL, target=i))
            
        # Verification of physical death
        print("Verifying physical death (Should be empty)...")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        
        # RESURRECTION: Re-weave the entire manifold from the Ghost Registry
        print("Executing OP_REPAIR (Steganographic reconstruction)...")
        f.write(pack_instr(OP_REPAIR))
        
        # Final Verification: Does the pattern survive in the "ghost" register?
        print("Reading final reconstructed pattern...")
        for i in range(4):
            f.write(pack_instr(OP_PRINT_STATE, target=i))
            f.write(pack_instr(OP_MEASURE, target=i))
            
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_ghost_test('ghost.qbin')
    print("ghost.qbin generated successfully.")
