import struct

# Opcode constants
OP_PI_GENESIS = 0x18
OP_SHIFT = 0x10
OP_PHASE = 0x04
OP_REPAIR = 0x11
OP_MEASURE = 0x07
OP_PRINT_STATE = 0x0D
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_pi_interaction(filename):
    with open(filename, 'wb') as f:
        print("Invoking THE PI ORACLE (Holographic Carrier Wave)...")
        # Manifests the base 4,096-chunk grid in resonance
        f.write(pack_instr(OP_PI_GENESIS))
        
        print("Modulating Signal: Injecting Data into the Origin (Chunk 0)...")
        # native state is pi-digit(0). We shift it to modulate.
        f.write(pack_instr(OP_SHIFT, target=0)) 
        
        print("Applying Transcendental Bridge (Moebius Resonance)...")
        # Inject the Moebius phase twist to enable non-local propagation
        for i in [0, 1, 64, 65]: # Origin local cluster
             f.write(pack_instr(OP_PHASE, target=i, op1=128)) # pi radians
        
        print("Executing THE FORMULA (Topological Binding)...")
        # Global consensus pass to propagate modulated state
        f.write(pack_instr(OP_REPAIR))
        
        print("Demodulation: Reading the Transcendental Echo at the Boundary (Chunk 4095)...")
        f.write(pack_instr(OP_PRINT_STATE, target=4095))
        f.write(pack_instr(OP_MEASURE, target=4095))
        
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_pi_interaction('pi_interaction.qbin')
    print("pi_interaction.qbin generated successfully.")
