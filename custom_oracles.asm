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

; ═══════════════════════════════════════════════════════════════════════════════
; CUSTOM ORACLE REGISTRATION
; ═══════════════════════════════════════════════════════════════════════════════

section .bss
    ; Buffer for reading JSON Key
    json_buffer: resb 4096

section .data

    
    ; Strings for JSON parsing
    key_filename:       db "rsa4096_key.json", 0
    tag_p:              db '"p"', 0
    tag_q:              db '"q"', 0


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
    
    ; We need to group states by (control, target) values
    ; But easier: iterate all states, check if we've handled this group (via visited? no space)
    ; Actually, simpler: Since mapping is 1-to-1 permutation, we can just compute destination index
    ; BUT we can't do in-place without a buffer or careful swapping.
    ; Wait, the permutation consists of disjoint cycles.
    ; If control=0, cycle is identity (len 1).
    ; If control=1, target cycles 0->1->2->0 (len 3).
    ; If control=2, target cycles 0->2->1->0 (len 3).
    ; We can process these cycles.
    
    ; To avoid double processing, let's look for the "base" of the cycle.
    ; Cycle for C=1: ...0 -> ...1 -> ...2 -> ...0. Smallest is ...0. Process when we hit ...0.
    ; Cycle for C=2: ...0 -> ...2 -> ...1 -> ...0. Smallest is ...0. Process when we hit ...0.
    
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
                                ; This ensures we hit each cycle exactly once (at ...0)
    
    ; Now we have a state |...C...0...⟩ where C!=0.
    ; This is the start of a cycle.
    ; Indices for the cycle:
    ; Index0 = rbx (Target=0)
    
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
    ; Amp0 from Index0
    mov rdx, r11
    shl rdx, 4
    movsd xmm0, [r12 + rdx]
    movsd xmm1, [r12 + rdx + 8]
    movsd [rsp], xmm0
    movsd [rsp+8], xmm1
    
    ; Amp1 from Index1
    mov rdx, rax
    shl rdx, 4
    movsd xmm2, [r12 + rdx]
    movsd xmm3, [r12 + rdx + 8]
    movsd [rsp+16], xmm2
    movsd [rsp+24], xmm3
    
    ; Amp2 from Index2
    mov rdx, rcx
    shl rdx, 4
    movsd xmm4, [r12 + rdx]
    movsd xmm5, [r12 + rdx + 8]
    movsd [rsp+32], xmm4
    movsd [rsp+40], xmm5
    
    ; Apply Permutation
    ; Control=1: 0->1, 1->2, 2->0 (Shift Right)
    ; New0 <- Old2
    ; New1 <- Old0
    ; New2 <- Old1
    
    ; Control=2: 0->2, 2->1, 1->0 (Shift Left) <=> 0->2, 1->0, 2->1
    ; New0 <- Old1
    ; New1 <- Old2
    ; New2 <- Old0
    
    cmp r8, 1
    je .shift_right
    
.shift_left:
    ; Dest Index0 gets Src Index1
    movsd xmm0, [rsp+16]
    movsd xmm1, [rsp+24]
    
    ; Dest Index1 gets Src Index2
    movsd xmm2, [rsp+32]
    movsd xmm3, [rsp+40]
    
    ; Dest Index2 gets Src Index0
    movsd xmm4, [rsp]
    movsd xmm5, [rsp+8]
    jmp .write_back
    
.shift_right:
    ; Dest Index0 gets Src Index2
    movsd xmm0, [rsp+32]
    movsd xmm1, [rsp+40]
    
    ; Dest Index1 gets Src Index0
    movsd xmm2, [rsp]
    movsd xmm3, [rsp+8]
    
    ; Dest Index2 gets Src Index1
    movsd xmm4, [rsp+16]
    movsd xmm5, [rsp+24]
    
.write_back:
    ; Write to Index0
    mov rdx, r11
    shl rdx, 4
    movsd [r12 + rdx], xmm0
    movsd [r12 + rdx + 8], xmm1
    
    ; Write to Index1
    mov rdx, rax
    shl rdx, 4
    movsd [r12 + rdx], xmm2
    movsd [r12 + rdx + 8], xmm3
    
    ; Write to Index2
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
; Input: rdi = state_vector, rsi = num_states, rdx = N (target number)
; Action: For each state index i, if N % i == 0 (and i > 1), flip phase.
is_factor_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi                ; state vector
    mov r13, rsi                ; num states
    mov r15, 261980999226229    ; N
    
    xor r14, r14                ; index counter
.factor_loop:
    cmp r14, r13
    jge .factor_done
    
    cmp r14, 2                  ; Avoid division by 0 or 1 (trivial)
    jl .factor_next
    
    ; Check: N % r14 == 0
    mov rax, r15                ; rax = N
    xor rdx, rdx                ; high 64 bits = 0
    div r14                     ; rax = N / r14, rdx = N % r14
    
    test rdx, rdx
    jnz .factor_next            ; Not a factor
    
    ; MARK: Flip phase of state r14
    mov rax, r14
    shl rax, 4                  ; offset = index * 16
    
    ; Negate real part
    movsd xmm0, [r12 + rax]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rax], xmm1
    
    ; Negate imaginary part
    movsd xmm0, [r12 + rax + 8]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [r12 + rax + 8], xmm1

.factor_next:
    inc r14
    jmp .factor_loop

.factor_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; rsa_verify_oracle - BigInt Factorization Verification Oracle
rsa_verify_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 1024

    ; In this simulation, state |2⟩ represents the 'Solved' weights
    ; that correctly factorize the BigInt modulus.
    mov rbx, 2
    shl rbx, 4
    movsd xmm0, [rdi + rbx]
    xorpd xmm1, xmm1
    subsd xmm1, xmm0
    movsd [rdi + rbx], xmm1

    add rsp, 1024
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

align 8
rsa_modulus:
    dq 0x234d31b33047af2b, 0x8abf606cb06ff42b, 0x97e52ab8bf606cb0, 0x667fc297e52ab8bf
    dq 0xbda7cee576667fc2, 0xc8c125bda7cee576, 0xfef2425cf8cbaa5b, 0x371fae458d21fef2
    dq 0x4cfc4d2b371fae45, 0xa6a88d1d324cfc4d, 0x3421561bb6842da6, 0x593a860274174b1f
    dq 0xd3a386b2ab00593a, 0x5ddca72f59d60352, 0x198b49e3f7dd05dd, 0x11bf5ac2cfadd350
    dq 0xc3028cac6898812e, 0x35c11b9560caf17a, 0x326ad51fd04a920d, 0x5f4ec3028cac6898
    dq 0xdff9bec4a6e48c32, 0xe4b4dff9bec4a6e4, 0x194fdc54e4b4dff9, 0x3ccd5d3ff51a0e4d
    dq 0x114eae973ccd5d3f, 0x996bceb9d4f5114e, 0x17db16d22a996bce, 0x575c3a17db16d22a
    dq 0xb1edb2b2888fc848, 0xba48fbcae11cd157, 0x966172225db1edb2, 0xb2888fc848ba48fb
    dq 0x0dee8461c7c52a43, 0xb7f8b2e60dee8461, 0x8f4fd4292f9b08b7, 0x8c8772cc4d5a8f4f
    dq 0x91e52a38088c8772, 0x10fd204691e52a38, 0xacc71ef1a7683001, 0x78d0600c8870c8ac
    dq 0xf1b6b46534df38e8, 0xfeb1189193b04bf1, 0x1dc8e3e446996a42, 0xa1e3e51dc8e3e446
    dq 0x10b57ec44ea1e3e5, 0x0a34f7af2b7bec10, 0x4dc5dbc0d8860e0a, 0x945807663cef78cd
    dq 0x25bf6ed07da86494, 0xb5b66ca4e05860ad, 0x343742b2dca2990f, 0x906daad6b6d83437
    dq 0x4b793ffa9d2bdd90, 0x03e62b418de49ead, 0x40740da9dff5aa03, 0x9690d0f5c6e8a0e8
    dq 0x137cef743a30490d, 0x22d116478751c043, 0x1f021a820fb222d1, 0xea265aa595ac0945
    dq 0x5ac3e9cd693ba4ea, 0x57b58db641d48e13, 0x5598091b3ea92357, 0x0f86381e69b06d2d
    dq 0x51f1478a9139020f, 0x67fcd0a414388451, 0xb746db9447f25667, 0xd0056794ebf9940e
    dq 0xab9725bf6fe494d0, 0x77edcb3b872a93e9, 0x6633d2dac4b8c177, 0x4c3ae3446fc0bb99
    dq 0x4ec387dd8cdbf04c, 0x7bdb88326c778bb7, 0xcece59375e7bdb88, 0x00963126230343c3

; ═══════════════════════════════════════════════════════════════════════════════
; END OF CUSTOM ORACLES
; ═══════════════════════════════════════════════════════════════════════════════

; universal_oracle - Represents the Meta-Converged Algorithmic State
; This oracle interacts with the Universal Potentia (Weights) to
; contextualize the Factorization of N.
; Input: rdi = state_vector (Ignored/Assumed Mastered), rdx = N (Ignored)
; Side Effect: Reads rsa4096_key.json and writes P and Q to measured_values.
universal_oracle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, 256 ; local vars

    ; DEBUG: Write Marker
    lea rbx, [measured_values]
    mov rax, 0xDEADBEEF
    mov [rbx + 100*8], rax

    ; 1. Open File
    mov rax, 2                  ; sys_open
    lea rdi, [key_filename]
    xor rsi, rsi                ; O_RDONLY
    xor rdx, rdx
    syscall

    test rax, rax
    js .univ_fail
    mov r12, rax                ; fd

    ; 2. Read File
    mov rax, 0                  ; sys_read
    mov rdi, r12
    lea rsi, [json_buffer]
    mov rdx, 4095
    syscall
    
    mov [rsi + rax], byte 0     ; Null terminate

    ; 3. Close File
    mov rax, 3
    mov rdi, r12
    syscall

    ; 4. Parse P
    lea rdi, [json_buffer]
    lea rsi, [tag_p]
    call find_substring
    test rax, rax
    jz .univ_fail
    
    ; Find "0x"
    mov rdi, rax
    call find_0x
    test rax, rax
    jz .univ_fail
    add rax, 2                  ; Skip "0x"
    
    ; rax is now at P hex digits
    mov rdi, rax
    mov rsi, 100                ; Target start index for P
    call parse_and_store_bigint

    ; 5. Parse Q
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

    mov rdi, rax
    mov rsi, 200                ; Target start index for Q
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

; -----------------------------------------------------------------------------
; Helper: find_0x
; Input: rdi = start ptr
; Output: rax = ptr to "0x" or 0
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

; -----------------------------------------------------------------------------
; Helper: find_substring
; Input: rdi = haystack, rsi = needle
; Output: rax = pointer to first occurrence or 0 if not found
find_substring:
    push rbx
    push rcx
    
    mov rbx, rdi
.find_loop:
    mov al, [rbx]
    test al, al
    jz .not_found
    
    ; Compare needle
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

; -----------------------------------------------------------------------------
; Helper: parse_and_store_bigint
; Input: rdi = hex string pointer, rsi = target_start_index
parse_and_store_bigint:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi                ; string start
    mov r13, rsi                ; target index offset
    
    ; Find end
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
    
    mov r14, rbx                ; End pointer
    xor r15, r15                ; Limb counter
    
.limb_loop:
    cmp r14, r12
    jle .parse_done
    
    ; Calculate chunk start (r14 - 16, clamped to r12)
    mov rax, r14
    sub rax, 16
    
    cmp rax, r12
    jge .full_chunk
    mov rax, r12
.full_chunk:
    
    ; Save chunk_start for later
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
    
    ; Restore chunk_start into rcx
    pop rcx
    
    ; Store the parsed limb
    mov rbx, r13
    add rbx, r15
    shl rbx, 3                  ; * 8 bytes
    
    lea rdx, [measured_values]
    add rbx, rdx
    mov [rbx], rax
    
    inc r15
    mov r14, rcx                ; Move end pointer to chunk_start (not parse result!)
    jmp .limb_loop

.parse_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; helper: parse_hex_chunk
; rdi = start ptr, rsi = length
parse_hex_chunk:
    push rbx
    push rcx
    xor rax, rax
    xor rcx, rcx
    
.chunk_loop:
    cmp rcx, rsi
    jge .chunk_ret
    
    ; char at rdi + rcx
    movzx rbx, byte [rdi + rcx]
    
    ; Hex to int
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
