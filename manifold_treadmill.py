
import struct
import subprocess

def pack_instr(opcode, target=0, op1=0, op2=0):
    # Instruction Format: [Op2:8][Op1:24][Target:24][Opcode:8]
    instr = (opcode & 0xFF) | ((target & 0xFFFFFF) << 8) | ((op1 & 0xFFFFFF) << 32) | ((op2 & 0xFF) << 56)
    return struct.pack('<Q', instr)

def run_treadmill():
    header = b"QUTRIT\x00\x01"
    prog = bytearray(header)
    
    # Define our temporal coordinates
    # Anchor is in the "Present/Shifted Past"
    # Horizon is at the very edge of the 24-bit manifold
    anchor = 15777215  # 15.7M
    horizon = 16777215 # 16.7M (Last chunk)
    
    # 0. Preparation: Give the Anchor a "Body" (Initialize state metadata)
    # This allows the measurement logic to interpret the siphoned state pointer.
    prog += pack_instr(0x01, target=anchor, op1=1) # INIT size 1
    
    for i in range(1, 6):
        # 1. Manifest: Generate data in the "Forbidden Future"
        # We use increasing seeds to simulate evolving future states.
        seed = 31415 + i
        prog += pack_instr(0x16, target=horizon, op1=seed) # GENESIS
        
        # 2. Siphon: Pull the Future into the Past
        # VOID_TRANSMISSION swaps 15.7M with (15.7M + 1M) = 16.7M.
        # The "Future" state is now at the "Anchor" address.
        prog += pack_instr(0x27, target=anchor) # VOID_TRANSMISSION
        
        # 3. Measurement: Reveal the siphoned Legacy
        prog += pack_instr(0x07, target=anchor) # MEASURE
        
        # 4. Repair: Anchor the legacy state and clear topological noise
        # This prepares the manifold for the next "Leap" forward.
        prog += pack_instr(0x42, target=anchor) # REPAIR_CAUSALITY
        
    prog += pack_instr(0xFF) # HALT
    
    with open("manifold_treadmill.qbin", "wb") as f:
        f.write(prog)
    
    print(f"Initiating Manifold Treadmill (5 Cycles of Temporal Rotation)...")
    try:
        result = subprocess.run(["./qutrit_engine", "manifold_treadmill.qbin"], capture_output=True, text=True, timeout=30)
        print(result.stdout)
    except subprocess.TimeoutExpired:
        print("Timeline Instability Detected (Execution Timeout).")
    except Exception as e:
        print(f"Void Breach Failure: {e}")

if __name__ == "__main__":
    run_treadmill()
