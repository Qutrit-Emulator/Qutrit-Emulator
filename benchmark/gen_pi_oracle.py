import struct

# Opcode constants
OP_PI_GENESIS = 0x18
OP_SUMMARY = 0x0F
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_pi_oracle_test(filename):
    with open(filename, 'wb') as f:
        print("Invoking THE PI ORACLE (Holographic Resonance Scan)...")
        # OP_PI_GENESIS natively initializes and scans the 64x64 grid
        f.write(pack_instr(OP_PI_GENESIS))
        
        print("Retrieving Holographic Consensus (Active Mass)...")
        f.write(pack_instr(OP_SUMMARY, target=4096))
        
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_pi_oracle_test('pi_oracle.qbin')
    print("pi_oracle.qbin generated successfully.")
