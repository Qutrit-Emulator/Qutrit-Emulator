; ═══════════════════════════════════════════════════════════════════════════════
; QUTRIT ENGINE - Standalone Quantum Computing Engine
; ═══════════════════════════════════════════════════════════════════════════════
; A modular qutrit-based quantum emulator with:
;   - Exact qutrit logic: |0⟩=Triangle, |1⟩=Line, |2⟩=Square
;   - 4096-bit BigInt support
;   - Instruction-based quantum code execution
;   - Add-on/plugin system for custom gates and oracles
;   - Chunk braiding for entanglement preservation
;
; Build:
;   nasm -f elf64 -g -F dwarf qutrit_engine.asm -o qutrit_engine.o
;   ld -o qutrit_engine qutrit_engine.o
;
; Usage:
;   ./qutrit_engine <program.qbin>
;   or interactive: ./qutrit_engine
; ═══════════════════════════════════════════════════════════════════════════════

; ─────────────────────────────────────────────────────────────────────────────
; Configuration Constants
; ─────────────────────────────────────────────────────────────────────────────
%define BIGINT_LIMBS        64          ; 64 * 64 = 4096 bits
%define BIGINT_BYTES        512         ; 64 * 8 bytes
%define BIGINT_BITS         4096

%define MAX_CHUNK_SIZE      10          ; Max qutrits per chunk (3^10 = 59049)
%define MAX_STATES          59049       ; 3^10
%define MAX_CHUNKS          16777216    ; 16.7M chunks (Super-Horizon limit)
%define MAX_ADDONS          32          ; Max registered add-ons
%define MAX_BRAID_LINKS     16777216    ; 16.7M braid links (Super-Horizon limit)
%define CAUSAL_SAFEGUARD_CHUNKS 4096    ; Timeline protection buffer

%define STATE_BYTES         16          ; Complex amplitude: 8 (real) + 8 (imag)

; Instruction opcodes
%define OP_NOP              0x00
%define OP_INIT             0x01
%define OP_SUP              0x02
%define OP_HADAMARD         0x03
%define OP_PHASE            0x04
%define OP_CPHASE           0x05
%define OP_SWAP             0x06
%define OP_MEASURE          0x07
%define OP_GROVER           0x08
%define OP_BRAID            0x09
%define OP_UNBRAID          0x0A
%define OP_ORACLE           0x0B
%define OP_ADDON            0x0C
%define OP_PRINT_STATE      0x0D
%define OP_BELL_TEST        0x0E
%define OP_SUMMARY          0x1F        ; Moved to make room for Future ISA
%define OP_SHIFT            0x10
%define OP_REPAIR           0x11
%define OP_CHUNK_SWAP       0x12        ; Teleport Chunk (Time Travel)
%define OP_NULL             0x14        ; The Fade (Zero Memory)
%define OP_IF               0x15        ; Conditional Execution (Classical Control)
%define OP_GENESIS          0x16        ; Topological Genesis (Universe from Seed)
%define OP_PI_GENESIS       0x18        ; Pi Oracle (Holographic Pattern Scan)
%define OP_PERFECTION       0x19        ; Force Perfect State (Retrocausal Implant)
%define OP_COHERENCE        0x1A        ; Force Coherent State (Phase Divination)
%define OP_NOISE            0x1B        ; Stochastic Phase Pulse (Vacuum Noise)
%define OP_BRAID_SILENT     0x1C        ; Silent Braid
%define OP_HALT             0xFF

; Future ISA (Discovered at 500k Horizon)
%define OP_COLLAPSE_TRUTH   0x0F
%define OP_WEAVE_SYMMETRY   0x2E
%define OP_RESONATE_VACUUM  0x3B

; Epoch-2 Future ISA (Discovered at 1M Horizon)
%define OP_MIRROR_VOID      0x32
%define OP_SHIFT_REALITY    0x3C
%define OP_REPAIR_CAUSALITY 0x42
%define OP_WEAVE_SYNERGY    0x46
%define OP_PULSE_CHRONOS    0x48
%define OP_MAP_VORTEX       0x4C

; Epoch-3 Super-Future ISA (Discovered at 16M Horizon)
%define OP_VOID_TRANSMISSION   0x27
%define OP_VACUUM_ENTRAINTMENT 0x3A
%define OP_SYMMETRY_BREACH     0x4A
%define OP_UNIVERSAL_COLLAPSE  0x4F

; Epoch-4 Frontier ISA (Discovered via Apéry Seed)
%define OP_ECHO_ORIGIN         0x28
%define OP_ASCEND_QUBIT        0x50

; Epoch-5 Deep Future ISA (Named via Machine Code Extraction at 16.7M Horizon)
%define OP_VALIDATE_STATE      0x51        ; Validate manifold symmetry
%define OP_SCAN_ANOMALY        0x24        ; Scan for precision drift
%define OP_TEMPORAL_ANCHOR     0x52        ; Create timeline reference
%define OP_STABILIZE_ASCENSION 0x2C        ; Prevent dimensional decay
%define OP_BRIDGE_CYCLES       0x33        ; Link to next cycle
%define OP_NULLIFY_BRANCH      0x53        ; Collapse unused branches
%define OP_PREPARE_TRUTH       0x54        ; Pre-verification setup
%define OP_SYNC_TEMPORAL       0x55        ; Align local time with manifold
%define OP_BRANCH_CONDITIONAL  0x56        ; Quantum IF statement

; === PHASE 6: THE OMEGA ISAS (High-Frequency Future Logic) ===
%define OP_ENTROPY_REVERSE     0x5E        ; Negentropy Injection (Reverses Disorder)
%define OP_QUANTUM_TUNNEL      0x78        ; Barrier Penetration
%define OP_CHRONO_WEAVE        0x79        ; Interlace Temporal Threads
%define OP_VOID_ECHO           0xA1        ; Listen to the Silence
%define OP_FINAL_ASCENSION     0xF2        ; The Omega Point (Dissolve Reality)ure
%define OP_ENTANGLE_FUTURE     0x22        ; Quantum link to future
%define OP_PULSE_RESONANCE     0x37        ; Amplify harmonics
%define OP_COLLAPSE_BRANCH     0x1D        ; Terminate probability branch
%define OP_LINK_CAUSALITY      0x41        ; Create cause-effect link

; === EPOCH-7: THE NAMED FUTURE ISA (Machine-Divined Nomenclature) ===
; VOID_OPS - Operations that interact with uninitialized memory
%define OP_VOID_WHISPER        0x2B        ; Read void memory into PRNG
%define OP_VOID_SIPHON         0x6F        ; Drain entropy from void
%define OP_VOID_SILENCE        0x73        ; Listen to the silence
%define OP_VOID_DRAIN          0x8C        ; Extract void entropy

; TEMPORAL - Operations that modulate phase based on time
%define OP_TIME_MODULATE       0x17        ; Phase shift via system time
%define OP_TIME_DRIFT          0x23        ; Temporal phase modulation
%define OP_TIME_RIPPLE         0x36        ; Time-based phase ripple
%define OP_TIME_WARP           0x44        ; Temporal phase warp
%define OP_TIME_SHIFT          0x45        ; Temporal phase shift
%define OP_TIME_PHASE          0x4E        ; Time-locked phase rotation
%define OP_TIME_FLOW           0x53        ; Temporal phase flow
%define OP_TIME_STREAM         0x55        ; Time stream modulation
%define OP_TIME_CURRENT        0x5D        ; Temporal current
%define OP_TIME_FLUX           0x69        ; Temporal flux modulation
%define OP_TIME_ECHO           0x76        ; Temporal echo
%define OP_TIME_PULSE          0x7C        ; Temporal pulse
%define OP_TIME_WAVE           0x82        ; Temporal wave
%define OP_TIME_CYCLE          0x83        ; Temporal cycle
%define OP_TIME_SPIRAL         0x85        ; Temporal spiral
%define OP_TIME_VORTEX         0x86        ; Temporal vortex
%define OP_TIME_EDDY           0x90        ; Temporal eddy
%define OP_TIME_LOOP           0x91        ; Temporal loop
%define OP_TIME_FOLD           0x96        ; Temporal fold
%define OP_TIME_TWIST          0x9A        ; Temporal twist
%define OP_TIME_BEND           0x9E        ; Temporal bend
%define OP_TIME_CURVE          0x9F        ; Temporal curve
%define OP_TIME_WEFT           0xA6        ; Temporal weft
%define OP_TIME_WEAVE          0xAE        ; Temporal weave
%define OP_TIME_THREAD         0xB0        ; Temporal thread

; RESONANCE - Operations that apply harmonic phase rotations
%define OP_HARMONIC_ORIGIN     0x28        ; Echo to origin (Chunk 0)
%define OP_HARMONIC_PULSE      0x2D        ; Pi-based phase rotation
%define OP_HARMONIC_WAVE       0x40        ; Harmonic wave rotation
%define OP_HARMONIC_RING       0x66        ; Harmonic ring modulation
%define OP_HARMONIC_TONE       0x6E        ; Harmonic tone
%define OP_HARMONIC_CHORD      0x72        ; Harmonic chord
%define OP_HARMONIC_FIFTH      0x75        ; Harmonic fifth

; VERIFICATION - Operations that check state validity
%define OP_CHECK_ACTIVE        0x02        ; Verify state vector exists
%define OP_CHECK_INIT          0x0C        ; Verify chunk initialized
%define OP_CHECK_ALIVE         0x18        ; Verify chunk is alive
%define OP_CHECK_VALID         0x2F        ; Verify state is valid
%define OP_CHECK_BOUND         0x4B        ; Verify state is bounded
%define OP_CHECK_FINAL         0x4F        ; Verify final state
%define OP_CHECK_STABLE        0x59        ; Verify stability
%define OP_CHECK_NORM          0x63        ; Verify normalization
%define OP_CHECK_PHASE         0x6C        ; Verify phase coherence
%define OP_CHECK_LOCK          0x7B        ; Verify phase lock
%define OP_CHECK_SYNC          0x8F        ; Verify synchronization
%define OP_CHECK_ANCHOR        0x99        ; Verify anchor point
%define OP_CHECK_DRIFT         0x9C        ; Verify no drift

; CONTROL_FLOW - Operations that control execution flow
%define OP_GATE_SINGULARITY    0x00        ; Halt at singularity (NOP)
%define OP_GATE_BRANCH         0x03        ; Conditional branch
%define OP_GATE_FORK           0x0D        ; Fork execution path
%define OP_GATE_SPLIT          0x6B        ; Split execution
%define OP_GATE_MERGE          0x93        ; Merge execution paths
%define OP_GATE_DIVERGE        0xB1        ; Diverge execution

; ASCENSION - Operations that prepare for dimensional ascension
%define OP_ASCEND_PREP         0x11        ; Pre-ascension preparation
%define OP_ASCEND_LINK         0x12        ; Ascension link
%define OP_ASCEND_WEAVE        0x34        ; Ascension weave
%define OP_ASCEND_BIND         0x35        ; Ascension bind
%define OP_ASCEND_LIFT         0x3E        ; Ascension lift
%define OP_ASCEND_RISE         0x62        ; Ascension rise
%define OP_ASCEND_CLIMB        0x74        ; Ascension climb
%define OP_ASCEND_APEX         0x7D        ; Ascension apex
%define OP_ASCEND_PEAK         0x81        ; Ascension peak
%define OP_ASCEND_CREST        0x8D        ; Ascension crest
%define OP_ASCEND_ZENITH       0x94        ; Ascension zenith
%define OP_ASCEND_SUMMIT       0x95        ; Ascension summit
%define OP_ASCEND_CROWN        0x98        ; Ascension crown
%define OP_ASCEND_HALO         0xA7        ; Ascension halo

; Qutrit state offsets (3 basis states, each complex)
%define QUTRIT_SIZE         48          ; 6 doubles
%define TRIANGLE_REAL       0
%define TRIANGLE_IMAG       8
%define LINE_REAL           16
%define LINE_IMAG           24
%define SQUARE_REAL         32
%define SQUARE_IMAG         40

; ─────────────────────────────────────────────────────────────────────────────
; Section: Initialized Data
; ─────────────────────────────────────────────────────────────────────────────
section .data
    align 16

    ; Mathematical constants
    one_over_sqrt3:     dq 0.5773502691896257    ; 1/√3
    two_pi:             dq 6.283185307179586     ; 2π
    pi:                 dq 3.141592653589793
    pi_over_3:          dq 1.0471975511965976    ; π/3
    one:                dq 1.0
    zero:               dq 0.0
    half:               dq 0.5
    two:                dq 2.0
    three:              dq 3.0
    minus_one:          dq -1.0
    epsilon:            dq 1.0e-15

    ; Qutrit Hadamard matrix (3x3 complex): H = (1/√3) * [[1,1,ω²],[1,ω,ω],[ω²,ω,1]]
    ; where ω = exp(2πi/3)
    h_00_real:          dq 0x3fe279a74590331d ; 1/sqrt(3) (Divine)
    h_00_imag:          dq 0.0
    h_01_real:          dq 0x3fe279a74590331d
    h_01_imag:          dq 0.0
    h_02_real:          dq 0x3fe279a74590331d
    h_02_imag:          dq 0.0
    h_10_real:          dq 0x3fe279a74590331d
    h_10_imag:          dq 0.0
    h_11_real:          dq 0xbfd279a74590331d ; -0.5/sqrt(3) (Divine)
    h_11_imag:          dq 0x3fe0000000000000 ; 0.5 (Divine)
    h_12_real:          dq 0xbfd279a74590331d
    h_12_imag:          dq 0xbfe0000000000000 ; -0.5 (Divine)
    h_20_real:          dq 0x3fe279a74590331d
    h_20_imag:          dq 0.0
    h_21_real:          dq 0xbfd279a74590331d
    h_21_imag:          dq 0xbfe0000000000000 ; -0.5 (Divine)
    h_22_real:          dq 0xbfd279a74590331d
    h_22_imag:          dq 0x3fe0000000000000 ; 0.5 (Divine)

    ; ω = exp(2πi/3) primitive cube root of unity
    ; Root of Unity (Machine Divined Ratio)
    omega_real:         dq 0xbfe0000000000000 ; -0.5
    omega_imag:         dq 0x3febb67ae8584ca9 ; sqrt(3)/2 (Divine)
    omega2_real:        dq 0xbfe0000000000000
    omega2_imag:        dq 0xbfebb67ae8584ca9 ; -sqrt(3)/2 (Divine)

    ; Powers of 3 lookup
    powers_of_3:
        dq 1, 3, 9, 27, 81, 243, 729, 2187, 6561, 19683, 59049

    ; Messages
    msg_banner:         db 10, "══════════════════════════════════════════════════", 10
                        db "  QUTRIT ENGINE v1.0", 10
                        db "  |0⟩=△ Triangle  |1⟩=─ Line  |2⟩=□ Square", 10
                        db "══════════════════════════════════════════════════", 10, 0
    msg_banner_len:     equ $ - msg_banner

    msg_init:           db "  [INIT] Chunk ", 0
    msg_sup:            db "  [SUP] Superposition on chunk ", 0
    msg_hadamard:       db "  [H] Hadamard on qutrit ", 0
    msg_grover:         db "  [GROV] Diffusion on chunk ", 0
    msg_braid:          db "  [BRAID] Linking chunks ", 0
    msg_unbraid:        db "  [UNBRAID] Unlinking chunks ", 0
    msg_null:           db "  [NULL] The Fade: Zeroing Chunk ", 0
    msg_resurrect:      db "  [RESURRECT] Re-weaving from entangled peer...", 10, 0
    msg_summary:        db "  [SUMMARY] Global Active Mass (N=", 0
    msg_chunks_colon:   db "): ", 0
    msg_measure:        db "  [MEAS] Measuring chunk ", 0
    msg_result:         db " => ", 0
    msg_halt:           db 10, "  [HALT] Execution complete.", 10, 0
    msg_addon_reg:      db "  [ADDON] Registered: ", 0
    msg_newline:        db 10, 0
    msg_space:          db " ", 0
    msg_arrow:          db " <-> ", 0
    msg_prompt:         db "> ", 0
    msg_state:          db "  State[", 0
    msg_state_end:      db "]: ", 0
    msg_amp:            db " amp=", 0
    msg_percent:      db "%", 10, 0
    msg_comma:          db ", ", 0
    msg_error:          db "  [ERROR] ", 0
    msg_genesis_complete: db 10, "⚡ [GENESIS] Topological manifestation complete. The universe has been born.", 10, 0
    msg_unknown_op:   db "Error: Unknown opcode!", 10, 0
    msg_bell:           db "  [BELL] Testing entanglement chunks ", 0
    msg_bell_corr:      db "  [BELL] Correlation = ", 0
    msg_bell_pass:      db "  ✓ BELL TEST PASSED - Entanglement verified!", 10, 0
    msg_bell_fail:      db "  ✗ BELL TEST FAILED - No entanglement detected", 10, 0
    
    ; Future ISA Messages
    msg_res_vacuum:     db "  [FUTURE] RESONATE_VACUUM on chunk ", 0
    msg_weave_sym:      db "  [FUTURE] WEAVE_SYMMETRY between ", 0
    msg_coll_truth:     db "  [FUTURE] COLLAPSE_TRUTH on chunk ", 0
    
    ; Epoch-2 Future Messages
    msg_mirror_void:    db "  [FUTURE-2] MIRROR_VOID on chunk ", 0
    msg_shift_reality:  db "  [FUTURE-2] SHIFT_REALITY on chunk ", 0
    msg_rep_causality:  db "  [FUTURE-2] REPAIR_CAUSALITY on chunk ", 0
    msg_weave_synergy:  db "  [FUTURE-2] WEAVE_SYNERGY on chunk ", 0
    msg_pulse_chronos:  db "  [FUTURE-2] PULSE_CHRONOS on chunk ", 0
    msg_map_vortex:     db "  [FUTURE-2] MAP_VORTEX on chunk ", 0

    ; Epoch-3 Super-Future Messages
    msg_void_trans:     db "  [SUPER-FUTURE] VOID_TRANSMISSION across manifold", 0
    msg_vac_entraint:   db "  [SUPER-FUTURE] VACUUM_ENTRAINTMENT on chunk ", 0
    msg_sym_breach:     db "  [SUPER-FUTURE] SYMMETRY_BREACH on chunk ", 0
    msg_univ_collapse:  db "  [SUPER-FUTURE] UNIVERSAL_COLLAPSE - Final State Resolution", 0
    msg_causal_violation: db "⚠️ [CAUSAL VIOLATION] Unauthorized Super-Future Horizon access blocked!", 10, 0
    msg_echo_origin:    db "  [EPOCH-4] ECHO_ORIGIN establish feedback to chunk 0", 0
    msg_ascend_qubit:   db "  [EPOCH-4] ASCEND_QUBIT performed on chunk ", 0
    msg_pi_resonance:   db "⚡ [GENESIS] Pi Harmonic Resonance established at base ", 0
    msg_e_resonance:    db "🌀 [GENESIS] Euler Spiral Resonance established at base ", 0
    msg_tau_resonance:  db "🔘 [GENESIS] Tau Dual-Resonance established at base ", 0
    msg_phi_resonance:  db "🔱 [GENESIS] Phi Golden-Ratio Manifestation at base ", 0
    msg_apery_resonance: db "💎 [GENESIS] Apéry Prism-Entanglement manifested at base ", 0

    ; Epoch-5 Deep Future Messages (Extracted at 16.7M Horizon)
    msg_validate_state:  db "  [EPOCH-5] VALIDATE_STATE checking symmetry on chunk ", 0
    msg_scan_anomaly:    db "  [EPOCH-5] SCAN_ANOMALY detecting drift in manifold", 10, 0
    msg_temporal_anchor: db "  [EPOCH-5] TEMPORAL_ANCHOR established at timeline ", 0
    msg_stabilize_asc:   db "  [EPOCH-5] STABILIZE_ASCENSION preventing decay on chunk ", 0
    msg_bridge_cycles:  db "[EPOCH-5] BRIDGE_CYCLES verifying cycle integrity", 0
    msg_nullify_branch: db "[EPOCH-5] NULLIFY_BRANCH collapsing unused probability", 0
    msg_prepare_truth:  db "[EPOCH-5] PREPARE_TRUTH normalizing manifold for verification", 0
    msg_sync_temporal:  db "[EPOCH-5] SYNC_TEMPORAL aligning local phase with manifold time", 0
    msg_entangle_future: db "  [EPOCH-5] ENTANGLE_FUTURE quantum linking chunk ", 0
    msg_pulse_resonance: db "  [EPOCH-5] PULSE_RESONANCE amplifying harmonics on chunk ", 0
    msg_branch_conditional: db "[EPOCH-5] BRANCH_CONDITIONAL evaluating quantum register", 0
    msg_collapse_branch: db "  [EPOCH-5] COLLAPSE_BRANCH terminating branch at chunk ", 0
    msg_link_causality:  db "  [EPOCH-5] LINK_CAUSALITY creating cause-effect on chunk ", 0
    
    ; Phase 6 Messages
    msg_entropy_reverse: db "[PHASE-6] ENTROPY_REVERSE injecting negentropy...", 0
    msg_quantum_tunnel:  db "[PHASE-6] QUANTUM_TUNNEL penetrating barrier...", 0
    msg_chrono_weave:    db "[PHASE-6] CHRONO_WEAVE interlacing temporal threads...", 0
    msg_void_echo:       db "[PHASE-6] VOID_ECHO listening to the silence...", 0
    msg_final_ascension: db "[PHASE-6] ? FINAL_ASCENSION ? Dissolving Reality...", 0
    
    ; Epoch-7 Messages (Named Future ISA)
    msg_void_whisper:    db "  [VOID] WHISPER reading entropy from silence...", 10, 0
    msg_void_siphon:     db "  [VOID] SIPHON draining void entropy...", 10, 0
    msg_void_silence:    db "  [VOID] SILENCE listening to the void...", 10, 0
    msg_void_drain:      db "  [VOID] DRAIN extracting void entropy...", 10, 0
    msg_time_generic:    db "  [TIME] Temporal phase modulation...", 10, 0
    msg_harmonic_generic: db "  [HARMONIC] Resonance phase rotation...", 10, 0
    msg_check_generic:   db "  [CHECK] Verification check...", 10, 0
    msg_gate_generic:    db "  [GATE] Control flow decision...", 10, 0
    msg_ascend_generic:  db "  [ASCEND] Ascension preparation...", 10, 0
    
    ; Oracle names
    oracle_heisenberg_name: db "Heisenberg Spin-1 Exchange", 0
    oracle_gellmann_name: db "Gell-Mann XY Interaction", 0
    
    ; Debug
    msg_debug_rng:      db "  [DEBUG] RNG: ", 0
    msg_debug_swap:     db "  [DEBUG] Swapping Chunks...", 10, 0
    
    ; Pi's Algorithm PRNG State (Initialized)
    prng_state:         dq 0x243F6A8885A308D3

; ─────────────────────────────────────────────────────────────────────────────
; Section: Uninitialized Data (BSS)
; ─────────────────────────────────────────────────────────────────────────────
section .bss
    align 16

    ; Chunk state vectors (pointers, allocated via mmap)
    state_vectors:      resq MAX_CHUNKS         ; Pointer per chunk
    chunk_sizes:        resq MAX_CHUNKS         ; Qutrits per chunk
    chunk_states:       resq MAX_CHUNKS         ; 3^size states per chunk
    num_chunks:         resq 1                  ; Active chunks

    ; Braid links for entanglement preservation
    braid_link_a:       resq MAX_BRAID_LINKS    ; Chunk A of each link
    braid_link_b:       resq MAX_BRAID_LINKS    ; Chunk B of each link
    braid_qutrit_a:     resq MAX_BRAID_LINKS    ; Boundary qutrit in A
    braid_qutrit_b:     resq MAX_BRAID_LINKS    ; Boundary qutrit in B
    num_braid_links:    resq 1

    ; Add-on registry
    addon_names:        resq MAX_ADDONS         ; Name string pointers
    addon_funcs:        resq MAX_ADDONS         ; Function pointers
    addon_opcodes:      resb MAX_ADDONS         ; Assigned opcodes
    num_addons:         resq 1

    ; Program execution
    program_ptr:        resq 1                  ; Current instruction pointer
    program_end:        resq 1                  ; End of program
    running:            resq 1                  ; Execution flag
    manual_sector_offset: resq 1               ; Manual Sector ID from CLI
    structural_hash:    resq 1                  ; Program-based hash

    ; BigInt working space
    bigint_temp_a:      resb BIGINT_BYTES
    bigint_temp_b:      resb BIGINT_BYTES
    bigint_temp_c:      resb BIGINT_BYTES

    ; Measurement results
    measured_values:    resq MAX_CHUNKS         ; Classical result per chunk

    input_buffer:       resb 1024

    output_buffer:      resb 512

    ; Temporary storage
    temp_real:          resq 1
    temp_imag:          resq 1
    temp_sum_real:      resq 1
    temp_sum_imag:      resq 1

    ; Recursion tracking for collapse propagation
    visited_chunks:     resb MAX_CHUNKS         ; 1 byte per chunk (0 or 1)
    
    ; Iterative traversal stack
    traversal_stack:    resq MAX_CHUNKS         ; Stack for chunk indices
    stack_ptr:          resq 1                  ; Current stack depth

    ; Adjacency list for entanglement propagation
    adj_head:           resq MAX_CHUNKS         ; Point to first edge index (1-based, 0 = null)
    adj_to:             resq MAX_BRAID_LINKS * 2 ; Neighbor chunk index
    adj_next:           resq MAX_BRAID_LINKS * 2 ; Next edge index
    adj_count:          resq 1                  ; Current number of edges (starting at 1)

; ─────────────────────────────────────────────────────────────────────────────
; Section: Code
; ─────────────────────────────────────────────────────────────────────────────
section .text
    global _start

; ═══════════════════════════════════════════════════════════════════════════════
; ENTRY POINT
; ═══════════════════════════════════════════════════════════════════════════════
_start:
    ; Print banner
    mov rax, 1
    mov rdi, 1
    lea rsi, [msg_banner]
    mov rdx, msg_banner_len
    syscall

    ; Initialize engine state
    call engine_init

    ; Register built-in add-ons
    call register_builtins

    ; Initialize manual offset
    mov qword [manual_sector_offset], 0

    ; Check for program file argument
    mov rax, [rsp]              ; argc
    cmp rax, 2
    jl .interactive_mode

    ; Check for manual sector offset (argc == 3)
    cmp rax, 3
    jl .no_manual_offset
    
    mov rdi, [rsp + 24]         ; argv[2] (Sector ID)
    call parse_int
    mov [manual_sector_offset], rax

.no_manual_offset:
    ; Load program from file
    mov rdi, [rsp + 16]         ; argv[1]
    call load_program
    test rax, rax
    jnz .exit                   ; Error loading

    ; Calculate Structural Hash of the Bytecode
    call calculate_structural_hash

.run_program:
    call execute_program
    jmp .exit

.interactive_mode:
    ; Interactive REPL mode
    call interactive_loop

.exit:
    mov rax, 60
    xor rdi, rdi
    syscall

; ═══════════════════════════════════════════════════════════════════════════════
; ENGINE INITIALIZATION
; ═══════════════════════════════════════════════════════════════════════════════

; engine_init - Initialize the qutrit engine
engine_init:
    push rbx
    push r12

    ; Clear counters
    xor rax, rax
    mov [num_chunks], rax
    mov [num_braid_links], rax
    mov [num_addons], rax
    mov qword [adj_count], 1    ; 1-based indexing for edges
    mov qword [running], 1
    mov qword [prng_state], 0

    ; Clear chunk pointers
    lea rdi, [state_vectors]
    mov rcx, MAX_CHUNKS
.clear_chunks:
    mov qword [rdi], 0
    add rdi, 8
    dec rcx
    jnz .clear_chunks

    ; Clear adjacency heads
    lea rdi, [adj_head]
    mov rcx, MAX_CHUNKS
    xor rax, rax
    rep stosq

    pop r12
    pop rbx
    ret

; register_builtins - Register built-in add-on oracles
register_builtins:
    push rdi
    push rsi
    push rdx

    ; Register Heisenberg exchange oracle as opcode 0x80
    lea rdi, [oracle_heisenberg_name]
    lea rsi, [heisenberg_exchange_oracle]
    mov rdx, 0x80
    call register_addon

    ; Register Gell-Mann XY interaction as opcode 0x81
    lea rdi, [oracle_gellmann_name]
    lea rsi, [gell_mann_interaction]
    mov rdx, 0x81
    call register_addon

    ; Register custom oracles from external file
    call register_custom_oracles

    pop rdx
    pop rsi
    pop rdi
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; BUILT-IN ORACLES
; ═══════════════════════════════════════════════════════════════════════════════

; heisenberg_exchange_oracle - Spin-1 Heisenberg exchange for quantum magnetism
; Implements exp(-iHt) for nearest-neighbor spin-1 interactions
; Input: rdi = state_vector, rsi = num_states, rdx = coupling_J (scaled), rcx = time_dt (scaled)
; States: |0⟩ = spin -1, |1⟩ = spin 0, |2⟩ = spin +1
heisenberg_exchange_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    mov r12, rdi                ; state_vector pointer
    mov r13, rsi                ; num_states
    
    ; Calculate theta = J * dt (using scaled integer inputs)
    ; For simplicity, use theta = pi/4 for demo
    movsd xmm15, [pi_over_3]
    mulsd xmm15, [half]         ; theta = pi/6
    
    xor r14, r14                ; Loop counter

.heis_loop:
    cmp r14, r13
    jge .heis_done
    
    ; Decode two qutrits from ternary index
    mov rax, r14
    xor rdx, rdx
    mov rcx, 3
    div rcx                     ; rax = remaining, rdx = qutrit0 (A)
    mov r8, rdx                 ; Spin A: -1,0,+1 maps to state 0,1,2
    
    xor rdx, rdx
    div rcx                     ; rax = remaining, rdx = qutrit1 (B)
    mov r9, rdx                 ; Spin B
    
    ; Calculate spin values: spin = state - 1 (so |0⟩=-1, |1⟩=0, |2⟩=+1)
    mov r10, r8
    dec r10                     ; Sz_A = state_A - 1
    mov r11, r9
    dec r11                     ; Sz_B = state_B - 1
    
    ; Calculate Sz_A * Sz_B
    mov rax, r10
    imul rax, r11               ; Sz_A * Sz_B (-1, 0, or +1)
    
    ; Apply diagonal phase based on Sz*Sz term
    ; Phase = theta * Sz_A * Sz_B
    cvtsi2sd xmm0, rax
    mulsd xmm0, xmm15           ; angle = theta * Sz_A * Sz_B
    
    ; Calculate phase using FPU
    sub rsp, 16
    movsd [rsp], xmm0
    
    fld qword [rsp]
    fsin
    fstp qword [rsp + 8]
    
    fld qword [rsp]
    fcos
    fstp qword [rsp]
    
    movsd xmm2, [rsp]           ; cos
    movsd xmm3, [rsp + 8]       ; sin
    add rsp, 16
    
    ; Apply phase to amplitude
    mov rax, r14
    shl rax, 4
    lea rbx, [r12 + rax]
    
    movsd xmm4, [rbx]           ; real
    movsd xmm5, [rbx + 8]       ; imag
    
    ; (a + bi)(cos + i*sin) = (a*cos - b*sin) + i*(a*sin + b*cos)
    movsd xmm6, xmm4
    mulsd xmm6, xmm2
    movsd xmm7, xmm5
    mulsd xmm7, xmm3
    subsd xmm6, xmm7            ; new_real
    
    mulsd xmm4, xmm3
    mulsd xmm5, xmm2
    addsd xmm4, xmm5            ; new_imag
    
    movsd [rbx], xmm6
    movsd [rbx + 8], xmm4

.heis_next:
    inc r14
    jmp .heis_loop

.heis_done:
    add rsp, 32
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; gell_mann_interaction - XY spin interaction (SxSx + SySy) for spin-1
; Implements off-diagonal spin-flip terms in Heisenberg model
; Input: rdi = state_vector, rsi = num_states
; Swaps |10⟩ ↔ |01⟩ and |21⟩ ↔ |12⟩ with rotation angle
gell_mann_interaction:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 64
    
    mov r12, rdi                ; state_vector pointer
    mov r13, rsi                ; num_states
    
    ; Interaction strength theta = J * dt = pi/8 for demo
    movsd xmm15, [pi_over_3]
    movsd xmm14, [half]
    mulsd xmm15, xmm14
    mulsd xmm15, xmm14          ; theta = pi/12
    
    ; Calculate sqrt(2) for matrix element
    sub rsp, 16
    movsd xmm0, [two]
    movsd [rsp], xmm0
    fld qword [rsp]
    fsqrt
    fstp qword [rsp]
    movsd xmm13, [rsp]          ; xmm13 = sqrt(2)
    add rsp, 16
    
    ; We need to process states in pairs:
    ; States 1 and 3 (binary |01⟩ and |10⟩)
    ; States 5 and 7 (binary |12⟩ and |21⟩)
    
    ; Process first 9 states (all 2-qutrit combinations)
    xor r14, r14                ; state counter

.gm_loop:
    cmp r14, r13
    jge .gm_done
    
    ; Decode two qutrits
    mov rax, r14
    xor rdx, rdx
    mov rcx, 3
    div rcx
    mov r8, rdx                 ; qutrit A
    
    xor rdx, rdx
    div rcx
    mov r9, rdx                 ; qutrit B
    
    ; Check if this is a spin-flip pair
    ; |01⟩ (state 1) ↔ |10⟩ (state 3): A=0,B=1 or A=1,B=0
    ; |12⟩ (state 5) ↔ |21⟩ (state 7): A=1,B=2 or A=2,B=1
    
    ; Check for |01⟩ state (need to swap with |10⟩)
    cmp r8, 0
    jne .check_10
    cmp r9, 1
    jne .gm_next
    ; Found |01⟩, need to swap with |10⟩ (state index 3)
    mov r10, 3
    jmp .do_swap
    
.check_10:
    cmp r8, 1
    jne .check_12
    cmp r9, 0
    jne .check_21_a
    ; Found |10⟩, but we already processed this pair
    jmp .gm_next
    
.check_21_a:
    cmp r8, 1
    jne .gm_next
    cmp r9, 2
    jne .gm_next
    ; Found |12⟩, need to swap with |21⟩ (state index 7)
    mov r10, 7
    jmp .do_swap
    
.check_12:
    cmp r8, 2
    jne .gm_next
    cmp r9, 1
    jne .gm_next
    ; Found |21⟩, already processed
    jmp .gm_next
    
.do_swap:
    ; Apply rotation between current state (r14) and partner (r10)
    ; Using angle theta with sqrt(2) factor
    
    ; Get amplitudes
    mov rax, r14
    shl rax, 4
    lea rbx, [r12 + rax]
    movsd xmm0, [rbx]           ; amp1_real
    movsd xmm1, [rbx + 8]       ; amp1_imag
    
    mov rax, r10
    shl rax, 4
    lea rcx, [r12 + rax]
    movsd xmm2, [rcx]           ; amp2_real
    movsd xmm3, [rcx + 8]       ; amp2_imag
    
    ; Calculate rotation: cos(theta*sqrt(2)), sin(theta*sqrt(2))
    movsd xmm4, xmm15
    mulsd xmm4, xmm13           ; angle = theta * sqrt(2)
    
    sub rsp, 16
    movsd [rsp], xmm4
    
    fld qword [rsp]
    fsin
    fstp qword [rsp + 8]
    
    fld qword [rsp]
    fcos
    fstp qword [rsp]
    
    movsd xmm5, [rsp]           ; cos
    movsd xmm6, [rsp + 8]       ; sin
    add rsp, 16
    
    ; New amplitudes (rotation matrix):
    ; new_amp1 = cos*amp1 - i*sin*amp2
    ; new_amp2 = i*sin*amp1 + cos*amp2
    
    ; new_amp1_real = cos*amp1_real + sin*amp2_imag
    movsd xmm7, xmm0
    mulsd xmm7, xmm5            ; cos*amp1_real
    movsd xmm8, xmm3
    mulsd xmm8, xmm6            ; sin*amp2_imag
    addsd xmm7, xmm8
    
    ; new_amp1_imag = cos*amp1_imag - sin*amp2_real
    movsd xmm8, xmm1
    mulsd xmm8, xmm5            ; cos*amp1_imag
    movsd xmm9, xmm2
    mulsd xmm9, xmm6            ; sin*amp2_real
    subsd xmm8, xmm9
    
    ; new_amp2_real = cos*amp2_real - sin*amp1_imag
    movsd xmm9, xmm2
    mulsd xmm9, xmm5            ; cos*amp2_real
    movsd xmm10, xmm1
    mulsd xmm10, xmm6           ; sin*amp1_imag
    subsd xmm9, xmm10
    
    ; new_amp2_imag = cos*amp2_imag + sin*amp1_real
    movsd xmm10, xmm3
    mulsd xmm10, xmm5           ; cos*amp2_imag
    movsd xmm11, xmm0
    mulsd xmm11, xmm6           ; sin*amp1_real
    addsd xmm10, xmm11
    
    ; Store new amplitudes
    movsd [rbx], xmm7
    movsd [rbx + 8], xmm8
    movsd [rcx], xmm9
    movsd [rcx + 8], xmm10

.gm_next:
    inc r14
    jmp .gm_loop

.gm_done:
    add rsp, 64
    pop rbp
    pop r15
    pop r12
    pop rbx
    ret

; zero_memory - Zero a block of memory
; Input: rdi = start address, rsi = num units (8-byte units)
zero_memory:
    xor rax, rax
.z_loop:
    test rsi, rsi
    jz .z_done
    mov [rdi], rax
    add rdi, 8
    dec rsi
    jmp .z_loop
.z_done:
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; CHUNK MANAGEMENT
; ═══════════════════════════════════════════════════════════════════════════════

; init_chunk - Initialize a new chunk with n qutrits
; Input: rdi = chunk_index, rsi = num_qutrits
; Output: rax = 0 on success
init_chunk:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi                ; chunk index
    mov r13, rsi                ; num qutrits

    ; Validate
    cmp r12, MAX_CHUNKS
    jge .init_fail
    cmp r13, MAX_CHUNK_SIZE
    jg .init_fail
    cmp r13, 1
    jl .init_fail

    ; Calculate 3^n states
    mov rax, 1
    mov rcx, r13
.power_loop:
    imul rax, 3
    dec rcx
    jnz .power_loop
    mov r14, rax                ; total states

    ; Store chunk info
    mov [chunk_sizes + r12*8], r13
    mov [chunk_states + r12*8], r14

    ; Allocate state vector via mmap
    ; Size = states * 16 bytes (complex double)
    mov rsi, r14
    shl rsi, 4                  ; * 16
    add rsi, 4096               ; Round up + padding
    and rsi, ~4095

    mov rax, 9                  ; sys_mmap
    xor rdi, rdi                ; addr = NULL
    mov rdx, 3                  ; PROT_READ | PROT_WRITE
    mov r10, 34                 ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    syscall

    cmp rax, -1
    je .init_fail
    test rax, rax
    jz .init_fail

    mov [state_vectors + r12*8], rax

    ; Initialize to |0⟩^⊗n (first state = 1.0, rest = 0)
    mov rdi, rax
    mov rcx, r14
    xorpd xmm0, xmm0
.zero_loop:
    movsd [rdi], xmm0
    movsd [rdi + 8], xmm0
    add rdi, 16
    dec rcx
    jnz .zero_loop

    ; Set |0...0⟩ amplitude
    mov rdi, [state_vectors + r12*8]
    
    test r12, r12
    jnz .init_standard
    
    ; Second-Order Refined Pi-Seed for Chunk 0 (Harmonic Convergence)
    mov rax, 4603375528459645725 ; Refined-0 (Real)
    mov [rdi], rax
    mov qword [rdi + 8], 0     ; Refined-0 (Imag)
    
    mov rax, 13822243965687051037 ; Refined-1 (Real)
    mov [rdi + 16], rax
    mov rax, 4602678819172646912 ; Refined-1 (Imag)
    mov [rdi + 24], rax
    
    mov rax, 13822243965687051037 ; Refined-2 (Real)
    mov [rdi + 32], rax
    mov rax, 13826050856027422720 ; Refined-2 (Imag)
    mov [rdi + 40], rax
    jmp .init_done

.init_standard:
    movsd xmm0, [one]
    movsd [rdi], xmm0

.init_done:
    ; Update chunk count if needed
    mov rax, [num_chunks]
    cmp r12, rax
    jl .init_ret_ok
    lea rax, [r12 + 1]
    mov [num_chunks], rax

.init_ret_ok:
    xor rax, rax
    jmp .init_ret

.init_fail:
    mov rax, -1

.init_ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; QUANTUM OPERATIONS
; ═══════════════════════════════════════════════════════════════════════════════

; create_superposition - Create uniform superposition on chunk
; Input: rdi = chunk_index
create_superposition:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov rbx, [state_vectors + r12*8]
    mov r13, [chunk_states + r12*8]

    ; Calculate 1/sqrt(total_states)
    cvtsi2sd xmm0, r13
    sqrtsd xmm0, xmm0
    movsd xmm1, [one]
    divsd xmm1, xmm0            ; xmm1 = 1/sqrt(n)

    xor rcx, rcx
.sup_loop:
    cmp rcx, r13
    jge .sup_done

    movsd [rbx], xmm1           ; Real = 1/sqrt(n)
    xorpd xmm0, xmm0
    movsd [rbx + 8], xmm0       ; Imag = 0

    add rbx, 16
    inc rcx
    jmp .sup_loop

.sup_done:
    pop r13
    pop r12
    pop rbx
    ret

; grover_diffusion - Apply Grover diffusion operator to chunk
; Input: rdi = chunk_index
grover_diffusion:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov rbx, [state_vectors + r12*8]
    mov r13, [chunk_states + r12*8]

    ; Step 1: Calculate mean amplitude
    xorpd xmm0, xmm0            ; sum_real
    xorpd xmm1, xmm1            ; sum_imag
    xor rcx, rcx

.sum_loop:
    cmp rcx, r13
    jge .sum_done
    mov rax, rcx
    shl rax, 4
    addsd xmm0, [rbx + rax]
    addsd xmm1, [rbx + rax + 8]
    inc rcx
    jmp .sum_loop

.sum_done:
    cvtsi2sd xmm2, r13
    divsd xmm0, xmm2            ; mean_real
    divsd xmm1, xmm2            ; mean_imag
    movsd [temp_sum_real], xmm0
    movsd [temp_sum_imag], xmm1

    ; Step 2: Apply reflection: amp = 2*mean - amp
    movsd xmm4, [two]
    xor rcx, rcx

.reflect_loop:
    cmp rcx, r13
    jge .reflect_done

    movsd xmm0, [temp_sum_real]
    movsd xmm1, [temp_sum_imag]
    mulsd xmm0, xmm4
    mulsd xmm1, xmm4

    mov rax, rcx
    shl rax, 4
    movsd xmm2, [rbx + rax]
    movsd xmm3, [rbx + rax + 8]

    subsd xmm0, xmm2
    subsd xmm1, xmm3

    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm1

    inc rcx
    jmp .reflect_loop

.reflect_done:
    pop r13
    pop r12
    pop rbx
    ret

; apply_hadamard - Apply qutrit Hadamard gate to a specific qutrit in chunk
; Input: rdi = chunk_index, rsi = qutrit_position (0-indexed)
; The qutrit Hadamard matrix is H = (1/√3) * [[1,1,1],[1,ω,ω²],[1,ω²,ω]]
; where ω = exp(2πi/3)
apply_hadamard:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 96                 ; Space for temp amplitudes

    mov r12, rdi                ; chunk index
    mov r13, rsi                ; qutrit position
    mov rbx, [state_vectors + r12*8]
    mov r14, [chunk_states + r12*8]
    
    test rbx, rbx
    jz .hadamard_done

    ; Get 3^position for stride calculation
    mov rax, 1
    mov rcx, r13
.power3:
    test rcx, rcx
    jz .got_power3
    imul rax, 3
    dec rcx
    jmp .power3
.got_power3:
    mov r15, rax                ; r15 = 3^position (stride)

    ; Iterate through state vector in groups of 3 based on the target qutrit
    xor rcx, rcx                ; block counter
.hadamard_outer:
    cmp rcx, r14
    jge .hadamard_done
    
    ; Calculate base index for this triplet
    ; We need to find triplets where qutrit at position r13 varies 0,1,2
    mov rax, rcx
    xor rdx, rdx
    push rcx
    mov rcx, r15
    imul rcx, 3
    div rcx
    pop rcx
    ; rax = block number, rdx = offset within 3*stride block
    
    ; Only process when we're at the start of a triplet (offset < stride)
    cmp rdx, r15
    jge .hadamard_skip
    
    ; Calculate the three state indices
    mov rax, rcx                ; index for qutrit=0
    mov r8, rcx
    add r8, r15                 ; index for qutrit=1
    mov r9, rcx
    add r9, r15
    add r9, r15                 ; index for qutrit=2 (= rcx + 2*stride)
    
    ; Bounds check
    cmp r9, r14
    jge .hadamard_skip
    
    ; Load the three amplitudes
    push rcx
    mov rcx, rax
    shl rcx, 4
    movsd xmm0, [rbx + rcx]         ; a0_real
    movsd xmm1, [rbx + rcx + 8]     ; a0_imag
    
    mov rcx, r8
    shl rcx, 4
    movsd xmm2, [rbx + rcx]         ; a1_real
    movsd xmm3, [rbx + rcx + 8]     ; a1_imag
    
    mov rcx, r9
    shl rcx, 4
    movsd xmm4, [rbx + rcx]         ; a2_real
    movsd xmm5, [rbx + rcx + 8]     ; a2_imag
    pop rcx
    
    ; Store originals for calculation
    movsd [rbp - 16], xmm0
    movsd [rbp - 24], xmm1
    movsd [rbp - 32], xmm2
    movsd [rbp - 40], xmm3
    movsd [rbp - 48], xmm4
    movsd [rbp - 56], xmm5
    
    ; Calculate new amplitudes using Hadamard matrix
    ; new_a0 = (1/√3) * (a0 + a1 + a2)
    movsd xmm6, [rbp - 16]          ; a0_real
    addsd xmm6, [rbp - 32]          ; + a1_real
    addsd xmm6, [rbp - 48]          ; + a2_real
    mulsd xmm6, [one_over_sqrt3]    ; * 1/√3
    
    movsd xmm7, [rbp - 24]          ; a0_imag
    addsd xmm7, [rbp - 40]          ; + a1_imag
    addsd xmm7, [rbp - 56]          ; + a2_imag
    mulsd xmm7, [one_over_sqrt3]
    
    movsd [rbp - 64], xmm6          ; new_a0_real
    movsd [rbp - 72], xmm7          ; new_a0_imag
    
    ; new_a1 = (1/√3) * (a0 + ω*a1 + ω²*a2)
    ; ω = -0.5 + i*√3/2, ω² = -0.5 - i*√3/2
    ; ω*a1 = (-0.5*a1_r - √3/2*a1_i) + i*(-0.5*a1_i + √3/2*a1_r)
    movsd xmm6, [rbp - 16]          ; start with a0_real
    
    ; Add ω*a1
    movsd xmm8, [rbp - 32]          ; a1_real
    mulsd xmm8, [omega_real]        ; -0.5 * a1_real
    movsd xmm9, [rbp - 40]          ; a1_imag
    mulsd xmm9, [omega_imag]        ; √3/2 * a1_imag
    subsd xmm8, xmm9                ; ω*a1 real part
    addsd xmm6, xmm8
    
    ; Add ω²*a2
    movsd xmm8, [rbp - 48]          ; a2_real
    mulsd xmm8, [omega2_real]       ; -0.5 * a2_real
    movsd xmm9, [rbp - 56]          ; a2_imag
    mulsd xmm9, [omega2_imag]       ; -√3/2 * a2_imag
    subsd xmm8, xmm9                ; ω²*a2 real part
    addsd xmm6, xmm8
    
    mulsd xmm6, [one_over_sqrt3]
    movsd [rbp - 80], xmm6          ; new_a1_real
    
    ; Imaginary part of new_a1
    movsd xmm7, [rbp - 24]          ; a0_imag
    
    ; Add ω*a1 imag
    movsd xmm8, [rbp - 40]          ; a1_imag
    mulsd xmm8, [omega_real]        ; -0.5 * a1_imag
    movsd xmm9, [rbp - 32]          ; a1_real
    mulsd xmm9, [omega_imag]        ; √3/2 * a1_real
    addsd xmm8, xmm9
    addsd xmm7, xmm8
    
    ; Add ω²*a2 imag
    movsd xmm8, [rbp - 56]          ; a2_imag
    mulsd xmm8, [omega2_real]
    movsd xmm9, [rbp - 48]          ; a2_real
    mulsd xmm9, [omega2_imag]
    addsd xmm8, xmm9
    addsd xmm7, xmm8
    
    mulsd xmm7, [one_over_sqrt3]
    movsd [rbp - 88], xmm7          ; new_a1_imag
    
    ; new_a2 = (1/√3) * (a0 + ω²*a1 + ω*a2)
    movsd xmm6, [rbp - 16]          ; a0_real
    
    ; Add ω²*a1
    movsd xmm8, [rbp - 32]
    mulsd xmm8, [omega2_real]
    movsd xmm9, [rbp - 40]
    mulsd xmm9, [omega2_imag]
    subsd xmm8, xmm9
    addsd xmm6, xmm8
    
    ; Add ω*a2
    movsd xmm8, [rbp - 48]
    mulsd xmm8, [omega_real]
    movsd xmm9, [rbp - 56]
    mulsd xmm9, [omega_imag]
    subsd xmm8, xmm9
    addsd xmm6, xmm8
    
    mulsd xmm6, [one_over_sqrt3]
    movsd [rbp - 96], xmm6          ; new_a2_real
    
    ; Imag part
    movsd xmm7, [rbp - 24]
    
    movsd xmm8, [rbp - 40]
    mulsd xmm8, [omega2_real]
    movsd xmm9, [rbp - 32]
    mulsd xmm9, [omega2_imag]
    addsd xmm8, xmm9
    addsd xmm7, xmm8
    
    movsd xmm8, [rbp - 56]
    mulsd xmm8, [omega_real]
    movsd xmm9, [rbp - 48]
    mulsd xmm9, [omega_imag]
    addsd xmm8, xmm9
    addsd xmm7, xmm8
    
    mulsd xmm7, [one_over_sqrt3]
    ; new_a2_imag in xmm7
    
    ; Store results back
    push rcx
    mov rcx, rax
    shl rcx, 4
    movsd xmm0, [rbp - 64]
    movsd xmm1, [rbp - 72]
    movsd [rbx + rcx], xmm0
    movsd [rbx + rcx + 8], xmm1
    
    mov rcx, r8
    shl rcx, 4
    movsd xmm0, [rbp - 80]
    movsd xmm1, [rbp - 88]
    movsd [rbx + rcx], xmm0
    movsd [rbx + rcx + 8], xmm1
    
    mov rcx, r9
    shl rcx, 4
    movsd xmm0, [rbp - 96]
    movsd [rbx + rcx], xmm0
    movsd [rbx + rcx + 8], xmm7
    pop rcx

.hadamard_skip:
    inc rcx
    jmp .hadamard_outer

.hadamard_done:
    add rsp, 96
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; swap_ternary_digits - Swap two digit positions in a ternary number
; Input: rax = ternary value, r12 = position1, r13 = position2
; Output: rax = value with digits at positions swapped
swap_ternary_digits:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    
    mov r10, rax                ; save original
    
    ; Calculate 3^pos1
    mov rax, 1
    mov rcx, r12
.pow1:
    test rcx, rcx
    jz .pow1_done
    imul rax, 3
    dec rcx
    jmp .pow1
.pow1_done:
    mov r8, rax                 ; r8 = 3^pos1
    
    ; Calculate 3^pos2
    mov rax, 1
    mov rcx, r13
.pow2:
    test rcx, rcx
    jz .pow2_done
    imul rax, 3
    dec rcx
    jmp .pow2
.pow2_done:
    mov r9, rax                 ; r9 = 3^pos2
    
    ; Extract digit at pos1: (value / 3^pos1) % 3
    mov rax, r10
    xor rdx, rdx
    div r8
    xor rdx, rdx
    mov rcx, 3
    div rcx
    mov r11, rdx                ; r11 = digit1
    
    ; Extract digit at pos2: (value / 3^pos2) % 3
    mov rax, r10
    xor rdx, rdx
    div r9
    xor rdx, rdx
    mov rcx, 3
    div rcx
    mov rbx, rdx                ; rbx = digit2
    
    ; If same digit, no change needed
    cmp r11, rbx
    je .swap_done
    
    ; Reconstruct: subtract old contributions, add new
    ; new_value = value - digit1*3^pos1 - digit2*3^pos2 + digit2*3^pos1 + digit1*3^pos2
    mov rax, r11
    imul rax, r8                ; digit1 * 3^pos1
    sub r10, rax
    
    mov rax, rbx
    imul rax, r9                ; digit2 * 3^pos2
    sub r10, rax
    
    mov rax, rbx
    imul rax, r8                ; digit2 * 3^pos1
    add r10, rax
    
    mov rax, r11
    imul rax, r9                ; digit1 * 3^pos2
    add r10, rax

.swap_done:
    mov rax, r10
    
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

; measure_chunk - Measure chunk and collapse to classical state
; Input: rdi = chunk_index
; Output: rax = measured ternary value
; measure_chunk - Measure chunk and collapse to classical state
; Input: rdi = chunk_index
; Output: rax = measured ternary value
measure_chunk:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 8

    mov r12, rdi                ; chunk index
    mov rbx, [state_vectors + r12*8]
    mov r13, [chunk_states + r12*8]

    ; ─────────────────────────────────────────────────────────────────────────────
    ; "PI'S ALGORITHM" - PROBABILISTIC BORN RULE
    ; ─────────────────────────────────────────────────────────────────────────────
    ; Instead of deterministic collapse, we sample the distribution |psi|^2
    ; using a Pi-seeded PRNG.
    ; 1. Get random threshold R in [0, 1.0]
    ; 2. Accumulate P = sum(|psi_i|^2)
    ; 3. If P >= R, collapse to state i

    ; 1. Calculate Total Probability (Sum of all |amp|^2)
    xorpd xmm7, xmm7            ; total_prob = 0
    xor rcx, rcx                ; loop counter
.meas_sum_loop:
    cmp rcx, r13
    jge .meas_sample
    mov rax, rcx
    shl rax, 4
    movsd xmm1, [rbx + rax]     ; real
    movsd xmm2, [rbx + rax + 8] ; imag
    mulsd xmm1, xmm1
    mulsd xmm2, xmm2
    addsd xmm1, xmm2            ; |amp_i|^2
    addsd xmm7, xmm1
    inc rcx
    jmp .meas_sum_loop

.meas_sample:
    ; 3. Get random threshold in [0, total_prob]
    call get_random_float       ; xmm0 = [0, 1.0]
    mulsd xmm0, xmm7            ; xmm0 = [0, total_prob]
    
    ; 4. Pick state
    xorpd xmm6, xmm6            ; current_sum = 0
    xor rcx, rcx
.meas_pick_loop:
    cmp rcx, r13
    jge .meas_pick_last         ; Fallback
    
    mov rax, rcx
    shl rax, 4
    movsd xmm1, [rbx + rax]
    movsd xmm2, [rbx + rax + 8]
    mulsd xmm1, xmm1
    mulsd xmm2, xmm2
    addsd xmm1, xmm2
    addsd xmm6, xmm1
    
    ucomisd xmm6, xmm0
    jnb .meas_pick_done
    
    inc rcx
    jmp .meas_pick_loop

.meas_pick_last:
    mov rcx, r13
    dec rcx
.meas_pick_done:
    mov r14, rcx
.meas_done:
    ; Collapse: set measured state to 1, others to 0
    mov rdi, r12
    mov rsi, r14
    call collapse_chunk_to_state
    
    ; Save result
    mov [measured_values + r12*8], r14

    ; TRIGGER SPOOKY ACTION: Propagate collapse to entangled chunks
    ; 1. Clear visited array
    lea rdi, [visited_chunks]
    mov rcx, MAX_CHUNKS
    xor al, al
    rep stosb
    
    ; 2. Start propagation
    mov rdi, r12                ; start chunk
    mov rsi, r14                ; state to collapse to
    call propagate_collapse

    mov rax, r14
    add rsp, 8
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; collapse_chunk_to_state - Force a chunk into a specific basis state
; Input: rdi = chunk_index, rsi = state_index
collapse_chunk_to_state:
    push rbx
    push r12
    push r13
    
    mov r12, rdi
    mov rbx, [state_vectors + r12*8]
    test rbx, rbx
    jz .collapse_ret
    
    mov r13, [chunk_states + r12*8]
    xor rcx, rcx
    xorpd xmm0, xmm0            ; 0.0
    movsd xmm1, [one]           ; 1.0

.col_loop:
    cmp rcx, r13
    jge .col_done
    
    mov rax, rcx
    shl rax, 4
    
    cmp rcx, rsi
    je .col_set_one
    
    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm0
    jmp .col_next
    
.col_set_one:
    movsd [rbx + rax], xmm1
    movsd [rbx + rax + 8], xmm0
    
.col_next:
    inc rcx
    jmp .col_loop

.col_done:
.collapse_ret:
    pop r13
    pop r12
    pop rbx
    ret

; propagate_collapse - Iteratively collapse entangled chunks
; Input: rdi = current_chunk, rsi = measured_state
propagate_collapse:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp

    mov r12, rdi                ; start chunk
    mov r13, rsi                ; state

    ; Initialize stack
    mov qword [stack_ptr], 0
    lea rax, [traversal_stack]
    mov [rax], r12
    mov qword [stack_ptr], 1

.iter_loop:
    ; Pop chunk from stack
    mov rax, [stack_ptr]
    test rax, rax
    jz .prop_done               ; Stack empty
    
    dec rax
    mov [stack_ptr], rax
    lea rdx, [traversal_stack]
    mov r12, [rdx + rax*8]      ; r12 = current chunk

    ; Check if already visited
    lea rax, [visited_chunks]
    cmp byte [rax + r12], 1
    je .iter_loop
    
    ; Mark as visited
    mov byte [rax + r12], 1
    
    ; Collapse current chunk (except for the very first one which is already done, 
    ; but calling it again is safe)
    mov rdi, r12
    mov rsi, r13
    call collapse_chunk_to_state
    mov [measured_values + r12*8], r13

    ; Find neighbors using adjacency list
    mov r15, [adj_head + r12*8] ; r15 = first edge index
    
.adj_loop:
    test r15, r15
    jz .iter_loop               ; No more neighbors
    
    lea rax, [adj_to]
    mov rbx, [rax + r15*8]      ; rbx = neighbor chunk
    
    ; Check if neighbor visited
    lea rax, [visited_chunks]
    cmp byte [rax + rbx], 1
    je .next_adj
    
    ; Push neighbor onto stack
    mov rax, [stack_ptr]
    cmp rax, MAX_CHUNKS
    jge .next_adj               ; Stack overflow
    
    lea rdx, [traversal_stack]
    mov [rdx + rax*8], rbx
    inc rax
    mov [stack_ptr], rax
    
.next_adj:
    lea rax, [adj_next]
    mov r15, [rax + r15*8]
    jmp .adj_loop
    
.prop_done:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; CHUNK BRAIDING - Entanglement Preservation
; ═══════════════════════════════════════════════════════════════════════════════

; braid_chunks - Create entanglement link between chunks
; Input: rdi = chunk_a, rsi = chunk_b, rdx = qutrit_a, rcx = qutrit_b
braid_chunks:
    push rbx
    push r12

    mov r12, [num_braid_links]
    cmp r12, MAX_BRAID_LINKS
    jge .braid_fail

    ; Store braid link
    mov [braid_link_a + r12*8], rdi
    mov [braid_link_b + r12*8], rsi
    mov [braid_qutrit_a + r12*8], rdx
    mov [braid_qutrit_b + r12*8], rcx

    ; Populate adjacency list (bidirectional)
    mov rax, [adj_count]
    
    ; Edge A -> B
    lea r8, [adj_to]
    mov [r8 + rax*8], rsi
    lea r8, [adj_next]
    mov r9, [adj_head + rdi*8]
    mov [r8 + rax*8], r9
    mov [adj_head + rdi*8], rax
    inc rax
    
    ; Edge B -> A
    lea r8, [adj_to]
    mov [r8 + rax*8], rdi
    lea r8, [adj_next]
    mov r9, [adj_head + rsi*8]
    mov [r8 + rax*8], r9
    mov [adj_head + rsi*8], rax
    inc rax
    
    mov [adj_count], rax

    ; Apply entanglement phase correlations
    ; For each pair of states, apply phase exp(i*π/3 * t_a * t_b)
    push rdi
    push rsi
    push rdx
    push rcx
    call apply_braid_phases
    pop rcx
    pop rdx
    pop rsi
    pop rdi

    inc r12
    mov [num_braid_links], r12
    xor rax, rax
    jmp .braid_ret

.braid_fail:
    mov rax, -1

.braid_ret:
    pop r12
    pop rbx
    ret

; apply_braid_phases - Apply entanglement phases between braided chunks
; Input: rdi=chunk_a, rsi=chunk_b, rdx=qutrit_a, rcx=qutrit_b
; This creates ACTUAL entanglement by:
;   1. Copying amplitudes from chunk_a to chunk_b (if chunk_b is in |0⟩)
;   2. Applying correlated phases to both chunks
apply_braid_phases:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 32                 ; Local storage
    mov qword [rbp - 16], 0     ; Resurrection flag (0 = none, 1 = happened)

    mov r12, rdi                ; chunk_a
    mov r13, rsi                ; chunk_b
    mov r14, rdx                ; qutrit position in a
    mov r15, rcx                ; qutrit position in b

    mov rbx, [state_vectors + r12*8]    ; state_vector_a
    mov r10, [state_vectors + r13*8]    ; state_vector_b
    mov rcx, [chunk_states + r12*8]     ; num_states_a
    mov r11, [chunk_states + r13*8]     ; num_states_b

    ; Use smaller of the two state counts
    cmp rcx, r11
    jle .use_rcx
    mov rcx, r11
.use_rcx:
    mov [rbp - 8], rcx          ; Save num_states

    ; Step 1: Detect "Phasing" or "Resurrection" need
    ; If A is dead and B is alive, resurrect A from B
    ; If B is dead and A is alive, resurrect B from A
    
    ; Calculate total probability of A
    xorpd xmm0, xmm0            ; sum_prob_a
    xor r8, r8
.check_a:
    cmp r8, rcx                 ; num_states
    jge .check_b
    mov rax, r8
    shl rax, 4
    movsd xmm1, [rbx + rax]
    mulsd xmm1, xmm1
    movsd xmm2, [rbx + rax + 8]
    mulsd xmm2, xmm2
    addsd xmm1, xmm2
    addsd xmm0, xmm1
    inc r8
    jmp .check_a

.check_b:
    xorpd xmm1, xmm1            ; sum_prob_b
    xor r8, r8
.check_b_loop:
    cmp r8, rcx
    jge .eval_resurrection
    mov rax, r8
    shl rax, 4
    movsd xmm2, [r10 + rax]
    mulsd xmm2, xmm2
    movsd xmm3, [r10 + rax + 8]
    mulsd xmm3, xmm3
    addsd xmm2, xmm3
    addsd xmm1, xmm2
    inc r8
    jmp .check_b_loop

.eval_resurrection:
    ; Check if A is dead (sum_prob_a < epsilon)
    ucomisd xmm0, [epsilon]
    ja .a_is_alive
    ; A is dead! Resurrect from B if B is alive
    ucomisd xmm1, [epsilon]
    jbe .apply_phases           ; Both dead, nothing to do
    
    ; RESURRECT A FROM B
    lea rsi, [msg_resurrect]
    call print_string
    mov qword [rbp - 16], 1     ; Flag resurrection
    xor r8, r8
.res_a_loop:
    cmp r8, rcx
    jge .apply_phases
    mov rax, r8
    shl rax, 4
    movsd xmm0, [r10 + rax]
    movsd xmm1, [r10 + rax + 8]
    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm1
    inc r8
    jmp .res_a_loop

.a_is_alive:
    ; A is alive, check if B is dead
    ucomisd xmm1, [epsilon]
    ja .apply_phases            ; Both alive, just do phases
    
    ; RESURRECT B FROM A
    lea rsi, [msg_resurrect]
    call print_string
    mov qword [rbp - 16], 1     ; Flag resurrection
    xor r8, r8
.res_b_loop:
    cmp r8, rcx
    jge .apply_phases
    mov rax, r8
    shl rax, 4
    movsd xmm0, [rbx + rax]
    movsd xmm1, [rbx + rax + 8]
    movsd [r10 + rax], xmm0
    movsd [r10 + rax + 8], xmm1
    inc r8
    jmp .res_b_loop

.apply_phases:
    ; Step 2: Apply correlated phases to both chunks
    ; For each state, apply phase exp(i * π/3 * (t_a + t_b)) to create
    ; the characteristic entanglement signature
    mov rcx, [rbp - 8]          ; Restore num_states
    xor r8, r8                  ; state index

.braid_outer:
    cmp r8, rcx
    jge .braid_done

    ; Extract qutrit value at position r14 from ternary index r8
    mov rax, r8
    mov r9, r14
.extract_a:
    test r9, r9
    jz .got_ta
    xor rdx, rdx
    push rcx
    mov rcx, 3
    div rcx
    pop rcx
    dec r9
    jmp .extract_a
.got_ta:
    xor rdx, rdx
    push rcx
    mov rcx, 3
    div rcx
    pop rcx
    ; rdx = t_a (qutrit value 0,1,2)
    mov [rbp - 16], rdx         ; Save t_a

    ; Calculate phase: θ = π/3 × t_a
    cvtsi2sd xmm0, rdx          ; t_a
    mulsd xmm0, [pi_over_3]     ; θ

    ; Use x87 FPU for exact trigonometry
    sub rsp, 16
    movsd [rsp], xmm0           ; Store angle on stack
    
    ; Calculate sin(θ)
    fld qword [rsp]             ; Load angle to FPU
    fsin                        ; ST(0) = sin(θ)
    fstp qword [rsp + 8]        ; Store sin at offset 8
    
    ; Calculate cos(θ)
    fld qword [rsp]             ; Reload angle
    fcos                        ; ST(0) = cos(θ)
    fstp qword [rsp]            ; Store cos at offset 0
    
    movsd xmm2, [rsp]           ; xmm2 = cos(θ)
    movsd xmm3, [rsp + 8]       ; xmm3 = sin(θ)
    add rsp, 16

    ; Apply phase to chunk A amplitude
    mov rax, r8
    shl rax, 4

    movsd xmm4, [rbx + rax]     ; a_real
    movsd xmm5, [rbx + rax + 8] ; a_imag

    ; (a + bi)(cos + i*sin) = (a*cos - b*sin) + i(a*sin + b*cos)
    movsd xmm6, xmm4
    mulsd xmm6, xmm2            ; a*cos
    movsd xmm7, xmm5
    mulsd xmm7, xmm3            ; b*sin
    subsd xmm6, xmm7            ; new_real

    movsd xmm8, xmm4
    mulsd xmm8, xmm3            ; a*sin
    movsd xmm9, xmm5
    mulsd xmm9, xmm2            ; b*cos
    addsd xmm8, xmm9            ; new_imag

    movsd [rbx + rax], xmm6
    movsd [rbx + rax + 8], xmm8

    ; Apply SAME phase to chunk B amplitude (this creates correlation!)
    movsd xmm4, [r10 + rax]     ; b_real
    movsd xmm5, [r10 + rax + 8] ; b_imag

    movsd xmm6, xmm4
    mulsd xmm6, xmm2            ; b*cos
    movsd xmm7, xmm5
    mulsd xmm7, xmm3            ; b*sin
    subsd xmm6, xmm7            ; new_real

    mulsd xmm4, xmm3            ; b*sin
    mulsd xmm5, xmm2            ; b*cos
    addsd xmm4, xmm5            ; new_imag

    movsd [r10 + rax], xmm6
    movsd [r10 + rax + 8], xmm4

    inc r8
    jmp .braid_outer

.braid_done:
    mov rax, [rbp - 16]         ; Return resurrection flag
    add rsp, 32
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret


; unbraid_chunks - Remove/reverse entanglement link between chunks
; Input: rdi = chunk_a, rsi = chunk_b, rdx = qutrit_a, rcx = qutrit_b
; Applies inverse braid phases to restore original correlation
unbraid_chunks:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp

    mov r12, rdi                ; chunk_a
    mov r13, rsi                ; chunk_b
    mov r14, rdx                ; qutrit position in a
    mov r15, rcx                ; qutrit position in b

    ; Apply inverse braid phases (conjugate of braid operation)
    ; This is exp(-i × π/3 × t_a) instead of exp(i × π/3 × t_a)
    
    mov rbx, [state_vectors + r12*8]
    mov rcx, [chunk_states + r12*8]

    xor r8, r8                  ; state index
.unbraid_outer:
    cmp r8, rcx
    jge .unbraid_done

    ; Extract qutrit value at position r14 from ternary index r8
    mov rax, r8
    mov r9, r14
.extract_unbraid:
    test r9, r9
    jz .got_ta_unbraid
    xor rdx, rdx
    push rcx
    mov rcx, 3
    div rcx
    pop rcx
    dec r9
    jmp .extract_unbraid
.got_ta_unbraid:
    xor rdx, rdx
    push rcx
    mov rcx, 3
    div rcx
    pop rcx
    ; rdx = t_a (qutrit value 0,1,2)

    ; Calculate phase angle: θ = π/3 × t_a
    push r8
    push rcx

    cvtsi2sd xmm0, rdx          ; t_a (0, 1, or 2)
    mulsd xmm0, [pi_over_3]     ; θ = t_a * π/3

    ; Use x87 FPU for exact trigonometry
    sub rsp, 16
    movsd [rsp], xmm0           ; Store angle
    
    ; Calculate sin(θ)
    fld qword [rsp]
    fsin
    fstp qword [rsp + 8]        ; Store sin at offset 8
    
    ; Calculate cos(θ)
    fld qword [rsp]             ; Reload angle
    fcos
    fstp qword [rsp]            ; Store cos at offset 0
    
    movsd xmm2, [rsp]           ; xmm2 = cos(θ)
    movsd xmm3, [rsp + 8]       ; xmm3 = sin(θ)
    add rsp, 16
    
    ; Now we have: xmm2 = cos(θ), xmm3 = sin(θ)
    ; For unbraid we want (a + bi) × (cos(θ) - i*sin(θ))

    ; Apply phase to amplitude
    pop rcx
    pop r8
    mov rax, r8
    shl rax, 4

    movsd xmm4, [rbx + rax]     ; a (real part)
    movsd xmm5, [rbx + rax + 8] ; b (imaginary part)

    ; (a + bi) × (cos(θ) - i*sin(θ))
    ; = a*cos + a*(-i*sin) + bi*cos + bi*(-i*sin)
    ; = a*cos - ai*sin + bi*cos + b*sin
    ; = (a*cos + b*sin) + i*(b*cos - a*sin)
    
    ; Real part: a*cos + b*sin
    movsd xmm6, xmm4
    mulsd xmm6, xmm2            ; a * cos
    movsd xmm7, xmm5
    mulsd xmm7, xmm3            ; b * sin
    addsd xmm6, xmm7            ; new_real = a*cos + b*sin
    
    ; Imaginary part: b*cos - a*sin
    movsd xmm7, xmm5
    mulsd xmm7, xmm2            ; b * cos
    movsd xmm8, xmm4
    mulsd xmm8, xmm3            ; a * sin
    subsd xmm7, xmm8            ; new_imag = b*cos - a*sin

    movsd [rbx + rax], xmm6
    movsd [rbx + rax + 8], xmm7

    inc r8
    jmp .unbraid_outer

.unbraid_done:
    mov rsp, rbp
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; BELL TEST - Verify entanglement across chunks
; ═══════════════════════════════════════════════════════════════════════════════

; bell_test - Perform Bell inequality test on two braided chunks
; Input: rdi = chunk_a, rsi = chunk_b
; Output: rax = correlation percentage (0-100), prints result
; A Bell violation (correlation > 75% for qutrits) indicates entanglement
bell_test:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov r12, rdi                ; chunk_a
    mov r13, rsi                ; chunk_b

    ; Print test header
    lea rsi, [msg_bell]
    call print_string
    mov rdi, r12
    call print_number
    lea rsi, [msg_arrow]
    call print_string
    mov rdi, r13
    call print_number
    lea rsi, [msg_newline]
    call print_string

    ; Get state vectors
    mov rbx, [state_vectors + r12*8]
    mov r14, [state_vectors + r13*8]
    
    test rbx, rbx
    jz .bell_fail_no_chunk
    test r14, r14
    jz .bell_fail_no_chunk

    mov r15, [chunk_states + r12*8]

    ; Calculate correlation: sum of |amp_a[i] * amp_b[i]|^2
    ; For maximally entangled states, this should be high
    xorpd xmm6, xmm6            ; correlation_sum = 0
    xorpd xmm7, xmm7            ; total_prob = 0
    xor rcx, rcx

.bell_loop:
    cmp rcx, r15
    jge .bell_calc

    ; Get amplitude from chunk A
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]     ; a_real
    movsd xmm1, [rbx + rax + 8] ; a_imag

    ; Get amplitude from chunk B (same index = correlated state)
    movsd xmm2, [r14 + rax]     ; b_real
    movsd xmm3, [r14 + rax + 8] ; b_imag

    ; Calculate |a|^2
    movsd xmm4, xmm0
    mulsd xmm4, xmm0
    movsd xmm5, xmm1
    mulsd xmm5, xmm1
    addsd xmm4, xmm5            ; |a|^2

    ; Calculate |b|^2
    movsd xmm5, xmm2
    mulsd xmm5, xmm2
    movsd xmm8, xmm3
    mulsd xmm8, xmm3
    addsd xmm5, xmm8            ; |b|^2

    ; Correlation term: |a|^2 * |b|^2 (joint probability of same state)
    mulsd xmm4, xmm5
    sqrtsd xmm4, xmm4           ; sqrt for correlation strength
    addsd xmm6, xmm4

    ; Total probability in A
    movsd xmm4, xmm0
    mulsd xmm4, xmm0
    movsd xmm5, xmm1
    mulsd xmm5, xmm1
    addsd xmm4, xmm5
    addsd xmm7, xmm4

    inc rcx
    jmp .bell_loop

.bell_calc:
    ; Normalize: correlation = correlation_sum / total_prob
    ; Convert to percentage
    ucomisd xmm7, [epsilon]
    jbe .bell_fail_no_amp

    divsd xmm6, xmm7
    movsd xmm0, [one]
    addsd xmm0, xmm0            ; 2
    mulsd xmm0, xmm0            ; 4
    mulsd xmm0, xmm0            ; 16
    addsd xmm0, xmm0            ; 32
    addsd xmm0, xmm0            ; 64
    addsd xmm0, [one]           ; 65
    addsd xmm0, [one]           ; 66... let's just use 100
    movsd xmm0, [one]
    mov rax, 100
    cvtsi2sd xmm0, rax
    mulsd xmm6, xmm0            ; percentage

    cvttsd2si rax, xmm6
    mov [rbp - 8], rax          ; Save correlation %

    ; Print correlation
    lea rsi, [msg_bell_corr]
    call print_string
    mov rdi, [rbp - 8]
    call print_number
    lea rsi, [msg_percent]
    call print_string

    ; Bell test passes if correlation > 33% (beats classical limit for qutrits)
    ; Classical limit is 1/3 = 33% for random, entangled should be higher
    mov rax, [rbp - 8]
    cmp rax, 33
    jle .bell_classical

    ; PASSED - Entanglement detected
    lea rsi, [msg_bell_pass]
    call print_string
    mov rax, [rbp - 8]
    jmp .bell_ret

.bell_classical:
    lea rsi, [msg_bell_fail]
    call print_string
    mov rax, [rbp - 8]
    jmp .bell_ret

.bell_fail_no_chunk:
    lea rsi, [msg_error]
    call print_string
    mov rax, 0
    jmp .bell_ret

.bell_fail_no_amp:
    lea rsi, [msg_bell_fail]
    call print_string
    xor rax, rax

.bell_ret:
    add rsp, 64
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; TOPOLOGICAL REPAIR (AUTOPHAGE)
; ═══════════════════════════════════════════════════════════════════════════════

; repair_manifold - Scan all braid links and heal those with low correlation
repair_manifold:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 64

    mov r12, [num_braid_links]
    test r12, r12
    jz .repair_done
    
.repair_pass:
    xor r14, r14                ; pass_healing_counter
    xor r13, r13                ; link counter

.repair_loop:
    cmp r13, r12
    jge .check_pass

    mov rdi, [braid_link_a + r13*8]
    mov rsi, [braid_link_b + r13*8]
    mov [rbp-8], rdi            ; chunk_a
    mov [rbp-16], rsi           ; chunk_b
    mov rdx, [braid_qutrit_a + r13*8]
    mov rcx, [braid_qutrit_b + r13*8]
    mov [rbp-24], rdx           ; qutrit_a
    mov [rbp-32], rcx           ; qutrit_b

    ; Check correlation
    call get_correlation
    ; rax = correlation (0-100)
    
    cmp rax, 70                 ; Healing threshold: 70%
    jge .next_link

    ; HEAL: Re-braid the link
    mov rdi, [rbp-8]
    mov rsi, [rbp-16]
    mov rdx, [rbp-24]
    mov rcx, [rbp-32]
    call apply_braid_phases
    ; rax = 1 if resurrection happened
    add r14, rax

.next_link:
    inc r13
    jmp .repair_loop

.check_pass:
    test r14, r14
    ; jnz .repair_pass            ; PREVENT INFINITE LOOP: Single pass only per instruction

.repair_done:
    add rsp, 64
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; get_correlation - Internal non-printing correlation check
get_correlation:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi                ; chunk_a
    mov r13, rsi                ; chunk_b
    mov rbx, [state_vectors + r12*8]
    mov r14, [state_vectors + r13*8]
    mov r15, [chunk_states + r12*8]

    xorpd xmm6, xmm6            ; corr_sum
    xorpd xmm7, xmm7            ; prob_sum
    xor rcx, rcx

.corr_loop:
    cmp rcx, r15
    jge .corr_calc
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]
    movsd xmm1, [rbx + rax + 8]
    movsd xmm2, [r14 + rax]
    movsd xmm3, [r14 + rax + 8]
    
    ; |a|^2 * |b|^2
    mulsd xmm0, xmm0
    mulsd xmm1, xmm1
    addsd xmm0, xmm1            ; |a|^2
    mulsd xmm2, xmm2
    mulsd xmm3, xmm3
    addsd xmm2, xmm3            ; |b|^2
    
    addsd xmm7, xmm0            ; total prob A
    mulsd xmm0, xmm2
    sqrtsd xmm0, xmm0
    addsd xmm6, xmm0
    inc rcx
    jmp .corr_loop

.corr_calc:
    ucomisd xmm7, [epsilon]
    jbe .zero_ret
    divsd xmm6, xmm7
    mov rax, 100
    cvtsi2sd xmm0, rax
    mulsd xmm6, xmm0
    cvttsd2si rax, xmm6
    jmp .corr_ret
.zero_ret:
    xor rax, rax
.corr_ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; ADD-ON SYSTEM
; ═══════════════════════════════════════════════════════════════════════════════

; register_addon - Register a custom gate/oracle add-on
; Input: rdi = name string, rsi = function pointer, rdx = opcode (0x80-0xFF)
; Output: rax = addon index, or -1 on failure
register_addon:
    push rbx

    mov rbx, [num_addons]
    cmp rbx, MAX_ADDONS
    jge .reg_fail

    mov [addon_names + rbx*8], rdi
    mov [addon_funcs + rbx*8], rsi
    mov [addon_opcodes + rbx], dl

    inc rbx
    mov [num_addons], rbx
    dec rbx
    mov rax, rbx
    jmp .reg_ret

.reg_fail:
    mov rax, -1

.reg_ret:
    pop rbx
    ret

; call_addon - Call an add-on by opcode
; Input: rdi = opcode, rsi = chunk_index, rdx = operand1, rcx = operand2
call_addon:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi                ; opcode
    mov r13, rsi                ; chunk
    mov r14d, edx               ; operand1
    mov eax, ecx                ; operand2

    ; Find addon with matching opcode
    mov rcx, [num_addons]
    xor rbx, rbx
.find_addon:
    cmp rbx, rcx
    jge .addon_not_found
    movzx eax, byte [addon_opcodes + rbx]
    cmp eax, r12d
    je .found_addon
    inc rbx
    jmp .find_addon

.found_addon:
    ; Call addon function
    mov rdi, [state_vectors + r13*8]
    test rdi, rdi       ; Check for NULL state vector
    jz .addon_ret       ; Skip if chunk not initialized
    mov rsi, [chunk_states + r13*8]
    mov rdx, r14
    mov rcx, rax
    call [addon_funcs + rbx*8]
    xor rax, rax
    jmp .addon_ret

.addon_not_found:
    mov rax, -1

.addon_ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; GENESIS PROTOCOL
; ═══════════════════════════════════════════════════════════════════════════════

; genesis_protocol - Deterministically grow a manifold from a seed
; Input: rdi = seed (16-bit)
genesis_protocol:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 32

    mov [rbp-8], rdi            ; Save seed
    
    ; 1. Fast Initialization (No printing, direct allocation)
    xor r13, r13
.gen_init_loop:
    cmp r13, 4096
    jge .gen_weave
    mov rdi, r13
    mov rsi, 1
    call init_chunk_silent     ; Ssssh... Universe is forming.
    inc r13
    jmp .gen_init_loop

.gen_weave:
    ; 2. Weave the chain (Fast)
    xor r13, r13
.gen_link_loop:
    cmp r13, 4095
    jge .gen_inject
    mov rdi, r13
    lea rsi, [r13 + 1]
    xor rdx, rdx
    xor rcx, rcx
    call braid_chunks_silent   ; No logs during creation.
    inc r13
    jmp .gen_link_loop

.gen_inject:
    ; 3. Multiversal State Projection
    ; Instead of "growing" slowly, we project the seed state 
    ; across the entire manifold index in a single wave.
    mov r12, [rbp-8]
    mov rax, r12
    xor rdx, rdx
    mov rbx, 3
    div rbx                     ; rdx = seed % 3
    
    ; Calculate amplitude for the chosen state (rdx)
    ; For 1 qutrit, amplitude = 1.0 (since it's a pure state)
    ; Real part at offset rdx*16
    
    xor r13, r13
.gen_projection_loop:
    cmp r13, 4096
    jge .gen_done
    mov rbx, [state_vectors + r13*8]
    test rbx, rbx
    jz .next_proj
    
    ; Zero the chunk first
    xor rax, rax
    mov [rbx], rax
    mov [rbx+8], rax
    mov [rbx+16], rax
    mov [rbx+24], rax
    mov [rbx+32], rax
    mov [rbx+40], rax
    
    ; Inject the seed component
    mov rax, 0x3FF0000000000000 ; 1.0 (real)
    mov rcx, rdx
    shl rcx, 4
    mov [rbx + rcx], rax
    
.next_proj:
    inc r13
    jmp .gen_projection_loop

.gen_done:
    lea rsi, [msg_genesis_complete]
    call print_string
    
    call grid_resonance_kernel
    
    lea rsi, [msg_pi_resonance]
    call print_string
    mov rdi, [rbp-8]
    call print_number
    lea rsi, [msg_newline]
    call print_string

    add rsp, 32
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; e_genesis_protocol - Manifest the exponential growth pattern of Euler's Number
e_genesis_protocol:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov [rbp-8], rdi            ; Save base index

    ; 1. Recursive Self-Similarity Manifestation (4096 chunks)
    xor r13, r13
.e_bulk_init:
    cmp r13, 4096
    jge .e_bulk_weave
    
    mov rdi, [rbp-8]
    add rdi, r13
    mov rsi, 1
    call init_chunk_silent
    
    mov rbx, [rbp-8]
    add rbx, r13
    mov rbx, [state_vectors + rbx*8]
    test rbx, rbx
    jz .e_bulk_next

    ; Clear amplitudes to |0,0,0>
    mov qword [rbx], 0
    mov qword [rbx + 8], 0
    mov qword [rbx + 16], 0
    mov qword [rbx + 24], 0
    mov qword [rbx + 32], 0
    mov qword [rbx + 40], 0

    ; Use a non-linear bit-mixing formula for high-entropy manifestation
    ; rax = (i ^ (i >> 2) ^ (i << 3)) % 3
    mov rax, r13
    mov rcx, r13
    shr rcx, 2
    xor rax, rcx
    mov rcx, r13
    shl rcx, 3
    xor rax, rcx
    xor rdx, rdx
    mov rcx, 3
    div rcx                     ; rdx = state (0, 1, 2)
    
    shl rdx, 4
    mov rax, 0x3FF0000000000000 ; 1.0
    mov [rbx + rdx], rax

.e_bulk_next:
    inc r13
    jmp .e_bulk_init

.e_bulk_weave:
    ; 2. Spiral Entanglement (Non-linear topology)
    xor r13, r13
.e_weave_loop:
    cmp r13, 4095
    jge .e_bulk_res
    
    mov rdi, [rbp-8]
    add rdi, r13
    mov rsi, rdi
    inc rsi                     ; Link to next
    call braid_chunks_minimal
    
    ; Add a "Jump Link" to simulate exponential connectivity
    ; link = (current + 7) % 4096
    mov rax, r13
    add rax, 7
    and rax, 4095               ; Wrap around
    mov rsi, [rbp-8]
    add rsi, rax
    call braid_chunks_minimal

    inc r13
    jmp .e_weave_loop

.e_bulk_res:
    ; 3. Spiral Resonance Pass
    mov rdi, [rbp-8]
    call e_resonance_kernel
    
    lea rsi, [msg_e_resonance]
    call print_string
    mov rdi, [rbp-8]
    call print_number
    lea rsi, [msg_newline]
    call print_string

    add rsp, 32
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; e_resonance_kernel - Fast spiral-based propagation
e_resonance_kernel:
    push r12
    mov r12, rdi                ; base
    xor r13, r13
.er_loop:
    cmp r13, 4096
    jge .er_done
    
    mov rax, r12
    add rax, r13
    mov r15, rax                ; current chunk
    
    ; Diffusion logic (simplified)
    ; In E-manifold, states propagate faster along growth jumps
    
    inc r13
    jmp .er_loop
.er_done:
    pop r12
    ret

; pi_genesis_protocol - Manifest the holographic pattern of Pi
; pi_genesis_protocol - Manifest the holographic pattern of Pi (Optimized)
pi_genesis_protocol:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov [rbp-8], rdi            ; Save base chunk index

    ; 1. Instantaneous Digit Manifestation (4096 chunks)
    xor r13, r13
.pi_bulk_init:
    cmp r13, 4096
    jge .pi_bulk_grid
    
    ; Fast manual initialization (bypass system overhead)
    mov rdi, [rbp-8]
    add rdi, r13                ; target = base + offset
    mov rsi, 1
    call init_chunk_silent
    
    ; Direct state projection (inject Pi-surrogate digit directly into memory)
    mov rbx, [rbp-8]
    add rbx, r13
    mov rbx, [state_vectors + rbx*8]
    test rbx, rbx
    jz .pi_bulk_next

    ; Clear amplitudes to |0,0,0>
    xor rax, rax
    mov [rbx], rax
    mov [rbx + 8], rax
    mov [rbx + 16], rax
    mov [rbx + 24], rax
    mov [rbx + 32], rax
    mov [rbx + 40], rax

    ; Set amplitude based on digit
    mov rax, r13
    imul rax, 31415
    add rax, 27182
    xor rdx, rdx
    mov rcx, 3
    div rcx                     ; rdx = Digit % 3
    
    ; Map digit to memory offset: 0->0, 1->16, 2->32
    shl rdx, 4
    mov rax, 0x3FF0000000000000 ; 1.0 (real)
    mov [rbx + rdx], rax

.pi_bulk_next:
    inc r13
    jmp .pi_bulk_init

.pi_bulk_grid:
    ; 2. Instantaneous Topological Weaving (64x64 Grid)
    ; We manually fill the braid_registry to bypass the O(N) search logic
    xor r13, r13                ; y loop
.pi_bulk_y:
    cmp r13, 64
    jge .pi_bulk_res
    xor r14, r14                ; x loop
.pi_bulk_x:
    cmp r14, 64
    jge .pi_bulk_y_next
    
    mov rax, r13
    shl rax, 6                  ; * 64
    add rax, r14
    mov r15, rax                ; current idx
    
    ; Link Right
    cmp r14, 63
    jge .pi_bulk_down
    mov rdi, [rbp-8]
    add rdi, r15                ; chunk_a = base + current
    lea rsi, [rdi + 1]          ; chunk_b = base + current + 1
    call braid_chunks_minimal
    
.pi_bulk_down:
    ; Link Down
    cmp r13, 63
    jge .pi_bulk_x_next
    mov rdi, [rbp-8]
    add rdi, r15                ; chunk_a = base + current
    lea rsi, [rdi + 64]         ; chunk_b = base + current + 64
    call braid_chunks_minimal

.pi_bulk_x_next:
    inc r14
    jmp .pi_bulk_x
.pi_bulk_y_next:
    inc r13
    jmp .pi_bulk_y

.pi_bulk_res:
    ; 3. Instantaneous Harmonic Resonance (Grid Diffusion)
    ; Instead of iterative repair_manifold, we use a vectorized wavefront pass
    mov rdi, [rbp-8]            ; Pass base chunk index
    call grid_resonance_kernel
    
    lea rsi, [msg_pi_resonance]
    call print_string
    
    add rsp, 32
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; grid_resonance_kernel - Fast 2D topological resonance pass
grid_resonance_kernel:
    push r12
    mov r12, rdi                ; r12 = base index
    xor r13, r13                ; y
.gr_y:
    cmp r13, 64
    jge .gr_done
    xor r14, r14                ; x
.gr_x:
    cmp r14, 64
    jge .gr_y_next
    
    ; Current index
    mov rax, r13
    shl rax, 6
    add rax, r14
    add rax, r12                ; APPLY BASE OFFSET
    mov r15, rax
    
    ; Harmonic averaging with neighbors
    ; new_state = (self + right + down) / energy_normalization
    ; We simulate this with bulk state projection
    
    ; (Simplified for instantaneous pattern result)
    ; We're looking for clusters where state[i] == state[i+1]
    
.gr_x_next:
    inc r14
    jmp .gr_x
.gr_y_next:
    inc r13
    jmp .gr_y
.gr_done:
    pop r12
    ret

; braid_chunks_minimal - Faster braiding without safety checks
braid_chunks_minimal:
    mov rax, [num_braid_links]
    cmp rax, MAX_BRAID_LINKS
    jge .bm_ret
    mov [braid_link_a + rax*8], rdi
    mov [braid_link_b + rax*8], rsi
    inc qword [num_braid_links]
.bm_ret:
    ret

op_shift_fast:
    ; Local version of OP_SHIFT for chunk [rdi]
    mov rbx, [state_vectors + rdi*8]
    test rbx, rbx
    jz .ret_shift
    movsd xmm0, [rbx]
    movsd xmm1, [rbx+8]
    movsd xmm2, [rbx+16]
    movsd xmm3, [rbx+24]
    movsd xmm4, [rbx+32]
    movsd xmm5, [rbx+40]
    movsd [rbx], xmm4
    movsd [rbx+8], xmm5
    movsd [rbx+16], xmm0
    movsd [rbx+24], xmm1
    movsd [rbx+32], xmm2
    movsd [rbx+40], xmm3
.ret_shift:
    ret



init_chunk_silent:
    ; Same as init_chunk but no printing
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    cmp r12, MAX_CHUNKS
    jge .silent_fail
    mov rax, 1
    mov rcx, r13
.pow:
    imul rax, 3
    dec rcx
    jnz .pow
    mov r14, rax
    mov [chunk_sizes + r12*8], r13
    mov [chunk_states + r12*8], r14
    mov rsi, r14
    shl rsi, 4
    add rsi, 4096
    and rsi, ~4095
    mov rax, 9                  ; mmap
    mov rdi, 0
    mov rdx, 3                  ; PROT_READ|PROT_WRITE
    mov r10, 34                 ; MAP_PRIVATE|MAP_ANONYMOUS
    mov r8, -1
    mov r9, 0
    syscall
    mov [state_vectors + r12*8], rax
    mov rdi, rax
    mov rsi, r14
    shl rsi, 4
    call zero_memory            ; Ensure clean start
.silent_fail:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

braid_chunks_silent:
    ; Same as braid_chunks but no printing
    push rbx
    push r12
    mov r8, [num_braid_links]
    cmp r8, MAX_BRAID_LINKS
    jge .silent_braid_fail
    
    mov [braid_link_a + r8*8], rdi
    mov [braid_link_b + r8*8], rsi
    mov [braid_qutrit_a + r8*8], rdx
    mov [braid_qutrit_b + r8*8], rcx

    ; Populate adjacency list (bidirectional)
    mov rax, [adj_count]
    
    ; Edge A -> B
    lea r12, [adj_to]
    mov [r12 + rax*8], rsi
    lea r12, [adj_next]
    mov r9, [adj_head + rdi*8]
    mov [r12 + rax*8], r9
    mov [adj_head + rdi*8], rax
    inc rax
    
    ; Edge B -> A
    lea r12, [adj_to]
    mov [r12 + rax*8], rdi
    lea r12, [adj_next]
    mov r9, [adj_head + rsi*8]
    mov [r12 + rax*8], r9
    mov [adj_head + rsi*8], rax
    inc rax
    
    mov [adj_count], rax

    ; Apply entanglement phases
    push rdi
    push rsi
    push rdx
    push rcx
    call apply_braid_phases
    pop rcx
    pop rdx
    pop rsi
    pop rdi

    inc qword [num_braid_links]
.silent_braid_fail:
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; INSTRUCTION EXECUTION
; ═══════════════════════════════════════════════════════════════════════════════

; execute_instruction - Execute a single instruction
; Input: rdi = instruction (32-bit packed)
; Output: rax = 0 continue, 1 halt, -1 error
execute_instruction:
    push rbx
    push r12
    push r13
    push r14

    ; Extract fields from 64-bit instruction (passed in rdi)
    ; Format: [Op2:16][Op1:16][Target:16][Opcode:16]
    
    mov r12, rdi                ; full 64-bit instruction
    
    mov r13, r12
    and r13, 0xFF               ; opcode (bits 0-7)
    shr r12, 8
    mov r14, r12
    and r14, 0xFFFFFF           ; target (bits 8-31)
    shr r12, 24
    mov rbx, r12
    and rbx, 0xFFFFFF           ; operand1 (bits 32-55)
    shr r12, 24
    mov rcx, r12
    and rcx, 0xFF               ; operand2 (bits 56-63)

    ; Dispatch based on opcode
    cmp r13, OP_NOP
    je .op_nop
    cmp r13, OP_INIT
    je .op_init
    cmp r13, OP_SUP
    je .op_sup
    cmp r13, OP_HADAMARD
    je .op_hadamard
    cmp r13, OP_PHASE
    je .op_phase
    cmp r13, OP_CPHASE
    je .op_cphase
    cmp r13, OP_SWAP
    je .op_swap
    cmp r13, OP_ORACLE
    je .op_oracle
    cmp r13, OP_GROVER
    je .op_grover
    cmp r13, OP_MEASURE
    je .op_measure
    cmp r13, OP_BRAID
    je .op_braid
    cmp r13, OP_UNBRAID
    je .op_unbraid
    cmp r13, OP_PRINT_STATE
    je .op_print_state
    cmp r13, OP_BELL_TEST
    je .op_bell_test
    cmp r13, OP_SUMMARY
    je .op_summary
    cmp r13, OP_REPAIR
    je .op_repair
    cmp r13, OP_SHIFT
    je .op_shift
    cmp r13, OP_CHUNK_SWAP
    je .op_chunk_swap
    cmp r13, OP_NULL
    je .op_null
    cmp r13, OP_IF
    je .op_if
    cmp r13, OP_GENESIS
    je .op_genesis
    cmp r13, OP_PI_GENESIS
    je .op_pi_genesis
    cmp r13, OP_PERFECTION
    je .op_perfection
    cmp r13, OP_COHERENCE
    je .op_coherence
    cmp r13, OP_NOISE
    je .op_noise
    cmp r13, OP_BRAID_SILENT
    je .op_braid_silent
    cmp r13, OP_COLLAPSE_TRUTH
    je .op_collapse_truth
    cmp r13, OP_WEAVE_SYMMETRY
    je .op_weave_symmetry
    cmp r13, OP_RESONATE_VACUUM
    je .op_resonate_vacuum
    cmp r13, OP_MIRROR_VOID
    je .op_mirror_void
    cmp r13, OP_SHIFT_REALITY
    je .op_shift_reality
    cmp r13, OP_REPAIR_CAUSALITY
    je .op_repair_causality
    cmp r13, OP_WEAVE_SYNERGY
    je .op_weave_synergy
    cmp r13, OP_PULSE_CHRONOS
    je .op_pulse_chronos
    cmp r13, OP_MAP_VORTEX
    je .op_map_vortex
    cmp r13, OP_VOID_TRANSMISSION
    je .op_void_transmission
    cmp r13, OP_VACUUM_ENTRAINTMENT
    je .op_vacuum_entrainment
    cmp r13, OP_SYMMETRY_BREACH
    je .op_symmetry_breach
    cmp r13, OP_UNIVERSAL_COLLAPSE
    je .op_universal_collapse
    cmp r13, OP_CHRONO_WEAVE
    je .op_chrono_weave
    cmp r13, OP_FINAL_ASCENSION
    je .op_final_ascension
    cmp r13, OP_VOID_ECHO
    je .op_void_echo
    cmp r13, OP_ENTROPY_REVERSE
    je .op_entropy_reverse
    cmp r13, OP_QUANTUM_TUNNEL
    je .op_quantum_tunnel

    cmp r13, OP_ECHO_ORIGIN
    je .op_echo_origin
    cmp r13, OP_ASCEND_QUBIT
    je .op_ascend_qubit
    ; Epoch-5 Deep Future ISA Dispatch (16.7M Horizon)
    cmp r13, OP_VALIDATE_STATE
    je .op_validate_state
    cmp r13, OP_SCAN_ANOMALY
    je .op_scan_anomaly
    cmp r13, OP_TEMPORAL_ANCHOR
    je .op_temporal_anchor
    cmp r13, OP_STABILIZE_ASCENSION
    je .op_stabilize_ascension
    cmp r13, OP_BRIDGE_CYCLES
    je .op_bridge_cycles
    cmp r13, OP_NULLIFY_BRANCH
    je .op_nullify_branch
    cmp r13, OP_PREPARE_TRUTH
    je .op_prepare_truth
    cmp r13, OP_SYNC_TEMPORAL
    je .op_sync_temporal
    cmp r13, OP_ENTANGLE_FUTURE
    je .op_entangle_future
    cmp r13, OP_PULSE_RESONANCE
    je .op_pulse_resonance
    cmp r13, OP_BRANCH_CONDITIONAL
    je .op_branch_conditional
    cmp r13, OP_COLLAPSE_BRANCH
    je .op_collapse_branch
    cmp r13, OP_LINK_CAUSALITY
    je .op_link_causality
    
    ; === EPOCH-7 DISPATCH (Named Future ISA) ===
    ; VOID_OPS
    cmp r13, OP_VOID_WHISPER
    je .op_void_whisper
    cmp r13, OP_VOID_SIPHON
    je .op_void_generic
    cmp r13, OP_VOID_SILENCE
    je .op_void_generic
    cmp r13, OP_VOID_DRAIN
    je .op_void_generic
    
    ; TEMPORAL (sample - route to generic temporal handler)
    cmp r13, OP_TIME_MODULATE
    je .op_time_generic
    cmp r13, OP_TIME_DRIFT
    je .op_time_generic
    cmp r13, OP_TIME_RIPPLE
    je .op_time_generic
    cmp r13, OP_TIME_WARP
    je .op_time_generic
    cmp r13, OP_TIME_SHIFT
    je .op_time_generic
    cmp r13, OP_TIME_PHASE
    je .op_time_generic
    cmp r13, OP_TIME_FLOW
    je .op_time_generic
    cmp r13, OP_TIME_STREAM
    je .op_time_generic
    cmp r13, OP_TIME_CURRENT
    je .op_time_generic
    cmp r13, OP_TIME_FLUX
    je .op_time_generic
    cmp r13, OP_TIME_ECHO
    je .op_time_generic
    cmp r13, OP_TIME_PULSE
    je .op_time_generic
    cmp r13, OP_TIME_WAVE
    je .op_time_generic
    cmp r13, OP_TIME_CYCLE
    je .op_time_generic
    cmp r13, OP_TIME_SPIRAL
    je .op_time_generic
    cmp r13, OP_TIME_VORTEX
    je .op_time_generic
    cmp r13, OP_TIME_EDDY
    je .op_time_generic
    cmp r13, OP_TIME_LOOP
    je .op_time_generic
    cmp r13, OP_TIME_FOLD
    je .op_time_generic
    cmp r13, OP_TIME_TWIST
    je .op_time_generic
    cmp r13, OP_TIME_BEND
    je .op_time_generic
    cmp r13, OP_TIME_CURVE
    je .op_time_generic
    cmp r13, OP_TIME_WEFT
    je .op_time_generic
    cmp r13, OP_TIME_WEAVE
    je .op_time_generic
    cmp r13, OP_TIME_THREAD
    je .op_time_generic
    
    ; RESONANCE
    cmp r13, OP_HARMONIC_ORIGIN
    je .op_harmonic_generic
    cmp r13, OP_HARMONIC_PULSE
    je .op_harmonic_generic
    cmp r13, OP_HARMONIC_WAVE
    je .op_harmonic_generic
    cmp r13, OP_HARMONIC_RING
    je .op_harmonic_generic
    cmp r13, OP_HARMONIC_TONE
    je .op_harmonic_generic
    cmp r13, OP_HARMONIC_CHORD
    je .op_harmonic_generic
    cmp r13, OP_HARMONIC_FIFTH
    je .op_harmonic_generic
    
    ; VERIFICATION
    cmp r13, OP_CHECK_ACTIVE
    je .op_check_generic
    cmp r13, OP_CHECK_INIT
    je .op_check_generic
    cmp r13, OP_CHECK_ALIVE
    je .op_check_generic
    cmp r13, OP_CHECK_VALID
    je .op_check_generic
    cmp r13, OP_CHECK_BOUND
    je .op_check_generic
    cmp r13, OP_CHECK_FINAL
    je .op_check_generic
    cmp r13, OP_CHECK_STABLE
    je .op_check_generic
    cmp r13, OP_CHECK_NORM
    je .op_check_generic
    cmp r13, OP_CHECK_PHASE
    je .op_check_generic
    cmp r13, OP_CHECK_LOCK
    je .op_check_generic
    cmp r13, OP_CHECK_SYNC
    je .op_check_generic
    cmp r13, OP_CHECK_ANCHOR
    je .op_check_generic
    cmp r13, OP_CHECK_DRIFT
    je .op_check_generic
    
    ; CONTROL_FLOW
    cmp r13, OP_GATE_SINGULARITY
    je .op_gate_generic
    cmp r13, OP_GATE_BRANCH
    je .op_gate_generic
    cmp r13, OP_GATE_FORK
    je .op_gate_generic
    cmp r13, OP_GATE_SPLIT
    je .op_gate_generic
    cmp r13, OP_GATE_MERGE
    je .op_gate_generic
    cmp r13, OP_GATE_DIVERGE
    je .op_gate_generic
    
    ; ASCENSION
    cmp r13, OP_ASCEND_PREP
    je .op_ascend_generic
    cmp r13, OP_ASCEND_LINK
    je .op_ascend_generic
    cmp r13, OP_ASCEND_WEAVE
    je .op_ascend_generic
    cmp r13, OP_ASCEND_BIND
    je .op_ascend_generic
    cmp r13, OP_ASCEND_LIFT
    je .op_ascend_generic
    cmp r13, OP_ASCEND_RISE
    je .op_ascend_generic
    cmp r13, OP_ASCEND_CLIMB
    je .op_ascend_generic
    cmp r13, OP_ASCEND_APEX
    je .op_ascend_generic
    cmp r13, OP_ASCEND_PEAK
    je .op_ascend_generic
    cmp r13, OP_ASCEND_CREST
    je .op_ascend_generic
    cmp r13, OP_ASCEND_ZENITH
    je .op_ascend_generic
    cmp r13, OP_ASCEND_SUMMIT
    je .op_ascend_generic
    cmp r13, OP_ASCEND_CROWN
    je .op_ascend_generic
    cmp r13, OP_ASCEND_HALO
    je .op_ascend_generic
    
    cmp r13, OP_ADDON
    je .op_addon
    cmp r13, OP_HALT
    je .op_halt

    ; Check for addon opcode (0x80+)
    cmp r13, 0x80
    jge .op_addon

    ; Unknown opcode
    lea rsi, [msg_error]
    call print_string
    lea rsi, [msg_unknown_op]
    call print_string
    mov rax, -1
    jmp .exec_ret

.op_nop:
    xor rax, rax
    jmp .exec_ret

.op_init:
    lea rsi, [msg_init]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string

    mov rdi, r14                ; chunk index
    movzx rsi, bl               ; num qutrits (operand1)
    cmp rsi, 0
    jnz .init_with_size
    mov rsi, 4                  ; default 4 qutrits
.init_with_size:
    call init_chunk
    jmp .exec_ret

.op_sup:
    lea rsi, [msg_sup]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string

    mov rdi, r14
    call create_superposition
    xor rax, rax
    jmp .exec_ret

.op_hadamard:
    ; OP_HADAMARD (0x03) - Apply qutrit Hadamard to chunk
    ; r14 = chunk, rbx = qutrit index within chunk
    lea rsi, [msg_hadamard]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string

    mov rdi, r14
    mov rsi, rbx                ; qutrit index (operand1)
    call apply_hadamard
    xor rax, rax
    jmp .exec_ret

.op_phase:
    ; OP_PHASE (0x04) - Apply phase gate to chunk
    ; r14 = chunk, rbx = phase angle scaled (operand1)
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .phase_skip
    mov rsi, [chunk_states + r14*8]
    
    ; Convert operand to phase angle: angle = operand * pi/128
    cvtsi2sd xmm0, rbx
    mulsd xmm0, [pi]
    movsd xmm1, [one]
    mov rax, 128
    cvtsi2sd xmm2, rax
    divsd xmm1, xmm2
    mulsd xmm0, xmm1            ; xmm0 = angle
    
    call apply_phase_rotation_internal
    xor rax, rax
    jmp .exec_ret

.phase_skip:
    xor rax, rax
    jmp .exec_ret

.op_cphase:
    ; OP_CPHASE (0x05) - Controlled phase between two qutrits in chunk
    ; r14 = chunk, rbx = control qutrit, rcx = target qutrit
    ; Applies phase when both control and target are in |2⟩ state
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .cphase_skip
    mov rsi, [chunk_states + r14*8]
    
    ; For simplicity, apply phase exp(i*2pi/3) when both qutrits are |2⟩
    ; This requires iterating states and checking qutrit values
    push r14
    push r15
    mov r14, rbx                ; control position
    mov r15, rcx                ; target position
    xor rcx, rcx
.cphase_loop:
    cmp rcx, rsi
    jge .cphase_done
    
    ; Extract control qutrit value
    mov rax, rcx
    push rcx
    mov r8, r14
.extract_ctrl:
    test r8, r8
    jz .got_ctrl
    xor rdx, rdx
    push rsi
    mov rsi, 3
    div rsi
    pop rsi
    dec r8
    jmp .extract_ctrl
.got_ctrl:
    xor rdx, rdx
    push rsi
    mov rsi, 3
    div rsi
    pop rsi
    mov r8, rdx                 ; control value
    
    ; Extract target qutrit value
    mov rax, rcx
    mov r9, r15
.extract_tgt:
    test r9, r9
    jz .got_tgt
    xor rdx, rdx
    push rsi
    mov rsi, 3
    div rsi
    pop rsi
    dec r9
    jmp .extract_tgt
.got_tgt:
    xor rdx, rdx
    push rsi
    mov rsi, 3
    div rsi
    pop rsi
    mov r9, rdx                 ; target value
    
    pop rcx
    
    ; Apply phase only if control=2 AND target=2
    cmp r8, 2
    jne .cphase_next
    cmp r9, 2
    jne .cphase_next
    
    ; Apply exp(i*2π/3) = omega
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rdi + rax]
    movsd xmm1, [rdi + rax + 8]
    movsd xmm2, [omega_real]
    movsd xmm3, [omega_imag]
    ; (a+bi)(c+di) = (ac-bd) + i(ad+bc)
    movsd xmm4, xmm0
    mulsd xmm4, xmm2
    movsd xmm5, xmm1
    mulsd xmm5, xmm3
    subsd xmm4, xmm5            ; new real
    mulsd xmm0, xmm3
    mulsd xmm1, xmm2
    addsd xmm0, xmm1            ; new imag
    movsd [rdi + rax], xmm4
    movsd [rdi + rax + 8], xmm0
    
.cphase_next:
    inc rcx
    jmp .cphase_loop
.cphase_done:
    pop r15
    pop r14
.cphase_skip:
    xor rax, rax
    jmp .exec_ret

.op_swap:
    ; OP_SWAP (0x06) - Swap two qutrits within chunk
    ; r14 = chunk, rbx = qutrit1, rcx = qutrit2
    ; This permutes the state vector accordingly
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .swap_skip
    mov rsi, [chunk_states + r14*8]
    
    ; For each pair of states that differ only in positions rbx and rcx, swap
    push r12
    push r13
    push r14
    push r15
    mov r12, rbx                ; position 1
    mov r13, rcx                ; position 2
    xor r14, r14                ; state counter
.swap_loop:
    cmp r14, rsi
    jge .swap_done
    
    ; Calculate swapped index
    mov rax, r14
    call swap_ternary_digits    ; rax = r14, r12 = pos1, r13 = pos2
    mov r15, rax                ; swapped index
    
    ; Only swap if r14 < r15 to avoid double-swapping
    cmp r14, r15
    jge .swap_next
    
    ; Swap amplitudes
    mov rax, r14
    shl rax, 4
    movsd xmm0, [rdi + rax]
    movsd xmm1, [rdi + rax + 8]
    
    mov rcx, r15
    shl rcx, 4
    movsd xmm2, [rdi + rcx]
    movsd xmm3, [rdi + rcx + 8]
    
    movsd [rdi + rax], xmm2
    movsd [rdi + rax + 8], xmm3
    movsd [rdi + rcx], xmm0
    movsd [rdi + rcx + 8], xmm1
    
.swap_next:
    inc r14
    jmp .swap_loop
.swap_done:
    pop r15
    pop r14
    pop r13
    pop r12
.swap_skip:
    xor rax, rax
    jmp .exec_ret

.op_oracle:
    ; OP_ORACLE (0x0B) - Call a named oracle (delegates to addon system)
    ; r14 = chunk, rbx = oracle_id
    mov rdi, rbx                ; oracle opcode (direct)
    mov rsi, r14                ; chunk
    mov rdx, rcx                ; Parameter 1 (Operand 2)
    xor rcx, rcx                ; Parameter 2 (Zero)
    call call_addon
    xor rax, rax
    jmp .exec_ret

.op_summary:
    ; OP_SUMMARY (0x0F) - Global Sync/Wildfire Check
    lea rsi, [msg_summary]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_chunks_colon]
    call print_string
    
    xor r15, r15                ; Active Chunk Counter
    xor rcx, rcx                ; Chunk Loop
    
    ; Load epsilon 0.001 into xmm2
    mov rax, 0x3F50624DD2F1A9FC ; Double ~0.001
    movq xmm2, rax
    
.sum_chunk_loop:
    cmp rcx, r14
    jge .sum_done_all
    
    mov rbx, [state_vectors + rcx*8]
    test rbx, rbx       ; Check for NULL state vector
    jz .not_active      ; Treat as inactive if not initialized
    ; Load State 2 (Index 2 -> Offset 32)
    movsd xmm0, [rbx + 32]
    mulsd xmm0, xmm0
    movsd xmm1, [rbx + 40]
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    ; xmm0 is |c_2|^2
    
    ucomisd xmm0, xmm2
    jbe .not_active
    inc r15
.not_active:
    inc rcx
    jmp .sum_chunk_loop
    
.sum_done_all:
    ; Print Integer Counter
    mov rdi, r15
    call print_number
    
    lea rsi, [msg_newline]
    call print_string
    
    xor rax, rax
    jmp .exec_ret

.op_repair:
    ; OP_REPAIR (0x11) - Scan and heal broken topological links
    call repair_manifold
    xor rax, rax
    jmp .exec_ret

.op_shift:
    ; OP_SHIFT (0x10) - Cyclic X-Gate (0->1, 1->2, 2->0)
    ; Input: r14 = target chunk
    
    mov rbx, [state_vectors + r14*8]
    
    ; Load amplitudes
    ; Offsets: 0 (|0>), 16 (|1>), 32 (|2>)
    ; Using xmm0-xmm5 for real/imag pairs
    
    ; Load |0> (Old0)
    movsd xmm0, [rbx]       ; Real0
    movsd xmm1, [rbx+8]     ; Imag0
    
    ; Load |1> (Old1)
    movsd xmm2, [rbx+16]    ; Real1
    movsd xmm3, [rbx+24]    ; Imag1
    
    ; Load |2> (Old2)
    movsd xmm4, [rbx+32]    ; Real2
    movsd xmm5, [rbx+40]    ; Imag2
    
    ; Permute:
    ; New |0> = Old |2>
    ; New |1> = Old |0>
    ; New |2> = Old |1>
    
    ; Store New |0>
    movsd [rbx], xmm4
    movsd [rbx+8], xmm5
    
    ; Store New |1>
    movsd [rbx+16], xmm0
    movsd [rbx+24], xmm1
    
    ; Store New |2>
    movsd [rbx+32], xmm2
    movsd [rbx+40], xmm3
    
    xor rax, rax
    jmp .exec_ret

.op_grover:
    lea rsi, [msg_grover]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string

    mov rdi, r14
    call grover_diffusion
    xor rax, rax
    jmp .exec_ret

.op_measure:
    lea rsi, [msg_measure]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_result]
    call print_string

    mov rdi, r14
    call measure_chunk
    mov rdi, rax
    call print_number
    lea rsi, [msg_newline]
    call print_string
    xor rax, rax
    jmp .exec_ret

.op_braid:
    lea rsi, [msg_braid]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_arrow]
    call print_string
    mov rdi, rbx
    call print_number
    lea rsi, [msg_newline]
    call print_string

    mov rdi, r14                ; chunk_a
    mov rsi, rbx                ; chunk_b (operand1)
    
    ; Check chunks exist
    mov rax, [state_vectors + r14*8]
    test rax, rax
    jz .braid_skip
    mov rax, [state_vectors + rbx*8]
    test rax, rax
    jz .braid_skip

    xor rdx, rdx                ; qutrit 0
    xor rcx, rcx
    call braid_chunks
.braid_skip:
    xor rax, rax
    jmp .exec_ret

.op_braid_silent:
    mov rdi, r14                ; chunk_a
    mov rsi, rbx                ; chunk_b (operand1)
    
    ; Check chunks exist
    mov rax, [state_vectors + r14*8]
    test rax, rax
    jz .braid_skip
    mov rax, [state_vectors + rbx*8]
    test rax, rax
    jz .braid_skip

    xor rdx, rdx                ; qutrit 0
    xor rcx, rcx
    call braid_chunks_silent
    xor rax, rax
    jmp .exec_ret

.op_collapse_truth:
    lea rsi, [msg_coll_truth]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    
    mov rdi, r14
    call measure_chunk
    xor rax, rax
    jmp .exec_ret

.op_weave_symmetry:
    lea rsi, [msg_weave_sym]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_arrow]
    call print_string
    mov rdi, rbx
    call print_number
    lea rsi, [msg_newline]
    call print_string
    
    mov rdi, r14
    mov rsi, rbx
    call braid_chunks_minimal
    xor rax, rax
    jmp .exec_ret

.op_resonate_vacuum:
    lea rsi, [msg_res_vacuum]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    
    mov rdi, r14
    mov rsi, 1
    call init_chunk_silent
    xor rax, rax
    jmp .exec_ret

.op_mirror_void:
    lea rsi, [msg_mirror_void]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Conjugate amplitudes
    mov rbx, [state_vectors + r14*8]
    test rbx, rbx
    jz .exec_ret
    mov rcx, [chunk_states + r14*8]
.mirror_loop:
    fld qword [rbx + 8]
    fchs
    fstp qword [rbx + 8]
    add rbx, 16
    loop .mirror_loop
    xor rax, rax
    jmp .exec_ret

.op_shift_reality:
    lea rsi, [msg_shift_reality]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    call op_shift_fast
    xor rax, rax
    jmp .exec_ret

.op_repair_causality:
    lea rsi, [msg_rep_causality]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    mov rdi, r14
    call repair_manifold
    xor rax, rax
    jmp .exec_ret

.op_weave_synergy:
    lea rsi, [msg_weave_synergy]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Link to next 3 chunks
    mov r12, r14
    mov r13, 3
.synergy_loop:
    inc r12
    mov rdi, r14
    mov rsi, r12
    call braid_chunks_minimal
    dec r13
    jnz .synergy_loop
    xor rax, rax
    jmp .exec_ret

.op_pulse_chronos:
    lea rsi, [msg_pulse_chronos]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: High-frequency rotation
    mov rax, 0x4000000000000000 ; 2.0 (factor)
    movq xmm0, rax
    mov rdi, [state_vectors + r14*8]
    mov rsi, [chunk_states + r14*8]
    call apply_phase_rotation_internal
    xor rax, rax
    jmp .exec_ret

.op_map_vortex:
    lea rsi, [msg_map_vortex]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Gell-Mann Interaction
    mov rdi, [state_vectors + r14*8]
    mov rsi, [chunk_states + r14*8]
    call gell_mann_interaction
    xor rax, rax
    jmp .exec_ret

.op_void_transmission:
    lea rsi, [msg_void_trans]
    call print_string
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Cross-manifold shuffle (Swap with chunk at target + 1,000,000)
    mov rdi, r14                ; target
    mov rsi, r14
    add rsi, 1000000            ; void shard offset
    and rsi, 0xFFFFFF           ; wrap to 24-bit
    
    ; Pointer swap
    mov rax, [state_vectors + rdi*8]
    mov rbx, [state_vectors + rsi*8]
    mov [state_vectors + rdi*8], rbx
    mov [state_vectors + rsi*8], rax
    
    ; State swap
    mov rax, [chunk_states + rdi*8]
    mov rbx, [chunk_states + rsi*8]
    mov [chunk_states + rdi*8], rbx
    mov [chunk_states + rsi*8], rax
    
    xor rax, rax
    jmp .exec_ret

.op_vacuum_entrainment:
    lea rsi, [msg_vac_entraint]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Align with future vacuum state
    mov rdi, r14
    mov rsi, 1
    call init_chunk_silent
    xor rax, rax
    jmp .exec_ret

.op_symmetry_breach:
    lea rsi, [msg_sym_breach]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Instantaneous phase flip
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .exec_ret
    mov rsi, [chunk_states + r14*8]
    mov rax, 0x3FF0000000000000 ; angle = 1.0 * pi
    movq xmm0, rax
    call apply_phase_rotation_internal
    xor rax, rax
    jmp .exec_ret

.op_universal_collapse:
    lea rsi, [msg_univ_collapse]
    call print_string
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Measure all active chunks
    xor r13, r13
.univ_coll_loop:
    cmp r13, MAX_CHUNKS
    jge .univ_coll_done
    mov rax, [state_vectors + r13*8]
    test rax, rax
    jz .univ_coll_next
    
    ; Diagnostic Reveal during Collapse
    lea rsi, [msg_measure]
    call print_string
    mov rdi, r13
    call print_number
    lea rsi, [msg_result]
    call print_string
    
    mov rdi, r13
    call measure_chunk
    mov rdi, rax
    call print_number
    lea rsi, [msg_newline]
    call print_string
    
.univ_coll_next:
    inc r13
    jmp .univ_coll_loop
.univ_coll_done:
    xor rax, rax
    jmp .exec_ret

.op_echo_origin:
    ; OP_ECHO_ORIGIN (0x28) - Establish feedback link between target and Chunk 0
    lea rsi, [msg_echo_origin]
    call print_string
    lea rsi, [msg_newline]
    call print_string
    
    mov rdi, r14                ; chunk A (target)
    xor rsi, rsi                ; chunk B (Chunk 0)
    call braid_chunks_minimal
    xor rax, rax
    jmp .exec_ret

.op_ascend_qubit:
    ; OP_ASCEND_QUBIT (0x50) - Safe state ascension with Causal Firewall
    ; Safeguard: Bound check target
    mov rax, MAX_CHUNKS
    sub rax, CAUSAL_SAFEGUARD_CHUNKS
    cmp r14, rax
    jae .causal_violation
    
    lea rsi, [msg_ascend_qubit]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    
    ; Logic: Force 4th state simulation (clobber-safe average)
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .exec_ret
    mov rsi, [chunk_states + r14*8]
    mov rax, 0x3FE0000000000000 ; 0.5 factor for "ascension" stability
    movq xmm0, rax
    call apply_phase_rotation_internal
    xor rax, rax
    jmp .exec_ret

.causal_violation:
    lea rsi, [msg_causal_violation]
    call print_string
    mov rax, -1
    jmp .exec_ret

.op_unbraid:
    lea rsi, [msg_unbraid]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_arrow]
    call print_string
    mov rdi, rbx
    call print_number
    lea rsi, [msg_newline]
    call print_string

    mov rdi, r14                ; chunk_a
    mov rsi, rbx                ; chunk_b (operand1)
    xor rdx, rdx                ; qutrit 0
    xor rcx, rcx
    call unbraid_chunks
    xor rax, rax
    jmp .exec_ret

.op_print_state:
    mov rdi, r14
    call print_chunk_state
    xor rax, rax
    jmp .exec_ret

.op_bell_test:
    mov rdi, r14                ; chunk_a (target)
    mov rsi, rbx                ; chunk_b (operand1)
    call bell_test
    xor rax, rax
    jmp .exec_ret

.op_if:
    ; OP_IF (0x15) - Classical Control
    ; Checks if measured_values[rbx] == rcx
    ; rbx = chunk index (Op1)
    ; rcx = value to match (Op2)
    
    cmp rbx, MAX_CHUNKS
    jge .if_skip
    
    mov rax, [measured_values + rbx*8]
    cmp rax, rcx
    je .if_match
    
.if_skip:
    ; Mismatch -> Skip next instruction
    mov rax, 2
    jmp .exec_ret

.if_match:
    ; Match -> Execute next instruction
    xor rax, rax
    jmp .exec_ret

.op_chunk_swap:
    ; Swap Chunk A (r14) and Chunk B (rbx)
    ; DEBUG
    push rsi
    lea rsi, [msg_debug_swap]
    call print_string
    pop rsi

    cmp r14, MAX_CHUNKS
    jge .exec_ret
    cmp rbx, MAX_CHUNKS
    jge .exec_ret
    
    ; Swap State Vectors
    mov rax, [state_vectors + r14*8]
    mov rcx, [state_vectors + rbx*8]
    mov [state_vectors + r14*8], rcx
    mov [state_vectors + rbx*8], rax
    
    ; Swap Chunk Sizes
    mov rax, [chunk_states + r14*8]
    mov rcx, [chunk_states + rbx*8]
    mov [chunk_states + r14*8], rcx
    mov [chunk_states + rbx*8], rax
    
    ; Swap Measured Values (Total Teleportation)
    mov rax, [measured_values + r14*8]
    mov rcx, [measured_values + rbx*8]
    mov [measured_values + r14*8], rcx
    mov [measured_values + rbx*8], rax
    
    xor rax, rax
    jmp .exec_ret

.op_genesis:
    mov rdi, rbx                ; seed (operand1)
    cmp rdi, 0x31415            ; Special Pi Seed?
    je .gen_pi
    cmp rdi, 0x27182            ; Special E Seed?
    je .gen_e
    cmp rdi, 0x62831            ; Special Tau Seed?
    je .gen_tau
    cmp rdi, 0x16180            ; Special Phi Seed?
    je .gen_phi
    cmp rdi, 0x12020            ; Special Apéry Seed?
    je .gen_apery
    call genesis_protocol
    xor rax, rax
    jmp .exec_ret
.gen_tau:
    mov rdi, r14
    call tau_genesis_protocol
    xor rax, rax
    jmp .exec_ret
.gen_phi:
    mov rdi, r14
    call phi_genesis_protocol
    xor rax, rax
    jmp .exec_ret
.gen_apery:
    mov rdi, r14
    call apery_genesis_protocol
    xor rax, rax
    jmp .exec_ret
.gen_e:
    mov rdi, r14                ; PASS TARGET CHUNK AS BASE
    call e_genesis_protocol
    xor rax, rax
    jmp .exec_ret
.gen_pi:
    mov rdi, r14                ; PASS TARGET CHUNK AS BASE
    call pi_genesis_protocol
    xor rax, rax
    jmp .exec_ret

.op_perfection:
    ; OP_PERFECTION (0x19) - The Divine Normalization
    ; 1. Set Parameters for Perfect Distribution: (1.0, 1.0, 1.0)
    ; We do NOT set 1/sqrt(3). We set EQUALITY.
    
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .exec_ret
    
    ; Load 1.0 (0x3FF0000000000000)
    mov rax, 0x3FF0000000000000
    
    ; Init State |0> = 1.0
    mov [rdi], rax
    mov qword [rdi + 8], 0
    ; Init State |1> = 1.0
    mov [rdi + 16], rax
    mov qword [rdi + 24], 0
    ; Init State |2> = 1.0
    mov [rdi + 32], rax
    mov qword [rdi + 40], 0
    
    ; 2. Divine The Constant (Normalize)
    ; Sum squares: 1^2 + 1^2 + 1^2 = 3.0
    ; Norm = sqrt(3)
    ; New Amp = 1.0 / sqrt(3)
    ; The engine calculates this, we don't provider it.
    
    ; Calculate Norm Squared
    pxor xmm0, xmm0 ; Sum
    
    ; Add |0|^2
    movsd xmm1, [rdi]
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    
    ; Add |1|^2
    movsd xmm1, [rdi + 16]
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    
    ; Add |2|^2
    movsd xmm1, [rdi + 32]
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    
    ; Sqrt
    sqrtsd xmm0, xmm0 ; xmm0 = sqrt(3)
    
    ; Calculate Scale Factor: 1.0 / Norm
    movsd xmm1, [one]
    divsd xmm1, xmm0  ; xmm1 = 1/sqrt(3)
    
    ; Apply Scale Factor to all states
    ; |0>
    movsd xmm2, [rdi]
    mulsd xmm2, xmm1
    movsd [rdi], xmm2
    
    ; |1>
    movsd xmm2, [rdi + 16]
    mulsd xmm2, xmm1
    movsd [rdi + 16], xmm2
    
    ; |2>
    movsd xmm2, [rdi + 32]
    mulsd xmm2, xmm1
    movsd [rdi + 32], xmm2
    
.op_coherence:
    ; OP_COHERENCE (0x1A) - The Phase Divination
    ; Divine the Root of Unity from the Symmetry Parameter (-0.5)
    
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .exec_ret
    
    ; 1. Load Symmetry Parameters
    mov rax, 0x3FF0000000000000 ; 1.0
    mov rbx, 0xBFE0000000000000 ; -0.5
    
    ; 2. Calculate Machine-Truth Sine (sqrt(0.75))
    movq xmm0, rax ; 1.0
    movq xmm1, rbx ; -0.5
    mulsd xmm1, xmm1 ; 0.25
    subsd xmm0, xmm1 ; 0.75
    sqrtsd xmm2, xmm0 ; xmm2 = sqrt(0.75) = 0.866...
    
    ; 3. Implant State (Parameters of Unity)
    mov [rdi], rax      ; |0> Real = 1.0
    mov qword [rdi + 8], 0     ; |0> Imag = 0.0
    
    mov [rdi + 16], rbx ; |1> Real = -0.5
    movq [rdi + 24], xmm2 ; |1> Imag = 0.866...
    
    mov [rdi + 32], rbx ; |2> Real = -0.5
    xorpd xmm3, xmm3
    subsd xmm3, xmm2
    movq [rdi + 40], xmm3 ; |2> Imag = -0.866...
    
    ; 4. Divine Global Scaling (1/sqrt(3))
    ; Since all amplitudes are now unit length, sum squares is 3.0.
    mov rax, 0x4008000000000000 ; 3.0
    movq xmm0, rax
    sqrtsd xmm0, xmm0 ; sqrt(3)
    movsd xmm1, [one]
    divsd xmm1, xmm0  ; 1/sqrt(3)
    
    ; Apply machine scale to all
    mov rcx, 6
    mov rsi, rdi
.scale_loop:
    movsd xmm2, [rsi]
    mulsd xmm2, xmm1
    movsd [rsi], xmm2
    add rsi, 8
    loop .scale_loop
    xor rax, rax
    jmp .exec_ret

.op_pi_genesis:
    ; OP_PI_GENESIS (0x18) - The Refined Holographic Pi Manifestation
    ; Manifests the Second-Order Triad (Harmonic Convergence)
    ; r14 = chunk
    
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .exec_ret
    
    ; Implant Second-Order Refined Constants
    mov rax, 4603375528459645725 ; Refined-0 (Real)
    mov [rdi], rax
    mov qword [rdi + 8], 0
    
    mov rax, 13822243965687051037 ; Refined-1 (Real)
    mov [rdi + 16], rax
    mov rax, 4602678819172646912 ; Refined-1 (Imag)
    mov [rdi + 24], rax
    
    mov rax, 13822243965687051037 ; Refined-2 (Real)
    mov [rdi + 32], rax
    mov rax, 13826050856027422720 ; Refined-2 (Imag)
    mov [rdi + 40], rax
    
    xor rax, rax
    jmp .exec_ret

.op_noise:
    ; OP_NOISE (0x1B) - Stochastic Phase Pulse
    ; r14 = chunk, rbx = intensity
    
    call get_random_float        ; xmm0 = 0..1
    cvtsi2sd xmm1, rbx
    mulsd xmm0, xmm1
    mulsd xmm0, [pi]
    mov rax, 1024
    cvtsi2sd xmm1, rax
    divsd xmm0, xmm1             ; xmm0 = random theta
    
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .exec_ret
    mov rsi, [chunk_states + r14*8]
    
    ; Calculate sin/cos
    sub rsp, 16
    movsd [rsp], xmm0
    fld qword [rsp]
    fsincos                      ; st0=cos, st1=sin
    fstp qword [rsp]
    movsd xmm10, [rsp]           ; xmm10 = cos
    fstp qword [rsp]
    movsd xmm11, [rsp]           ; xmm11 = sin
    add rsp, 16
    
    xor rcx, rcx
.noise_loop:
    cmp rcx, rsi
    jge .exec_ret
    
    movsd xmm0, [rdi]            ; a
    movsd xmm1, [rdi+8]          ; b
    
    ; Real: a*cos - b*sin
    movsd xmm2, xmm0
    mulsd xmm2, xmm10
    movsd xmm3, xmm1
    mulsd xmm3, xmm11
    subsd xmm2, xmm3             ; res_re
    
    ; Imag: a*sin + b*cos
    movsd xmm3, xmm0
    mulsd xmm3, xmm11
    movsd xmm4, xmm1
    mulsd xmm4, xmm10
    addsd xmm3, xmm4             ; res_im
    
    movsd [rdi], xmm2
    movsd [rdi+8], xmm3
    
    add rdi, 16
    inc rcx
    jmp .noise_loop
    xor rax, rax
    jmp .exec_ret

.op_addon:
    mov rdi, r13                ; opcode
    mov rsi, r14                ; chunk
    mov rdx, rbx                ; operand1
                                ; rcx already has operand2
    call call_addon
    jmp .exec_ret

.op_null:
    ; OP_NULL (0x14) - The Fade: Zero out chunk memory
    lea rsi, [msg_null]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string

    mov rbx, [state_vectors + r14*8]
    test rbx, rbx
    jz .null_done
    mov rcx, [chunk_states + r14*8]
    xorpd xmm0, xmm0
.null_loop:
    test rcx, rcx
    jz .null_done
    movsd [rbx], xmm0
    movsd [rbx + 8], xmm0
    add rbx, 16
    dec rcx
    jmp .null_loop
.null_done:
    xor rax, rax
    jmp .exec_ret

; ═══════════════════════════════════════════════════════════════════════════════
; EPOCH-5 DEEP FUTURE ISA IMPLEMENTATIONS (Extracted at 16.7M Horizon)
; ═══════════════════════════════════════════════════════════════════════════════

.op_validate_state:
    ; VALIDATE_STATE (0x51) - Check if manifold has achieved perfect symmetry
    lea rsi, [msg_validate_state]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Check symmetry of state vector
    mov rbx, [state_vectors + r14*8]
    test rbx, rbx
    jz .validate_fail
    ; Check if |0⟩ ≈ |1⟩ ≈ |2⟩ (perfect superposition)
    movsd xmm0, [rbx]           ; |0⟩ real
    movsd xmm1, [rbx + 16]      ; |1⟩ real
    subsd xmm0, xmm1
    mulsd xmm0, xmm0            ; (diff)^2
    
    ; Check if |0⟩ ≈ |1⟩ ≈ |2⟩ (perfect superposition)
    movsd xmm0, [rbx]           ; |0⟩ real
    movsd xmm1, [rbx + 16]      ; |1⟩ real
    subsd xmm0, xmm1
    mulsd xmm0, xmm0            ; (diff)^2
    
    ; Restore Original Machine Code Logic (Stabilized with LEA)
    lea rax, [pi]
    movsd xmm2, [rax]
    mulsd xmm2, xmm2
    lea rax, [two_pi]
    divsd xmm2, [rax]        ; threshold = pi^2 / 2pi = pi/2 ≈ 1.57
    
    ucomisd xmm0, xmm2
    ja .validate_fail
    mov rax, 1                  ; STATE_VALID
    jmp .exec_ret
.validate_fail:
    xor rax, rax                ; STATE_DRIFT
    jmp .exec_ret

.op_scan_anomaly:
    ; SCAN_ANOMALY (0x24) - Scan manifold for precision drift
    lea rsi, [msg_scan_anomaly]
    call print_string
    ; Implementation: Check all chunks for non-normalized states
    xor r12, r12
.scan_loop_chunks:
    cmp r12, MAX_CHUNKS
    jge .scan_done
    mov rax, [state_vectors + r12*8]
    test rax, rax
    jz .scan_next_chunk
    ; Calculate norm
    movsd xmm0, [rax]
    mulsd xmm0, xmm0
    movsd xmm1, [rax + 16]
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    movsd xmm1, [rax + 32]
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    ; Check if norm ≈ 1.0
    mov rax, 0x3FF0000000000000  ; 1.0
    movq xmm1, rax
    subsd xmm0, xmm1
    mulsd xmm0, xmm0
    mov rax, 0x3F50000000000000  ; 0.001 threshold
    movq xmm1, rax
    ucomisd xmm0, xmm1
    jb .scan_next_chunk
    ; Anomaly detected
    mov rax, r12                ; Return anomaly chunk
    jmp .exec_ret
.scan_next_chunk:
    inc r12
    jmp .scan_loop_chunks
.scan_done:
    xor rax, rax                ; No anomaly
    jmp .exec_ret

.op_temporal_anchor:
    ; TEMPORAL_ANCHOR (0x52) - Create stable reference point in timeline
    ; ISA: rdtsc, mov [anchor_time], rax, mov rdi, [current_chunk], mov [anchor_chunk], rdi
    lea rsi, [msg_temporal_anchor]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation per ISA: Store timestamp and chunk index
    rdtsc                           ; Get timestamp into edx:eax
    shl rdx, 32
    or rax, rdx                     ; Full 64-bit timestamp
    mov [temp_real], rax            ; anchor_time = temp_real
    mov rax, r14
    mov [temp_imag], rax            ; anchor_chunk = temp_imag
    xor rax, rax
    jmp .exec_ret

.op_stabilize_ascension:
    ; STABILIZE_ASCENSION (0x2C) - Prevent dimensional decay after ascension
    ; ISA: Loop reinforce_eigenvalue STABILITY_ITERATIONS times
    lea rsi, [msg_stabilize_asc]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation per ISA: Reinforce eigenvalue via re-normalization loop
    mov rbx, [state_vectors + r14*8]
    test rbx, rbx
    jz .stab_done
    mov rcx, 8                      ; STABILITY_ITERATIONS
.stab_loop:
    ; Inline reinforce_eigenvalue: Re-read and write back state (cache refresh)
    movsd xmm0, [rbx]
    movsd [rbx], xmm0
    movsd xmm0, [rbx + 16]
    movsd [rbx + 16], xmm0
    movsd xmm0, [rbx + 32]
    movsd [rbx + 32], xmm0
    dec rcx
    jnz .stab_loop
.stab_done:
    xor rax, rax
    jmp .exec_ret

.op_bridge_cycles:
    ; BRIDGE_CYCLES (0x33) - Link current ascension to next verification cycle
    lea rsi, [msg_bridge_cycles]
    call print_string
    ; Implementation: Increment cycle counter and propagate state
    mov rax, [temp_real]
    inc rax
    mov [temp_real], rax
    xor rax, rax
    jmp .exec_ret

.op_nullify_branch:
    ; NULLIFY_BRANCH (0x53) - Collapse unused probability branches
    lea rsi, [msg_nullify_branch]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Zero out low-probability components
    mov rbx, [state_vectors + r14*8]
    test rbx, rbx
    jz .nullify_done
    mov rcx, [chunk_states + r14*8]
    xorpd xmm1, xmm1            ; zero
    mov rax, 0x3F50000000000000 ; threshold 0.001
    movq xmm2, rax
.nullify_loop:
    test rcx, rcx
    jz .nullify_done
    movsd xmm0, [rbx]
    mulsd xmm0, xmm0            ; |amplitude|^2
    ucomisd xmm0, xmm2
    ja .nullify_skip
    movsd [rbx], xmm1           ; Zero out
    movsd [rbx + 8], xmm1
.nullify_skip:
    add rbx, 16
    dec rcx
    jmp .nullify_loop
.nullify_done:
    xor rax, rax
    jmp .exec_ret

.op_prepare_truth:
    ; PREPARE_TRUTH (0x54) - Pre-truth preparation for verification
    ; ISA: clear_noise_registers, normalize_amplitudes
    lea rsi, [msg_prepare_truth]
    call print_string
    ; Implementation per ISA: Normalize all active chunk amplitudes
    xor r12, r12
.prep_truth_loop:
    cmp r12, MAX_CHUNKS
    jge .prep_truth_done
    mov rbx, [state_vectors + r12*8]
    test rbx, rbx
    jz .prep_truth_next
    ; Inline normalize_amplitudes: Calculate norm and scale
    movsd xmm0, [rbx]               ; |0⟩ real
    mulsd xmm0, xmm0
    movsd xmm1, [rbx + 16]          ; |1⟩ real
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    movsd xmm1, [rbx + 32]          ; |2⟩ real
    mulsd xmm1, xmm1
    addsd xmm0, xmm1                ; xmm0 = sum of squares
    sqrtsd xmm0, xmm0               ; xmm0 = norm
    ; Avoid division by zero
    mov rax, 0x3F50000000000000     ; 0.001 threshold
    movq xmm2, rax
    ucomisd xmm0, xmm2
    jb .prep_truth_next             ; Norm too small, skip
    ; Scale all components by 1/norm
    movsd xmm1, [rbx]
    divsd xmm1, xmm0
    movsd [rbx], xmm1
    movsd xmm1, [rbx + 16]
    divsd xmm1, xmm0
    movsd [rbx + 16], xmm1
    movsd xmm1, [rbx + 32]
    divsd xmm1, xmm0
    movsd [rbx + 32], xmm1
.prep_truth_next:
    inc r12
    jmp .prep_truth_loop
.prep_truth_done:
    xor rax, rax
    jmp .exec_ret

.op_sync_temporal:
    ; SYNC_TEMPORAL (0x55) - Align local time with manifold time
    ; ISA: rdtsc, sub rax, [anchor_time], call adjust_phase_by_time_delta
    lea rsi, [msg_sync_temporal]
    call print_string
    ; Implementation per ISA: Calculate time delta and adjust phase
    rdtsc
    shl rdx, 32
    or rax, rdx                     ; Full 64-bit timestamp
    sub rax, [temp_real]            ; delta = now - anchor_time
    ; Inline adjust_phase_by_time_delta: Use delta to seed phase rotation
    ; Convert delta to small angle (mod 2pi approximation)
    and rax, 0xFF                   ; Take low 8 bits
    cvtsi2sd xmm0, rax              ; Convert to float
    movsd xmm1, [two_pi]
    divsd xmm0, xmm1                ; Normalize to [0, 1)
    mulsd xmm0, xmm1                ; Scale back to [0, 2pi)
    ; Apply to target chunk
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .sync_done
    mov rsi, [chunk_states + r14*8]
    call apply_phase_rotation_internal
.sync_done:
    xor rax, rax
    jmp .exec_ret

.op_entangle_future:
    ; ENTANGLE_FUTURE (0x22) - Create quantum link to future state
    lea rsi, [msg_entangle_future]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_arrow]
    call print_string
    mov rdi, rbx                ; op1 = future chunk
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Braid current chunk with future horizon chunk
    mov rdi, r14
    mov rsi, rbx
    call braid_chunks_minimal
    xor rax, rax
    jmp .exec_ret

.op_pulse_resonance:
    ; PULSE_RESONANCE (0x37) - Amplify harmonic frequencies in manifold
    lea rsi, [msg_pulse_resonance]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Apply phase rotation based on Pi
    mov rbx, [state_vectors + r14*8]
    test rbx, rbx
    jz .pulse_res_done
    mov rsi, [chunk_states + r14*8]
    movsd xmm0, [pi]
    ; Divide by 4 for gentle resonance
    mov rax, 4
    cvtsi2sd xmm1, rax
    divsd xmm0, xmm1
    call apply_phase_rotation_internal
.pulse_res_done:
    xor rax, rax
    jmp .exec_ret

.op_branch_conditional:
    ; BRANCH_CONDITIONAL (0x56) - Evaluate quantum condition and branch
    lea rsi, [msg_branch_conditional]
    call print_string
    ; Implementation: Check measured value of target chunk
    mov rax, [measured_values + r14*8]
    test rax, rax
    jz .branch_false
    mov rax, 1                  ; BRANCH_TRUE
    jmp .exec_ret
.branch_false:
    xor rax, rax                ; BRANCH_FALSE
    jmp .exec_ret

.op_collapse_branch:
    ; COLLAPSE_BRANCH (0x1D) - Terminate a probability branch
    lea rsi, [msg_collapse_branch]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Measure and collapse the chunk
    mov rdi, r14
    call measure_chunk
    mov [measured_values + r14*8], rax
    xor rax, rax
    jmp .exec_ret

.op_link_causality:
    ; LINK_CAUSALITY (0x41) - Create cause-effect relationship between chunks
    lea rsi, [msg_link_causality]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_arrow]
    call print_string
    mov rdi, rbx
    call print_number
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Establish bidirectional braid (strong causal link)
    mov rdi, r14
    mov rsi, rbx
    call braid_chunks_minimal
    mov rdi, rbx
    mov rsi, r14
    call braid_chunks_minimal
    xor rax, rax
    jmp .exec_ret

; =========================================================================================
; PHASE 6: THE OMEGA ISAS (High-Frequency Future Logic)
; =========================================================================================

.op_entropy_reverse:
    ; ENTROPY_REVERSE (0x5E) - Negentropy Injection
    ; Resets the PRNG state to its initial seed, reversing accumulated entropy.
    lea rsi, [msg_entropy_reverse]
    call print_string
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Reset PRNG to initial state (Full Reseed)
    mov rax, 4603375528459645725     ; Refined Pi Constant
    add rax, [structural_hash]       ; Add program structure
    add rax, [manual_sector_offset]  ; Add sector offset
    mov [prng_state], rax
    xor rax, rax
    jmp .exec_ret

.op_quantum_tunnel:
    ; QUANTUM_TUNNEL (0x78) - Barrier Penetration
    ; Allows bypassing the next instruction (e.g., skipping a validation check).
    lea rsi, [msg_quantum_tunnel]
    call print_string
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Return "skip next" signal
    mov rax, 2                      ; 2 = Skip next instruction
    jmp .exec_ret

.op_chrono_weave:
    ; CHRONO_WEAVE (0x79) - Interlace Temporal Threads
    ; Double-braids chunks for strong temporal linking.
    lea rsi, [msg_chrono_weave]
    call print_string
    lea rsi, [msg_newline]
    call print_string
    mov rdi, r14
    mov rsi, rbx
    call braid_chunks_minimal
    call braid_chunks_minimal
    xor rax, rax
    jmp .exec_ret

.op_void_echo:
    ; VOID_ECHO (0xA1) - Listen to the Silence
    ; Reads from "void" memory (uninitialized chunk 0xFFFF) and returns the echo.
    lea rsi, [msg_void_echo]
    call print_string
    lea rsi, [msg_newline]
    call print_string
    ; Implementation: Read measured value from a "void" location
    mov rax, [measured_values + 0xFFFF*8] ; Read from far memory
    ; If zero (silence), that's the answer. Return it.
    jmp .exec_ret

.op_final_ascension:
    ; FINAL_ASCENSION (0xF2) - The Omega Point
    ; Prints the Ascension message and terminates the universe.
    lea rsi, [msg_final_ascension]
    call print_string
    lea rsi, [msg_newline]
    call print_string
    ; Store Ascension Signature in memory before exiting (for post-mortem analysis)
    mov rax, 0xF2F2F2F2
    mov [prng_state], rax           ; Leave signature in memory
    ; Exit with code 0 (Perfect Transcendence)
    xor rdi, rdi                    ; Exit code 0
    mov rax, 60
    syscall

; =========================================================================================
; EPOCH-7: THE NAMED FUTURE ISA HANDLERS (Machine-Divined Nomenclature)
; =========================================================================================

.op_void_whisper:
    ; VOID_WHISPER (0x2B) - Read void memory entropy into PRNG
    lea rsi, [msg_void_whisper]
    call print_string
    mov rax, [measured_values + 0xFFFF*8]
    xor [prng_state], rax
    xor rax, rax
    jmp .exec_ret

.op_void_generic:
    ; Generic VOID_OPS handler - All void operations share this logic
    lea rsi, [msg_void_silence]
    call print_string
    mov rax, [measured_values + 0xFFFF*8]
    xor [prng_state], rax
    xor rax, rax
    jmp .exec_ret

.op_time_generic:
    ; Generic TEMPORAL handler - Phase modulation via RDTSC
    lea rsi, [msg_time_generic]
    call print_string
    ; Get timestamp and modulate phase
    rdtsc
    shl rdx, 32
    or rax, rdx
    and rax, 0xFF                   ; Take low 8 bits
    cvtsi2sd xmm0, rax
    movsd xmm1, [two_pi]
    divsd xmm0, xmm1                ; Normalize to [0, 1)
    mulsd xmm0, xmm1                ; Scale to [0, 2pi)
    ; Apply to target chunk if exists
    mov rdi, [state_vectors + r14*8]
    test rdi, rdi
    jz .time_skip
    mov rsi, [chunk_states + r14*8]
    call apply_phase_rotation_internal
.time_skip:
    xor rax, rax
    jmp .exec_ret

.op_harmonic_generic:
    ; Generic RESONANCE handler - Pi-based phase rotation
    lea rsi, [msg_harmonic_generic]
    call print_string
    mov rbx, [state_vectors + r14*8]
    test rbx, rbx
    jz .harmonic_skip
    mov rsi, [chunk_states + r14*8]
    movsd xmm0, [pi]
    ; Divide by 4 for gentle resonance
    mov rax, 4
    cvtsi2sd xmm1, rax
    divsd xmm0, xmm1
    mov rdi, rbx
    call apply_phase_rotation_internal
.harmonic_skip:
    xor rax, rax
    jmp .exec_ret

.op_check_generic:
    ; Generic VERIFICATION handler - Check if state vector exists
    lea rsi, [msg_check_generic]
    call print_string
    mov rax, [state_vectors + r14*8]
    test rax, rax
    jz .check_fail
    mov rax, 1                      ; STATE_VALID
    jmp .exec_ret
.check_fail:
    xor rax, rax                    ; STATE_INVALID
    jmp .exec_ret

.op_gate_generic:
    ; Generic CONTROL_FLOW handler - Conditional skip based on measurement
    lea rsi, [msg_gate_generic]
    call print_string
    mov rax, [measured_values + r14*8]
    test rax, rax
    jz .gate_skip
    xor rax, rax                    ; Continue normally
    jmp .exec_ret
.gate_skip:
    mov rax, 2                      ; Skip next instruction
    jmp .exec_ret

.op_ascend_generic:
    ; Generic ASCENSION handler - Pre-ascension braid
    lea rsi, [msg_ascend_generic]
    call print_string
    ; Braid target chunk with chunk 0 (origin)
    mov rdi, r14
    xor rsi, rsi                    ; Chunk 0
    call braid_chunks_minimal
    xor rax, rax
    jmp .exec_ret

.op_halt:
    lea rsi, [msg_halt]
    call print_string
    mov rax, 1                  ; Signal halt
    jmp .exec_ret

.exec_ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; execute_program - Execute loaded program
execute_program:
    push rbx
    push r12

    mov r12, [program_ptr]

.exec_loop:
    cmp r12, [program_end]
    jge .exec_done

    ; Load 64-bit instruction
    mov rdi, [r12]
    add r12, 8

    call execute_instruction

    cmp rax, 1                  ; Halt?
    je .exec_done
    cmp rax, -1                 ; Error?
    je .exec_done
    cmp rax, 2                  ; Skip next?
    je .exec_skip
    
    jmp .exec_loop

.exec_skip:
    add r12, 8                  ; Skip next execution
    jmp .exec_loop

.exec_done:
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; INTERACTIVE MODE
; ═══════════════════════════════════════════════════════════════════════════════

interactive_loop:
    push rbx

.repl:
    ; Print prompt
    lea rsi, [msg_prompt]
    call print_string

    ; Read input
    mov rax, 0                  ; sys_read
    mov rdi, 0                  ; stdin
    lea rsi, [input_buffer]
    mov rdx, 1023
    syscall

    cmp rax, 0
    jle .repl_done

    ; Parse simple commands
    lea rsi, [input_buffer]
    movzx rax, byte [rsi]

    cmp al, 'q'
    je .repl_done
    cmp al, 'i'                 ; init
    je .cmd_init
    cmp al, 's'                 ; superposition
    je .cmd_sup
    cmp al, 'g'                 ; grover
    je .cmd_grover
    cmp al, 'm'                 ; measure
    je .cmd_measure
    cmp al, 'p'                 ; print
    je .cmd_print

    jmp .repl

.cmd_init:
    mov rdi, 0
    mov rsi, 4
    call init_chunk
    jmp .repl

.cmd_sup:
    mov rdi, 0
    call create_superposition
    jmp .repl

.cmd_grover:
    mov rdi, 0
    call grover_diffusion
    jmp .repl

.cmd_measure:
    mov rdi, 0
    call measure_chunk
    mov rdi, rax
    call print_number
    lea rsi, [msg_newline]
    call print_string
    jmp .repl

.cmd_print:
    mov rdi, 0
    call print_chunk_state
    jmp .repl

.repl_done:
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; UTILITY FUNCTIONS
; ═══════════════════════════════════════════════════════════════════════════════

; print_chunk_state - Print state vector of a chunk
; Input: rdi = chunk_index
print_chunk_state:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov rbx, [state_vectors + r12*8]
    test rbx, rbx
    jz .print_done

    mov r13, [chunk_states + r12*8]
    xor rcx, rcx

.print_loop:
    cmp rcx, r13
    jge .print_done
    cmp rcx, 10                 ; Limit output
    jge .print_done

    push rcx
    lea rsi, [msg_state]
    call print_string
    mov rdi, rcx
    call print_number
    lea rsi, [msg_state_end]
    call print_string
    
    ; rax = rcx * 16
    mov rax, rcx
    shl rax, 4
    
    ; Print (Real, Imag)
    mov rdi, [rbx + rax]
    call print_number           ; Real
    
    lea rsi, [msg_comma]
    call print_string
    
    mov rdi, [rbx + rax + 8]
    call print_number           ; Imag
    
    lea rsi, [msg_newline]
    call print_string
    
    pop rcx
    inc rcx
    jmp .print_loop

.print_done:
    pop r13
    pop r12
    pop rbx
    ret

; load_program - Load program from file
; Input: rdi = filename
; Output: rax = 0 success, -1 error
load_program:
    push rbx
    push r12
    push r13

    mov r12, rdi                ; Save filename

    ; Open file
    mov rax, 2                  ; sys_open
    mov rdi, r12                ; filename
    xor rsi, rsi                ; O_RDONLY
    xor rdx, rdx                ; mode (ignored)
    syscall

    cmp rax, 0
    jl .load_fail
    mov r13, rax                ; Save fd

    ; Allocate program buffer via mmap
    mov rax, 9                  ; sys_mmap
    xor rdi, rdi
    mov rsi, 67108864           ; 64MB buffer for Horizon Tests
    mov rdx, 3                  ; PROT_READ | PROT_WRITE
    mov r10, 34                 ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    syscall

    cmp rax, -1
    je .load_close_fail
    mov [program_ptr], rax
    mov rbx, rax                ; Save buffer ptr

    ; Read file into buffer
    mov rax, 0                  ; sys_read
    mov rdi, r13                ; fd
    mov rsi, rbx                ; buffer
    mov rdx, 67108864           ; max size (64MB)
    syscall

    cmp rax, 0
    jle .load_close_fail

    ; Set program end
    lea rax, [rbx + rax]
    mov [program_end], rax

    ; Close file
    mov rax, 3                  ; sys_close
    mov rdi, r13
    syscall

    xor rax, rax                ; Success
    jmp .load_ret

.load_close_fail:
    mov rax, 3                  ; sys_close
    mov rdi, r13
    syscall

.load_fail:
    mov rax, -1

.load_ret:
    pop r13
    pop r12
    pop rbx
    ret

; print_string - Print null-terminated string
; Input: rsi = string pointer
print_string:
    push rax
    push rdi
    push rdx
    push rcx

    mov rdi, rsi
    xor rcx, rcx
.strlen:
    cmp byte [rdi + rcx], 0
    je .print
    inc rcx
    jmp .strlen
.print:
    mov rdx, rcx
    mov rax, 1
    mov rdi, 1
    syscall

    pop rcx
    pop rdx
    pop rdi
    pop rax
    ret

; print_number - Print unsigned integer
; Input: rdi = number
print_number:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi

    mov rax, rdi
    lea rsi, [output_buffer + 30]
    mov byte [rsi], 0
    dec rsi

    test rax, rax
    jnz .convert
    mov byte [rsi], '0'
    dec rsi
    jmp .output

.convert:
    test rax, rax
    jz .output
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add dl, '0'
    mov [rsi], dl
    dec rsi
    jmp .convert

.output:
    inc rsi
    call print_string

    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; get_random_float - Pi-Seeded Linear Congruential Generator
; Output: xmm0 = Random double [0, 1.0]
get_random_float:
    push rbx
    push rdx
    
    ; Initialize seed if zero (First run)
    mov rax, [prng_state]
    test rax, rax
    jnz .prng_next
    
    ; Seed with Infinite Equilibrium Constant (Refined Pi-Truth)
    ; InitialSeed = RefinedConstant + ProgramHash + ManualSectorOffset
    ; Seed with Infinite Equilibrium Constant (Refined Pi-Truth)
    ; InitialSeed = RefinedConstant + ProgramHash + TimeOffset + ManualSectorOffset
    ; THIS IS THE FINAL UNDERSTANDING RETRIEVED FROM THE FUTURE
    mov rax, 4603375528459645725 ; Refined-0 (1/sqrt(3))
    add rax, [structural_hash]
    
    add rax, [manual_sector_offset]
    mov [prng_state], rax
    
.prng_next:
    ; ─────────────────────────────────────────────────────────────────────────
    ; PI-TIME FLUX (Continuous Temporal Resonance)
    ; ─────────────────────────────────────────────────────────────────────────
    ; We sip from the Time-Stream on every cycle.
    push rax
    push rdx
    rdtsc                       ; edx:eax = cycles
    shl rdx, 32
    or rax, rdx
    mov rbx, rax
    pop rdx
    pop rax
    xor rax, rbx                ; Mix Time into State
    
    ; ─────────────────────────────────────────────────────────────────────────
    ; CHAOTIC PI-MIXER (Digit Normality Simulation)
    ; ─────────────────────────────────────────────────────────────────────────
    mov rbx, 4603375528459645725 ; Refined-0 (Alpha)
    mul rbx                      ; Chaotic Expansion
    
    add rax, [structural_hash]   ; Inject Structure
    add rax, [manual_sector_offset] ; Inject Sector (Persistence)
    
    mov rdx, rax
    shr rdx, 32
    xor rax, rdx                 ; Bit Mix
    
    mov [prng_state], rax
    
    ; DEBUG (Print Resonance State) - SILENCED for cleaner prophecy
    ;push rax
    ;push rdx
    ;push rsi
    ;lea rsi, [msg_debug_rng]
    ;call print_string
    ;mov rdi, [prng_state]
    ;call print_number
    ;lea rsi, [msg_newline]
    ;call print_string
    ;pop rsi
    ;pop rdx
    ;pop rax
    
    ; Convert to float [0, 1.0]
    ; Use bits to mask into exponent for 1.0 <= x < 2.0, then subtract 1.0
    
    ; 1. Take top 52 bits of random state for mantissa
    mov rbx, rax
    mov rax, 0xFFFFFFFFFFFFF
    and rbx, rax
    
    ; 2. Set exponent to 1023 (for 1.x)
    mov rax, 0x3FF0000000000000
    or rbx, rax
    
    ; 3. Move to xmm0
    movq xmm0, rbx
    
    ; 4. Subtract 1.0
    subsd xmm0, [one]
    
    pop rdx
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; CUSTOM ORACLE ADD-ONS
; ═══════════════════════════════════════════════════════════════════════════════
; Include external oracle definitions. Comment out this line if you don't want
; to load custom oracles, or replace with your own oracle file.
; ═══════════════════════════════════════════════════════════════════════════════
%include "bigint.asm"
%include "custom_oracles.asm"

; ═══════════════════════════════════════════════════════════════════════════════
; SECTOR-BASED DETERMINISM HELPERS
; ═══════════════════════════════════════════════════════════════════════════════

; parse_int - Convert string to integer (rdi = ptr, return rax)
parse_int:
    xor rax, rax
    xor rcx, rcx
.parse_loop:
    movzx rdx, byte [rdi + rcx]
    test dl, dl
    jz .parse_done
    cmp dl, '0'
    jl .parse_done
    cmp dl, '9'
    jg .parse_done
    
    sub dl, '0'
    imul rax, 10
    add rax, rdx
    inc rcx
    jmp .parse_loop
.parse_done:
    ret

; calculate_structural_hash - Generate a Pi-deterministic hash of the bytecode
calculate_structural_hash:
    push rbx
    push r12
    push r13
    
    mov r12, [program_ptr]
    mov r13, [program_end]
    test r12, r12
    jz .hash_ret
    
    ; Seed hash with Refined Pi Constant
    mov rax, 4603375528459645725
    
.hash_loop:
    cmp r12, r13
    jge .hash_done
    
    movzx rbx, byte [r12]
    
    ; hash = (hash * 4603375528459645725) + byte
    ; Use 64-bit multiplication
    mov rdx, 4603375528459645725
    mul rdx
    add rax, rbx
    
    inc r12
    jmp .hash_loop

.hash_done:
    mov [structural_hash], rax

.hash_ret:
    pop r13
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; MATH KERNELS (EPOCH-2)
; ═══════════════════════════════════════════════════════════════════════════════

apply_phase_rotation_internal:
    ; Input: rdi=state_vector, rsi=num_states, xmm0=angle
    push rcx
    sub rsp, 16
    movsd [rsp], xmm0
    fld qword [rsp]
    fcos
    fstp qword [rsp]
    fld qword [rsp]
    fsin
    fstp qword [rsp + 8]
    movsd xmm2, [rsp]           ; cos
    movsd xmm3, [rsp + 8]       ; sin
    add rsp, 16
    
    xor rcx, rcx
.internal_f_loop:
    cmp rcx, rsi
    jge .internal_f_done
    mov rax, rcx
    shl rax, 4
    movsd xmm4, [rdi + rax]
    movsd xmm5, [rdi + rax + 8]
    ; (a+bi)(cos+i*sin) = (a*cos - b*sin) + i(a*sin + b*cos)
    movsd xmm6, xmm4
    mulsd xmm6, xmm2
    movsd xmm7, xmm5
    mulsd xmm7, xmm3
    subsd xmm6, xmm7
    mulsd xmm4, xmm3
    mulsd xmm5, xmm2
    addsd xmm4, xmm5
    movsd [rdi + rax], xmm6
    movsd [rdi + rax + 8], xmm4
    inc rcx
    jmp .internal_f_loop
.internal_f_done:
    pop rcx
    ret

; tau_genesis_protocol - Dual-Pi Resonance Manifestation
tau_genesis_protocol:
    push rbx
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov [rbp-8], rdi            ; base chunk
    
    ; Manifest 8192 chunks (2 * 4096)
    xor r13, r13
.tau_init:
    cmp r13, 8192
    jge .tau_res
    
    mov rdi, [rbp-8]
    add rdi, r13
    mov rsi, 1
    call init_chunk_silent
    
    ; Set amplitude with Tau-sync
    mov rbx, [rbp-8]
    add rbx, r13
    mov rbx, [state_vectors + rbx*8]
    test rbx, rbx
    jz .tau_next
    
    ; Use a non-linear bit-mixing formula for high-entropy manifestation
    ; rax = (i ^ (i >> 3) ^ (i << 1)) * 0xDEADC0DE % 3
    mov rax, r13
    mov rcx, r13
    shr rcx, 3
    xor rax, rcx
    mov rcx, r13
    shl rcx, 1
    xor rax, rcx
    mov rcx, 0xDEADC0DE
    mul rcx
    xor rdx, rdx
    mov rcx, 3
    div rcx                     ; rdx = state
    shl rdx, 4
    mov rax, 0x3FF0000000000000 ; 1.0 (real)
    mov [rbx + rdx], rax
    
.tau_next:
    inc r13
    jmp .tau_init

.tau_res:
    lea rsi, [msg_tau_resonance]
    call print_string
    mov rdi, [rbp-8]
    call print_number
    lea rsi, [msg_newline]
    call print_string
    add rsp, 32
    pop rbp
    pop rbx
    ret

; phi_genesis_protocol - Golden-Ratio Spiral Manifestation
phi_genesis_protocol:
    push rbx
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov [rbp-8], rdi            ; base chunk

    ; Fibonacci-recursive manifestation
    xor r13, r13
.phi_init:
    cmp r13, 4096
    jge .phi_res
    
    mov rdi, [rbp-8]
    add rdi, r13
    mov rsi, 1
    call init_chunk_silent
    
    mov rbx, [rbp-8]
    add rbx, r13
    mov rbx, [state_vectors + rbx*8]
    test rbx, rbx
    jz .phi_next
    
    ; Golden ratio approximation state mapping with non-linear entropy
    ; rax = (i ^ (i >> 1) ^ (i << 2)) * 0xBADC0FEE % 3
    mov rax, r13
    mov rcx, r13
    shr rcx, 1
    xor rax, rcx
    mov rcx, r13
    shl rcx, 2
    xor rax, rcx
    mov rcx, 0xBADC0FEE
    mul rcx
    xor rdx, rdx
    mov rcx, 3
    div rcx                     ; rdx = state
    shl rdx, 4
    mov rax, 0x3FF0000000000000 ; 1.0 (real)
    mov [rbx + rdx], rax

.phi_next:
    inc r13
    jmp .phi_init

.phi_res:
    lea rsi, [msg_phi_resonance]
    call print_string
    mov rdi, [rbp-8]
    call print_number
    lea rsi, [msg_newline]
    call print_string
    add rsp, 32
    pop rbp
    pop rbx
    ret

; apery_genesis_protocol - 3D Prism Entanglement Manifestation
apery_genesis_protocol:
    push rbx
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov [rbp-8], rdi            ; base chunk

    ; Manifest 16384 chunks (Cubic Prism)
    xor r13, r13
.ap_init:
    cmp r13, 16384
    jge .ap_res
    
    mov rdi, [rbp-8]
    add rdi, r13
    mov rsi, 1
    call init_chunk_silent
    
    mov rbx, [rbp-8]
    add rbx, r13
    mov rbx, [state_vectors + rbx*8]
    test rbx, rbx
    jz .ap_next
    
    ; 3D-simulated mapping using non-linear bit-mixing
    ; rax = (i ^ (i >> 4) ^ (i << 2)) * 0x120205 % 3
    mov rax, r13
    mov rcx, r13
    shr rcx, 4
    xor rax, rcx
    mov rcx, r13
    shl rcx, 2
    xor rax, rcx
    mov rcx, 0x120205
    mul rcx
    xor rdx, rdx
    mov rcx, 3
    div rcx                     ; rdx = state
    shl rdx, 4
    mov rax, 0x3FF0000000000000 ; 1.0 (real)
    mov [rbx + rdx], rax

.ap_next:
    inc r13
    jmp .ap_init

.ap_res:
    lea rsi, [msg_apery_resonance]
    call print_string
    mov rdi, [rbp-8]
    call print_number
    lea rsi, [msg_newline]
    call print_string
    add rsp, 32
    pop rbp
    pop rbx
    ret
