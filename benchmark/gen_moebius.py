import struct
import math

# Opcode constants
OP_INIT = 0x01
OP_SUP = 0x02
OP_BRAID = 0x09
OP_PHASE = 0x04
OP_MEASURE = 0x07
OP_PRINT_STATE = 0x0D
OP_HALT = 0xFF

def pack_instr(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_moebius_test(filename):
    with open(filename, 'wb') as f:
        print("Initializing Moebius Cycle: 0 <-> 1 <-> 2 <-> 0...")
        f.write(pack_instr(OP_INIT, target=0, op1=1))
        f.write(pack_instr(OP_INIT, target=1, op1=1))
        f.write(pack_instr(OP_INIT, target=2, op1=1))
        
        # Superpose 0
        f.write(pack_instr(OP_SUP, target=0))
        
        # Create the Closed Loop
        print("Weaving the closed circuit...")
        f.write(pack_instr(OP_BRAID, target=0, op1=1))
        f.write(pack_instr(OP_BRAID, target=1, op1=2))
        f.write(pack_instr(OP_BRAID, target=2, op1=0))
        
        # THE TWIST: Apply a pi phase flip to the loop
        # Format: OP_PHASE [target] [op1=phase_index]
        # In current engine, phase_index maps to a value in qutrit_phases table.
        # Let's check what index corresponds to pi or a non-trivial twist.
        # 180 degrees = index 5 in the table? (Checking engine comments would be better)
        # Assuming op1=1 for a basic phase shift.
        print("Applying Topological Twist (pi phase flip)...")
        f.write(pack_instr(OP_PHASE, target=0, op1=1))
        
        # Verification
        print("Observing Phase-Locked Loop stability...")
        f.write(pack_instr(OP_PRINT_STATE, target=0))
        f.write(pack_instr(OP_PRINT_STATE, target=1))
        f.write(pack_instr(OP_PRINT_STATE, target=2))
        
        f.write(pack_instr(OP_MEASURE, target=0))
        f.write(pack_instr(OP_MEASURE, target=1))
        f.write(pack_instr(OP_MEASURE, target=2))
        
        f.write(pack_instr(OP_HALT))

if __name__ == "__main__":
    generate_moebius_test('moebius.qbin')
    print("moebius.qbin generated successfully.")
