import struct

# Opcode constants
OP_GENESIS = 0x16
OP_MEASURE = 0x07
OP_PRINT_STATE = 0x0D
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_genesis_test(filename, seed):
    with open(filename, 'wb') as f:
        # OP_GENESIS [unused] [seed] [unused]
        f.write(pack_instr(OP_GENESIS, target=0, op1=seed))
        
        # Verify result at different points in the manifold
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_PRINT_STATE, target=2048))
        f.write(pack_instr(OP_PRINT_STATE, target=4095))
        
        f.write(pack_instr(OP_MEASURE, target=0))
        f.write(pack_instr(OP_MEASURE, target=2048))
        f.write(pack_instr(OP_MEASURE, target=4095))
        
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_genesis_test('genesis_omega.qbin', 777)
    print("genesis_omega.qbin generated (Seed 777).")
    generate_genesis_test('genesis_alpha.qbin', 101)
    print("genesis_alpha.qbin generated (Seed 101).")
