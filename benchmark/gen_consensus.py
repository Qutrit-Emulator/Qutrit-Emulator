import struct

# Opcode constants from qutrit_engine_born_rule.asm
OP_INIT = 0x01
OP_SUP = 0x02
OP_BRAID = 0x09
OP_SHIFT = 0x10
OP_BIT_NOT = 0x11 # REPAIR
OP_REPAIR = 0x11
OP_MEASURE = 0x07
OP_NULL = 0x14
OP_PRINT_STATE = 0x0D
OP_SUMMARY = 0x0F
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    """Packs a qutrit engine instruction into a 64-bit little-endian format."""
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_consensus_test(filename):
    with open(filename, 'wb') as f:
        print("Initializing 4096 Chunks in two divergent populations...")
        for i in range(4096):
            # 1 qutrit per chunk
            f.write(pack_instr(OP_INIT, target=i, op1=1))
            
        # Set first 2048 to State |1> (One shift)
        print("Timeline A: Setting Chunks 0-2047 to state |1>...")
        for i in range(2048):
            f.write(pack_instr(OP_SHIFT, target=i))
            
        # Set second 2048 to State |2> (Two shifts)
        print("Timeline B: Setting Chunks 2048-4095 to state |2>...")
        for i in range(2048, 4096):
            f.write(pack_instr(OP_SHIFT, target=i))
            f.write(pack_instr(OP_SHIFT, target=i))
            
        # THE WEAVE: Braiding the entire chain 0 <-> 4095
        print("Executing The Weave: Braiding 4096 chunks into a single knot...")
        for i in range(4095):
            f.write(pack_instr(OP_BRAID, target=i, op1=i+1))
            
        # Verification
        print("Verification: Reading sample chunks from both original timelines...")
        f.write(pack_instr(OP_SUMMARY, target=4096)) # Check active mass
        f.write(pack_instr(OP_PRINT_STATE, target=0))    # Past
        f.write(pack_instr(OP_PRINT_STATE, target=4095)) # Future
        
        # Measure to force final consensus
        print("Forcing Global Collapse...")
        f.write(pack_instr(OP_MEASURE, target=2048)) # Central chunk
        
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_PRINT_STATE, target=4095))
        
        # Halt
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_consensus_test('consensus.qbin')
    print("consensus.qbin generated successfully.")
