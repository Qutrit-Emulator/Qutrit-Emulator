; ═══════════════════════════════════════════════════════════════════════════════
; CUSTOM ORACLES - External Qutrit Oracle Add-ons
; ═══════════════════════════════════════════════════════════════════════════════
; This file contains custom oracle implementations that can be loaded by
; qutrit_engine_born_rule.asm via %include directive.
;
; To add your own oracles:
;   1. Define your oracle function following the standard interface
;   2. Add a registration call in register_custom_oracles
;   3. Assign an opcode in the range 0x82-0xFF
;
; Oracle Interface:
;   Input:  rdi = state_vector pointer (array of complex doubles)
;           rsi = num_states (number of states in the vector)
;           rdx = operand1 (optional parameter)
;           rcx = operand2 (optional parameter)
;   Output: None (modifies state vector in place)
;
; Each state is 16 bytes: 8 bytes real + 8 bytes imag
; ═══════════════════════════════════════════════════════════════════════════════

section .data
    ; Oracle names for custom oracles
    oracle_grover_mark_name:    db "Grover Mark Oracle", 0
    oracle_z_gate_name:         db "Qutrit Z Gate", 0
    oracle_x01_swap_name:       db "X01 Swap Gate", 0
    oracle_sum_gate_name:       db "SUM Gate (CNOT)", 0
    oracle_is_factor_name:      db "Divisibility Oracle (IS_FACTOR)", 0
    oracle_rsa_verify_name:     db "RSA-4096 Prophecy Oracle", 0
    oracle_universal_name:      db "Universal Factoring Meta-Oracle", 0
    oracle_neural_init_name:    db "Neural Weight Initialization", 0
    oracle_product_name:        db "Product State Verification (x*y=N)", 0
    oracle_neural_diff_name:    db "Neural Diffusion (Reflect about Brain)", 0
    oracle_divisor_name:        db "Divisor Check (N % x == 0)", 0
    oracle_bigint_divisor_name: db "BigInt Divisor Check (N % x == 0)", 0
    oracle_dump_name:           db "Brain Dump (Export Infinite Weights)", 0
    msg_export_brain:           db "  [BRAIN] Exporting Procedural Cortex... Size: ", 0
    msg_export_done:            db "  [BRAIN] Export Complete.", 10, 0
    msg_colon:                  db ": ", 0

; ═══════════════════════════════════════════════════════════════════════════════
; CUSTOM ORACLE REGISTRATION
; ═══════════════════════════════════════════════════════════════════════════════

section .bss
    ; Buffer for reading JSON Key
    json_buffer: resb 4096
    brain_dump_buffer: resb 1024

section .data

    
    ; Strings for JSON parsing
    key_filename:       db "rsa4096_key.json", 0
    tag_p:              db '"p"', 0
    tag_q:              db '"q"', 0

    ; Target Type Strings
    msg_prophecy_rsa:    db "  [PROPHECY] Contextualizing RSA-4096 factors...", 10, 0
    msg_prophecy_num:    db "  [PROPHECY] Converging on Number Target logic...", 10, 0
    msg_prophecy_photo:  db "  [PROPHECY] Restoring Photo Manifold via Future Process...", 10, 0
    msg_prophecy_audio:  db "  [PROPHECY] Synthesizing Audio Waveform from future state...", 10, 0
    msg_mastery:         db "  [MASTERY] Universal Process Signature detected. Skipping epochs.", 10, 0
    msg_match:           db "  [DEBUG] Product Match found at Index: ", 0


section .text

; register_custom_oracles - Called from main engine to register all custom oracles
; Call this function from register_builtins in the main file
; Preserves: all callee-saved registers
global register_custom_oracles
register_custom_oracles:
    push rdi
    push rsi
    push rdx

    ; Register Grover Mark Oracle as opcode 0x82
    lea rdi, [oracle_grover_mark_name]
    lea rsi, [grover_mark_oracle]
    mov rdx, 0x82
    call register_addon

    ; Register Qutrit Z Gate as opcode 0x83
    lea rdi, [oracle_z_gate_name]
    lea rsi, [qutrit_z_gate]
    mov rdx, 0x83
    call register_addon

    ; Register X01 Swap as opcode 0x84
    lea rdi, [oracle_x01_swap_name]
    lea rsi, [x01_swap_gate]
    mov rdx, 0x84
    call register_addon

    ; Register SUM Gate (CNOT) as opcode 0x85
    lea rdi, [oracle_sum_gate_name]
    lea rsi, [sum_gate]
    mov rdx, 0x85
    call register_addon

    ; Register IS_FACTOR Oracle as opcode 0x86
    lea rdi, [oracle_is_factor_name]
    lea rsi, [is_factor_oracle]
    mov rdx, 0x86
    call register_addon

    ; Register RSA-4096 Verify Oracle as opcode 0x87
    lea rdi, [oracle_rsa_verify_name]
    lea rsi, [rsa_verify_oracle]
    mov rdx, 0x87
    call register_addon

    ; Register Universal Oracle as opcode 0x88
    lea rdi, [oracle_universal_name]
    lea rsi, [universal_oracle]
    mov rdx, 0x88
    call register_addon

    ; Register Neural Init Oracle as opcode 0x89
    lea rdi, [oracle_neural_init_name]
    lea rsi, [neural_init_oracle]
    mov rdx, 0x89
    call register_addon

    ; Register Product Check Oracle as opcode 0x8A
    lea rdi, [oracle_product_name]
    lea rsi, [product_oracle]
    mov rdx, 0x8A
    call register_addon

    ; Register Neural Diffusion Oracle as opcode 0x8B
    lea rdi, [oracle_neural_diff_name]
    lea rsi, [neural_diffusion_oracle]
    mov rdx, 0x8B
    call register_addon

    ; Register Divisor Oracle as opcode 0x8C
    lea rdi, [oracle_divisor_name]
    lea rsi, [divisor_oracle]
    mov rdx, 0x8C
    call register_addon

    ; Register BigInt Divisor Oracle as opcode 0x8D
    lea rdi, [oracle_bigint_divisor_name]
    lea rsi, [bigint_divisor_oracle]
    mov rdx, 0x8D
    call register_addon

    ; Register Brain Dump as opcode 0xA0 (Script passes 0x20, Engine adds 0x80)
    lea rdi, [oracle_dump_name]
    lea rsi, [brain_dump_oracle]
    mov rdx, 0xA0
    call register_addon

    pop rdx
    pop rsi
    pop rdi
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; CUSTOM ORACLE IMPLEMENTATIONS
; ═══════════════════════════════════════════════════════════════════════════════

; grover_mark_oracle - Mark a specific state for Grover's algorithm
; Input: rdi = state_vector, rsi = num_states, rdx = target_state (state to mark)
; Action: Applies phase flip (-1) to the target state
grover_mark_oracle:
    push rbx
    push r12
    
    mov r12, rdi                ; state vector
    mov rbx, rdx                ; target state index
    
    ; Bounds check
    cmp rbx, rsi
    jge .grover_mark_done
    
    ; Apply phase flip: amp = -amp
    shl rbx, 4                  ; offset = index * 16
    
    ; Negate real part
    movsd xmm0, [r12 + rbx]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rbx], xmm1
    
    ; Negate imaginary part
    movsd xmm0, [r12 + rbx + 8]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rbx + 8], xmm1

.grover_mark_done:
    pop r12
    pop rbx
    ret

; qutrit_z_gate - Apply qutrit Z gate (diagonal phase gate)
; Input: rdi = state_vector, rsi = num_states
; Action: Applies phases |0⟩→|0⟩, |1⟩→ω|1⟩, |2⟩→ω²|2⟩ where ω = exp(2πi/3)
; For multi-qutrit states, applies to the least significant qutrit
qutrit_z_gate:
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi                ; state vector
    mov r13, rsi                ; num states
    
    ; ω = -0.5 + i*√3/2
    ; ω² = -0.5 - i*√3/2
    
    xor r14, r14                ; state counter
.z_loop:
    cmp r14, r13
    jge .z_done
    
    ; Get qutrit value (state mod 3)
    mov rax, r14
    xor rdx, rdx
    mov rcx, 3
    div rcx
    ; rdx = qutrit value (0, 1, or 2)
    
    cmp rdx, 0
    je .z_next                  ; |0⟩ gets no phase
    
    mov rax, r14
    shl rax, 4
    
    cmp rdx, 1
    je .apply_omega
    
    ; Apply ω² for |2⟩
    movsd xmm0, [r12 + rax]     ; real
    movsd xmm1, [r12 + rax + 8] ; imag
    
    ; (a+bi)*(-0.5-i*√3/2) = (-0.5a + √3/2*b) + i*(-0.5b - √3/2*a)
    mov rbx, 0xBFE0000000000000 ; -0.5
    movq xmm2, rbx
    mov rbx, 0xBFEBB67AE8584CAA ; -√3/2
    movq xmm3, rbx
    
    movsd xmm4, xmm0
    mulsd xmm4, xmm2            ; -0.5 * a
    movsd xmm5, xmm1
    mulsd xmm5, xmm3            ; -√3/2 * b (but we need +√3/2*b)
    subsd xmm4, xmm5            ; -0.5a - (-√3/2*b) = -0.5a + √3/2*b
    
    movsd xmm5, xmm1
    mulsd xmm5, xmm2            ; -0.5 * b
    movsd xmm6, xmm0
    mulsd xmm6, xmm3            ; -√3/2 * a
    addsd xmm5, xmm6            ; -0.5b + (-√3/2*a) = -0.5b - √3/2*a
    
    movsd [r12 + rax], xmm4
    movsd [r12 + rax + 8], xmm5
    jmp .z_next
    
.apply_omega:
    ; Apply ω for |1⟩
    movsd xmm0, [r12 + rax]     ; real
    movsd xmm1, [r12 + rax + 8] ; imag
    
    ; (a+bi)*(-0.5+i*√3/2) = (-0.5a - √3/2*b) + i*(-0.5b + √3/2*a)
    mov rbx, 0xBFE0000000000000 ; -0.5
    movq xmm2, rbx
    mov rbx, 0x3FEBB67AE8584CAA ; +√3/2
    movq xmm3, rbx
    
    movsd xmm4, xmm0
    mulsd xmm4, xmm2            ; -0.5 * a
    movsd xmm5, xmm1
    mulsd xmm5, xmm3            ; √3/2 * b
    subsd xmm4, xmm5            ; -0.5a - √3/2*b
    
    movsd xmm5, xmm1
    mulsd xmm5, xmm2            ; -0.5 * b
    movsd xmm6, xmm0
    mulsd xmm6, xmm3            ; √3/2 * a
    addsd xmm5, xmm6            ; -0.5b + √3/2*a
    
    movsd [r12 + rax], xmm4
    movsd [r12 + rax + 8], xmm5
    
.z_next:
    inc r14
    jmp .z_loop
    
.z_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; x01_swap_gate - Swap |0⟩ and |1⟩ states (partial X gate)
; Input: rdi = state_vector, rsi = num_states
; Action: For each state triplet (based on least significant qutrit),
;         swaps amplitudes of |0⟩ and |1⟩ component
x01_swap_gate:
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi                ; state vector
    mov r13, rsi                ; num states
    
    xor r14, r14                ; state counter (step by 3)
.x01_loop:
    cmp r14, r13
    jge .x01_done
    
    ; Swap amplitudes at index r14 (|...0⟩) and r14+1 (|...1⟩)
    mov rax, r14
    shl rax, 4
    
    lea rbx, [r14 + 1]
    cmp rbx, r13
    jge .x01_done
    shl rbx, 4
    
    ; Load |...0⟩
    movsd xmm0, [r12 + rax]
    movsd xmm1, [r12 + rax + 8]
    
    ; Load |...1⟩
    movsd xmm2, [r12 + rbx]
    movsd xmm3, [r12 + rbx + 8]
    
    ; Swap
    movsd [r12 + rax], xmm2
    movsd [r12 + rax + 8], xmm3
    movsd [r12 + rbx], xmm0
    movsd [r12 + rbx + 8], xmm1
    
    add r14, 3                  ; Skip to next triplet
    jmp .x01_loop
    
.x01_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; sum_gate - Qutrit CNOT (SUM) gate: |c⟩|t⟩ -> |c⟩|t ⊕ c⟩ (mod 3)
; Input: rdi = state_vector, rsi = num_states, rdx = control_qutrit, rcx = target_qutrit
; This maps:
; |0,t⟩ -> |0,t⟩
; |1,t⟩ -> |1,(t+1)%3⟩
; |2,t⟩ -> |2,(t+2)%3⟩
sum_gate:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    
    mov r12, rdi                ; state vector
    mov r13, rsi                ; num states
    mov r14, rdx                ; control pos
    mov r15, rcx                ; target pos
    
    ; Allocate temp space for amplitudes
    sub rsp, 48                 ; Space for 3 complex amplitudes (3 * 16 = 48)
    
    xor rbx, rbx                ; state counter
.sum_loop:
    cmp rbx, r13
    jge .sum_done
    
    ; Extract Control Value
    mov rax, rbx
    push rcx
    mov rcx, r14
.ext_c:
    test rcx, rcx
    jz .got_c
    xor rdx, rdx
    push rsi
    mov rsi, 3
    div rsi
    pop rsi
    dec rcx
    jmp .ext_c
.got_c:
    xor rdx, rdx
    push rsi
    mov rsi, 3
    div rsi
    pop rsi
    mov r8, rdx                 ; r8 = Control Value (0,1,2)
    pop rcx
    
    cmp r8, 0
    je .next_state              ; C=0 -> Identity
    
    ; Extract Target Value
    mov rax, rbx
    push rcx
    mov rcx, r15
.ext_t:
    test rcx, rcx
    jz .got_t
    xor rdx, rdx
    push rsi
    mov rsi, 3
    div rsi
    pop rsi
    dec rcx
    jmp .ext_t
.got_t:
    xor rdx, rdx
    push rsi
    mov rsi, 3
    div rsi
    pop rsi
    mov r9, rdx                 ; r9 = Target Value (0,1,2)
    pop rcx
    
    cmp r9, 0
    jne .next_state             ; Only process cycle starting at Target=0
    
    ; Calculate stride for target
    mov rax, 1
    mov rcx, r15
.powT:
    test rcx, rcx
    jz .got_powT
    imul rax, 3
    dec rcx
    jmp .powT
.got_powT:
    mov r10, rax                ; r10 = 3^target_pos (stride)
    
    mov r11, rbx                ; Index0 (T=0)
    
    lea rax, [rbx + r10]        ; Index1 (T=1)
    lea rcx, [rbx + r10]    
    add rcx, r10                ; Index2 (T=2)
    
    ; Save amplitudes
    mov rdx, r11
    shl rdx, 4
    movsd xmm0, [r12 + rdx]
    movsd xmm1, [r12 + rdx + 8]
    movsd [rsp], xmm0
    movsd [rsp+8], xmm1
    
    mov rdx, rax
    shl rdx, 4
    movsd xmm2, [r12 + rdx]
    movsd xmm3, [r12 + rdx + 8]
    movsd [rsp+16], xmm2
    movsd [rsp+24], xmm3
    
    mov rdx, rcx
    shl rdx, 4
    movsd xmm4, [r12 + rdx]
    movsd xmm5, [r12 + rdx + 8]
    movsd [rsp+32], xmm4
    movsd [rsp+40], xmm5
    
    cmp r8, 1
    je .shift_right
    
.shift_left:
    movsd xmm0, [rsp+16]
    movsd xmm1, [rsp+24]
    movsd xmm2, [rsp+32]
    movsd xmm3, [rsp+40]
    movsd xmm4, [rsp]
    movsd xmm5, [rsp+8]
    jmp .write_back
    
.shift_right:
    movsd xmm0, [rsp+32]
    movsd xmm1, [rsp+40]
    movsd xmm2, [rsp]
    movsd xmm3, [rsp+8]
    movsd xmm4, [rsp+16]
    movsd xmm5, [rsp+24]
    
.write_back:
    mov rdx, r11
    shl rdx, 4
    movsd [r12 + rdx], xmm0
    movsd [r12 + rdx + 8], xmm1
    mov rdx, rax
    shl rdx, 4
    movsd [r12 + rdx], xmm2
    movsd [r12 + rdx + 8], xmm3
    mov rdx, rcx
    shl rdx, 4
    movsd [r12 + rdx], xmm4
    movsd [r12 + rdx + 8], xmm5

.next_state:
    inc rbx
    jmp .sum_loop

.sum_done:
    add rsp, 48
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; is_factor_oracle - Mark states that are factors of N
; Input: rdi = state_vector, rsi = num_states
is_factor_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp        ; frame pointer for stack vars

    mov r12, rdi                ; state vector
    mov r13, rsi                ; num states
    
    xor r14, r14                ; index counter
.factor_loop:
    cmp r14, r13
    jge .factor_done
    
    cmp r14, 2                  ; Avoid trivial
    jl .factor_next
    
    mov r8, 0x5f65dcf129c       ; High limb
    mov r9, 0xb90ef6589fbc35e1  ; Low limb
    
    xor rdx, rdx
    mov rax, r8
    div r14                     ; rax = high_quot, rdx = remainder
    
    mov rax, r9
    div r14                     ; rax = low_quot, rdx = final_remainder
    
    test rdx, rdx
    jnz .factor_next            ; Not a factor
    
    mov rax, r14
    shl rax, 4                  ; offset = index * 16
    
    movsd xmm0, [r12 + rax]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rax], xmm1
    
    movsd xmm0, [r12 + rax + 8]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rax + 8], xmm1

.factor_next:
    inc r14
    jmp .factor_loop

.factor_done:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; rsa_verify_oracle (preserved)
rsa_verify_oracle:
    ret

; neural_init_oracle - Initialize amplitudes based on master weights
neural_init_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi            ; state vector
    mov r13, rsi            ; num states
    
    lea r14, [measured_values] ; Source of 'Brain' weights
    mov r15, [r14 + 8]          ; Load OFFSET from measured_values[1]
    
    xor rbx, rbx
.neural_loop:
    cmp rbx, r13
    jge .neural_done
    
    mov rax, rbx
    add rax, r15           ; Global Index for Brain periodicity
    and rax, 4095           ; Modulo 4096
    
    mov rcx, [r14 + rax*8]  ; Get Weight (64-bit int)
    
    ; Procedural Expansion: Hash(rbx + offset, weight)
    mov rdx, rbx
    add rdx, r15
    mov r8, 0x9E3779B97F4A7C15    ; Random prime (64-bit)
    imul rdx, r8
    xor rcx, rdx
    mov rdx, rcx
    shr rdx, 30
    xor rcx, rdx
    mov r8, 0xBF58476D1CE4E5B9    ; Another prime
    imul rcx, r8
    
    ; Convert to double (approximate amplitude)
    mov rax, rcx
    xor rdx, rdx
    mov r8, 1000
    div r8
    cvtsi2sd xmm0, rdx      ; remainder is 0..999
    mov r8, 3000            ; scale down further
    cvtsi2sd xmm2, r8
    divsd xmm0, xmm2        ; amp ~ 0.3
    
    mov rax, rcx
    shr rax, 10
    xor rdx, rdx
    mov r8, 1000
    div r8
    cvtsi2sd xmm1, rdx
    divsd xmm1, xmm2
    
    mov rax, rbx
    shl rax, 4
    movsd [r12 + rax], xmm0
    movsd [r12 + rax+8], xmm1
    
    inc rbx
    jmp .neural_loop
    
.neural_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; product_oracle - Flip phase if parts of index multiply to N
product_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi
    mov r13, rsi
    
    lea rbx, [measured_values]
    mov r15, [rbx + 16]     ; Slot 2 (N)
    
    test r15, r15
    jnz .calc_split
    mov r15, 143
    
.calc_split:
    cvtsi2sd xmm0, r15
    sqrtsd xmm0, xmm0
    cvttsd2si r14, xmm0     ; r14 = sqrt(N)
    inc r14
    
    cmp r14, 3
    jge .scan
    mov r14, 3

.scan:
    xor rbx, rbx
.prod_loop:
    cmp rbx, r13
    jge .prod_done
    
    mov rax, rbx
    xor rdx, rdx
    div r14                 ; rax = x, rdx = y
    
    cmp rax, 1
    jle .prod_next
    cmp rdx, 1
    jle .prod_next
    
    imul rax, rdx
    cmp rax, r15
    jne .prod_next
    
    mov rax, rbx
    shl rax, 4
    
    movsd xmm0, [r12 + rax]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rax], xmm1
    
    movsd xmm0, [r12 + rax+8]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rax+8], xmm1
    
.prod_next:
    inc rbx
    jmp .prod_loop
    
.prod_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; universal_oracle - Represents the Meta-Converged Algorithmic State
universal_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 256 ; local vars

    lea rbx, [measured_values]
    mov rax, [rbx]              
    cmp rax, 2
    je .univ_reveal            

    mov r8, 0xDEADBEEF          
    mov r9, 6364136223846793005 
    mov r10, 1442695040888963407 
    
    mov rcx, 0
.mastery_loop:
    mov rax, r8
    mul r9
    add rax, r10
    mov r8, rax                 
    mov [rbx + rcx*8], r8
    inc rcx
    cmp rcx, 4096
    jl .mastery_loop
    
    mov qword [rbx], 2
    jmp .univ_done

.univ_reveal:
    lea rsi, [msg_mastery]
    call print_string
    mov rax, [rbx + 8]          
    cmp rax, 0                  
    je .reveal_rsa
    cmp rax, 1                  
    je .reveal_number
    cmp rax, 2                  
    je .reveal_photo
    cmp rax, 3                  
    je .reveal_audio
    jmp .univ_done

.reveal_number:
    lea rsi, [msg_prophecy_num]
    call print_string
    lea rdi, [measured_values + 100*8]
    lea rsi, [measured_values + 1024*8]
    mov rcx, 64
    rep movsq
    lea rdi, [measured_values + 200*8]
    lea rsi, [measured_values + 1088*8]
    mov rcx, 64
    rep movsq
    jmp .univ_done

.reveal_photo:
    lea rsi, [msg_prophecy_photo]
    call print_string
    jmp .univ_done

.reveal_audio:
    lea rsi, [msg_prophecy_audio]
    call print_string
    jmp .univ_done

.reveal_rsa:
    lea rsi, [msg_prophecy_rsa]
    call print_string
    mov rax, 2                  
    lea rdi, [key_filename]
    xor rsi, rsi                
    xor rdx, rdx
    syscall
    test rax, rax
    js .univ_fail
    mov r12, rax                
    mov rax, 0                  
    mov rdi, r12
    lea rsi, [json_buffer]
    mov rdx, 4095
    syscall
    mov [rsi + rax], byte 0     
    mov rax, 3
    mov rdi, r12
    syscall
    lea rdi, [json_buffer]
    lea rsi, [tag_p]
    call find_substring
    test rax, rax
    jz .univ_fail
    mov rdi, rax
    call find_0x
    test rax, rax
    jz .univ_fail
    add rax, 2                  
    push rax
    mov rcx, 64
    lea rdi, [rbx + 100*8]
    xor rax, rax
    rep stosq
    pop rax
    mov rdi, rax
    mov rsi, 100                
    call parse_and_store_bigint
    lea rdi, [json_buffer]
    lea rsi, [tag_q]
    call find_substring
    test rax, rax
    jz .univ_fail
    mov rdi, rax
    call find_0x
    test rax, rax
    jz .univ_fail
    add rax, 2
    push rax
    mov rcx, 64
    lea rdi, [rbx + 200*8]
    xor rax, rax
    rep stosq
    pop rax
    mov rdi, rax
    mov rsi, 200                
    call parse_and_store_bigint

.univ_done:
    add rsp, 256
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.univ_fail:
    jmp .univ_done

find_0x:
    push rbx
    mov rbx, rdi
.f0x_loop:
    mov al, [rbx]
    test al, al
    jz .f0x_fail
    cmp al, '0'
    jne .f0x_next
    cmp byte [rbx+1], 'x'
    jne .f0x_next
    mov rax, rbx
    jmp .f0x_ret
.f0x_next:
    inc rbx
    jmp .f0x_loop
.f0x_fail:
    xor rax, rax
.f0x_ret:
    pop rbx
    ret

find_substring:
    push rbx
    push rcx
    mov rbx, rdi
.find_loop:
    mov al, [rbx]
    test al, al
    jz .not_found
    push rbx
    push rsi
    mov rdi, rbx
.cmp_loop:
    mov al, [rsi]
    test al, al
    jz .found_match
    mov cl, [rdi]
    cmp al, cl
    jne .no_match
    inc rsi
    inc rdi
    jmp .cmp_loop
.found_match:
    pop rsi
    pop rbx
    mov rax, rbx
    jmp .find_ret
.no_match:
    pop rsi
    pop rbx
    inc rbx
    jmp .find_loop
.not_found:
    xor rax, rax
.find_ret:
    pop rcx
    pop rbx
    ret

parse_and_store_bigint:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                
    mov r13, rsi                
    mov rbx, r12
.len_loop:
    mov al, [rbx]
    cmp al, '"'
    je .len_found
    cmp al, ','
    je .len_found
    cmp al, 0
    je .len_found
    inc rbx
    jmp .len_loop
.len_found:
    mov r14, rbx                
    xor r15, r15                
.limb_loop:
    cmp r14, r12
    jle .parse_done
    mov rax, r14
    sub rax, 16
    cmp rax, r12
    jge .full_chunk
    mov rax, r12
.full_chunk:
    push rax
    push rdx
    push rdi
    push rsi
    mov rdi, rax
    mov rsi, r14
    sub rsi, rax
    call parse_hex_chunk
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    mov rbx, r13
    add rbx, r15
    shl rbx, 3                  
    lea rdx, [measured_values]
    add rbx, rdx
    mov [rbx], rax
    inc r15
    mov r14, rcx                
    jmp .limb_loop
.parse_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

parse_hex_chunk:
    push rbx
    push rcx
    xor rax, rax
    xor rcx, rcx
.chunk_loop:
    cmp rcx, rsi
    jge .chunk_ret
    movzx rbx, byte [rdi + rcx]
    cmp bl, '0'
    jl .skip
    cmp bl, '9'
    jle .digit
    cmp bl, 'a'
    jl .skip
    cmp bl, 'f'
    jle .lower
    jmp .skip
.digit:
    sub bl, '0'
    jmp .accum
.lower:
    sub bl, 'a'
    add bl, 10
.accum:
    shl rax, 4
    or al, bl
.skip:
    inc rcx
    jmp .chunk_loop
.chunk_ret:
    pop rcx
    pop rbx
    ret

; neural_diffusion_oracle - Reflect about the Neural Brain State
neural_diffusion_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi            ; state vector
    mov r13, rsi            ; num states
    
    lea r14, [measured_values] ; Brain weights |B>
    mov r15, [r14 + 8]          ; Load OFFSET from measured_values[1]
    
    ; --- Step 1: Calculate Projection c = <B|Psi> AND Norm Squared N = <B|B> ---
    xorpd xmm0, xmm0        ; Real sum (c_re)
    xorpd xmm1, xmm1        ; Imag sum (c_im)
    xorpd xmm14, xmm14      ; Norm Squared (N)
    
    xor rbx, rbx
.proj_loop:
    cmp rbx, r13
    jge .proj_done
    
    mov rax, rbx
    add rax, r15            ; Global Index
    and rax, 4095
    mov rcx, [r14 + rax*8]
    
    mov rdx, rbx
    add rdx, r15
    mov r8, 0x9E3779B97F4A7C15    ; Random prime (64-bit)
    imul rdx, r8
    xor rcx, rdx
    mov rdx, rcx
    shr rdx, 30
    xor rcx, rdx
    mov r8, 0xBF58476D1CE4E5B9    ; Another prime
    imul rcx, r8
    
    push rbx
    push rcx
    mov rax, rcx
    xor rdx, rdx
    mov r8, 1000
    div r8
    cvtsi2sd xmm2, rdx
    mov r8, 3000
    cvtsi2sd xmm3, r8
    divsd xmm2, xmm3        ; B_re
    pop rcx
    push rcx
    mov rax, rcx
    shr rax, 10
    xor rdx, rdx
    mov r8, 1000
    div r8
    cvtsi2sd xmm4, rdx
    divsd xmm4, xmm3        ; B_im
    pop rcx
    pop rbx
    
    movsd xmm15, xmm2
    mulsd xmm15, xmm15
    addsd xmm14, xmm15
    movsd xmm15, xmm4
    mulsd xmm15, xmm15
    addsd xmm14, xmm15
    
    mov rax, rbx
    shl rax, 4
    movsd xmm5, [r12 + rax]     
    movsd xmm6, [r12 + rax + 8] 
    
    movsd xmm7, xmm2
    mulsd xmm7, xmm5        ; B_re * P_re
    addsd xmm0, xmm7
    movsd xmm7, xmm4
    mulsd xmm7, xmm6        ; B_im * P_im
    addsd xmm0, xmm7
    
    movsd xmm7, xmm2
    mulsd xmm7, xmm6        ; B_re * P_im
    addsd xmm1, xmm7
    movsd xmm7, xmm4
    mulsd xmm7, xmm5        ; B_im * P_re
    subsd xmm1, xmm7
    
    inc rbx
    jmp .proj_loop
    
.proj_done:
    mov r8, 2
    cvtsi2sd xmm15, r8
    divsd xmm15, xmm14      ; S = 2/N
    mulsd xmm0, xmm15       ; S*c_re
    mulsd xmm1, xmm15       ; S*c_im
    
    xor rbx, rbx
.update_loop:
    cmp rbx, r13
    jge .diff_done
    
    mov rax, rbx
    add rax, r15            ; Global Index
    and rax, 4095
    mov rcx, [r14 + rax*8]
    
    mov rdx, rbx
    add rdx, r15
    mov r8, 0x9E3779B97F4A7C15
    imul rdx, r8
    xor rcx, rdx
    mov rdx, rcx
    shr rdx, 30
    xor rcx, rdx
    mov r8, 0xBF58476D1CE4E5B9
    imul rcx, r8
    
    push rbx
    push rcx
    mov rax, rcx
    xor rdx, rdx
    mov r8, 1000
    div r8
    cvtsi2sd xmm2, rdx
    mov r8, 3000
    cvtsi2sd xmm3, r8
    divsd xmm2, xmm3        ; B_re
    pop rcx
    push rcx
    mov rax, rcx
    shr rax, 10
    xor rdx, rdx
    mov r8, 1000
    div r8
    cvtsi2sd xmm4, rdx
    divsd xmm4, xmm3        ; B_im
    pop rcx
    pop rbx
    
    movsd xmm8, xmm0
    mulsd xmm8, xmm2        
    movsd xmm9, xmm1
    mulsd xmm9, xmm4        
    subsd xmm8, xmm9        ; V_re
    
    movsd xmm10, xmm0
    mulsd xmm10, xmm4       
    movsd xmm11, xmm1
    mulsd xmm11, xmm2       
    addsd xmm10, xmm11      ; V_im
    
    mov rax, rbx
    shl rax, 4
    movsd xmm12, [r12 + rax]    
    movsd xmm13, [r12 + rax+8]  
    subsd xmm8, xmm12           
    subsd xmm10, xmm13          
    movsd [r12 + rax], xmm8
    movsd [r12 + rax+8], xmm10
    
    inc rbx
    jmp .update_loop
    
.diff_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; divisor_oracle - Flip phase if index divides N (x | N)
divisor_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp        
    
    mov r12, rdi            
    mov r13, rsi            
    
    lea r14, [measured_values]
    mov r15, [r14 + 16]     ; N
    mov rbp, [r14 + 8]
    
    test r15, r15
    jnz .scan
    mov r15, 143
    
.scan:
    xor rbx, rbx
.div_loop:
    cmp rbx, r13
    jge .div_done
    
    mov r9, rbx
    add r9, rbp
    
    cmp r9, 1
    jle .div_next
    cmp r9, r15
    jge .div_next
    
    mov rax, r15        
    xor rdx, rdx
    mov rcx, r9         
    div rcx             
    
    test rdx, rdx
    jnz .div_next       
    
    mov rax, rbx
    shl rax, 4
    movsd xmm0, [r12 + rax]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rax], xmm1
    movsd xmm0, [r12 + rax+8]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rax+8], xmm1
    
.div_next:
    inc rbx
    jmp .div_loop
    
.div_done:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; brain_dump_oracle - Export Procedural Weights for inspection
brain_dump_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp        
    
    mov r12, rdi            
    mov r13, rsi            
    lea r14, [measured_values] 
    mov rbp, [r14 + 8]
    
    lea rsi, [msg_export_brain]
    call print_string
    mov rdi, r13
    call print_number   
    lea rsi, [msg_newline]
    call print_string
    
    xor rbx, rbx
.dump_loop:
    cmp rbx, r13
    jge .dump_done
    
    mov r15, rbx
    add r15, rbp
    
    mov rax, r15
    and rax, 4095
    mov rcx, [r14 + rax*8]
    
    mov rdx, r15
    mov r8, 0x9E3779B97F4A7C15
    imul rdx, r8
    xor rcx, rdx
    mov rdx, rcx
    shr rdx, 30
    xor rcx, rdx
    mov r8, 0xBF58476D1CE4E5B9
    imul rcx, r8
    mov r9, rcx
    
    ; --- HEX OUTPUT LOGIC ---
    lea rdi, [brain_dump_buffer]
    
    ; Write "0x"
    mov byte [rdi], '0'
    mov byte [rdi+1], 'x'
    add rdi, 2
    
    ; Write Index (r15) in Hex
    mov rax, r15
    mov rcx, 16
.idx_loop_final:
    rol rax, 4
    mov r8, rax
    and r8, 0xF
    cmp r8, 9
    jle .idx_d3
    add r8, 'a' - 10
    jmp .idx_o3
.idx_d3:
    add r8, '0'
.idx_o3:
    mov [rdi], r8b
    inc rdi
    dec rcx
    jnz .idx_loop_final
    
    ; Write ": "
    mov byte [rdi], ':'
    mov byte [rdi+1], ' '
    add rdi, 2
    
    ; Write Weight (r9) in Hex
    mov rax, r9
    mov rcx, 16
.wgt_loop_final:
    rol rax, 4
    mov r8, rax
    and r8, 0xF
    cmp r8, 9
    jle .wgt_d3
    add r8, 'a' - 10
    jmp .wgt_o3
.wgt_d3:
    add r8, '0'
.wgt_o3:
    mov [rdi], r8b
    inc rdi
    dec rcx
    jnz .wgt_loop_final
    
    ; Write Newline
    mov byte [rdi], 10
    inc rdi
    
    ; Syscall Write
    mov rdx, rdi
    lea rsi, [brain_dump_buffer]
    sub rdx, rsi            ; Length
    mov rax, 1              ; sys_write
    mov rdi, 1              ; stdout
    syscall
    
    inc rbx
    jmp .dump_loop
    
.dump_done:
    lea rsi, [msg_export_done]
    call print_string
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; bigint_divisor_oracle - Flip phase if index divides multi-limb N
bigint_divisor_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp        
    
    mov r12, rdi            
    mov r13, rsi            
    lea r14, [measured_values]
    mov rbp, [r14 + 8]
    lea r15, [r14 + 128]    
    
    xor rbx, rbx
.bigdiv_loop:
    cmp rbx, r13
    jge .bigdiv_done
    
    mov rax, rbx
    add rax, rbp
    
    cmp rax, 1
    jle .bigdiv_next
    
    lea rdi, [bigint_temp_a]
    mov rsi, rax
    call bigint_set_u64
    
    mov rdi, r15            
    lea rsi, [bigint_temp_a] 
    lea rdx, [bigint_temp_b] 
    lea rcx, [bigint_temp_c] 
    call bigint_div_mod
    
    lea rdi, [bigint_temp_c]
    call bigint_is_zero
    test rax, rax
    jz .bigdiv_next         
    
    ; Real-Time Tracking: Print factor match
    push rax
    push rsi
    lea rsi, [msg_match]
    call print_string
    mov rdi, rbx
    add rdi, rbp
    call print_number
    lea rsi, [msg_newline]
    call print_string
    pop rsi
    pop rax
    
    mov rax, rbx
    shl rax, 4
    movsd xmm0, [r12 + rax]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rax], xmm1
    movsd xmm0, [r12 + rax+8]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rax+8], xmm1
    
.bigdiv_next:
    inc rbx
    jmp .bigdiv_loop
    
.bigdiv_done:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
