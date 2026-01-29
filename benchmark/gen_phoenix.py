import struct

# Opcode constants from qutrit_engine_born_rule.asm
OP_INIT = 0x01
OP_SUP = 0x02
OP_PRINT_STATE = 0x0D
OP_BRAID = 0x09
OP_NULL = 0x14
OP_REPAIR = 0x11
OP_MEASURE = 0x07
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    """Packs a qutrit engine instruction into a 64-bit little-endian format."""
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_phoenix_test(filename):
    with open(filename, 'wb') as f:
        # 1. Initialize Chunks
        print("Initializing Chunk 0 (The Phoenix) and Chunk 1 (The Anchor)...")
        f.write(pack_instr(OP_INIT, target=0, op1=1))
        f.write(pack_instr(OP_INIT, target=1, op1=1))
        
        # 2. Encode the state in the Phoenix
        print("Superpositioning Chunk 0...")
        f.write(pack_instr(OP_SUP, target=0))
        
        # 3. Create the Topological Link (Persistent Anchor)
        print("Braiding Chunk 0 <-> Chunk 1...")
        f.write(pack_instr(OP_BRAID, target=0, op1=1))
        
        # 4. Verification: Print original state
        print("Original State of Phoenix (Chunk 0):")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        
        # 5. THE FADE: Physically destroy Chunk 0
        print("Executing OP_NULL on Chunk 0 (The Death)...")
        f.write(pack_instr(OP_NULL, target=0))
        
        # 6. Verification: Verify physical death
        print("Post-Fade State (Should be empty):")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        
        # 7. QUANTUM RESURRECTION: Re-weave from topological anchor
        print("Executing OP_REPAIR (The Resurrection)...")
        f.write(pack_instr(OP_REPAIR))
        
        # 8. Final Verification: Print restored state
        print("Restored State (Should be back to original):")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_MEASURE, target=0))
        
        # 9. Halt
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_phoenix_test('phoenix.qbin')
    print("phoenix.qbin generated successfully.")
