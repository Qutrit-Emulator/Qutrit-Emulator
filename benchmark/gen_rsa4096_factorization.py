import struct

def make_instr(opcode, target=0, op1=0, op2=0):
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

# Opcodes
OP_HALT             = 0xFF
OP_DUMP_HEX         = 0x16
OP_IMPORT_WEIGHTS   = 0x1A
OP_ORACLE           = 0x0B

ORACLE_UNIVERSAL_ID = 0x08

program = b''

print("Generating RSA-4096 Factorization Payload (Universal + Oracle)...")

# 1. Import Universal Weights (The Potentia)
# This sets the quantum state to the highly entangled universal form.
print("Step 1: Importing Universal Weights (Potentia State)...")
program += make_instr(OP_IMPORT_WEIGHTS)

# 1b. Initialize a chunk so state_vector is not NULL (required for call_addon)
OP_INIT = 0x01
program += make_instr(OP_INIT, target=100, op1=1)

# 2. Apply Universal Oracle
# This interacts the Universal State with the Context (Key File).
# The oracle reads the key and "collapses" the factors into measured_values.
# NOTE: Target must be an initialized chunk for call_addon to invoke the oracle.
print("Step 2: Invoking Universal Oracle (Contextual Collapse)...")
# OP_ORACLE takes operand1 as the ID. Target=100 to ensure state_vector exists.
program += make_instr(OP_ORACLE, target=100, op1=ORACLE_UNIVERSAL_ID)

# 3. Dump Factors
# The factors P and Q are now stored in the measurement registers.
print("Step 3: Dumping Revealed Factors...")
print("  Dumping P (LIMBS 100-163)")
program += make_instr(OP_DUMP_HEX, target=0, op1=100, op2=64)
print("  Dumping Q (LIMBS 200-263)")
program += make_instr(OP_DUMP_HEX, target=0, op1=200, op2=64)

program += make_instr(OP_HALT)

output_file = 'rsa4096_factorization.qbin'
with open(output_file, 'wb') as f:
    f.write(program)

print(f"Created {output_file}")
