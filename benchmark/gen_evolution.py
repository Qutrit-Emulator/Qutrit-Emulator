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

def generate_evolution_test(filename):
    with open(filename, 'wb') as f:
        # 1. Setup
        print("Initializing Evolutionary Node (0) and Anchor (1)...")
        f.write(pack_instr(OP_INIT, target=0, op1=1))
        f.write(pack_instr(OP_INIT, target=1, op1=1))
        
        # 2. Superposition
        f.write(pack_instr(OP_SUP, target=0))
        
        # 3. Anchor connection
        f.write(pack_instr(OP_BRAID, target=0, op1=1))
        
        # 4. Measure 0 - We want |2> (Square).
        # We will iterate 3 times to "force" the evolution.
        for i in range(3):
            print(f"Evolution Pass {i+1}...")
            f.write(pack_instr(OP_MEASURE, target=0))
            f.write(pack_instr(OP_PRINT_STATE, target=0))
            
            # IF State == 0 (Triangle) -> NULL (Evolutionary failure)
            f.write(pack_instr(OP_IF, target=0, op1=0))
            f.write(pack_instr(OP_NULL, target=0))
            
            # IF State == 1 (Line) -> NULL (Evolutionary failure)
            f.write(pack_instr(OP_IF, target=0, op1=1))
            f.write(pack_instr(OP_NULL, target=0))
            
            # REPAIR (Resurrection from Anchor which preserves the entangled identity)
            f.write(pack_instr(OP_REPAIR))
            
        print("Final result after evolutionary pruning:")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_MEASURE, target=0))
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_evolution_test('evolution.qbin')
    print("evolution.qbin generated successfully.")
