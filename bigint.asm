; ═══════════════════════════════════════════════════════════════════════════════
; BIGINT LIBRARY - 4096-bit Arbitrary Precision Integer Arithmetic (v2.0 Fix)
; ═══════════════════════════════════════════════════════════════════════════════
; Includes Stack Padded GCD and Register-Based DivMod to avoid Segfaults.

%ifndef BIGINT_LIMBS
%define BIGINT_LIMBS        64
%define BIGINT_BYTES        512
%define BIGINT_BITS         4096
%endif

bigint_clear:
    push rcx
    push rax
    push rdi
    xor rax, rax
    mov rcx, BIGINT_LIMBS
.loop:
    mov [rdi], rax
    add rdi, 8
    dec rcx
    jnz .loop
    pop rdi
    pop rax
    pop rcx
    ret

bigint_copy:
    push rcx
    push rax
    push rdi
    push rsi
    mov rcx, BIGINT_LIMBS
.loop:
    mov rax, [rsi]
    mov [rdi], rax
    add rdi, 8
    add rsi, 8
    dec rcx
    jnz .loop
    pop rsi
    pop rdi
    pop rax
    pop rcx
    ret

; Restoring missing helpers
bigint_clr_bit:
    push rax
    push rcx
    push rdx
    mov rax, rsi
    shr rax, 6
    mov rcx, rsi
    and rcx, 63
    mov rdx, 1
    shl rdx, cl
    not rdx
    and [rdi + rax*8], rdx
    pop rdx
    pop rcx
    pop rax
    ret

bigint_btc:
    push rax
    push rcx
    push rdx
    mov rax, rsi
    shr rax, 6
    mov rcx, rsi
    and rcx, 63
    mov rdx, 1
    shl rdx, cl
    xor [rdi + rax*8], rdx
    pop rdx
    pop rcx
    pop rax
    ret

bigint_bitlen:
    push rcx
    push rdx
    mov rcx, BIGINT_LIMBS - 1
.find:
    mov rax, [rdi + rcx*8]
    test rax, rax
    jnz .found
    test rcx, rcx
    jz .is_zero
    dec rcx
    jmp .find
.found:
    bsr rdx, rax
    shl rcx, 6
    add rcx, rdx
    inc rcx
    mov rax, rcx
    jmp .done
.is_zero:
    xor rax, rax
.done:
    pop rdx
    pop rcx
    ret

bigint_is_zero:
    push rcx
    push rsi
    mov rsi, rdi
    mov rcx, BIGINT_LIMBS
.loop:
    mov rax, [rsi]
    test rax, rax
    jnz .not_zero
    add rsi, 8
    dec rcx
    jnz .loop
    mov rax, 1
    jmp .done
.not_zero:
    xor rax, rax
.done:
    pop rsi
    pop rcx
    ret

bigint_cmp:
    push rcx
    push r8
    push r9
    mov rcx, BIGINT_LIMBS - 1
.loop:
    mov r8, [rdi + rcx*8]
    mov r9, [rsi + rcx*8]
    cmp r8, r9
    ja .greater
    jb .less
    test rcx, rcx
    jz .equal
    dec rcx
    jmp .loop
.greater:
    mov rax, 1
    jmp .done
.less:
    mov rax, -1
    jmp .done
.equal:
    xor rax, rax
.done:
    pop r9
    pop r8
    pop rcx
    ret

bigint_add:
    push rcx
    push r8
    push r9
    push rdi
    push rsi
    push rdx
    clc
    mov rcx, BIGINT_LIMBS
.loop:
    mov r8, [rsi]
    mov r9, [rdx]
    adc r8, r9
    mov [rdi], r8
    add rdi, 8
    add rsi, 8
    add rdx, 8
    dec rcx
    jnz .loop
    pop rdx
    pop rsi
    pop rdi
    pop r9
    pop r8
    pop rcx
    ret

bigint_sub:
    push rcx
    push r8
    push r9
    push rdi
    push rsi
    push rdx
    clc
    mov rcx, BIGINT_LIMBS
.loop:
    mov r8, [rsi]
    mov r9, [rdx]
    sbb r8, r9
    mov [rdi], r8
    add rdi, 8
    add rsi, 8
    add rdx, 8
    dec rcx
    jnz .loop
    pop rdx
    pop rsi
    pop rdi
    pop r9
    pop r8
    pop rcx
    ret

bigint_shl1:
    push rcx
    push rax
    push rdi
    clc
    mov rcx, BIGINT_LIMBS
.loop:
    mov rax, [rdi]
    rcl rax, 1
    mov [rdi], rax
    add rdi, 8
    dec rcx
    jnz .loop
    pop rdi
    pop rax
    pop rcx
    ret

bigint_shr1:
    push rcx
    push rax
    push rsi
    lea rsi, [rdi + (BIGINT_LIMBS - 1) * 8]
    clc
    mov rcx, BIGINT_LIMBS
.loop:
    mov rax, [rsi]
    rcr rax, 1
    mov [rsi], rax
    sub rsi, 8
    dec rcx
    jnz .loop
    pop rsi
    pop rax
    pop rcx
    ret

bigint_get_bit:
    push rcx
    push rdx
    mov rax, rsi
    shr rax, 6
    mov rcx, rsi
    and rcx, 63
    mov rdx, [rdi + rax*8]
    shr rdx, cl
    and rdx, 1
    mov rax, rdx
    pop rdx
    pop rcx
    ret

bigint_set_bit:
    push rax
    push rcx
    push rdx
    mov rax, rsi
    shr rax, 6
    mov rcx, rsi
    and rcx, 63
    mov rdx, 1
    shl rdx, cl
    or [rdi + rax*8], rdx
    pop rdx
    pop rcx
    pop rax
    ret

bigint_set_u64:
    push rcx
    push rax
    push rdi
    mov rax, rdi
    call bigint_clear
    mov rdi, rax
    pop rdi
    mov [rdi], rsi
    pop rax
    pop rcx
    ret

bigint_to_u64:
    mov rax, [rdi]
    ret

bigint_mul:
    push rbx
    push rcx
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    sub rsp, BIGINT_BYTES * 2
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    lea rdi, [rbp - BIGINT_BYTES * 2]
    mov rcx, BIGINT_LIMBS * 2
    xor rax, rax
.clear:
    mov [rdi], rax
    add rdi, 8
    dec rcx
    jnz .clear
    xor r8, r8
.outer:
    cmp r8, BIGINT_LIMBS
    jge .copy
    mov r9, [r13 + r8*8]
    test r9, r9
    jz .next_i
    xor r10, r10
    xor r11, r11
.inner:
    cmp r10, BIGINT_LIMBS
    jge .store_carry
    mov rax, [r14 + r10*8]
    mul r9
    add rax, r11
    adc rdx, 0
    mov rcx, r8
    add rcx, r10
    add [rbp - BIGINT_BYTES * 2 + rcx*8], rax
    adc rdx, 0
    mov r11, rdx
    inc r10
    jmp .inner
.store_carry:
    mov rcx, r8
    add rcx, BIGINT_LIMBS
    cmp rcx, BIGINT_LIMBS * 2
    jge .next_i
    add [rbp - BIGINT_BYTES * 2 + rcx*8], r11
.next_i:
    inc r8
    jmp .outer
.copy:
    mov rdi, r12
    lea rsi, [rbp - BIGINT_BYTES * 2]
    mov rcx, BIGINT_LIMBS
.copy_loop:
    mov rax, [rsi]
    mov [rdi], rax
    add rdi, 8
    add rsi, 8
    dec rcx
    jnz .copy_loop
    add rsp, BIGINT_BYTES * 2
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; bigint_div_mod (Register Based)
; ─────────────────────────────────────────────────────────────────────────────
bigint_div_mod:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    
    ; Save pointers in non-volatile registers
    mov rbx, rdi ; Dividend
    mov r13, rsi ; Divisor
    mov r14, rdx ; Quotient
    mov r15, rcx ; Remainder
    
    ; Init Q, R
    mov rdi, r14
    call bigint_clear
    mov rdi, r15
    call bigint_clear
    
    ; Counter on stack (start from dividend bit length - 1)
    mov rdi, rbx
    call bigint_bitlen
    
    test rax, rax
    jz .done_loop_early
    
    dec rax
    push rax
    
.div_loop:
    mov rax, [rsp]
    test rax, rax
    js .done_loop
    
    ; remainder <<= 1
    mov rdi, r15
    call bigint_shl1
    
    ; bit = get_bit(dividend, i)
    mov rdi, rbx
    mov rsi, [rsp]
    call bigint_get_bit
    
    test rax, rax
    jz .no_set_rem
    mov rdi, r15
    mov rsi, 0
    call bigint_set_bit
.no_set_rem:
    ; cmp rem, div
    mov rdi, r15
    mov rsi, r13
    call bigint_cmp
    cmp rax, 0
    jl .next_bit
    
    ; rem -= div
    mov rdi, r15
    mov rsi, r15
    mov rdx, r13
    call bigint_sub
    
    ; set bit Q
    mov rdi, r14
    mov rsi, [rsp]
    call bigint_set_bit
    
.next_bit:
    dec qword [rsp]
    jmp .div_loop
    
.done_loop:
    pop rax
.done_loop_early:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; bigint_gcd (Stack Padding Fix)
; ─────────────────────────────────────────────────────────────────────────────
bigint_gcd:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    
    ; Allocate 4KB stack padding
    sub rsp, 4096
    
    mov r12, rdi ; a src
    mov r13, rsi ; b src
    mov r14, rdx ; result
    
    lea rbx, [rbp - 512]
    lea r15, [rbp - 1100] ; > 512 gap
    
    ; Copy inputs
    mov rdi, rbx
    mov rsi, r12
    call bigint_copy
    mov rdi, r15
    mov rsi, r13
    call bigint_copy
    
    lea r12, [rbp - 1700] ; Quotient temp
    lea r13, [rbp - 2300] ; Remainder temp
    
.gcd_loop:
    mov rdi, r15
    call bigint_is_zero
    cmp rax, 1
    je .gcd_done_a
    
    ; div_mod
    mov rdi, rbx
    mov rsi, r15
    mov rdx, r12
    mov rcx, r13
    call bigint_div_mod
    
    ; A=B
    mov rdi, rbx
    mov rsi, r15
    call bigint_copy
    
    ; B=R
    mov rdi, r15
    mov rsi, r13
    call bigint_copy
    
    jmp .gcd_loop
    
.gcd_done_a:
    mov rdi, r14
    mov rsi, rbx
    call bigint_copy
    
    add rsp, 4096
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; bigint_pow_mod (Safe Stack)
; ─────────────────────────────────────────────────────────────────────────────
bigint_pow_mod:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov rbp, rsp
    
    ; Allocate 4KB padding
    sub rsp, 4096
    
    ; Copy inputs (rdi=result, rsi=base, rdx=exp, rcx=mod)
    lea rbx, [rbp - 512]      ; base copy
    lea r12, [rbp - 1100]     ; exp copy
    lea r13, [rbp - 1700]     ; temp mul / num
    lea r14, [rbp - 2300]     ; temp quote
    
    mov r15, rdi ; result ptr
    
    ; save mod ptr on stack (safely below buffers)
    mov [rbp - 2900], rcx
    
    ; Copy base
    mov rdi, rbx
    call bigint_copy ; rsi is base
    
    ; Copy exp
    mov rdi, r12
    mov rsi, rdx
    call bigint_copy
    
    ; Result = 1
    mov rdi, r15
    call bigint_clear
    mov qword [r15], 1
    
    mov rdi, r12
    call bigint_bitlen
    mov r9, rax
    xor r10, r10
    
.pm_loop:
    cmp r10, r9
    jge .pm_done
    
    mov rdi, r12
    mov rsi, r10
    call bigint_get_bit
    test rax, rax
    jz .pm_square
    
    ; result = result * base
    mov rdi, r13
    mov rsi, r15
    mov rdx, rbx
    call bigint_mul
    
    ; mod
    mov rdi, r13
    mov rsi, [rbp - 2900]
    mov rdx, r14
    mov rcx, r15 ; dest
    call bigint_div_mod
    
.pm_square:
    ; base = base * base
    mov rdi, r13
    mov rsi, rbx
    mov rdx, rbx
    call bigint_mul
    
    mov rdi, r13
    mov rsi, [rbp - 2900]
    mov rdx, r14
    mov rcx, rbx ; dest (base)
    call bigint_div_mod
    
    inc r10
    jmp .pm_loop
    
.pm_done:
    add rsp, 4096
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
