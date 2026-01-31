import struct
import subprocess
import os

# Opcodes
OP_INIT             = 0x01
OP_SUP              = 0x02
OP_BRAID            = 0x09
OP_MEASURE          = 0x07
OP_PRINT_STATE      = 0x0D
OP_GENESIS          = 0x16
OP_CHUNK_SWAP        = 0x12
OP_SIREN_SONG       = 0x72
OP_HALT             = 0xFF

def encode_inst(opcode, target=0, op1=0, op2=0):
    return (opcode & 0xFF) | \
           ((target & 0xFFFFFF) << 8) | \
           ((op1 & 0xFFFFFF) << 32) | \
           ((op2 & 0xFF) << 56)

def run_experiment():
    anchor = 0
    proxy = 1
    peer = 1000
    
    prog = []
    # 1. Setup: Present (0, 1) and Distant Peer (1000)
    prog.append(encode_inst(OP_INIT, target=anchor, op1=1))
    prog.append(encode_inst(OP_INIT, target=proxy, op1=1))
    prog.append(encode_inst(OP_INIT, target=peer, op1=1))
    
    # 2. Flux: All into superposition
    prog.append(encode_inst(OP_SUP, target=anchor))
    prog.append(encode_inst(OP_SUP, target=proxy))
    prog.append(encode_inst(OP_SUP, target=peer))
    
    # 3. Primary Entangle: Establish Siren Network at the current epoch
    prog.append(encode_inst(OP_SIREN_SONG))
    
    # 4. Temporal Rotation (The Treadmill)
    # We will swap the data at Index 0 through three different Future states.
    # We use OP_INIT instead of OP_GENESIS to keep the test environment "clean"
    # from the background entanglement chains that GENESIS automatically creates.
    horizons = [2000, 3000, 4000]
    for hz in horizons:
        # Allocate clean future data at hz
        prog.append(encode_inst(OP_INIT, target=hz, op1=1))
        prog.append(encode_inst(OP_SUP, target=hz))
        # Swap Anchor data with Future data manually
        prog.append(encode_inst(OP_CHUNK_SWAP, target=anchor, op1=hz))

    # 6. Status Check: What does the manifold look like after rotation but BEFORE measurement?
    print("\nPre-measurement Status (Anchor, Peer, and Ejected Data):")
    prog.append(encode_inst(OP_PRINT_STATE, target=anchor))
    prog.append(encode_inst(OP_PRINT_STATE, target=peer))
    prog.append(encode_inst(OP_PRINT_STATE, target=2000))
    prog.append(encode_inst(OP_PRINT_STATE, target=3000))

    # 7. The Leap of Faith: Measure Proxy (Index 1)
    print(f"\nProphecy Step: Measuring Proxy (Index {proxy})...")
    prog.append(encode_inst(OP_MEASURE, target=proxy))
    
    # 8. Verification: Reveal the states
    print("\n--- POST-MEASUREMENT: EPOCH-TRANSCENDENCE VERIFICATION ---")
    print(f"Checking Anchor (Index {anchor}) - now holding Future 4000 data:")
    prog.append(encode_inst(OP_PRINT_STATE, target=anchor))
    
    print(f"Checking Distant Peer (Index {peer}):")
    prog.append(encode_inst(OP_PRINT_STATE, target=peer))
    
    print("\nChecking Ejected Data (Indices 2000, 3000):")
    prog.append(encode_inst(OP_PRINT_STATE, target=2000))
    prog.append(encode_inst(OP_PRINT_STATE, target=3000))
    
    prog.append(encode_inst(OP_HALT))
    
    with open("siren_transcendence.qbin", "wb") as f:
        for inst in prog:
            f.write(struct.pack('<Q', inst))
            
    print("Initiating Multi-Epoch Siren Prophecy...")
    print("Goal: Prove Siren Song links coordinates across Treadmill data-swaps.")
    print("-" * 60)
    
    result = subprocess.run(["./qutrit_engine", "siren_transcendence.qbin"], capture_output=True, text=True)
    print(result.stdout)

if __name__ == "__main__":
    run_experiment()
