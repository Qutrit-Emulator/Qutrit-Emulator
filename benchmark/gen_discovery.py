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

def generate_discovery_test(filename):
    with open(filename, 'wb') as f:
        print("Initializing Causal Pair: Question (0) and Answer (3000)...")
        f.write(pack_instr(OP_INIT, target=0, op1=1))
        f.write(pack_instr(OP_INIT, target=3000, op1=1))
        
        # Superpose the future
        f.write(pack_instr(OP_SUP, target=3000))
        
        # Establish the Braid
        print("Linking Question to Answer...")
        f.write(pack_instr(OP_BRAID, target=0, op1=3000))
        
        # Complex intervention on 3000
        print("Future event: Performing complex transformation on Answer...")
        f.write(pack_instr(OP_SHIFT, target=3000))
        
        # INSTANT DISCOVERY: Measure the Past to see the Future's state
        print("Instant Discovery: Measuring Question (0) to resolve Answer (3000)...")
        f.write(pack_instr(OP_MEASURE, target=0))
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        
        # Verify the Future
        print("Verifying Answer (3000) matches the discovery...")
        f.write(pack_instr(OP_PRINT_STATE, target=3000))
        f.write(pack_instr(OP_MEASURE, target=3000))
        
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_discovery_test('discovery.qbin')
    print("discovery.qbin generated successfully.")
