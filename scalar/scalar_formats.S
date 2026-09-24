.option norvc
.text
.align 2
.globl bits8_add
bits8_add:
    add     a0, a0, a1
    andi    a0, a0, 255
    ret
.globl bits8_sub
bits8_sub:
    sub     a0, a0, a1
    andi    a0, a0, 255
    ret
.globl bits8_mul
bits8_mul:
    mul     a0, a0, a1
    andi    a0, a0, 255
    ret
.globl f32_bits_to_e5m3
f32_bits_to_e5m3:
    lui     t0, 0x38000
    sub     a0, a0, t0
    srli    a0, a0, 20
    andi    a0, a0, 255
    ret
.globl e5m3_to_f32_bits
e5m3_to_f32_bits:
    andi    a0, a0, 255
    slli    a0, a0, 20
    lui     t0, 0x38080
    add     a0, a0, t0
    ret
.globl f32_bits_to_e3m2_sat_rne
f32_bits_to_e3m2_sat_rne:
    li      a1, 0
    j       .Lfp32_to_narrow
.globl f32_bits_to_e4m3_sat_rne
f32_bits_to_e4m3_sat_rne:
    li      a1, 1
    j       .Lfp32_to_narrow
.globl f32_bits_to_e5m2_sat_rne
f32_bits_to_e5m2_sat_rne:
    li      a1, 2
    j       .Lfp32_to_narrow
.Lfp32_to_narrow:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    sw      s4, 8(sp)
    sw      s5, 4(sp)
    srli    t0, a0, 31
    beqz    a1, .Lenc_params_e3m2
    li      t1, 1
    beq     a1, t1, .Lenc_params_e4m3
    li      s1, 2
    li      s2, 15
    li      s3, 0x7b
    li      s4, 0x7d
    slli    s0, t0, 7
    j       .Lenc_params_done
.Lenc_params_e4m3:
    li      s1, 3
    li      s2, 7
    li      s3, 0x7e
    li      s4, 0x7f
    slli    s0, t0, 7
    j       .Lenc_params_done
.Lenc_params_e3m2:
    li      s1, 2
    li      s2, 3
    li      s3, 0x1f
    li      s4, 0
    slli    s0, t0, 5
.Lenc_params_done:
    slli    a0, a0, 1
    srli    a0, a0, 1
    srli    t0, a0, 23
    slli    t1, a0, 9
    srli    t1, t1, 9
    li      t2, 255
    bne     t0, t2, .Lenc_finite
    bnez    t1, .Lenc_nan
    or      a0, s3, s0
    j       .Lenc_return
.Lenc_nan:
    mv      a0, s4
    j       .Lenc_return
.Lenc_finite:
    bnez    t0, .Lenc_source_normal
    mv      a0, s0
    j       .Lenc_return
.Lenc_source_normal:
    addi    s5, t0, -127
    lui     t2, 0x800
    or      t1, t1, t2
    li      t2, 1
    sub     t2, t2, s2
    blt     s5, t2, .Lenc_subnormal
    mv      a0, t1
    li      a1, 23
    sub     a1, a1, s1
    call    .Lround_shift_rne
    li      t0, 1
    addi    t1, s1, 1
    sll     t0, t0, t1
    bne     a0, t0, .Lenc_normal_no_carry
    srli    a0, a0, 1
    addi    s5, s5, 1
.Lenc_normal_no_carry:
    add     t0, s5, s2
    sll     t0, t0, s1
    li      t1, 1
    sll     t1, t1, s1
    sub     a0, a0, t1
    add     a0, a0, t0
    bgeu    s3, a0, .Lenc_attach_sign
    mv      a0, s3
    j       .Lenc_attach_sign
.Lenc_subnormal:
    li      a1, 24
    sub     a1, a1, s2
    sub     a1, a1, s1
    sub     a1, a1, s5
    li      t0, 24
    bltu    t0, a1, .Lenc_zero
    mv      a0, t1
    call    .Lround_shift_rne
    li      t0, 1
    sll     t0, t0, s1
    bltu    a0, t0, .Lenc_attach_sign
    mv      a0, t0
    j       .Lenc_attach_sign
.Lenc_zero:
    li      a0, 0
.Lenc_attach_sign:
    or      a0, a0, s0
.Lenc_return:
    lw      s5, 4(sp)
    lw      s4, 8(sp)
    lw      s3, 12(sp)
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret
.Lround_shift_rne:
    srl     t0, a0, a1
    li      t1, 1
    sll     t1, t1, a1
    addi    t1, t1, -1
    and     t2, a0, t1
    addi    t1, t1, 1
    srli    t1, t1, 1
    bltu    t1, t2, .Lround_inc
    bltu    t2, t1, .Lround_done
    andi    t3, t0, 1
    beqz    t3, .Lround_done
.Lround_inc:
    addi    t0, t0, 1
.Lround_done:
    mv      a0, t0
    ret
.globl e3m2_to_f32_bits
e3m2_to_f32_bits:
    li      a1, 0
    j       .Lnarrow_to_fp32
.globl e4m3_to_f32_bits
e4m3_to_f32_bits:
    li      a1, 1
    j       .Lnarrow_to_fp32
.globl e5m2_to_f32_bits
e5m2_to_f32_bits:
    li      a1, 2
    j       .Lnarrow_to_fp32
.Lnarrow_to_fp32:
    addi    sp, sp, -16
    sw      s0, 12(sp)
    sw      s1, 8(sp)
    sw      s2, 4(sp)
    sw      s3, 0(sp)
    beqz    a1, .Ldec_params_e3m2
    li      t0, 1
    beq     a1, t0, .Ldec_params_e4m3
    li      s0, 2
    li      s1, 15
    li      s2, 7
    li      s3, 2
    j       .Ldec_params_done
.Ldec_params_e4m3:
    li      s0, 3
    li      s1, 7
    li      s2, 7
    li      s3, 1
    j       .Ldec_params_done
.Ldec_params_e3m2:
    li      s0, 2
    li      s1, 3
    li      s2, 5
    li      s3, 0
.Ldec_params_done:
    srl     t0, a0, s2
    andi    t0, t0, 1
    slli    t0, t0, 31
    li      t1, 1
    sll     t1, t1, s2
    addi    t1, t1, -1
    and     a0, a0, t1
    srl     t1, a0, s0
    li      t2, 1
    sll     t2, t2, s0
    addi    t2, t2, -1
    and     t2, t2, a0
    li      t3, 2
    bne     s3, t3, .Ldec_check_e4m3
    li      t3, 31
    bne     t1, t3, .Ldec_regular
    bnez    t2, .Ldec_nan
    lui     a0, 0x7f800
    or      a0, a0, t0
    j       .Ldec_return
.Ldec_check_e4m3:
    li      t3, 1
    bne     s3, t3, .Ldec_regular
    li      t3, 15
    bne     t1, t3, .Ldec_regular
    li      t3, 7
    beq     t2, t3, .Ldec_nan
    j       .Ldec_regular
.Ldec_nan:
    lui     a0, 0x7fc00
    or      a0, a0, t0
    j       .Ldec_return
.Ldec_regular:
    bnez    t1, .Ldec_normal
    bnez    t2, .Ldec_subnormal
    mv      a0, t0
    j       .Ldec_return
.Ldec_normal:
    sub     t1, t1, s1
    addi    t1, t1, 127
    slli    t1, t1, 23
    li      t3, 23
    sub     t3, t3, s0
    sll     t2, t2, t3
    or      a0, t1, t2
    or      a0, a0, t0
    j       .Ldec_return
.Ldec_subnormal:
    li      t1, 1
    sub     t1, t1, s1
    li      t3, 1
    sll     t3, t3, s0
.Ldec_subnormal_loop:
    and     t4, t2, t3
    bnez    t4, .Ldec_subnormal_ready
    slli    t2, t2, 1
    addi    t1, t1, -1
    j       .Ldec_subnormal_loop
.Ldec_subnormal_ready:
    not     t4, t3
    and     t2, t2, t4
    addi    t1, t1, 127
    slli    t1, t1, 23
    li      t3, 23
    sub     t3, t3, s0
    sll     t2, t2, t3
    or      a0, t1, t2
    or      a0, a0, t0
.Ldec_return:
    lw      s3, 0(sp)
    lw      s2, 4(sp)
    lw      s1, 8(sp)
    lw      s0, 12(sp)
    addi    sp, sp, 16
    ret
