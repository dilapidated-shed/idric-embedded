.syntax unified
.cpu cortex-m0plus
.thumb
.text
.align 2
.global bits8_add
.thumb_func
bits8_add:
    adds    r0, r0, r1
    uxtb    r0, r0
    bx      lr
.global bits8_sub
.thumb_func
bits8_sub:
    subs    r0, r0, r1
    uxtb    r0, r0
    bx      lr
.global bits8_mul
.thumb_func
bits8_mul:
    muls    r0, r1, r0
    uxtb    r0, r0
    bx      lr
.global e3m2_add
.thumb_func
e3m2_add:
    ldr     r2, =e3m2_add_table
    b       .Le3m2_binary_lookup
.global e3m2_sub
.thumb_func
e3m2_sub:
    ldr     r2, =e3m2_sub_table
    b       .Le3m2_binary_lookup
.global e3m2_mul
.thumb_func
e3m2_mul:
    ldr     r2, =e3m2_mul_table
    b       .Le3m2_binary_lookup
.global e3m2_div
.thumb_func
e3m2_div:
    ldr     r2, =e3m2_div_table
    b       .Le3m2_binary_lookup
.thumb_func
.Le3m2_binary_lookup:
    movs    r3, #63
    ands    r0, r3
    ands    r1, r3
    lsls    r0, r0, #6
    adds    r0, r0, r1
    ldrb    r0, [r2, r0]
    bx      lr
.global e3m2_sqrt
.thumb_func
e3m2_sqrt:
    movs    r1, #63
    ands    r0, r1
    ldr     r1, =e3m2_sqrt_table
    ldrb    r0, [r1, r0]
    bx      lr
.ltorg
.global f32_bits_to_e5m3
.thumb_func
f32_bits_to_e5m3:
    ldr     r1, .Lbias_e5m3_encode
    subs    r0, r0, r1
    lsrs    r0, r0, #20
    uxtb    r0, r0
    bx      lr
.global e5m3_to_f32_bits
.thumb_func
e5m3_to_f32_bits:
    uxtb    r0, r0
    lsls    r0, r0, #20
    ldr     r1, .Lbias_e5m3_decode
    adds    r0, r0, r1
    bx      lr
.global f32_bits_to_e3m2_sat_rne
.thumb_func
f32_bits_to_e3m2_sat_rne:
    movs    r1, #0
    b       .Lfp32_to_narrow
.global f32_bits_to_e4m3_sat_rne
.thumb_func
f32_bits_to_e4m3_sat_rne:
    movs    r1, #1
    b       .Lfp32_to_narrow
.global f32_bits_to_e5m2_sat_rne
.thumb_func
f32_bits_to_e5m2_sat_rne:
    movs    r1, #2
    b       .Lfp32_to_narrow
.thumb_func
.Lfp32_to_narrow:
    push    {r4-r7, lr}
    mov     r2, r0
    lsrs    r2, r2, #31
    cmp     r1, #0
    beq     .Lenc_params_e3m2
    cmp     r1, #1
    beq     .Lenc_params_e4m3
    movs    r5, #2
    movs    r6, #15
    movs    r7, #0x7b
    movs    r3, #0x7d
    movs    r4, #0
    cmp     r2, #0
    beq     .Lenc_params_done
    movs    r4, #0x80
    b       .Lenc_params_done
.Lenc_params_e4m3:
    movs    r5, #3
    movs    r6, #7
    movs    r7, #0x7e
    movs    r3, #0x7f
    movs    r4, #0
    cmp     r2, #0
    beq     .Lenc_params_done
    movs    r4, #0x80
    b       .Lenc_params_done
.Lenc_params_e3m2:
    movs    r5, #2
    movs    r6, #3
    movs    r7, #0x1f
    movs    r3, #0
    movs    r4, #0
    cmp     r2, #0
    beq     .Lenc_params_done
    movs    r4, #0x20
.Lenc_params_done:
    lsls    r0, r0, #1
    lsrs    r0, r0, #1
    lsrs    r1, r0, #23
    lsls    r2, r0, #9
    lsrs    r2, r2, #9
    cmp     r1, #255
    bne     .Lenc_finite
    cmp     r2, #0
    bne     .Lenc_nan
    mov     r0, r7
    orrs    r0, r4
    pop     {r4-r7, pc}
.Lenc_nan:
    mov     r0, r3
    pop     {r4-r7, pc}
.Lenc_finite:
    cmp     r1, #0
    bne     .Lenc_source_normal
    mov     r0, r4
    pop     {r4-r7, pc}
.Lenc_source_normal:
    subs    r1, r1, #127
    movs    r3, #1
    lsls    r3, r3, #23
    orrs    r2, r3
    movs    r3, #1
    subs    r3, r3, r6
    cmp     r1, r3
    blt     .Lenc_subnormal
    mov     r3, r1
    mov     r0, r2
    movs    r1, #23
    subs    r1, r1, r5
    bl      .Lround_shift_rne
    movs    r1, #1
    mov     r2, r5
    adds    r2, r2, #1
    lsls    r1, r1, r2
    cmp     r0, r1
    bne     .Lenc_normal_no_carry
    lsrs    r0, r0, #1
    adds    r3, r3, #1
.Lenc_normal_no_carry:
    adds    r3, r3, r6
    lsls    r3, r3, r5
    movs    r1, #1
    lsls    r1, r1, r5
    subs    r0, r0, r1
    adds    r0, r0, r3
    cmp     r0, r7
    bls     .Lenc_attach_sign
    mov     r0, r7
    b       .Lenc_attach_sign
.Lenc_subnormal:
    mov     r3, r1
    movs    r1, #24
    subs    r1, r1, r6
    subs    r1, r1, r5
    subs    r1, r1, r3
    cmp     r1, #24
    bhi     .Lenc_zero
    mov     r0, r2
    bl      .Lround_shift_rne
    movs    r1, #1
    lsls    r1, r1, r5
    cmp     r0, r1
    blo     .Lenc_attach_sign
    mov     r0, r1
    b       .Lenc_attach_sign
.Lenc_zero:
    movs    r0, #0
.Lenc_attach_sign:
    orrs    r0, r4
    pop     {r4-r7, pc}
.thumb_func
.Lround_shift_rne:
    push    {r2, r3, lr}
    mov     r2, r0
    lsrs    r2, r2, r1
    movs    r3, #1
    lsls    r3, r3, r1
    subs    r3, r3, #1
    ands    r0, r3
    adds    r3, r3, #1
    lsrs    r3, r3, #1
    cmp     r0, r3
    bhi     .Lround_inc
    blo     .Lround_done
    movs    r0, #1
    tst     r2, r0
    beq     .Lround_done
.Lround_inc:
    adds    r2, r2, #1
.Lround_done:
    mov     r0, r2
    pop     {r2, r3, pc}
.global e3m2_to_f32_bits
.thumb_func
e3m2_to_f32_bits:
    movs    r1, #0
    b       .Lnarrow_to_fp32
.global e4m3_to_f32_bits
.thumb_func
e4m3_to_f32_bits:
    movs    r1, #1
    b       .Lnarrow_to_fp32
.global e5m2_to_f32_bits
.thumb_func
e5m2_to_f32_bits:
    movs    r1, #2
    b       .Lnarrow_to_fp32
.thumb_func
.Lnarrow_to_fp32:
    push    {r4-r7, lr}
    cmp     r1, #0
    beq     .Ldec_params_e3m2
    cmp     r1, #1
    beq     .Ldec_params_e4m3
    movs    r5, #2
    movs    r6, #15
    movs    r7, #31
    movs    r4, #7
    b       .Ldec_params_done
.Ldec_params_e4m3:
    movs    r5, #3
    movs    r6, #7
    movs    r7, #15
    movs    r4, #7
    b       .Ldec_params_done
.Ldec_params_e3m2:
    movs    r5, #2
    movs    r6, #3
    movs    r7, #0
    movs    r4, #5
.Ldec_params_done:
    mov     r2, r0
    lsrs    r2, r2, r4
    movs    r3, #1
    ands    r2, r3
    lsls    r2, r2, #31
    mov     r3, r2
    movs    r2, #1
    lsls    r2, r2, r4
    subs    r2, r2, #1
    ands    r0, r2
    mov     r1, r0
    lsrs    r1, r1, r5
    movs    r2, #1
    lsls    r2, r2, r5
    subs    r2, r2, #1
    ands    r2, r0
    cmp     r4, #7
    bne     .Ldec_not_e5m2
    cmp     r5, #2
    bne     .Ldec_not_e5m2
    cmp     r1, #31
    bne     .Ldec_not_e5m2
    cmp     r2, #0
    bne     .Ldec_nan
    ldr     r0, .Lf32_inf
    orrs    r0, r3
    pop     {r4-r7, pc}
.Ldec_not_e5m2:
    cmp     r4, #7
    bne     .Ldec_regular
    cmp     r5, #3
    bne     .Ldec_regular
    cmp     r1, #15
    bne     .Ldec_regular
    cmp     r2, #7
    beq     .Ldec_nan
    b       .Ldec_regular
.Ldec_nan:
    ldr     r0, .Lf32_qnan
    orrs    r0, r3
    pop     {r4-r7, pc}
.Ldec_regular:
    cmp     r1, #0
    bne     .Ldec_normal
    cmp     r2, #0
    bne     .Ldec_subnormal
    mov     r0, r3
    pop     {r4-r7, pc}
.Ldec_normal:
    subs    r1, r1, r6
    adds    r1, r1, #127
    lsls    r1, r1, #23
    movs    r0, #23
    subs    r0, r0, r5
    lsls    r2, r2, r0
    orrs    r1, r2
    orrs    r1, r3
    mov     r0, r1
    pop     {r4-r7, pc}
.Ldec_subnormal:
    movs    r1, #1
    subs    r1, r1, r6
    movs    r0, #1
    lsls    r0, r0, r5
.Ldec_subnormal_loop:
    tst     r2, r0
    bne     .Ldec_subnormal_ready
    lsls    r2, r2, #1
    subs    r1, r1, #1
    b       .Ldec_subnormal_loop
.Ldec_subnormal_ready:
    bics    r2, r0
    adds    r1, r1, #127
    lsls    r1, r1, #23
    movs    r0, #23
    subs    r0, r0, r5
    lsls    r2, r2, r0
    orrs    r1, r2
    orrs    r1, r3
    mov     r0, r1
    pop     {r4-r7, pc}
.align 2
.Lbias_e5m3_encode:
    .word   0x38000000
.Lbias_e5m3_decode:
    .word   0x38080000
.Lf32_inf:
    .word   0x7f800000
.Lf32_qnan:
    .word   0x7fc00000
