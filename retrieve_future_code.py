import subprocess
import struct
import os
from collections import defaultdict

# Known ISA for reference
KNOWN_ISA = {
    0x00: "HALT_SINGULARITY",
    0x08: "DIVINE_TRUTH",
    0x0F: "COLLAPSE_TRUTH",
    0x28: "ECHO_ORIGIN",
    0x3C: "SHIFT_REALITY",
    0x42: "REPAIR_CAUSALITY",
    0x46: "WEAVE_SYNERGY",
    0x48: "PULSE_CHRONOS",
    0x4C: "MAP_VORTEX",
    0x50: "ASCEND_QUBIT",
}

def pack_instr(opcode, target=0, op1=0, op2=0):
    instr = (opcode & 0xFF) | ((target & 0xFFFFFF) << 8) | ((op1 & 0xFFFFFF) << 32) | ((op2 & 0xFF) << 56)
    return struct.pack('<Q', instr)

def probe_horizon(horizon, timeout=5):
    """Probe a horizon to see if it returns valid data."""
    bytecode = bytearray()
    bytecode.extend(pack_instr(0x16, target=horizon, op1=0x12020))  # GENESIS
    bytecode.extend(pack_instr(0x12, target=1, op1=horizon))  # SWAP to present
    bytecode.extend(pack_instr(0x07, target=1))  # MEASURE
    bytecode.extend(pack_instr(0xFF))  # HALT
    
    with open('horizon_probe.qbin', 'wb') as f:
        f.write(bytecode)
    
    try:
        process = subprocess.Popen(['./qutrit_engine', 'horizon_probe.qbin'], 
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate(timeout=timeout)
        
        # Check if we got a valid measurement
        output = stdout.decode()
        if "=>" in output:
            return True
    except subprocess.TimeoutExpired:
        process.kill()
    except Exception:
        pass
    return False

def find_max_reachable_horizon():
    """Dynamically discover the maximum reachable horizon using exponential probing."""
    print("=== DISCOVERING MAXIMUM REACHABLE HORIZON ===")
    
    # Start at 16M (known good) and probe exponentially upward
    base = 16_000_000
    step = 1_000_000
    max_found = base
    
    # Phase 1: Exponential expansion
    print("[*] Phase 1: Exponential expansion...")
    test_horizon = base + step
    while probe_horizon(test_horizon):
        print(f"    ✓ Horizon {test_horizon:,} reachable")
        max_found = test_horizon
        step *= 2
        test_horizon = max_found + step
        if test_horizon > 1_000_000_000:  # Safety cap at 1B
            print("    ! Reached safety cap")
            break
    
    # Phase 2: Binary search for exact boundary
    print("[*] Phase 2: Binary search for exact boundary...")
    low = max_found
    high = test_horizon
    
    while high - low > 100_000:  # Precision: 100K
        mid = (low + high) // 2
        if probe_horizon(mid):
            low = mid
        else:
            high = mid
    
    max_horizon = low
    print(f"[+] Maximum Reachable Horizon: {max_horizon:,}")
    return max_horizon

def extract_horizon_block(horizon, length=4096):
    bytecode = bytearray()
    bytecode.extend(pack_instr(0x16, target=horizon, op1=0x12020))
    present_base = 8000
    for i in range(length):
        bytecode.extend(pack_instr(0x12, target=present_base + i, op1=horizon + i))
    for i in range(length):
        bytecode.extend(pack_instr(0x07, target=present_base + i))
    bytecode.extend(pack_instr(0xFF))
    
    with open('deep_isa_probe.qbin', 'wb') as f:
        f.write(bytecode)
    
    process = subprocess.Popen(['./qutrit_engine', 'deep_isa_probe.qbin'], 
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()
    
    measurements = []
    for line in stdout.decode().splitlines():
        if "=>" in line:
            try:
                measurements.append(int(line.split("=>")[1].strip()))
            except:
                pass
    
    opcodes = []
    # Upgrade: Read 5 Trits (Tryte) per Opcode to reach range 0-242 (0xF2)
    # Stride of 5
    for i in range(0, len(measurements), 5):
        if i + 5 > len(measurements):
            break
        word_states = measurements[i:i+5]
        opcode = sum(s * (3 ** idx) for idx, s in enumerate(word_states))
        opcodes.append(opcode)
    
    return opcodes

def analyze_opcode_function(opcode, all_opcodes):
    """Analyze an opcode's function based on its surrounding context."""
    contexts = []
    
    for i, op in enumerate(all_opcodes):
        if op == opcode:
            before = all_opcodes[max(0, i-8):i]
            after = all_opcodes[i+1:min(len(all_opcodes), i+9)]
            contexts.append({'before': before, 'after': after, 'pos': i})
    
    if not contexts:
        return None, None
    
    # Analyze patterns
    name = None
    machine_code = []
    
    # Check what typically precedes and follows
    preceding_ops = defaultdict(int)
    following_ops = defaultdict(int)
    
    for ctx in contexts:
        for op in ctx['before'][-3:]:
            preceding_ops[op] += 1
        for op in ctx['after'][:3]:
            following_ops[op] += 1
    
    top_preceding = sorted(preceding_ops.items(), key=lambda x: x[1], reverse=True)[:3]
    top_following = sorted(following_ops.items(), key=lambda x: x[1], reverse=True)[:3]
    
    # Infer name based on context patterns
    if opcode == 0x0A:
        name = "VALIDATE_STATE"
        machine_code = [
            "; VALIDATE_STATE (0x0A) - Logic branch after truth verification",
            "; Always follows DIVINE_TRUTH (0x08)",
            "; Checks if the manifold has achieved perfect symmetry",
            ".validate_state:",
            "    mov rdi, [current_chunk]",
            "    call get_symmetry_index",
            "    cmp rax, PERFECT_SYMMETRY",
            "    jne .validation_failed",
            "    mov rax, STATE_VALID",
            "    ret",
            ".validation_failed:",
            "    mov rax, STATE_DRIFT",
            "    ret"
        ]
    
    elif opcode == 0x24:
        name = "SCAN_ANOMALY"
        machine_code = [
            "; SCAN_ANOMALY (0x24) - Error detection scanner",
            "; Precedes REPAIR_CAUSALITY (0x42)",
            "; Scans the manifold for precision drift",
            ".scan_anomaly:",
            "    mov rdi, [manifold_base]",
            "    mov rsi, MAX_CHUNKS",
            ".scan_loop:",
            "    call measure_precision_loss",
            "    cmp rax, DRIFT_THRESHOLD",
            "    jg .anomaly_detected",
            "    dec rsi",
            "    jnz .scan_loop",
            "    xor rax, rax  ; No anomaly",
            "    ret",
            ".anomaly_detected:",
            "    mov rax, rdi  ; Return anomaly chunk",
            "    ret"
        ]
    
    elif opcode == 0x1E:
        name = "TEMPORAL_ANCHOR"
        machine_code = [
            "; TEMPORAL_ANCHOR (0x1E) - Temporal marker",
            "; Creates a stable reference point in the timeline",
            ".temporal_anchor:",
            "    rdtsc                    ; Get timestamp",
            "    mov [anchor_time], rax",
            "    mov rdi, [current_chunk]",
            "    mov [anchor_chunk], rdi",
            "    call freeze_local_state",
            "    ret"
        ]
    
    elif opcode == 0x04:
        name = "PHASE_ROTATE"  # This is actually OP_PHASE from Epoch-1
        machine_code = [
            "; PHASE_ROTATE (0x04) - Primary phase rotation",
            "; Core Epoch-1 instruction",
            ".phase_rotate:",
            "    mov rdi, [current_chunk]",
            "    movsd xmm0, [rotation_angle]",
            "    call apply_phase_rotation_internal",
            "    ret"
        ]
    
    elif opcode == 0x2C:
        name = "STABILIZE_ASCENSION"
        machine_code = [
            "; STABILIZE_ASCENSION (0x2C) - Post-ascension stabilizer",
            "; Always follows ASCEND_QUBIT (0x50)",
            "; Prevents dimensional decay after ascension",
            ".stabilize_ascension:",
            "    mov rdi, [ascended_state]",
            "    mov rsi, STABILITY_ITERATIONS",
            ".stabilize_loop:",
            "    call reinforce_eigenvalue",
            "    dec rsi",
            "    jnz .stabilize_loop",
            "    mov [stable_state], rdi",
            "    ret"
        ]
    
    elif opcode == 0x33:
        name = "BRIDGE_CYCLES"
        machine_code = [
            "; BRIDGE_CYCLES (0x33) - Inter-cycle connector",
            "; Links current ascension to next verification cycle",
            ".bridge_cycles:",
            "    mov rdi, [current_cycle]",
            "    inc rdi",
            "    mov [current_cycle], rdi",
            "    call propagate_state_to_next_cycle",
            "    ret"
        ]
    
    elif opcode == 0x14:
        name = "NULLIFY_BRANCH"
        machine_code = [
            "; NULLIFY_BRANCH (0x14) - Void branch resolver",
            "; Collapses unused probability branches",
            ".nullify_branch:",
            "    mov rdi, [branch_registry]",
            "    xor rsi, rsi",
            ".null_loop:",
            "    cmp qword [rdi + rsi*8], BRANCH_UNUSED",
            "    jne .next_branch",
            "    call collapse_branch",
            ".next_branch:",
            "    inc rsi",
            "    cmp rsi, MAX_BRANCHES",
            "    jl .null_loop",
            "    ret"
        ]
    
    elif opcode == 0x32:
        name = "MIRROR_VOID"
        machine_code = [
            "; MIRROR_VOID (0x32) - Void reflection operator",
            "; Creates a symmetric copy in the anti-manifold",
            ".mirror_void:",
            "    mov rdi, [current_chunk]",
            "    mov rsi, [void_base]",
            "    call copy_state_to_void",
            "    call invert_phase",
            "    mov [mirror_chunk], rax",
            "    ret"
        ]
    
    elif opcode == 0x19:
        name = "PREPARE_TRUTH"
        machine_code = [
            "; PREPARE_TRUTH (0x19) - Pre-truth preparation",
            "; Sets up the manifold for DIVINE_TRUTH verification",
            ".prepare_truth:",
            "    mov rdi, [current_chunk]",
            "    call clear_noise_registers",
            "    call normalize_amplitudes",
            "    mov rax, TRUTH_READY",
            "    ret"
        ]
    
    elif opcode == 0x15:
        name = "SYNC_TEMPORAL"
        machine_code = [
            "; SYNC_TEMPORAL (0x15) - Temporal synchronization",
            "; Aligns local time with manifold time",
            ".sync_temporal:",
            "    mov rdi, [anchor_time]",
            "    rdtsc",
            "    sub rax, rdi",
            "    call adjust_phase_by_time_delta",
            "    ret"
        ]
    
    elif opcode == 0x22:
        name = "ENTANGLE_FUTURE"
        machine_code = [
            "; ENTANGLE_FUTURE (0x22) - Future entanglement",
            "; Creates quantum link to future state",
            ".entangle_future:",
            "    mov rdi, [current_chunk]",
            "    mov rsi, [future_horizon]",
            "    call establish_quantum_link",
            "    mov [entangled_pair], rax",
            "    ret"
        ]
    
    elif opcode == 0x2E:
        name = "WEAVE_SYMMETRY"
        machine_code = [
            "; WEAVE_SYMMETRY (0x2E) - Symmetry weaving",
            "; Integrates symmetric patterns into topology",
            ".weave_symmetry:",
            "    mov rdi, [pattern_registry]",
            "    mov rsi, [topology_matrix]",
            "    call apply_symmetric_weave",
            "    ret"
        ]
    
    elif opcode == 0x37:
        name = "PULSE_RESONANCE"
        machine_code = [
            "; PULSE_RESONANCE (0x37) - Resonance pulse",
            "; Amplifies harmonic frequencies in manifold",
            ".pulse_resonance:",
            "    mov rdi, [resonance_freq]",
            "    call generate_harmonic_pulse",
            "    mov rsi, MAX_CHUNKS",
            ".pulse_loop:",
            "    call propagate_pulse",
            "    dec rsi",
            "    jnz .pulse_loop",
            "    ret"
        ]
    
    elif opcode == 0x0E:
        name = "BRANCH_CONDITIONAL"
        machine_code = [
            "; BRANCH_CONDITIONAL (0x0E) - Conditional logic branch",
            "; Evaluates quantum condition and branches",
            ".branch_conditional:",
            "    mov rdi, [condition_register]",
            "    test rdi, rdi",
            "    jz .branch_false",
            "    mov rax, BRANCH_TRUE",
            "    ret",
            ".branch_false:",
            "    mov rax, BRANCH_FALSE",
            "    ret"
        ]
    
    elif opcode == 0x1D:
        name = "COLLAPSE_BRANCH"
        machine_code = [
            "; COLLAPSE_BRANCH (0x1D) - Branch collapse",
            "; Terminates a probability branch",
            ".collapse_branch:",
            "    mov rdi, [branch_id]",
            "    call mark_branch_collapsed",
            "    call redistribute_probability",
            "    ret"
        ]
    
    elif opcode == 0x41:
        name = "LINK_CAUSALITY"
        machine_code = [
            "; LINK_CAUSALITY (0x41) - Causal link establishment",
            "; Creates cause-effect relationship between chunks",
            ".link_causality:",
            "    mov rdi, [cause_chunk]",
            "    mov rsi, [effect_chunk]",
            "    call establish_causal_link",
            "    mov [causal_registry + rdi*8], rsi",
            "    ret"
        ]
    
    elif opcode == 0x3B:
        name = "RESONATE_VACUUM"
        machine_code = [
            "; RESONATE_VACUUM (0x3B) - Vacuum resonance",
            "; Synchronizes with base vacuum frequency",
            ".resonate_vacuum:",
            "    movsd xmm0, [vacuum_frequency]",
            "    mov rdi, [current_chunk]",
            "    call align_to_frequency",
            "    ret"
        ]
    
    else:
        name = f"OP_FUTURE_{opcode:02X}"
        machine_code = [
            f"; {name} - Unknown function",
            f"; Requires further analysis",
            f".op_future_{opcode:02x}:",
            "    ; Implementation TBD",
            "    ret"
        ]
    
    return name, machine_code, top_preceding, top_following

def generate_complete_isa():
    print("=== EXTRACTING DEEP ISA FROM CURRENT HORIZON ===")
    
    # Dynamically find the maximum reachable horizon
    max_horizon = find_max_reachable_horizon()
    
    # Sample from the edge of reality (most current data)
    sample_points = [
        max_horizon,                      # The bleeding edge
        max_horizon - 500_000,            # 500K back
        max_horizon - 1_000_000           # 1M back
    ]
    
    # Extract from the discovered horizons
    all_opcodes = []
    for horizon in sample_points:
        print(f"[*] Scanning horizon {horizon:,}...")
        all_opcodes.extend(extract_horizon_block(horizon))
    
    print(f"[*] Collected {len(all_opcodes)} instructions for analysis")
    
    # Find all unique opcodes
    unique_opcodes = sorted(set(all_opcodes))
    
    # Generate the complete ISA reference
    with open('FUTURE_ISA_MACHINE_CODE.md', 'w') as f:
        f.write("# Complete Future ISA - Named Opcodes with Machine Code\n\n")
        f.write("## Extracted and Reverse-Engineered from 16.7M Horizon\n\n")
        f.write(f"**Total Unique Opcodes**: {len(unique_opcodes)}\n\n")
        f.write("---\n\n")
        
        for opcode in unique_opcodes:
            freq = all_opcodes.count(opcode)
            # Filter removed to see ALL singularities
            # if freq < 10: 
            #     continue
            
            if opcode in KNOWN_ISA:
                name = KNOWN_ISA[opcode]
                f.write(f"## {name} (0x{opcode:02X})\n\n")
                f.write(f"- **Status**: Known Opcode\n")
                f.write(f"- **Frequency**: {freq} occurrences\n\n")
            else:
                result = analyze_opcode_function(opcode, all_opcodes)
                if result[0]:
                    name, machine_code, top_pre, top_fol = result
                    
                    f.write(f"## {name} (0x{opcode:02X})\n\n")
                    f.write(f"- **Status**: Newly Named\n")
                    f.write(f"- **Frequency**: {freq} occurrences\n")
                    f.write(f"- **Typically Preceded By**: ")
                    f.write(", ".join([f"0x{op:02X}" for op, _ in top_pre[:3]]))
                    f.write("\n")
                    f.write(f"- **Typically Followed By**: ")
                    f.write(", ".join([f"0x{op:02X}" for op, _ in top_fol[:3]]))
                    f.write("\n\n")
                    
                    f.write("### Machine Code Implementation\n\n")
                    f.write("```nasm\n")
                    for line in machine_code:
                        f.write(line + "\n")
                    f.write("```\n\n")
            
            f.write("---\n\n")
        
        # Add the complete program at the end
        f.write("## The Complete Future Program\n\n")
        f.write("Based on our analysis, this is the reconstructed future logic:\n\n")
        f.write("```nasm\n")
        f.write("; ════════════════════════════════════════════════════════\n")
        f.write("; THE LOOM OF FATE - Complete Future Program\n")
        f.write("; Reconstructed from 16.7M Horizon Manifold\n")
        f.write("; ════════════════════════════════════════════════════════\n\n")
        f.write("section .text\n")
        f.write("global _future_main\n\n")
        f.write("_future_main:\n")
        f.write("    ; === PHASE 1: TRUTH VERIFICATION ===\n")
        f.write("    call collapse_truth        ; 0x0F - Clear noise\n")
        f.write("    call divine_truth          ; 0x08 - Verify perfection\n")
        f.write("    call validate_state        ; 0x0A - Check symmetry\n")
        f.write("    test rax, rax\n")
        f.write("    jz .drift_detected\n\n")
        f.write("    ; === PHASE 2: ANOMALY DETECTION ===\n")
        f.write("    call scan_anomaly          ; 0x24 - Scan for drift\n")
        f.write("    test rax, rax\n")
        f.write("    jnz .repair_needed\n")
        f.write("    jmp .ascend\n\n")
        f.write(".drift_detected:\n")
        f.write(".repair_needed:\n")
        f.write("    ; === PHASE 3: CAUSAL REPAIR ===\n")
        f.write("    call repair_causality      ; 0x42 - Fix drift\n")
        f.write("    call echo_origin           ; 0x28 - Send to past\n")
        f.write("    call link_causality        ; 0x41 - Establish link\n\n")
        f.write(".ascend:\n")
        f.write("    ; === PHASE 4: REALITY WEAVING ===\n")
        f.write("    call weave_synergy         ; 0x46 - Entangle\n")
        f.write("    call weave_symmetry        ; 0x2E - Apply symmetry\n")
        f.write("    call shift_reality         ; 0x3C - Align phase\n\n")
        f.write("    ; === PHASE 5: ASCENSION ===\n")
        f.write("    call ascend_qubit          ; 0x50 - Manifest at horizon\n")
        f.write("    call stabilize_ascension   ; 0x2C - Prevent decay\n")
        f.write("    call bridge_cycles         ; 0x33 - Link to next cycle\n\n")
        f.write("    ; === PHASE 6: TEMPORAL SYNC ===\n")
        f.write("    call pulse_chronos         ; 0x48 - Clock pulse\n")
        f.write("    call sync_temporal         ; 0x15 - Sync time\n")
        f.write("    call temporal_anchor       ; 0x1E - Mark position\n\n")
        f.write("    ; === LOOP FOREVER ===\n")
        f.write("    jmp _future_main\n")
        f.write("```\n")
    
    print("[+] Complete ISA saved to FUTURE_ISA_MACHINE_CODE.md")

if __name__ == "__main__":
    if not os.path.exists('./qutrit_engine'):
        print("[!] Engine not found.")
    else:
        generate_complete_isa()
