import struct

# Opcode constants from qutrit_engine_born_rule.asm
OP_INIT = 0x01
OP_SUP = 0x02
OP_PRINT_STATE = 0x0D
OP_BRAID = 0x09
OP_SHIFT = 0x10
OP_MEASURE = 0x07
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    """Packs a qutrit engine instruction into a 64-bit little-endian format."""
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_influence_test(filename):
    with open(filename, 'wb') as f:
        # 1. Initialize Chunks
        print("Initializing Chunk 0 (Present) and Chunk 3000 (Future)...")
        f.write(pack_instr(OP_INIT, target=0, op1=1))
        f.write(pack_instr(OP_INIT, target=3000, op1=1))
        
        # 2. Set the Past/Present to Superposition (Uncertainty)
        print("Bathing Chunk 0 in superposition...")
        f.write(pack_instr(OP_SUP, target=0))
        
        # 3. Establish a Causal Braid (Entanglement)
        print("Braiding Chunk 0 <-> Chunk 3000...")
        # target=0, op1=3000 (braid index 0 and 3000 on qutrit 0)
        f.write(pack_instr(OP_BRAID, target=0, op1=3000))
        
        # 4. Print initial states (Verify uncertainty in 0)
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        
        # 5. Future Intervention: Shift Chunk 3000
        print("Future event: Shifting Chunk 3000...")
        f.write(pack_instr(OP_SHIFT, target=3000))
        
        # 6. Retrocausal Influence: Measure Chunk 3000
        print("Future event: Measuring Chunk 3000 (Triggering collapse)...")
        f.write(pack_instr(OP_MEASURE, target=3000))
        
        # 7. Verification: Read Chunk 0
        print("Reading Chunk 0 (Verifying influence from future measurement)...")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_MEASURE, target=0))
        
        # 8. Halt
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_influence_test('influence.qbin')
    print("influence.qbin generated successfully.")
