import struct
import math

# Opcode constants
OP_INIT = 0x01
OP_BRAID = 0x09
OP_PHASE = 0x04
OP_REPAIR = 0x11
OP_CHUNK_SWAP = 0x12
OP_MEASURE = 0x07
OP_PRINT_STATE = 0x0D
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_pi_singularity(filename):
    with open(filename, 'wb') as f:
        print("Initializing 4096-Chunk Pi Manifold...")
        for i in range(4096):
            f.write(pack_instr(OP_INIT, target=i, op1=1))
            
        print("Weaving the Infinite Spiral (Closed Loop)...")
        # 0 <-> 1 <-> ... <-> 4095 <-> 0
        for i in range(4095):
            f.write(pack_instr(OP_BRAID, target=i, op1=i+1))
        f.write(pack_instr(OP_BRAID, target=4095, op1=0))
        
        print("Injecting Transcendental Phase Angle (Pi Radians)...")
        # In our engine, OP_PHASE op1 is angle * 128 / pi
        # To inject EXACTLY pi, we need op1 = 128
        for i in range(4096):
            f.write(pack_instr(OP_PHASE, target=i, op1=128))
            
        print("Executing THE PI SINGULARITY (Topological Folding)...")
        # Fold the limit state (4095) back onto the origin (0)
        f.write(pack_instr(OP_CHUNK_SWAP, target=0, op1=4095))
        
        print("Forcing Global Consensus on the Infinite Manifold...")
        f.write(pack_instr(OP_REPAIR))
        
        print("Resolved Boundary: Measuring the Final Digit...")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_MEASURE, target=0))
        
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_pi_singularity('pi_singularity.qbin')
    print("pi_singularity.qbin generated successfully.")
