import struct

# Opcode constants from qutrit_engine_born_rule.asm
OP_INIT = 0x01
OP_SUP = 0x02
OP_BRAID = 0x09
OP_SHIFT = 0x10
OP_BIT_NOT = 0x11 # Actually REPAIR in this engine if no operands
OP_REPAIR = 0x11
OP_MEASURE = 0x07
OP_NULL = 0x14
OP_PRINT_STATE = 0x0D
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    """Packs a qutrit engine instruction into a 64-bit little-endian format."""
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_teleport_test(filename):
    with open(filename, 'wb') as f:
        # 1. Initialize Chunks A(0), B(1), C(2)
        print("Initializing Chunks 0, 1, 2...")
        f.write(pack_instr(OP_INIT, target=0, op1=1))
        f.write(pack_instr(OP_INIT, target=1, op1=1))
        f.write(pack_instr(OP_INIT, target=2, op1=1))
        
        # 2. Assign Identity to A (Chunk 0)
        # Shift twice to get |2>
        print("Encoding State |2> in Chunk 0...")
        f.write(pack_instr(OP_SHIFT, target=0))
        f.write(pack_instr(OP_SHIFT, target=0))
        
        # 3. Create the Chain: A <-> B <-> C
        # A and C never touch directly
        print("Establishing chain 0 <-> 1 <-> 2...")
        f.write(pack_instr(OP_BRAID, target=0, op1=1))
        f.write(pack_instr(OP_BRAID, target=1, op1=2))
        
        # 4. Verification: Print original states
        print("Original States:")
        f.write(pack_instr(OP_PRINT_STATE, target=0)) # A (|2>)
        f.write(pack_instr(OP_PRINT_STATE, target=1)) # B (|2> due to braid)
        f.write(pack_instr(OP_PRINT_STATE, target=2)) # C (|2> due to braid)
        
        # 5. THE VOID: Kill the Intermediary (Chunk 1)
        print("Executing OP_NULL on Intermediary (Chunk 1)...")
        f.write(pack_instr(OP_NULL, target=1))
        
        # 6. RESURRECTION: Re-weave the identity of B from A
        print("Executing OP_REPAIR (Heals B from A)...")
        f.write(pack_instr(OP_REPAIR))
        
        # 7. VERIFICATION: Does B (and therefore C) now hold the identity?
        print("Final Verification: Reading Chunk 2 (C)...")
        f.write(pack_instr(OP_PRINT_STATE, target=2))
        f.write(pack_instr(OP_MEASURE, target=2))
        
        # 8. Halt
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_teleport_test('teleport.qbin')
    print("teleport.qbin generated successfully.")
