; ═══════════════════════════════════════════════════════════════════════════════
; ORACLE TEMPLATE - Create Your Own Qutrit Oracle
; ═══════════════════════════════════════════════════════════════════════════════
;
; This template shows how to create custom oracles for the Qutrit Engine.
; Copy this file, rename it, and implement your oracle logic.
;
; ═══════════════════════════════════════════════════════════════════════════════
; ORACLE INTERFACE SPECIFICATION
; ═══════════════════════════════════════════════════════════════════════════════
;
; Function Signature:
;   my_oracle:
;       Input Registers:
;           rdi = state_vector pointer
;                 Array of complex amplitudes, each 16 bytes:
;                   [offset + 0:7]   = real part (double)
;                   [offset + 8:15]  = imaginary part (double)
;           rsi = num_states
;                 Total number of basis states (3^n for n qutrits)
;           rdx = operand1 (optional, from instruction encoding)
;           rcx = operand2 (optional, from instruction encoding)
;
;       Output:
;           None - modify state_vector in place
;
;       Preserved Registers (you MUST save/restore these):
;           rbx, rbp, r12-r15
;
;       Scratch Registers (free to use):
;           rax, rcx, rdx, r8-r11, xmm0-xmm15
;
; Qutrit Basis States:
;   |0⟩ = Triangle (△)  - Index mod 3 = 0
;   |1⟩ = Line (─)      - Index mod 3 = 1
;   |2⟩ = Square (□)    - Index mod 3 = 2
;
; Multi-qutrit State Indexing:
;   For n qutrits, state index = t₀ + 3*t₁ + 9*t₂ + ... + 3^(n-1)*tₙ₋₁
;   where tᵢ ∈ {0,1,2} is the value of qutrit i
;
; ═══════════════════════════════════════════════════════════════════════════════

section .data
    ; Define your oracle's name string here
    my_oracle_name: db "My Custom Oracle", 0
    
    ; Define any constants your oracle needs
    ; Example: phase angle
    my_phase_angle: dq 1.0471975511965976  ; π/3

section .text

; ═══════════════════════════════════════════════════════════════════════════════
; ORACLE IMPLEMENTATION
; ═══════════════════════════════════════════════════════════════════════════════

; my_oracle - [Describe what your oracle does]
; Input: rdi = state_vector, rsi = num_states, rdx = param1, rcx = param2
; Action: [Describe the transformation]
my_oracle:
    ; Save callee-saved registers
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    
    ; Set up local variables if needed
    mov rbp, rsp
    sub rsp, 32                 ; Allocate stack space if needed
    
    ; Save input parameters
    mov r12, rdi                ; state_vector
    mov r13, rsi                ; num_states
    mov r14, rdx                ; param1
    mov r15, rcx                ; param2
    
    ; ─────────────────────────────────────────────────────────────────────────
    ; YOUR ORACLE LOGIC GOES HERE
    ; ─────────────────────────────────────────────────────────────────────────
    
    ; Example: Apply a phase to all states
    xor rbx, rbx                ; loop counter
.loop:
    cmp rbx, r13
    jge .done
    
    ; Calculate offset for this state
    mov rax, rbx
    shl rax, 4                  ; offset = index * 16
    
    ; Load amplitude
    movsd xmm0, [r12 + rax]     ; real part
    movsd xmm1, [r12 + rax + 8] ; imaginary part
    
    ; TODO: Apply your transformation to xmm0, xmm1
    ; Example: just pass through unchanged
    
    ; Store result
    movsd [r12 + rax], xmm0
    movsd [r12 + rax + 8], xmm1
    
    inc rbx
    jmp .loop
    
    ; ─────────────────────────────────────────────────────────────────────────
    ; END OF ORACLE LOGIC
    ; ─────────────────────────────────────────────────────────────────────────

.done:
    ; Clean up stack
    add rsp, 32
    
    ; Restore callee-saved registers
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; REGISTRATION
; ═══════════════════════════════════════════════════════════════════════════════

; Add this call to register_custom_oracles in custom_oracles.asm:
;
;   ; Register My Custom Oracle as opcode 0x85
;   lea rdi, [my_oracle_name]
;   lea rsi, [my_oracle]
;   mov rdx, 0x85
;   call register_addon
;
; Then %include this file BEFORE custom_oracles.asm in the main engine.

; ═══════════════════════════════════════════════════════════════════════════════
; UTILITY MACROS AND HELPERS
; ═══════════════════════════════════════════════════════════════════════════════

; Macro to extract qutrit value at position from state index
; Usage: After macro, rdx contains the qutrit value (0, 1, or 2)
; Clobbers: rax, rdx, rcx (via division)
%macro EXTRACT_QUTRIT 2     ; %1 = state_index (reg), %2 = position (reg/imm)
    mov rax, %1
    mov rcx, %2
%%extract_loop:
    test rcx, rcx
    jz %%extract_done
    xor rdx, rdx
    push rcx
    mov rcx, 3
    div rcx
    pop rcx
    dec rcx
    jmp %%extract_loop
%%extract_done:
    xor rdx, rdx
    push rcx
    mov rcx, 3
    div rcx
    pop rcx
    ; rdx now contains the qutrit value at position
%endmacro

; Macro to apply complex multiplication (a+bi)*(c+di)
; Result: xmm0 = new_real, xmm1 = new_imag
; Inputs: xmm0 = a, xmm1 = b, xmm2 = c, xmm3 = d
%macro COMPLEX_MUL 0
    movsd xmm4, xmm0        ; save a
    movsd xmm5, xmm1        ; save b
    mulsd xmm0, xmm2        ; a*c
    mulsd xmm1, xmm3        ; b*d
    subsd xmm0, xmm1        ; ac - bd = new_real
    mulsd xmm4, xmm3        ; a*d
    mulsd xmm5, xmm2        ; b*c
    addsd xmm4, xmm5        ; ad + bc = new_imag
    movsd xmm1, xmm4
%endmacro

; ═══════════════════════════════════════════════════════════════════════════════
; END OF TEMPLATE
; ═══════════════════════════════════════════════════════════════════════════════
