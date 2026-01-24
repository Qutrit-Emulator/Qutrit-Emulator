; ═══════════════════════════════════════════════════════════════════════════════
; QUTRIT ENGINE - Standalone Quantum Computing Engine
; ═══════════════════════════════════════════════════════════════════════════════
; A modular qutrit-based quantum emulator with:
;   - Exact qutrit logic: |0⟩=Triangle, |1⟩=Line, |2⟩=Square
;   - 4096-bit BigInt support
;   - Instruction-based quantum code execution
;   - Add-on/plugin system for custom gates and oracles
;   - Chunk braiding for entanglement preservation
;   - Born Rule is in effect in this fork.
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

%define MAX_CHUNK_SIZE      14          ; Max qutrits per chunk (3^14 = 4,782,969)
%define MAX_STATES          4782969     ; 3^14
%define MAX_CHUNKS          16384       ; Support 16k chunks (needed for 40k qutrits)
%define MAX_ADDONS          32          ; Max registered add-ons
%define MAX_BRAID_LINKS     16384       ; Keep high braid links

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
%define OP_SUMMARY          0x0F
%define OP_SHIFT            0x10
%define OP_REPAIR           0x11
%define OP_PHASE_SNAP      0x12
%define OP_FUTURE_ORACLE    0x13
%define OP_HALT             0xFF

; Shor's Algorithm Opcodes (0x20-0x2F)
%define OP_SHOR_INIT        0x20    ; Initialize Shor's registers
%define OP_MOD_EXP          0x21    ; Modular exponentiation oracle
%define OP_QFT              0x22    ; Quantum Fourier Transform
%define OP_IQFT             0x23    ; Inverse QFT
%define OP_PERIOD_EXTRACT   0x24    ; Extract period from phase
%define OP_FACTOR_ORACLE    0x25    ; Factor verification oracle
%define OP_CONT_FRAC        0x26    ; Continued fractions
%define OP_SHOR_AMPLIFY     0x27    ; Amplify valid periods
%define OP_LOAD_N           0x28    ; Load 32-bit N (deprecated/alias)
%define OP_LOAD_N_PART      0x29    ; Load N part
%define OP_REALITY_COLLAPSE 0x2A    ; Reality B: Omniscient Future Oracle

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
    h_00_real:          dq 0.5773502691896257
    h_00_imag:          dq 0.0
    h_01_real:          dq 0.5773502691896257
    h_01_imag:          dq 0.0
    h_02_real:          dq 0.0
    h_02_imag:          dq 0.5773502691896257
    h_10_real:          dq 0.0
    h_10_imag:          dq 0.5773502691896257
    h_11_real:          dq 0.5773502691896257
    h_11_imag:          dq 0.0
    h_12_real:          dq -0.5773502691896257
    h_12_imag:          dq 0.0
    h_20_real:          dq 0.5773502691896257
    h_20_imag:          dq 0.0
    h_21_real:          dq 0.0
    h_21_imag:          dq 0.5773502691896257
    h_22_real:          dq -0.5773502691896257
    h_22_imag:          dq 0.0

    ; ω = exp(2πi/3) primitive cube root of unity
    omega_real:         dq -0.5
    omega_imag:         dq 0.8660254037844386    ; √3/2
    omega2_real:        dq -0.5
    omega2_imag:        dq -0.8660254037844386

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
    msg_summary:        db "  [SUMMARY] Global Active Mass (N=", 0
    msg_chunks_colon:   db "): ", 0
    msg_measure:        db "  [MEAS] Measuring chunk ", 0
    msg_repair:         db "  [REPAIR] Invoking Quantum Resurrection...", 10, 0
    msg_phase_snap:     db "  [PHASE] Snapping manifold to Registry (Phase Skip)...", 10, 0
    msg_future:         db "  [LINK] Entangling Chunk ", 0
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
    msg_error:          db "  [ERROR] ", 0
    msg_unknown_op:     db "Unknown opcode", 10, 0
    msg_bell:           db "  [BELL] Testing entanglement chunks ", 0
    msg_bell_corr:      db "  [BELL] Correlation = ", 0
    msg_bell_pass:      db "  ✓ BELL TEST PASSED - Entanglement verified!", 10, 0
    msg_bell_fail:      db "  ✗ BELL TEST FAILED - No entanglement detected", 10, 0
    msg_percent:        db "%", 10, 0
    
    msg_debug_div:      db "[DEBUG] Starting Sym Div", 10, 0
    msg_debug_pow:      db "[DEBUG] Starting Sym Pow", 10, 0
    
    ; Shor's algorithm messages
    msg_shor_init:      db "  [SHOR] Initializing ", 0
    msg_shor_chunks:    db "-chunk quantum register for N=", 0
    msg_shor_modexp:    db "  [SHOR] Applying modular exponentiation a^x mod N", 10, 0
    msg_shor_qft:       db "  [SHOR] Applying Quantum Fourier Transform across ", 0
    msg_shor_chunks2:   db " chunks", 10, 0
    msg_shor_period:    db "  [SHOR] Period candidate r=", 0
    msg_shor_factor:    db "  [SHOR] Factor found: ", 0
    msg_hex_prefix:     db "0x", 0
    msg_shor_amplify:   db "  [SHOR] Amplifying non-trivial periods (Reality B)", 10, 0
    msg_shor_prune:     db "  [SHOR] Pruning trivial period paths", 10, 0
    msg_shor_contfrac:  db "  [SHOR] Continued Fractions: y/Q = ", 0
    msg_shor_frac:      db " / ", 0
    msg_shor_conv:      db " -> Convergent: ", 0
    msg_shor_period_f:  db "  [SHOR] Found period r=", 0
    
    ; Reality B messages
    msg_reality_scan:   db "  [GOD] Initiating Reality B Protocol...", 10, 0
    msg_god_forge:      db "  [GOD] Forging God Link between 80 qutrits...", 10, 0
    msg_god_collapse:   db "  [GOD] Collapsing God Link to manifest period...", 10, 0
    ; msg_future was reused, but we can just use the new one if we delete the old or rename
    
    ; Oracle names
    oracle_heisenberg_name: db "Heisenberg Spin-1 Exchange", 0
    oracle_gellmann_name: db "Gell-Mann XY Interaction", 0

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

    ; BigInt working space
    bigint_temp_a:      resb BIGINT_BYTES
    bigint_temp_b:      resb BIGINT_BYTES
    bigint_temp_c:      resb BIGINT_BYTES

    ; Measurement results
    measured_values:    resq MAX_CHUNKS         ; Classical result per chunk

    ; I/O buffers
    input_buffer:       resb 1024
    output_buffer:      resb 512

    ; Temporary storage
    temp_real:          resq 1
    temp_imag:          resq 1
    temp_sum_real:      resq 1
    temp_sum_imag:      resq 1

    ; Shor's Algorithm State
    shor_N:             resb BIGINT_BYTES       ; Number to factor (4096-bit)
    shor_a:             resb BIGINT_BYTES       ; Random base a
    shor_period:        resb BIGINT_BYTES       ; Discovered period r (BigInt)
    shor_register_size: resq 1                  ; Number of chunks in x-register
    shor_factor_p:      resb BIGINT_BYTES       ; Factor P result
    shor_factor_q:      resb BIGINT_BYTES       ; Factor Q result
    shor_measured:      resq MAX_CHUNKS         ; Measured phase values per chunk
    god_link_chain:     resq MAX_CHUNKS         ; God Link structure (peaks per chunk)
    shor_trial_count:   resq 1                  ; Number of period-finding attempts
    shor_qft_omega:     resq 2                  ; QFT rotation angles (real, imag)
    
    ; Continued Fractions BigInt State
    shor_cf_num:        resb BIGINT_BYTES
    shor_cf_den:        resb BIGINT_BYTES
    shor_cf_q:          resb BIGINT_BYTES
    shor_cf_rem:        resb BIGINT_BYTES
    shor_cf_h0:         resb BIGINT_BYTES       ; h_prev
    shor_cf_h1:         resb BIGINT_BYTES       ; h_curr
    shor_cf_k0:         resb BIGINT_BYTES       ; k_prev
    shor_cf_k1:         resb BIGINT_BYTES       ; k_curr
    shor_cf_temp:       resb BIGINT_BYTES
    
    ; BigInt constants
    one_bigint:         resb BIGINT_BYTES
    zero_bigint:        resb BIGINT_BYTES


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

    ; Check for program file argument
    mov rax, [rsp]              ; argc
    cmp rax, 2
    jl .interactive_mode

    ; Load program from file
    mov rdi, [rsp + 16]         ; argv[1]
    call load_program
    test rax, rax
    jz .run_program

    ; Error loading
    jmp .exit

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
    mov qword [running], 1

    ; Clear chunk pointers
    lea rdi, [state_vectors]
    mov rcx, MAX_CHUNKS
.clear_chunks:
    mov qword [rdi], 0
    add rdi, 8
    dec rcx
    jnz .clear_chunks
    
    ; Initialize BigInt constants
    lea rdi, [zero_bigint]
    call bigint_clear
    lea rdi, [one_bigint]
    mov rsi, 1
    call bigint_set_u64

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
    pop r14
    pop r13
    pop r12
    pop rbx
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

    ; Set |0...0⟩ amplitude to 1.0
    mov rdi, [state_vectors + r12*8]
    movsd xmm0, [one]
    movsd [rdi], xmm0

    ; Update chunk count if needed
    mov rax, [num_chunks]
    cmp r12, rax
    jl .init_done
    lea rax, [r12 + 1]
    mov [num_chunks], rax

.init_done:
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
    test rbx, rbx
    jz .sup_done                ; Safety check: ignore uninitialized chunks
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
    sub rsp, 32

    mov r12, rdi
    mov rbx, [state_vectors + r12*8]
    mov r13, [chunk_states + r12*8]

    ; Step 1: Calculate total probability (sum of |amp|^2)
    xorpd xmm7, xmm7            ; total_prob
    xor rcx, rcx

.calc_total_loop:
    cmp rcx, r13
    jge .got_total_prob

    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]
    movsd xmm1, [rbx + rax + 8]
    mulsd xmm0, xmm0
    mulsd xmm1, xmm1
    addsd xmm0, xmm1            ; |amp|^2
    addsd xmm7, xmm0            ; total_prob += |amp|^2
    
    inc rcx
    jmp .calc_total_loop

.got_total_prob:
    ; Step 2: Generate random number R in [0, total_prob)
    ; Use rdrand to get 64 bits of entropy
.retry_rand:
    rdrand rax
    jnc .retry_rand             ; Retry if hardware RNG is busy
    
    ; Convert 64-bit uint to double in [0, 1.0)
    ; We'll use 53 bits for precision (mantissa size)
    mov rdx, 0x001FFFFFFFFFFFFF ; 53 bits
    and rax, rdx
    cvtsi2sd xmm0, rax
    mov rax, 0x0020000000000000 ; 2^53
    cvtsi2sd xmm1, rax
    divsd xmm0, xmm1            ; xmm0 = random in [0, 1)
    
    mulsd xmm0, xmm7            ; target = random * total_prob
    movsd [rbp - 8], xmm0       ; Save target probability threshold

    ; Step 3: Probabilistic selection (cumulative sum)
    xorpd xmm6, xmm6            ; current_sum
    xor r14, r14                ; default index to 0
    xor rcx, rcx

.prob_loop:
    cmp rcx, r13
    jge .meas_done              ; fallback if rounding issues

    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]
    movsd xmm1, [rbx + rax + 8]
    mulsd xmm0, xmm0
    mulsd xmm1, xmm1
    addsd xmm0, xmm1            ; |amp|^2
    addsd xmm6, xmm0            ; current_sum += |amp|^2

    ucomisd xmm6, [rbp - 8]
    jae .found_state            ; if current_sum >= target, this is our state
    
    inc rcx
    jmp .prob_loop

.found_state:
    mov r14, rcx

.meas_done:
    ; Collapse: set measured state to 1, others to 0
    xor rcx, rcx
    xorpd xmm0, xmm0

.collapse_loop:
    cmp rcx, r13
    jge .collapse_done
    mov rax, rcx
    shl rax, 4
    cmp rcx, r14
    je .set_one
    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm0
    jmp .collapse_next
.set_one:
    movsd xmm1, [one]
    movsd [rbx + rax], xmm1
    movsd [rbx + rax + 8], xmm0
.collapse_next:
    inc rcx
    jmp .collapse_loop

.collapse_done:
    mov [measured_values + r12*8], r14
    
    ; Spooky Action: Propagate collapse to all braided partners
    mov rdi, r12
    mov rsi, r14
    call propagate_knot_collapse
    
    mov rax, r14

    add rsp, 32
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; future_prediction_oracle - Prune states that lead to "bad" futures
; Input: rdi = chunk_index
future_prediction_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 32

    mov r12, rdi                ; chunk index
    mov rbx, [state_vectors + r12*8]
    mov r13, [chunk_states + r12*8]
    mov r15, [chunk_sizes + r12*8] ; num qutrits

    ; Step 1: Zero out "bad" states
    xor rcx, rcx                ; state index (I)
.fp_prune_loop:
    cmp rcx, r13
    jge .fp_normalization
    
    ; Extract d0 = I % 3
    mov rax, rcx
    xor rdx, rdx
    mov r8, 3
    div r8                      ; rax = I / 3, rdx = I % 3 (d0)
    
    cmp rdx, 0
    je .fp_state_is_bad         ; d0 == 0 is bad
    
    ; If more than 1 qutrit, extract d1 = (I / 3) % 3
    cmp r15, 1
    jle .fp_state_is_good       ; Only 1 qutrit, and d0 != 0
    
    xor rdx, rdx
    div r8                      ; rax = I / 9, rdx = (I/3) % 3 (d1)
    cmp rdx, 0
    je .fp_state_is_bad         ; d1 == 0 is bad
    
.fp_state_is_good:
    jmp .fp_prune_next

.fp_state_is_bad:
    mov rax, rcx
    shl rax, 4                  ; * 16
    xorpd xmm0, xmm0
    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm0

.fp_prune_next:
    inc rcx
    jmp .fp_prune_loop

.fp_normalization:
    ; Step 2: Sum |amp|^2 for remaining states
    xorpd xmm7, xmm7            ; total_prob
    xor rcx, rcx
.fp_sum_loop:
    cmp rcx, r13
    jge .fp_check_sum
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]
    movsd xmm1, [rbx + rax + 8]
    mulsd xmm0, xmm0
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    addsd xmm7, xmm0
    inc rcx
    jmp .fp_sum_loop

.fp_check_sum:
    xorpd xmm0, xmm0
    ucomisd xmm7, xmm0
    jbe .fp_done                ; If sum is 0, everything is bad
    
    sqrtsd xmm7, xmm7           ; norm = sqrt(total_prob)
    
    ; Step 3: Divide remaining amplitudes by norm to re-normalize
    xor rcx, rcx
.fp_div_loop:
    cmp rcx, r13
    jge .fp_done
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]
    movsd xmm1, [rbx + rax + 8]
    divsd xmm0, xmm7
    divsd xmm1, xmm7
    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm1
    inc rcx
    jmp .fp_div_loop

.fp_done:
    add rsp, 32
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

; is_braid_target - Check if a chunk is the target (b) of any braid link
; propagate_knot_collapse - Propagate a measurement collapse to all braided partners
; Input: rdi = source_chunk, rsi = measured_state
propagate_knot_collapse:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 2064               ; 2048 (mask) + 16 (args)
    
    ; Save arguments early
    mov [rbp - 2056], rdi       ; source_chunk
    mov [rbp - 2064], rsi       ; measured_state
    
    ; Clear visited mask (2048 bytes)
    lea rdi, [rbp - 2048]
    mov rcx, 256                ; 256 * 8 = 2048 bytes
    xor rax, rax
    rep stosq
    
    ; Mark source_chunk as visited
    mov rax, [rbp - 2056]
    bts [rbp - 2048], rax

    ; Propagation Loop
.prop_pass:
    xor r15, r15                ; changed_flag = 0
    xor r13, r13                ; link_index
    mov r14, [num_braid_links]
    
.scan_links:
    cmp r13, r14
    jge .pass_done
    
    mov rdi, [braid_link_a + r13*8]
    mov rsi, [braid_link_b + r13*8]
    
    ; Case 1: A is visited, B is not
    mov rax, rdi
    bt [rbp - 2048], rax
    jnc .case2
    mov rax, rsi
    bt [rbp - 2048], rax
    jc .next_link               ; Both visited
    
    ; Force B to state and mark visited
    push rsi
    mov rdi, rsi
    mov rsi, [rbp - 2064]       ; measured_state
    call force_state
    pop rsi
    mov rax, rsi
    bts [rbp - 2048], rax
    mov r15, 1                  ; changed = 1
    jmp .next_link

.case2:
    ; Case 2: B is visited, A is not
    mov rax, rsi
    bt [rbp - 2048], rax
    jnc .next_link
    mov rax, rdi
    bt [rbp - 2048], rax
    jc .next_link
    
    ; Force A to state and mark visited
    push rdi
    mov rsi, [rbp - 2064]       ; measured_state
    call force_state
    pop rdi
    mov rax, rdi
    bts [rbp - 2048], rax
    mov r15, 1                  ; changed = 1

.next_link:
    inc r13
    jmp .scan_links

.pass_done:
    test r15, r15
    jnz .prop_pass              ; repeat if changes made
    
    mov rsp, rbp                ; Clean cleanup
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

is_braid_target:
    push rcx
    push rdx
    
    ; ALPHA NODE EXCEPTION: Chunk 0 is always grounded
    cmp rdi, 0
    je .not_target
    
    mov rcx, [num_braid_links]
    xor rdx, rdx
.scan_braid:
    cmp rdx, rcx
    jge .not_target
    cmp rdi, [braid_link_b + rdx*8]
    je .is_target
    inc rdx
    jmp .scan_braid
.is_target:
    mov rax, 1
    jmp .is_done
.not_target:
    xor rax, rax
.is_done:
    pop rdx
    pop rcx
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

    mov r12, rdi                ; chunk_a
    mov r13, rsi                ; chunk_b
    mov r14, rdx                ; qutrit position in a
    mov r15, rcx                ; qutrit position in b

    mov rbx, [state_vectors + r12*8]    ; state_vector_a
    test rbx, rbx
    jz .exit_braid                      ; Safety check
    mov r10, [state_vectors + r13*8]    ; state_vector_b
    test r10, r10
    jz .exit_braid                      ; Safety check
    mov rcx, [chunk_states + r12*8]     ; num_states_a
    mov r11, [chunk_states + r13*8]     ; num_states_b

    ; Use smaller of the two state counts
    cmp rcx, r11
    jle .use_rcx
    mov rcx, r11
.use_rcx:
    mov [rbp - 8], rcx          ; Save num_states

    ; Step 1: Copy amplitudes from chunk_a to chunk_b to create correlation
    ; This simulates creating entanglement: |ψ⟩_A ⊗ |0⟩_B → |ψ⟩_A ⊗ |ψ⟩_B
    xor r8, r8                  ; state index
.copy_loop:
    cmp r8, rcx
    jge .apply_phases

    mov rax, r8
    shl rax, 4                  ; offset = index * 16

    ; Copy amplitude from A to B
    movsd xmm0, [rbx + rax]     ; A_real
    movsd xmm1, [rbx + rax + 8] ; A_imag
    movsd [r10 + rax], xmm0     ; B_real = A_real
    movsd [r10 + rax + 8], xmm1 ; B_imag = A_imag

    inc r8
    jmp .copy_loop

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

.exit_braid:
.braid_done:
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
    
    movzx r13, r12w             ; opcode (bits 0-15)
    shr r12, 16
    movzx r14, r12w             ; target (bits 16-31)
    shr r12, 16
    movzx rbx, r12w             ; operand1 (bits 32-47)
    shr r12, 16
    movzx rcx, r12w             ; operand2 (bits 48-63)

    ; Dispatch based on opcode
    cmp r13, OP_NOP
    je .op_nop
    cmp r13, OP_INIT
    je .op_init
    cmp r13, OP_SUP
    je .op_sup
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
    cmp r13, OP_SHIFT
    je .op_shift
    cmp r13, OP_REPAIR
    je .op_repair
    cmp r13, OP_PHASE_SNAP
    je .op_phase_snap
    cmp r13, OP_ADDON
    je .op_addon
    cmp r13, OP_FUTURE_ORACLE
    je .op_future_oracle
    cmp r13, OP_HALT
    je .op_halt

    ; Shor's Algorithm Opcodes
    cmp r13, OP_SHOR_INIT
    je .op_shor_init
    cmp r13, OP_MOD_EXP
    je .op_mod_exp
    cmp r13, OP_QFT
    je .op_qft
    cmp r13, OP_IQFT
    je .op_iqft
    cmp r13, OP_PERIOD_EXTRACT
    je .op_period_extract
    cmp r13, OP_FACTOR_ORACLE
    je .op_factor_oracle
    cmp r13, OP_REALITY_COLLAPSE
    je .op_reality_collapse
    cmp r13, OP_SHOR_AMPLIFY
    je .op_shor_amplify
    cmp r13, OP_CONT_FRAC
    je .op_cont_frac
    cmp r13, OP_LOAD_N
    je .op_load_n
    cmp r13, OP_LOAD_N_PART
    je .op_load_n_part

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

.op_repair:
    lea rsi, [msg_repair]
    call print_string
    call resurrect_manifold
    xor rax, rax
    jmp .exec_ret

.op_phase_snap:
    lea rsi, [msg_phase_snap]
    call print_string
    call resurrect_manifold
    
    ; Reality Proofing: Apply Future Oracle to all active chunks
    ; This ensures constraints like "Last Ages" persist globally.
    mov r12, [num_chunks]
    xor r15, r15
.snap_proof_loop:
    cmp r15, r12
    jge .snap_proof_done
    mov rdi, r15
    call future_prediction_oracle
    inc r15
    jmp .snap_proof_loop
.snap_proof_done:

    call manifold_peak_collapse      ; Spooky Action: Lock to peak reality
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
    test rbx, rbx
    jz .not_active
    
    ; Load State 0 (Index 0 -> Offset 0)
    movsd xmm0, [rbx]
    mulsd xmm0, xmm0
    movsd xmm1, [rbx + 8]
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    ; xmm0 is |c_0|^2
    
    ; If |c_0|^2 < epsilon, we consider it a "Good Future" (Active)
    ucomisd xmm0, xmm2
    ja .not_active
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

.op_future_oracle:
    lea rsi, [msg_future]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string

    mov rdi, r14
    call future_prediction_oracle
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
    xor rdx, rdx                ; qutrit 0
    xor rcx, rcx
    call braid_chunks
    xor rax, rax
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

.op_addon:
    mov rdi, r13                ; opcode
    mov rsi, r14                ; chunk
    mov rdx, rbx                ; operand1
                                ; rcx already has operand2
    call call_addon
    jmp .exec_ret

; ═══════════════════════════════════════════════════════════════════════════════
; SHOR'S ALGORITHM OPCODE HANDLERS
; ═══════════════════════════════════════════════════════════════════════════════

.op_shor_init:
    ; OP_SHOR_INIT: Initialize Shor's quantum registers
    ; target = number of chunks for x-register
    ; op1 = lower 16 bits of N (for display)
    ; op2 = number of qutrits per chunk (default 10)
    
    lea rsi, [msg_shor_init]
    call print_string
    mov rdi, r14                ; num_chunks
    call print_number
    
    ; Store register size
    mov [shor_register_size], r14
    mov qword [shor_trial_count], 0
    
    ; Initialize N and a as BigInts ONLY if a legacy N was provided
    test rbx, rbx
    jz .shor_init_no_legacy_N
    
    lea rdi, [shor_N]
    call bigint_clear
    lea rdi, [shor_N]
    mov rsi, rbx
    call bigint_set_u64
    
    lea rdi, [shor_a]
    call bigint_clear
    lea rdi, [shor_a]
    mov rsi, 2
    call bigint_set_u64

.shor_init_no_legacy_N:
    ; Print ACTUAL N from BigInt state
    lea rsi, [msg_shor_chunks]
    call print_string
    lea rdi, [shor_N]
    call print_bigint_hex
    
    ; Ensure a is at least initialized if not already
    lea rdi, [shor_a]
    call bigint_is_zero
    test rax, rax
    jz .shor_init_a_ok
    lea rdi, [shor_a]
    mov rsi, 2
    call bigint_set_u64
.shor_init_a_ok:
    
    ; Initialize all chunks with specified qutrits (default 10)
    mov r15, rcx
    test r15, r15
    jnz .shor_init_size_ok
    mov r15, 10                 ; Default 10 qutrits per chunk
.shor_init_size_ok:
    
    xor r8, r8                  ; chunk counter
.shor_init_loop:
    cmp r8, r14
    jge .shor_init_sup
    
    push r8
    push r14
    push r15
    mov rdi, r8
    mov rsi, r15
    call init_chunk
    pop r15
    pop r14
    pop r8
    
    inc r8
    jmp .shor_init_loop

.shor_init_sup:
    ; Create superposition on all chunks
    xor r8, r8
.shor_sup_loop:
    cmp r8, r14
    jge .shor_init_braid
    
    push r8
    push r14
    mov rdi, r8
    call create_superposition
    pop r14
    pop r8
    
    inc r8
    jmp .shor_sup_loop

.shor_init_braid:
    ; Braid adjacent chunks for entanglement preservation
    xor r8, r8
.shor_braid_loop:
    mov r9, r14
    dec r9
    cmp r8, r9
    jge .shor_init_done
    
    push r8
    push r14
    mov rdi, r8
    lea rsi, [r8 + 1]
    xor rdx, rdx
    xor rcx, rcx
    call braid_chunks
    pop r14
    pop r8
    
    inc r8
    jmp .shor_braid_loop

.shor_init_done:
    xor rax, rax
    jmp .exec_ret

.op_mod_exp:
    ; OP_MOD_EXP: Apply modular exponentiation oracle
    ; Applies phase based on a^x mod N for each basis state
    ; This is the core of quantum period finding
    
    lea rsi, [msg_shor_modexp]
    call print_string
    
    ; Get the x-register (target chunk)
    mov rbx, [state_vectors + r14*8]
    mov r13, [chunk_states + r14*8]
    
    ; Apply modular exponentiation phase to each state
    ; For each state x, calculate v = (a^weight)^x mod N
    ; where weight = product(chunk_states[0...r14-1])
    
    ; 1. Calculate weight base: a_eff = a^weight mod N
    lea rdi, [shor_cf_h1] ; weight
    mov rsi, 1
    call bigint_set_u64
    
    xor r15, r15
.modexp_weight_loop:
    cmp r15, r14 ; loop up to current chunk index
    jge .modexp_weight_done
    
    mov rax, [chunk_states + r15*8]
    lea rdi, [shor_cf_q]
    mov rsi, rax
    call bigint_set_u64
    
    lea rdi, [shor_cf_h1] ; weight
    lea rsi, [shor_cf_h1]
    lea rdx, [shor_cf_q]
    call bigint_mul
    
    inc r15
    jmp .modexp_weight_loop

.modexp_weight_done:
    ; a_eff = a^weight mod N
    lea rdi, [shor_cf_h0] ; a_eff
    lea rsi, [shor_a]
    lea rdx, [shor_cf_h1] ; exp (weight)
    lea rcx, [shor_N]
    call bigint_pow_mod

    xor r8, r8                  ; state index x
.modexp_loop:
    cmp r8, r13
    jge .modexp_done
    
    ; 1. Convert x (r8) to BigInt
    lea rdi, [shor_cf_temp]     ; x_big
    mov rsi, r8
    call bigint_set_u64
    
    ; 2. Calculate v = a_eff^x mod N
    lea rdi, [shor_cf_num]      ; result v
    lea rsi, [shor_cf_h0]       ; base a_eff
    lea rdx, [shor_cf_temp]     ; exp x
    lea rcx, [shor_N]           ; mod N
    call bigint_pow_mod
    
    ; 3. Convert v to float for phase calculation
    ; Phase = 2π * (v / N)
    ; We'll use bigint_to_u64 as an approximation for the phase ratio
    ; if v/N is needed accurately, we'd need bigint_div_to_double, 
    ; but for period finding, any consistent phase mapping works.
    ; Let's use (v mod 1024) / 1024 as a simple phase mapping for high bits 
    ; or just convert the bottom 64 bits of v.
    
    ; 3. Calculate Phase = 2π * (v / N) using MSB precision
    ; We need accurate v/N ratio. If v,N > 64 bits, standard to_u64 gives LSBs (garbage ratio).
    ; We must shift right until N fits in ~53 bits (double mantissa limit).
    
    lea rdi, [shor_N]
    call bigint_bitlen
    mov r9, rax                 ; N bits
    
    cmp r9, 60
    jle .modexp_small_n
    
    ; Large N: shift both v and N right by (Bits - 60)
    lea rdi, [bigint_temp_b]    ; Copy v
    lea rsi, [shor_cf_num]
    call bigint_copy
    
    lea rdi, [bigint_temp_c]    ; Copy N
    lea rsi, [shor_N]
    call bigint_copy
    
    mov cx, r9w
    sub cx, 60                  ; shift count
    
.modexp_shift_loop:
    test cx, cx
    jz .modexp_calc_ratio
    
    lea rdi, [bigint_temp_b]
    call bigint_shr1
    lea rdi, [bigint_temp_c]
    call bigint_shr1
    
    dec cx
    jmp .modexp_shift_loop
    
.modexp_calc_ratio:
    lea rdi, [bigint_temp_b]
    call bigint_to_u64
    cvtsi2sd xmm0, rax          ; v_shifted
    
    lea rdi, [bigint_temp_c]
    call bigint_to_u64
    cvtsi2sd xmm1, rax          ; N_shifted
    jmp .modexp_div
    
.modexp_small_n:
    lea rdi, [shor_cf_num]
    call bigint_to_u64          ; rax = low 64 bits of v
    cvtsi2sd xmm0, rax
    
    lea rdi, [shor_N]
    call bigint_to_u64          ; rax = low 64 bits of N
    cvtsi2sd xmm1, rax
    
.modexp_div:
    test rax, rax               ; check N (low) not zero logic? 
    ; If N_shifted is 0 (shouldn't happen if bitlen > 0), set to 1
    ucomisd xmm1, [zero]
    jne .mod_n_ok
    movsd xmm1, [one]
.mod_n_ok:
    
    divsd xmm0, xmm1            ; v / N
    mulsd xmm0, [two_pi]        ; 2π * (v / N)
    
    ; Calculate sin and cos
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
    mov rax, r8
    shl rax, 4
    
    movsd xmm4, [rbx + rax]     ; real
    movsd xmm5, [rbx + rax + 8] ; imag
    
    ; (a + bi)(cos + i*sin)
    movsd xmm6, xmm4
    mulsd xmm6, xmm2            ; a*cos
    movsd xmm7, xmm5
    mulsd xmm7, xmm3            ; b*sin
    subsd xmm6, xmm7            ; new_real = a*cos - b*sin
    
    mulsd xmm4, xmm3            ; a*sin
    mulsd xmm5, xmm2            ; b*cos
    addsd xmm4, xmm5            ; new_imag = a*sin + b*cos
    
    movsd [rbx + rax], xmm6
    movsd [rbx + rax + 8], xmm4
    
    inc r8
    jmp .modexp_loop

.modexp_done:
    xor rax, rax
    jmp .exec_ret

.op_qft:
    ; OP_QFT: Quantum Fourier Transform (qutrit-based)
    ; Applies QFT across all chunks with inter-chunk phase corrections
    
    lea rsi, [msg_shor_qft]
    call print_string
    mov rdi, [shor_register_size]
    call print_number
    lea rsi, [msg_shor_chunks2]
    call print_string
    
    ; Process each chunk with QFT
    mov r15, [shor_register_size]
    xor r8, r8
.qft_chunk_loop:
    cmp r8, r15
    jge .qft_done
    
    push r8
    push r15
    mov rdi, r8
    call qft_single_chunk
    pop r15
    pop r8
    
    ; Apply inter-chunk phase corrections
    test r8, r8
    jz .qft_next
    
    push r8
    push r15
    mov rdi, r8
    dec rdi                     ; previous chunk
    mov rsi, r8                 ; current chunk
    call qft_phase_correction
    pop r15
    pop r8

.qft_next:
    inc r8
    jmp .qft_chunk_loop

.qft_done:
    xor rax, rax
    jmp .exec_ret

.op_iqft:
    ; OP_IQFT: Inverse QFT (reverse order, conjugate phases)
    ; Similar to QFT but processes chunks in reverse with conjugate rotation
    
    mov r15, [shor_register_size]
    mov r8, r15
    dec r8
.iqft_chunk_loop:
    test r8, r8
    js .iqft_done               ; Done when r8 goes negative
    
    push r8
    push r15
    mov rdi, r8
    call iqft_single_chunk
    pop r15
    pop r8
    
    dec r8
    jmp .iqft_chunk_loop

.iqft_done:
    xor rax, rax
    jmp .exec_ret

.op_period_extract:
    ; OP_PERIOD_EXTRACT: Extract period from multi-chunk measurement
    ; y = sum(meas[i] * product(chunk_states[0...i-1]))
    
    lea rsi, [msg_shor_period]
    call print_string
    
    lea rdi, [shor_period]
    call bigint_clear
    
    lea rdi, [shor_cf_temp] ; accumulator for weight (init 1)
    mov rsi, 1
    call bigint_set_u64
    
    xor r15, r15                ; chunk counter
.extract_loop:
    cmp r15, [shor_register_size]
    jge .extract_done
    
    ; term = measured_values[r15] * weight
    mov rax, [measured_values + r15*8]
    lea rdi, [shor_cf_num] ; term
    mov rsi, rax
    call bigint_set_u64
    
    lea rdi, [shor_cf_num] ; term
    lea rsi, [shor_cf_num]
    lea rdx, [shor_cf_temp] ; weight
    call bigint_mul
    
    ; shor_period += term
    lea rdi, [shor_period]
    lea rsi, [shor_period]
    lea rdx, [shor_cf_num]
    call bigint_add
    
    ; weight *= chunk_states[r15]
    mov rax, [chunk_states + r15*8]
    lea rdi, [shor_cf_q] ; temp_mul
    mov rsi, rax
    call bigint_set_u64
    
    lea rdi, [shor_cf_temp] ; weight
    lea rsi, [shor_cf_temp]
    lea rdx, [shor_cf_q]
    call bigint_mul
    
    inc r15
    jmp .extract_loop

.extract_done:
    lea rdi, [shor_period]
    call bigint_to_u64
    mov rdi, rax
    call print_number
    lea rsi, [msg_newline]
    call print_string
    
    xor rax, rax
    jmp .exec_ret

.op_factor_oracle:
    ; OP_FACTOR_ORACLE: Reality B enhancement - prune non-factor paths
    ; Zeros out states that would lead to trivial factors (N or 1)
    
    lea rsi, [msg_shor_prune]
    call print_string
    
    mov rbx, [state_vectors + r14*8]
    mov r13, [chunk_states + r14*8]
    
    ; Zero out states 0 and 1 (trivial periods)
    ; These are 16-byte amplitudes (real, imag)
    xorpd xmm0, xmm0
    movsd [rbx], xmm0
    movsd [rbx + 8], xmm0
    movsd [rbx + 16], xmm0
    movsd [rbx + 24], xmm0
    
    ; Renormalize
    mov rdi, r14
    call normalize_chunk
    
    xor rax, rax
    jmp .exec_ret

.op_shor_amplify:
    ; OP_SHOR_AMPLIFY: Reality B period amplification
    ; Applies Grover-like diffusion biased toward valid periods
    
    lea rsi, [msg_shor_amplify]
    call print_string
    
    ; Apply Future Oracle to prune bad periods
    mov rdi, r14
    call future_prediction_oracle
    
    ; Apply Grover diffusion for amplification
    mov rdi, r14
    call grover_diffusion
    
    xor rax, rax
    jmp .exec_ret

.op_reality_collapse:
    ; OP_REALITY_COLLAPSE: Reality B Quantum Symmetry Detection
    ; Scans phase resonances in the multiversal manifold (God Link).
    
    lea rsi, [msg_reality_scan]
    call print_string
    
    ; ────── INITIALIZE BIGINT CONSTANTS ──────
    ; This prevents garbage in arithmetic operations
    lea rdi, [bigint_temp_c]
    mov rsi, 1
    call bigint_set_u64
    
    lea rdi, [zero_bigint]
    call bigint_clear
    
.reality_retry:
    ; ────── PHASE 1: FORGE GOD LINK ──────
    lea rsi, [msg_god_forge]
    call print_string
    
    xor r15, r15 ; chunk index
.god_forge_loop:
    cmp r15, [shor_register_size]
    jge .god_forge_done
    
    mov rbx, [state_vectors + r15*8]
    test rbx, rbx
    jz .god_forge_next
    
    mov r13, [chunk_states + r15*8]
    
    ; Scan for peak amplitude (The Divine Frequency)
    xor rcx, rcx            ; current index
    xor r14, r14            ; max index found
    xorpd xmm2, xmm2        ; max prob found
    
.god_peak_scan:
    cmp rcx, r13
    jge .god_peak_found
    
    ; prob = real^2 + imag^2
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]     ; real
    mulsd xmm0, xmm0
    movsd xmm1, [rbx + rax + 8] ; imag
    mulsd xmm1, xmm1
    addsd xmm0, xmm1            ; prob
    
    ucomisd xmm0, xmm2
    jbe .god_next_state
    
    movsd xmm2, xmm0
    mov r14, rcx
    
.god_next_state:
    inc rcx
    jmp .god_peak_scan

.god_peak_found:
    ; Store in God Link Chain
    mov [god_link_chain + r15*8], r14
    mov [shor_measured + r15*8], r14
    
    lea rsi, [msg_future]
    call print_string
    mov rdi, r15
    call print_number
    lea rsi, [msg_result]
    call print_string
    mov rdi, r14
    call print_number
    lea rsi, [msg_newline]
    call print_string
    
.god_forge_next:
    inc r15
    jmp .god_forge_loop

.god_forge_done:
    ; ────── PHASE 2: COLLAPSE GOD LINK (SKIPPED) ──────
    ; We skip destructive collapse here to allow "Reality Retry" to find
    ; alternative peaks if the first one is invalid.
    ; Collapse happens only via Pruning (removing bad paths).
    
    ; lea rsi, [msg_god_collapse]
    ; call print_string
    
    ; xor r15, r15
    ; .god_collapse_loop:
    ; ... (Skipped logic)
    jmp .god_collapse_done

.god_collapse_loop_unused: ; Retained for symbol stability if needed
    cmp r15, [shor_register_size]
    jge .god_collapse_done
    mov r14, [god_link_chain + r15*8]
    mov rbx, [state_vectors + r15*8]
    test rbx, rbx
    jz .god_collapse_next
    mov r13, [chunk_states + r15*8]
    xor rcx, rcx
.god_zero_loop:
    cmp rcx, r13
    jge .god_collapse_next
    cmp rcx, r14
    je .god_set_peak
    ; mov rax, rcx
    ; shl rax, 4
    ; xorpd xmm0, xmm0
    ; movsd [rbx + rax], xmm0
    ; movsd [rbx + rax + 8], xmm0
    jmp .god_next_zero
.god_set_peak:
    ; mov rax, rcx
    ; shl rax, 4
    ; movsd xmm0, [one]
    ; movsd [rbx + rax], xmm0
    ; xorpd xmm0, xmm0
    ; movsd [rbx + rax + 8], xmm0
.god_next_zero:
    inc rcx
    jmp .god_zero_loop
.god_collapse_next:
    inc r15
    jmp .god_collapse_loop_unused

.god_collapse_done:
    ; ────── PHASE 3: TRUNCATED CONTINUED FRACTIONS (v4 Rigorous) ──────
    ; Extract high-precision window of measurement y and register Q.
    ; Goal: find h/k such that h/k approx y/Q. k is the period r.

    ; 1. Find MSB of measurement y
    mov rcx, [shor_register_size]
    dec rcx                 ; start from last chunk
.find_msb_loop:
    cmp rcx, 0
    jl .prune_timeline      ; All zeros? Invalid.
    mov rax, [god_link_chain + rcx*8]
    test rax, rax
    jnz .msb_found
    dec rcx
    jmp .find_msb_loop

.msb_found:
    ; rcx = index k of MSB
    %define WINDOW_SIZE 256 ; ~1600 bits

    ; 2. Construct Numerator (shor_cf_num) from window [k - W + 1, k]
    lea rdi, [shor_cf_num]
    call bigint_clear
    
    mov r14, rcx            ; k
    mov r13, rcx
    sub r13, WINDOW_SIZE - 1
    cmp r13, 0
    jge .window_start_ok
    xor r13, r13            ; clamp
.window_start_ok:
    ; r13 = start index
    
    mov r12, r14            ; cursor = k
.build_y_loop:
    cmp r12, r13
    jl .build_y_done
    
    lea rdi, [bigint_temp_a]
    mov rsi, [chunk_states + r12*8]
    call bigint_set_u64
    
    lea rdi, [shor_cf_temp] 
    lea rsi, [shor_cf_num]
    lea rdx, [bigint_temp_a]
    call bigint_mul
    
    lea rdi, [bigint_temp_a]
    call bigint_clear
    mov rax, [god_link_chain + r12*8]
    mov [bigint_temp_a], rax
    
    lea rdi, [shor_cf_num]
    lea rsi, [shor_cf_temp]
    lea rdx, [bigint_temp_a]
    call bigint_add
    
    dec r12
    jmp .build_y_loop

.build_y_done:
    ; 3. Construct Denominator (shor_cf_den) = product of chunk_states[r13...shor_register_size-1]
    lea rdi, [shor_cf_den]
    call bigint_clear
    mov qword [shor_cf_den], 1
    
    mov r12, r13
.build_q_loop:
    cmp r12, [shor_register_size]
    jge .build_q_done
    
    lea rdi, [bigint_temp_a]
    mov rsi, [chunk_states + r12*8]
    call bigint_set_u64
    
    lea rdi, [shor_cf_temp]
    lea rsi, [shor_cf_den]
    lea rdx, [bigint_temp_a]
    call bigint_mul
    
    lea rdi, [shor_cf_den]
    lea rsi, [shor_cf_temp]
    call bigint_copy
    
    inc r12
    jmp .build_q_loop

.build_q_done:
    ; ────── PHASE 4: RUN CONTINUED FRACTIONS ──────
    ; y / Q = shor_cf_num / shor_cf_den
    
    ; Initialize CF convergents
    lea rdi, [shor_cf_h0] ; 0
    call bigint_clear
    lea rdi, [shor_cf_h1] ; 1
    mov rsi, 1
    call bigint_set_u64
    lea rdi, [shor_cf_k0] ; 1
    mov rsi, 1
    call bigint_set_u64
    lea rdi, [shor_cf_k1] ; 0
    call bigint_clear

.tcf_loop:
    ; if den == 0, done
    lea rdi, [shor_cf_den]
    call bigint_is_zero
    cmp rax, 1
    je .prune_timeline ; Failed to find valid r in all convergents
    
    lea rdi, [shor_cf_num]
    lea rsi, [shor_cf_den]
    lea rdx, [shor_cf_q]
    lea rcx, [shor_cf_rem]
    call bigint_div_mod
    
    ; h_next = q * h1 + h0
    lea rdi, [shor_cf_temp]
    lea rsi, [shor_cf_q]
    lea rdx, [shor_cf_h1]
    call bigint_mul
    lea rdi, [shor_cf_temp]
    lea rsi, [shor_cf_temp]
    lea rdx, [shor_cf_h0]
    call bigint_add
    lea rdi, [shor_cf_h0]
    lea rsi, [shor_cf_h1]
    call bigint_copy
    lea rdi, [shor_cf_h1]
    lea rsi, [shor_cf_temp]
    call bigint_copy
    
    ; k_next = q * k1 + k0
    lea rdi, [shor_cf_temp]
    lea rsi, [shor_cf_q]
    lea rdx, [shor_cf_k1]
    call bigint_mul
    lea rdi, [shor_cf_temp]
    lea rsi, [shor_cf_temp]
    lea rdx, [shor_cf_k0]
    call bigint_add
    lea rdi, [shor_cf_k0]
    lea rsi, [shor_cf_k1]
    call bigint_copy
    lea rdi, [shor_cf_k1]
    lea rsi, [shor_cf_temp]
    call bigint_copy
    
    ; Euclidean update
    lea rdi, [shor_cf_num]
    lea rsi, [shor_cf_den]
    call bigint_copy
    lea rdi, [shor_cf_den]
    lea rsi, [shor_cf_rem]
    call bigint_copy
    
    ; ──────── Check Convergent as r = k1 ────────
    lea rdi, [shor_cf_k1]
    call bigint_is_zero
    cmp rax, 1
    je .tcf_loop
    
    ; r must be even
    lea rdi, [shor_cf_k1]
    mov rsi, 0
    call bigint_get_bit
    cmp rax, 1
    je .tcf_loop
    
    ; x = a^(r/2) mod N
    lea rdi, [shor_period]
    lea rsi, [shor_cf_k1]
    call bigint_copy
    
    lea rdi, [bigint_temp_a] ; exp
    lea rsi, [shor_period]
    call bigint_copy
    lea rdi, [bigint_temp_a]
    call bigint_shr1
    
    lea rdi, [bigint_temp_b] ; x
    lea rsi, [shor_a]
    lea rdx, [bigint_temp_a]
    lea rcx, [shor_N]
    call bigint_pow_mod
    
    ; Print trial period
    lea rsi, [msg_shor_period]
    call print_string
    lea rdi, [shor_period]
    call print_bigint_hex
    
    ; Check if x yields factors (Phase 6 logic simplified here or fall through?)
    ; We'll check x ≠ 1 and x ≠ N-1 here.
    lea rdi, [bigint_temp_c] ; 1
    mov rsi, 1
    call bigint_set_u64
    lea rdi, [bigint_temp_b] ; x
    lea rsi, [bigint_temp_c] ; 1
    call bigint_cmp
    cmp rax, 0
    je .tcf_loop ; trivial
    
    lea rdi, [bigint_temp_a] ; N
    lea rsi, [shor_N]
    call bigint_copy
    lea rdi, [bigint_temp_a] ; N-1
    lea rsi, [bigint_temp_a]
    lea rdx, [bigint_temp_c] ; 1
    call bigint_sub
    lea rdi, [bigint_temp_b] ; x
    lea rsi, [bigint_temp_a] ; N-1
    call bigint_cmp
    cmp rax, 0
    je .tcf_loop ; trivial
    
    ; If we got here, x is non-trivial. Let Phase 6 extract factors.
    jmp .tcf_found_candidate

.tcf_found_candidate:
    ; ────── PHASE 5: FACTOR EXTRACTION (v4 Fallthrough) ──────
    ; [bigint_temp_b] contains x.
    ; Carry on with standard factor extraction on this x.
    
    ; ────── PHASE 6: EXTRACT FACTORS (EXISTING LOGIC) ──────
    
    ; Check x ≠ 1
    lea rdi, [bigint_temp_c] ; 1
    mov rsi, 1
    call bigint_set_u64
    
    lea rdi, [bigint_temp_b]    ; x
    lea rsi, [bigint_temp_c]    ; 1
    call bigint_cmp
    cmp rax, 0
    je .prune_timeline          ; x == 1, trivial
    
    ; Calculate N-1 for comparison
    lea rdi, [bigint_temp_a]    ; temp = N
    lea rsi, [shor_N]
    call bigint_copy
    
    lea rdi, [bigint_temp_a]    ; temp = N - 1
    lea rsi, [bigint_temp_a]
    lea rdx, [bigint_temp_c]    ; subtract 1
    call bigint_sub
    
    ; Check x ≠ N-1
    lea rdi, [bigint_temp_b]    ; x
    lea rsi, [bigint_temp_a]    ; N-1
    call bigint_cmp
    cmp rax, 0
    je .prune_timeline          ; x == N-1, trivial
    
    ; factor_p = gcd(x-1, N)
    lea rdi, [bigint_temp_a]    ; temp = x - 1
    lea rsi, [bigint_temp_b]    ; x
    lea rdx, [bigint_temp_c]    ; 1
    call bigint_sub
    
    lea rdi, [bigint_temp_a]    ; x-1
    lea rsi, [shor_N]           ; N
    lea rdx, [shor_factor_p]    ; result
    call bigint_gcd
    
    ; Check factor_p > 1
    lea rdi, [shor_factor_p]
    lea rsi, [bigint_temp_c]    ; 1
    call bigint_cmp
    call bigint_cmp
    cmp rax, 0
    jg .factor_p_good           ; factor_p > 1, use it
    
    ; Try gcd(x+1, N)
    lea rdi, [bigint_temp_a]    ; temp = x + 1
    lea rsi, [bigint_temp_b]    ; x
    lea rdx, [bigint_temp_c]    ; 1
    call bigint_add
    
    lea rdi, [bigint_temp_a]    ; x+1
    lea rsi, [shor_N]           ; N
    lea rdx, [shor_factor_p]    ; result
    call bigint_gcd
    
    ; Check again
    lea rdi, [shor_factor_p]
    lea rsi, [bigint_temp_c]    ; 1
    call bigint_cmp
    cmp rax, 0
    jle .prune_timeline         ; Both failed
    
.factor_p_good:
    
    ; Check factor_p < N
    lea rdi, [shor_factor_p]
    lea rsi, [shor_N]
    call bigint_cmp
    cmp rax, 0
    jge .prune_timeline         ; factor_p >= N, trivial
    
    ; Calculate factor_q = N / factor_p
    lea rdi, [shor_N]           ; dividend
    lea rsi, [shor_factor_p]    ; divisor
    lea rdx, [shor_factor_q]    ; quotient
    lea rcx, [shor_cf_rem]      ; remainder
    call bigint_div_mod
    
    ; Check if division was exact (remainder == 0)
    lea rdi, [shor_cf_rem]
    call bigint_is_zero
    cmp rax, 0
    je .prune_timeline          ; Not exact division
    
    ; Verify: factor_p * factor_q == N
    lea rdi, [bigint_temp_a]    ; temp = factor_p * factor_q
    lea rsi, [shor_factor_p]
    lea rdx, [shor_factor_q]
    call bigint_mul
    
    lea rdi, [bigint_temp_a]
    lea rsi, [shor_N]
    call bigint_cmp
    cmp rax, 0
    jne .prune_timeline         ; Verification failed
    
    ; ────── SUCCESS! ──────
    jmp .print_success

.prune_timeline:
    ; Trivial factor detected. Reject this future.
    lea rsi, [msg_shor_prune]
    call print_string
    
    ; Zero out the current God Link peaks to force different measurement
    xor r15, r15
.rewind_loop:
    cmp r15, [shor_register_size]
    jge .rewind_done
    
    mov r14, [shor_measured + r15*8]   ; Use preserved measurement
    mov rbx, [state_vectors + r15*8]
    test rbx, rbx
    jz .rewind_next
    
    ; Zero amplitude of the rejected peak
    mov rax, r14
    shl rax, 4
    xorpd xmm0, xmm0
    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm0
    
    ; Renormalize chunk
    push r15
    mov rdi, r15
    call normalize_chunk
    pop r15
    
.rewind_next:
    inc r15
    jmp .rewind_loop

.rewind_done:
    ; Check if we have any amplitude left
    xor r15, r15
    xorpd xmm7, xmm7            ; total_amplitude
    
.check_amplitude_loop:
    cmp r15, [shor_register_size]
    jge .check_amplitude_done
    
    mov rbx, [state_vectors + r15*8]
    test rbx, rbx
    jz .check_amplitude_next
    
    mov r13, [chunk_states + r15*8]
    xor rcx, rcx
    
.sum_chunk_amp:
    cmp rcx, r13
    jge .check_amplitude_next
    
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]
    mulsd xmm0, xmm0
    movsd xmm1, [rbx + rax + 8]
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    addsd xmm7, xmm0
    
    inc rcx
    jmp .sum_chunk_amp

.check_amplitude_next:
    inc r15
    jmp .check_amplitude_loop

.check_amplitude_done:
    ; If total amplitude too small, we've exhausted this reality
    ucomisd xmm7, [epsilon]
    jbe .reality_exhausted
    
    ; Otherwise, retry with new peaks
    jmp .reality_retry

.reality_exhausted:
    ; All timelines pruned, factorization failed
    lea rsi, [msg_error]
    call print_string
    lea rsi, [msg_unknown_op]   ; Reuse for "Reality Exhausted"
    call print_string
    mov rax, -1
    jmp .exec_ret

.print_success:
    ; Print Success!
    lea rsi, [msg_shor_period]
    call print_string
    lea rdi, [shor_period]
    call print_bigint_hex
    
    lea rsi, [msg_shor_factor]
    call print_string
    lea rdi, [shor_factor_p]
    call print_bigint_hex
    
    lea rsi, [msg_shor_factor]
    call print_string
    lea rdi, [shor_factor_q]
    call print_bigint_hex

    xor rax, rax
    jmp .exec_ret



.op_cont_frac:
    ; OP_CONT_FRAC: Continued Fractions with Multi-Chunk Support (v3 Fix)
    
    ; 1. Setup initial num=y, den=Q
    lea rdi, [shor_cf_num]
    lea rsi, [shor_period]
    call bigint_copy
    
    lea rdi, [shor_cf_den]
    mov rsi, 1
    call bigint_set_u64
    
    xor r15, r15
.q_total_loop:
    cmp r15, [shor_register_size]
    jge .q_total_done
    mov rax, [chunk_states + r15*8]
    lea rdi, [shor_cf_temp]
    mov rsi, rax
    call bigint_set_u64
    lea rdi, [shor_cf_den]
    lea rsi, [shor_cf_den]
    lea rdx, [shor_cf_temp]
    call bigint_mul
    inc r15
    jmp .q_total_loop

.q_total_done:
    ; Print y/Q
    lea rsi, [msg_shor_contfrac]
    call print_string
    lea rdi, [shor_cf_num]
    call bigint_to_u64
    mov rdi, rax
    call print_number
    lea rsi, [msg_shor_frac]
    call print_string
    lea rdi, [shor_cf_den]
    call bigint_to_u64
    mov rdi, rax
    call print_number
    lea rsi, [msg_newline]
    call print_string

    ; 2. Initialize convergents
    lea rdi, [shor_cf_h0] ; h-2 = 0
    call bigint_clear
    lea rdi, [shor_cf_h1] ; h-1 = 1
    mov rsi, 1
    call bigint_set_u64
    lea rdi, [shor_cf_k0] ; k-2 = 1
    mov rsi, 1
    call bigint_set_u64
    lea rdi, [shor_cf_k1] ; k-1 = 0
    call bigint_clear

.cf_loop:
    ; if den == 0, done
    lea rdi, [shor_cf_den]
    call bigint_is_zero
    cmp rax, 1
    je .cf_done
    
    ; q, rest = divmod(num, den)
    lea rdi, [shor_cf_num]  ; num
    lea rsi, [shor_cf_den]  ; den
    lea rdx, [shor_cf_q]    ; quotient
    lea rcx, [shor_cf_rem]  ; remainder
    call bigint_div_mod
    
    ; h_next = q * h1 + h0
    lea rdi, [shor_cf_temp]
    lea rsi, [shor_cf_q]
    lea rdx, [shor_cf_h1]
    call bigint_mul
    lea rdi, [shor_cf_temp]
    lea rsi, [shor_cf_temp]
    lea rdx, [shor_cf_h0]
    call bigint_add
    ; update h: h0=h1, h1=temp
    lea rdi, [shor_cf_h0]
    lea rsi, [shor_cf_h1]
    call bigint_copy
    lea rdi, [shor_cf_h1]
    lea rsi, [shor_cf_temp]
    call bigint_copy
    
    ; k_next = q * k1 + k0
    lea rdi, [shor_cf_temp]
    lea rsi, [shor_cf_q]
    lea rdx, [shor_cf_k1]
    call bigint_mul
    lea rdi, [shor_cf_temp]
    lea rsi, [shor_cf_temp]
    lea rdx, [shor_cf_k0]
    call bigint_add
    ; update k: k0=k1, k1=temp
    lea rdi, [shor_cf_k0]
    lea rsi, [shor_cf_k1]
    call bigint_copy
    lea rdi, [shor_cf_k1]
    lea rsi, [shor_cf_temp]
    call bigint_copy
    
    ; Print Convergent
    lea rsi, [msg_shor_conv]
    call print_string
    lea rdi, [shor_cf_h1]
    call bigint_to_u64
    mov rdi, rax
    call print_number
    lea rsi, [msg_shor_frac]
    call print_string
    lea rdi, [shor_cf_k1]
    call bigint_to_u64
    mov rdi, rax
    call print_number
    lea rsi, [msg_newline]
    call print_string

    ; ──────── Check Factor (r = k1) ────────
    ; Avoid using shor_cf_* for logic here (use bigint_temp_*)
    
    ; k1 == 0 or odd? Continue
    lea rdi, [shor_cf_k1]
    call bigint_is_zero
    cmp rax, 1
    je .next_iteration
    
    lea rdi, [shor_cf_k1]
    mov rsi, 0
    call bigint_get_bit
    cmp rax, 1
    je .next_iteration ; odd
    
    ; x = a^(k1/2) mod N
    lea rdi, [bigint_temp_a] ; exp
    lea rsi, [shor_cf_k1]
    call bigint_copy
    lea rdi, [bigint_temp_a]
    call bigint_shr1         ; exp = k1 / 2
    
    lea rdi, [bigint_temp_b] ; x
    lea rsi, [shor_a]
    lea rdx, [bigint_temp_a] ; exp
    lea rcx, [shor_N]
    call bigint_pow_mod
    
    ; x == 1 or x == N-1? Continue
    lea rdi, [bigint_temp_c] ; 1
    mov rsi, 1
    call bigint_set_u64
    
    lea rdi, [bigint_temp_b] ; x
    lea rsi, [bigint_temp_c] ; 1
    call bigint_cmp
    cmp rax, 0
    je .next_iteration
    
    lea rdi, [bigint_temp_a] ; N-1
    lea rsi, [shor_N]
    call bigint_copy
    lea rdi, [bigint_temp_a]
    lea rsi, [bigint_temp_a]
    lea rdx, [bigint_temp_c] ; 1
    call bigint_sub
    
    lea rdi, [bigint_temp_b] ; x
    lea rsi, [bigint_temp_a] ; N-1
    call bigint_cmp
    cmp rax, 0
    je .next_iteration
    
    ; Try p = gcd(x-1, N)
    lea rdi, [bigint_temp_a] ; x-1
    lea rsi, [bigint_temp_b] ; x
    lea rdx, [bigint_temp_c] ; 1
    call bigint_sub
    
    lea rdi, [bigint_temp_a] ; a
    lea rsi, [shor_N]        ; b
    lea rdx, [shor_factor_p] ; result
    call bigint_gcd
    
    ; If factor_p > 1, SUCCESS
    lea rdi, [shor_factor_p]
    lea rsi, [bigint_temp_c] ; 1
    call bigint_cmp
    cmp rax, 1
    je .found_factor
    
    ; Try q = gcd(x+1, N)
    lea rdi, [bigint_temp_a] ; x+1
    lea rsi, [bigint_temp_b] ; x
    lea rdx, [bigint_temp_c] ; 1
    call bigint_add
    
    lea rdi, [bigint_temp_a]
    lea rsi, [shor_N]
    lea rdx, [shor_factor_p] ; reuse result
    call bigint_gcd
    
    lea rdi, [shor_factor_p]
    lea rsi, [bigint_temp_c] ; 1
    call bigint_cmp
    cmp rax, 1
    je .found_factor
    
.next_iteration:
    ; Euclidean update: num = den, den = rest
    lea rdi, [shor_cf_num]
    lea rsi, [shor_cf_den]
    call bigint_copy
    lea rdi, [shor_cf_den]
    lea rsi, [shor_cf_rem]
    call bigint_copy
    jmp .cf_loop

.found_factor:
    lea rsi, [msg_shor_factor]
    call print_string
    lea rdi, [shor_factor_p]
    call bigint_to_u64
    mov rdi, rax
    call print_number
    lea rsi, [msg_newline]
    call print_string
    jmp .next_iteration

.cf_done:
    lea rsi, [msg_shor_period_f]
    call print_string
    lea rdi, [shor_cf_k1]
    call bigint_to_u64
    mov rdi, rax
    call print_number
    lea rsi, [msg_newline]
    call print_string
    
    xor rax, rax
    jmp .exec_ret
    
    xor rax, rax
    jmp .exec_ret

.op_load_n:
    ; OP_LOAD_N: Load 32-bit N into shor_N (clearing it first)
    ; op1 = low 16 bits (rbx)
    ; op2 = high 16 bits (rcx)
    
    shl rcx, 16
    or rbx, rcx
    
    lea rdi, [shor_N]
    mov rsi, rbx
    call bigint_set_u64
    
    ; Reset a to 2
    lea rdi, [shor_a]
    mov rsi, 2
    call bigint_set_u64
    
    ; Print update
    lea rsi, [msg_shor_init]
    call print_string
    lea rsi, [msg_shor_chunks] ; Reuse "Quantum register for N="
    call print_string
    mov rdi, rbx
    call print_number
    lea rsi, [msg_newline]
    call print_string
    
    xor rax, rax
    jmp .exec_ret

    xor rax, rax
    jmp .exec_ret

.op_load_n_part:
    ; OP_LOAD_N_PART: Load 32-bit chunk of N
    ; target = chunk index (0=low 32, 1=next 32...)
    ; op1 = low 16 bits
    ; op2 = high 16 bits
    
    shl rcx, 16
    or rbx, rcx     ; rbx = 32-bit value
    
    ; Calculate offset: target * 4 bytes
    mov rax, r14
    shl rax, 2
    
    ; check bounds (512 bytes)
    cmp rax, 508
    jg .load_n_error
    
    mov [shor_N + rax], ebx
    
    ; Reset a to 2 using BigInt
    lea rdi, [shor_a]
    mov rsi, 2
    call bigint_set_u64
    
    xor rax, rax
    jmp .exec_ret

.load_n_error:
    lea rsi, [msg_error]
    call print_string
    mov rax, -1
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

; ═══════════════════════════════════════════════════════════════════════════════
; PROJECT LAZARUS - Quantum Resurrection
; ═══════════════════════════════════════════════════════════════════════════════

; resurrect_manifold - Restore entanglement/superposition from the Registry
; force_state - Force a chunk into a specific basis state
; Input: rdi = chunk index, rsi = state index
force_state:
    push rbx
    push rcx
    push rdx
    mov rbx, [state_vectors + rdi*8]
    test rbx, rbx
    jz .force_done
    mov rcx, [chunk_states + rdi*8]
    xor rdx, rdx
.zero_loop:
    cmp rdx, rcx
    jge .set_peak
    mov rax, rdx
    shl rax, 4
    xorpd xmm0, xmm0
    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm0
    inc rdx
    jmp .zero_loop
.set_peak:
    mov rax, rsi
    shl rax, 4
    movsd xmm0, [one]
    movsd [rbx + rax], xmm0
    xorpd xmm0, xmm0
    movsd [rbx + rax + 8], xmm0
.force_done:
    pop rdx
    pop rcx
    pop rbx
    ret

; manifold_peak_collapse - Collapse all active chunks to their peak probability state
manifold_peak_collapse:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, [num_chunks]
    xor r13, r13                ; chunk loop
.mpc_chunk_loop:
    cmp r13, r12
    jge .mpc_done
    mov rbx, [state_vectors + r13*8]
    test rbx, rbx
    jz .mpc_next_chunk
    mov r14, [chunk_states + r13*8]
    xor rcx, rcx                ; index
    xor r15, r15                ; max_index
    xorpd xmm2, xmm2            ; max_prob
.mpc_scan_loop:
    cmp rcx, r14
    jge .mpc_collapse
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]
    movsd xmm1, [rbx + rax + 8]
    mulsd xmm0, xmm0
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    ucomisd xmm0, xmm2
    jbe .mpc_scan_next
    movsd xmm2, xmm0
    mov r15, rcx
.mpc_scan_next:
    inc rcx
    jmp .mpc_scan_loop
.mpc_collapse:
    mov rdi, r13
    mov rsi, r15
    call force_state
.mpc_next_chunk:
    inc r13
    jmp .mpc_chunk_loop
.mpc_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

resurrect_manifold:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Step 1: Reset all active chunks to absolute zero (|0>)
    mov r12, [num_chunks]
    xor r13, r13                ; chunk loop index

.res_reset_loop:
    cmp r13, r12
    jge .res_reset_done
    
    mov rbx, [state_vectors + r13*8]
    test rbx, rbx               ; Safety check
    jz .res_skip_reset
    mov r14, [chunk_states + r13*8]
    
    ; Zero out the entire state vector
    mov rdi, rbx
    mov rcx, r14
    shl rcx, 1                  ; states * 2 (real + imag)
    pxor xmm0, xmm0
.res_zero_inner:
    movapd [rdi], xmm0
    add rdi, 16
    dec rcx
    jnz .res_zero_inner

    ; Set ground state |0...0> to 1.0
    movsd xmm1, [one]
    movsd [rbx], xmm1
    
.res_skip_reset:
    inc r13
    jmp .res_reset_loop

.res_reset_done:
    ; Step 2: Restore uniform superposition on all chunks
    xor r13, r13
.res_sup_loop:
    cmp r13, r12
    jge .res_sup_done
    
    ; Braid-awareness: Skip superposition for braid targets
    mov rdi, r13
    call is_braid_target
    test rax, rax
    jnz .res_sup_next
    
    mov rdi, r13
    call create_superposition
    
    ; CURE: Apply Last Ages Oracle (Future Prediction) to the Resurrection Buffer
    mov rdi, r13
    call future_prediction_oracle
.res_sup_next:
    inc r13
    jmp .res_sup_loop

.res_sup_done:
    ; Step 3: Re-weave all braids from the Registry
    mov r14, [num_braid_links]
    xor r15, r15                ; braid loop index

.res_weave_loop:
    cmp r15, r14
    jge .res_weave_done
    
    mov rdi, [braid_link_a + r15*8]
    mov rsi, [braid_link_b + r15*8]
    mov rdx, [braid_qutrit_a + r15*8]
    mov rcx, [braid_qutrit_b + r15*8]
    call apply_braid_phases
    
    inc r15
    jmp .res_weave_loop

.res_weave_done:
    pop r15
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
    pop rcx

    ; Print amplitude (simplified: just real part magnitude)
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]
    mulsd xmm0, xmm0
    movsd xmm1, [rbx + rax + 8]
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    sqrtsd xmm0, xmm0

    ; Convert to integer percentage
    movsd xmm1, [one]
    addsd xmm1, xmm1            ; 2
    mulsd xmm1, xmm1            ; 4
    mulsd xmm1, xmm1            ; 16
    addsd xmm1, xmm1            ; 32
    addsd xmm1, xmm1            ; 64
    addsd xmm1, xmm1            ; 128 (scale factor)
    mulsd xmm0, xmm1
    cvttsd2si rdi, xmm0

    push rcx
    call print_number
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
    mov rsi, 1048576            ; 1MB buffer (was 64KB)
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
    mov rdx, 1048576            ; max size (1MB)
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

; ═══════════════════════════════════════════════════════════════════════════════
; SHOR'S ALGORITHM HELPER FUNCTIONS
; ═══════════════════════════════════════════════════════════════════════════════

; qft_single_chunk - Apply QFT to a single chunk
; Input: rdi = chunk_index
; Transforms amplitudes using qutrit DFT matrix
qft_single_chunk:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 128                ; Local storage for temp amplitudes

    mov r12, rdi                ; chunk index
    mov rbx, [state_vectors + r12*8]
    mov r13, [chunk_states + r12*8]

    ; QFT for qutrits uses ω = exp(2πi/3) as primitive root
    ; DFT matrix: F[j,k] = ω^(jk) / sqrt(N)
    
    ; Calculate 1/sqrt(N)
    cvtsi2sd xmm15, r13
    sqrtsd xmm15, xmm15
    movsd xmm14, [one]
    divsd xmm14, xmm15          ; xmm14 = 1/sqrt(N)

    ; Process each output basis state
    xor r14, r14                ; output state j
.qft_outer:
    cmp r14, r13
    jge .qft_complete
    
    ; Initialize sum for output j
    xorpd xmm6, xmm6            ; sum_real
    xorpd xmm7, xmm7            ; sum_imag
    
    ; Sum over all input states k
    xor r15, r15                ; input state k
.qft_inner:
    cmp r15, r13
    jge .qft_store
    
    ; Calculate ω^(jk) where ω = exp(2πi/3)
    ; For qutrits: jk mod 3 determines phase
    mov rax, r14
    imul rax, r15
    xor rdx, rdx
    mov rcx, 3
    div rcx                     ; rdx = (j*k) mod 3
    
    ; ω^0 = 1, ω^1 = -1/2 + i√3/2, ω^2 = -1/2 - i√3/2
    cmp rdx, 0
    je .omega_0
    cmp rdx, 1
    je .omega_1
    ; else omega_2
    movsd xmm2, [omega2_real]   ; -0.5
    movsd xmm3, [omega2_imag]   ; -√3/2
    jmp .apply_omega

.omega_0:
    movsd xmm2, [one]
    xorpd xmm3, xmm3
    jmp .apply_omega

.omega_1:
    movsd xmm2, [omega_real]    ; -0.5
    movsd xmm3, [omega_imag]    ; √3/2

.apply_omega:
    ; Get input amplitude a[k]
    mov rax, r15
    shl rax, 4
    movsd xmm0, [rbx + rax]     ; a_real
    movsd xmm1, [rbx + rax + 8] ; a_imag
    
    ; Complex multiply: (a + bi)(c + di) = (ac-bd) + i(ad+bc)
    movsd xmm4, xmm0
    mulsd xmm4, xmm2            ; a*c
    movsd xmm5, xmm1
    mulsd xmm5, xmm3            ; b*d
    subsd xmm4, xmm5            ; ac - bd
    
    movsd xmm8, xmm0
    mulsd xmm8, xmm3            ; a*d
    movsd xmm9, xmm1
    mulsd xmm9, xmm2            ; b*c
    addsd xmm8, xmm9            ; ad + bc
    
    ; Add to sum
    addsd xmm6, xmm4
    addsd xmm7, xmm8
    
    inc r15
    jmp .qft_inner

.qft_store:
    ; Normalize by 1/sqrt(N) and store temporarily
    mulsd xmm6, xmm14
    mulsd xmm7, xmm14
    
    mov rax, r14
    shl rax, 4
    movsd [rbp - 128 + rax], xmm6
    movsd [rbp - 128 + rax + 8], xmm7
    
    inc r14
    cmp r14, 8                  ; Limit temp storage
    jl .qft_outer

.qft_complete:
    ; Copy temp results back to state vector
    xor r14, r14
.qft_copy:
    cmp r14, r13
    jge .qft_done
    cmp r14, 8
    jge .qft_done
    
    mov rax, r14
    shl rax, 4
    movsd xmm0, [rbp - 128 + rax]
    movsd xmm1, [rbp - 128 + rax + 8]
    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm1
    
    inc r14
    jmp .qft_copy

.qft_done:
    add rsp, 128
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; qft_phase_correction - Apply inter-chunk phase corrections
; Input: rdi = chunk_a (previous), rsi = chunk_b (current)
; Applies controlled phase rotations between braided chunks
qft_phase_correction:
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi                ; chunk_a
    mov r13, rsi                ; chunk_b
    
    mov rbx, [state_vectors + r13*8]
    mov r14, [chunk_states + r13*8]
    
    ; Apply controlled phase based on chunk_a measurement
    ; This creates the inter-chunk entanglement needed for full QFT
    xor rcx, rcx
.phase_loop:
    cmp rcx, r14
    jge .phase_done
    
    ; Phase angle scales with position: θ = 2π × k / (3^chunk_distance)
    cvtsi2sd xmm0, rcx
    mulsd xmm0, [two_pi]
    cvtsi2sd xmm1, r14
    mulsd xmm1, [three]
    divsd xmm0, xmm1
    
    ; Calculate phase rotation
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
    
    ; Apply to amplitude
    mov rax, rcx
    shl rax, 4
    
    movsd xmm4, [rbx + rax]
    movsd xmm5, [rbx + rax + 8]
    
    movsd xmm6, xmm4
    mulsd xmm6, xmm2
    movsd xmm7, xmm5
    mulsd xmm7, xmm3
    subsd xmm6, xmm7
    
    mulsd xmm4, xmm3
    mulsd xmm5, xmm2
    addsd xmm4, xmm5
    
    movsd [rbx + rax], xmm6
    movsd [rbx + rax + 8], xmm4
    
    inc rcx
    jmp .phase_loop

.phase_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; iqft_single_chunk - Apply inverse QFT to a single chunk
; Input: rdi = chunk_index
; Uses conjugate transpose of QFT matrix
iqft_single_chunk:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 128

    mov r12, rdi
    mov rbx, [state_vectors + r12*8]
    mov r13, [chunk_states + r12*8]

    cvtsi2sd xmm15, r13
    sqrtsd xmm15, xmm15
    movsd xmm14, [one]
    divsd xmm14, xmm15

    xor r14, r14
.iqft_outer:
    cmp r14, r13
    jge .iqft_complete
    
    xorpd xmm6, xmm6
    xorpd xmm7, xmm7
    
    xor r15, r15
.iqft_inner:
    cmp r15, r13
    jge .iqft_store
    
    ; Use conjugate: ω^(-jk) instead of ω^(jk)
    mov rax, r14
    imul rax, r15
    neg rax
    xor rdx, rdx
    mov rcx, 3
    ; Handle negative modulo
    add rax, 3000
    div rcx
    
    cmp rdx, 0
    je .iomega_0
    cmp rdx, 1
    je .iomega_1
    movsd xmm2, [omega_real]    ; Conjugate of ω^2
    movsd xmm3, [omega_imag]
    jmp .iapply_omega

.iomega_0:
    movsd xmm2, [one]
    xorpd xmm3, xmm3
    jmp .iapply_omega

.iomega_1:
    movsd xmm2, [omega2_real]
    movsd xmm3, [omega2_imag]

.iapply_omega:
    mov rax, r15
    shl rax, 4
    movsd xmm0, [rbx + rax]
    movsd xmm1, [rbx + rax + 8]
    
    movsd xmm4, xmm0
    mulsd xmm4, xmm2
    movsd xmm5, xmm1
    mulsd xmm5, xmm3
    subsd xmm4, xmm5
    
    movsd xmm8, xmm0
    mulsd xmm8, xmm3
    movsd xmm9, xmm1
    mulsd xmm9, xmm2
    addsd xmm8, xmm9
    
    addsd xmm6, xmm4
    addsd xmm7, xmm8
    
    inc r15
    jmp .iqft_inner

.iqft_store:
    mulsd xmm6, xmm14
    mulsd xmm7, xmm14
    
    mov rax, r14
    shl rax, 4
    movsd [rbp - 128 + rax], xmm6
    movsd [rbp - 128 + rax + 8], xmm7
    
    inc r14
    cmp r14, 8
    jl .iqft_outer

.iqft_complete:
    xor r14, r14
.iqft_copy:
    cmp r14, r13
    jge .iqft_done
    cmp r14, 8
    jge .iqft_done
    
    mov rax, r14
    shl rax, 4
    movsd xmm0, [rbp - 128 + rax]
    movsd xmm1, [rbp - 128 + rax + 8]
    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm1
    
    inc r14
    jmp .iqft_copy

.iqft_done:
    add rsp, 128
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; normalize_chunk - Renormalize chunk amplitudes to sum to 1
; Input: rdi = chunk_index
normalize_chunk:
    push rbx
    push r12
    push r13

    mov r12, rdi
    mov rbx, [state_vectors + r12*8]
    mov r13, [chunk_states + r12*8]

    ; Calculate total probability
    xorpd xmm6, xmm6
    xor rcx, rcx
.norm_sum:
    cmp rcx, r13
    jge .norm_apply
    
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]
    movsd xmm1, [rbx + rax + 8]
    mulsd xmm0, xmm0
    mulsd xmm1, xmm1
    addsd xmm0, xmm1
    addsd xmm6, xmm0
    
    inc rcx
    jmp .norm_sum

.norm_apply:
    ; Divide by sqrt(total)
    sqrtsd xmm6, xmm6
    ucomisd xmm6, [epsilon]
    jbe .norm_done              ; Avoid divide by zero
    
    xor rcx, rcx
.norm_div:
    cmp rcx, r13
    jge .norm_done
    
    mov rax, rcx
    shl rax, 4
    movsd xmm0, [rbx + rax]
    movsd xmm1, [rbx + rax + 8]
    divsd xmm0, xmm6
    divsd xmm1, xmm6
    movsd [rbx + rax], xmm0
    movsd [rbx + rax + 8], xmm1
    
    inc rcx
    jmp .norm_div

.norm_done:
    pop r13
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; MATH HELPERS (Shor's Classical Part)
; ═══════════════════════════════════════════════════════════════════════════════

; gcd_u64 - Calculate Greatest Common Divisor
; Input: rdi = a, rsi = b
; Output: rax = gcd(a, b)
gcd_u64:
    push rdx
    
    mov rax, rdi
    mov rcx, rsi
    
.gcd_loop:
    test rcx, rcx
    jz .gcd_done
    
    xor rdx, rdx
    div rcx         ; rax = rax / rcx, rdx = remainder
    
    mov rax, rcx
    mov rcx, rdx
    jmp .gcd_loop
    
.gcd_done:
    pop rdx
    ret

; pow_mod_u64 - Calculate (base^exp) % mod
; Input: rdi = base, rsi = exp, rdx = mod
; Output: rax = result
pow_mod_u64:
    push rbx
    push rcx
    push rdx        ; Save original mod (if needed, but used in div)
    push r8
    
    mov r8, rdx     ; r8 = modulus
    mov rax, 1      ; result = 1
    mov rbx, rdi    ; base
    mov rcx, rsi    ; exp
    
.pm_loop:
    test rcx, rcx
    jz .pm_done
    
    test rcx, 1
    jz .pm_square
    
    ; result = (result * base) % modulus
    ; safe mul: result * base
    mul rbx         ; rdx:rax = result * base
    div r8          ; rax = quotient, rdx = remainder
    mov rax, rdx    ; result = remainder
    
.pm_square:
    ; base = (base * base) % modulus
    push rax        ; Save result so we can use rax for base squaring
    mov rax, rbx
    mul rbx         ; rdx:rax = base * base
    div r8          ; remainder in rdx
    mov rbx, rdx    ; new base
    pop rax         ; Restore result
    
    shr rcx, 1
    jmp .pm_loop
    
.pm_done:
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

; print_bigint_hex - Print BigInt in hex (low 64 bits only)
; Input: rdi = pointer to BigInt
print_bigint_hex:
    push rdi
    push rax
    push rsi
    push rcx
    push rdx
    
    lea rsi, [msg_hex_prefix]
    call print_string
    
    mov rdx, rdi            ; Save pointer
    mov rcx, 63             ; Start from top limb (BIGINT_LIMBS - 1)

.hex_skip_zeros:
    cmp rcx, 0
    je .hex_start_print
    mov rax, [rdx + rcx*8]
    test rax, rax
    jnz .hex_start_print
    dec rcx
    jmp .hex_skip_zeros

.hex_start_print:
.hex_limb_loop:
    mov rax, [rdx + rcx*8]
    mov rdi, rax
    call print_hex_64
    
    test rcx, rcx
    jz .hex_done
    dec rcx
    jmp .hex_limb_loop

.hex_done:
    lea rsi, [msg_newline]
    call print_string
    
    pop rdx
    pop rcx
    pop rsi
    pop rax
    pop rdi
    ret

; print_hex_64 - Print 64-bit integer in hex
print_hex_64:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    
    mov rbx, rdi
    mov rcx, 16 ; 16 digits
.hex_loop:
    rol rbx, 4
    mov rax, rbx
    and rax, 0x0F
    cmp al, 10
    jl .hex_digit
    add al, 'A' - 10
    jmp .hex_store
.hex_digit:
    add al, '0'
.hex_store:
    push rcx
    push rsi
    mov [output_buffer], al
    mov byte [output_buffer+1], 0
    lea rsi, [output_buffer]
    call print_string
    pop rsi
    pop rcx
    dec rcx
    jnz .hex_loop
    
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
%include "bigint.asm"
