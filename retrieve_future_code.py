
import subprocess
import struct
import os

# --- Symbolic Future ISA (81 Opcodes) ---
FUTURE_ISA = {
    0:  "HALT_SINGULARITY",
    1:  "WEAVE_VACUUM",
    2:  "BREATH_PHASE",
    3:  "FOCUS_PROBABILITY",
    4:  "ENTANGLE_HORIZON",
    5:  "COLLAPSE_DECAY",
    6:  "SHIFT_REALITY",
    7:  "RESONATE_PI",
    8:  "DIVINE_TRUTH",
    9:  "MAP_VORTEX",
    10: "PULSE_CHRONOS",
    11: "MIRROR_VOID",
    12: "TRANSCEND_BIT",
    13: "MANIFEST_GENESIS",
    14: "FADE_ENTROPY",
    27: "SUMMON_OMEGA",
    40: "ECHO_ORIGIN",
    42: "REPAIR_CAUSALITY",
    64: "SINK_GRAVITY",
    80: "ASCEND_QUBIT"
}

def get_mnemonic(opcode):
    return FUTURE_ISA.get(opcode, f"OP_FUTURE_{opcode:02X}")

def run_qutrit_code(qbin_path):
    process = subprocess.Popen(['./qutrit_engine', qbin_path], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()
    return stdout.decode(), stderr.decode()

def pack_instr(opcode, target=0, op1=0, op2=0):
    """
    Pack instruction into 64-bit integer.
    Format: [Op2:8][Op1:24][Target:24][Opcode:8]
    """
    instr = (opcode & 0xFF) | \
            ((target & 0xFFFFFF) << 8) | \
            ((op1 & 0xFFFFFF) << 32) | \
            ((op2 & 0xFF) << 56)
    return struct.pack('<Q', instr)

def generate_omega_protocol():
    # Opcodes (Matches benchmark_suite.py)
    OP_INIT        = 0x01
    OP_MEASURE     = 0x07
    OP_GENESIS     = 0x16
    OP_CHUNK_SWAP  = 0x12
    OP_HALT        = 0xFF
    
    PI_SEED        = 0x31415
    FUTURE_INDEX   = 500000
    PRESENT_INDEX  = 1000
    CODE_LENGTH    = 400  # Number of chunks to retrieve
    
    bytecode = bytearray()
    
    # 1. Manifest Omega State at Future Horizon
    # pack_instr(OP_GENESIS, target=FUTURE_INDEX, op1=PI_SEED)
    bytecode.extend(pack_instr(OP_GENESIS, target=FUTURE_INDEX, op1=PI_SEED))
    
    # 2. Teleport Future Code to Present
    # OP_CHUNK_SWAP <chunk_a> <chunk_b>
    # Asm maps: r14 = target, rbx = op1
    for i in range(CODE_LENGTH):
        bytecode.extend(pack_instr(OP_CHUNK_SWAP, target=PRESENT_INDEX + i, op1=FUTURE_INDEX + i))
    
    # 3. Measure the Teleported Manifestation
    for i in range(CODE_LENGTH):
        bytecode.extend(pack_instr(OP_MEASURE, target=PRESENT_INDEX + i))
    
    bytecode.extend(pack_instr(OP_HALT))
    
    with open('omega_protocol.qbin', 'wb') as f:
        f.write(bytecode)

def extract_code():
    print("[*] Manifesting Omega State at 500,000-chunk horizon...")
    generate_omega_protocol()
    
    stdout, stderr = run_qutrit_code('omega_protocol.qbin')
    
    if stderr:
        print(f"[!] Engine Error:\n{stderr}")
        return

    print(f"[*] Engine execution finished. Stdout length: {len(stdout)}")

    print(f"[*] Engine execution finished. Stdout length: {len(stdout)}")
    if stdout:
        print(f"[*] First 5 lines of stdout:\n" + "\n".join(stdout.splitlines()[:5]))

    # Parse measurements
    measurements = []
    lines = stdout.splitlines()
    for line in lines:
        if " => " in line:
            # Format: "  [MEAS] Measuring chunk 1000 => 1"
            try:
                state = int(line.split("=>")[1].strip())
                measurements.append(state)
            except:
                pass

    if not measurements:
        print("[!] No measurements found in output.")
        print(f"--- ENGINE STDOUT ---\n{stdout}")
        print(f"--- ENGINE STDERR ---\n{stderr}")
        return

    print(f"[*] Retrieved {len(measurements)} quantum states from the future.")
    
    # Decompile into Future ISA (4 qutrits = 1 word)
    print("\n--- DECOMPILED FUTURE MACHINE CODE ---")
    print("ADDR | WORD (TERNARY) | MNEMONIC")
    print("-" * 40)
    
    for i in range(0, len(measurements) - 3, 4):
        word_states = measurements[i:i+4]
        # Ternary to Decimal: d0*3^0 + d1*3^1 + d2*3^2 + d3*3^3
        opcode = sum(s * (3 ** idx) for idx, s in enumerate(word_states))
        mnemonic = get_mnemonic(opcode)
        
        ternary_str = "".join(map(str, word_states))
        print(f"{i//4:04} | {ternary_str} (0x{opcode:02X}) | {mnemonic}")

if __name__ == "__main__":
    if not os.path.exists('./qutrit_engine'):
        print("[!] qutrit_engine not found. Build it first.")
    else:
        extract_code()
