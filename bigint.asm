; ═══════════════════════════════════════════════════════════════════════════════
; BIGINT LIBRARY - 4096-bit Arbitrary Precision Integer Arithmetic
; ═══════════════════════════════════════════════════════════════════════════════
; For use with Qutrit Engine
; Include via: %include "bigint.asm"
;
; All BigInts are stored as arrays of 64 x 64-bit limbs in little-endian order
; (limb 0 is the least significant)
; ═══════════════════════════════════════════════════════════════════════════════

; Configuration (must match main file)
%ifndef BIGINT_LIMBS
%define BIGINT_LIMBS        64
%define BIGINT_BYTES        512
%define BIGINT_BITS         4096
%endif

; ─────────────────────────────────────────────────────────────────────────────
; bigint_clear - Zero a BigInt
; Input: rdi = pointer to BigInt
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_copy - Copy BigInt from src to dest
; Input: rdi = dest, rsi = src
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_is_zero - Check if BigInt is zero
; Input: rdi = pointer to BigInt
; Output: rax = 1 if zero, 0 otherwise
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_cmp - Compare two BigInts
; Input: rdi = a, rsi = b
; Output: rax = -1 if a < b, 0 if a == b, 1 if a > b
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_add - Add two BigInts: dest = a + b
; Input: rdi = dest, rsi = a, rdx = b
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_sub - Subtract two BigInts: dest = a - b
; Input: rdi = dest, rsi = a, rdx = b
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_shl1 - Shift BigInt left by 1 bit (in-place)
; Input: rdi = BigInt pointer
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_shr1 - Shift BigInt right by 1 bit (in-place)
; Input: rdi = BigInt pointer
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_get_bit - Get bit at position
; Input: rdi = BigInt pointer, rsi = bit position
; Output: rax = 0 or 1
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_set_bit - Set bit at position to 1
; Input: rdi = BigInt pointer, rsi = bit position
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_clr_bit - Clear bit at position to 0
; Input: rdi = BigInt pointer, rsi = bit position
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_btc - Toggle bit at position
; Input: rdi = BigInt pointer, rsi = bit position
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_bitlen - Get bit length of BigInt
; Input: rdi = BigInt pointer
; Output: rax = number of bits (0 for zero)
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_set_u64 - Set BigInt from 64-bit value
; Input: rdi = dest BigInt, rsi = 64-bit value
; ─────────────────────────────────────────────────────────────────────────────
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

; ─────────────────────────────────────────────────────────────────────────────
; bigint_to_u64 - Convert BigInt to 64-bit (truncates)
; Input: rdi = BigInt pointer
; Output: rax = lower 64 bits
; ─────────────────────────────────────────────────────────────────────────────
bigint_to_u64:
    mov rax, [rdi]
    ret

; ─────────────────────────────────────────────────────────────────────────────
; bigint_mul - Multiply two BigInts: dest = a * b
; Input: rdi = dest, rsi = a, rdx = b
; ─────────────────────────────────────────────────────────────────────────────
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
