import struct
import subprocess
import os

OP_INIT             = 0x01
OP_SUP              = 0x02
OP_MEASURE          = 0x07
OP_PRINT_STATE      = 0x0D
OP_SIREN_SONG       = 0x72
OP_HALT             = 0xFF

def encode_inst(opcode, target=0, op1=0, op2=0):
    return (opcode & 0xFF) | \
           ((target & 0xFFFFFF) << 8) | \
           ((op1 & 0xFFFFFF) << 32) | \
           ((op2 & 0xFF) << 56)

def run_prophecy():
    # Indices
    candidate = 0
    proxy = 1
    future = 1000
    
    prog = []
    # 1. Setup: Present (0, 1) and Future (1000)
    prog.append(encode_inst(OP_INIT, target=candidate, op1=1))
    prog.append(encode_inst(OP_INIT, target=proxy, op1=1))
    prog.append(encode_inst(OP_INIT, target=future, op1=1))
    
    # 2. Preparation: All qutrits into superposition (Flux state)
    prog.append(encode_inst(OP_SUP, target=candidate))
    prog.append(encode_inst(OP_SUP, target=proxy))
    prog.append(encode_inst(OP_SUP, target=future))
    
    # 3. Entangle: establish the Global Ghost Network
    prog.append(encode_inst(OP_SIREN_SONG))
    
    # 4. Status Check: Verify they are all in flux
    print("Pre-measurement verification (Expect superposition)...")
    prog.append(encode_inst(OP_PRINT_STATE, target=candidate))
    prog.append(encode_inst(OP_PRINT_STATE, target=future))
    
    # 5. Measure Proxy: This triggers the "Prophecy"
    # Collapsing the proxy should propagate through the universal siren link
    # to both the candidate and the future address.
    print(f"\n[MEAS] Measuring Proxy index {proxy}...")
    prog.append(encode_inst(OP_MEASURE, target=proxy))
    
    # 6. Final Reveal: Check if the collapse reached the end of the manifold
    print("\nPost-measurement results (The Prophecy Manifested):")
    prog.append(encode_inst(OP_PRINT_STATE, target=candidate))
    prog.append(encode_inst(OP_PRINT_STATE, target=future))
    
    prog.append(encode_inst(OP_HALT))
    
    with open("siren_prophecy.qbin", "wb") as f:
        for inst in prog:
            f.write(struct.pack('<Q', inst))
            
    print("-" * 60)
    result = subprocess.run(["./qutrit_engine", "siren_prophecy.qbin"], capture_output=True, text=True)
    print(result.stdout)

if __name__ == "__main__":
    run_prophecy()
