.text
.global bits8_add
bits8_add:
    add     r24, r22
    ret
.global bits8_sub
bits8_sub:
    sub     r24, r22
    ret
.global bits8_mul
bits8_mul:
    mov     r18, r24
    mov     r19, r22
    clr     r24
    ldi     r20, 8
.Lbits8_mul_loop:
    sbrc    r19, 0
    add     r24, r18
    lsl     r18
    lsr     r19
    dec     r20
    brne    .Lbits8_mul_loop
    ret
.global f32_bits_to_e5m3
f32_bits_to_e5m3:
    subi    r22, 0x00
    sbci    r23, 0x00
    sbci    r24, 0x00
    sbci    r25, 0x38
    ldi     r18, 20
.L_e5m3_encode_shift:
    lsr     r25
    ror     r24
    ror     r23
    ror     r22
    dec     r18
    brne    .L_e5m3_encode_shift
    mov     r24, r22
    ret
.global e5m3_to_f32_bits
e5m3_to_f32_bits:
    mov     r22, r24
    clr     r23
    clr     r24
    clr     r25
    ldi     r18, 20
.L_e5m3_decode_shift:
    lsl     r22
    rol     r23
    rol     r24
    rol     r25
    dec     r18
    brne    .L_e5m3_decode_shift
    ldi     r18, 0x08
    add     r24, r18
    ldi     r18, 0x38
    adc     r25, r18
    ret
.global f32_bits_to_e3m2_sat_rne
f32_bits_to_e3m2_sat_rne:
    ldi     r21, 0
    rjmp    .L_fp32_to_narrow
.global f32_bits_to_e4m3_sat_rne
f32_bits_to_e4m3_sat_rne:
    ldi     r21, 1
    rjmp    .L_fp32_to_narrow
.global f32_bits_to_e5m2_sat_rne
f32_bits_to_e5m2_sat_rne:
    ldi     r21, 2
    rjmp    .L_fp32_to_narrow
.L_fp32_to_narrow:
    push    r12
    push    r13
    push    r14
    push    r15
    push    r16
    push    r17
    mov     r18, r22
    mov     r19, r23
    mov     r20, r24
    andi    r20, 0x7f
    mov     r22, r25
    andi    r22, 0x7f
    lsl     r22
    sbrc    r24, 7
    ori     r22, 1
    tst     r21
    breq    .L_enc_params_e3m2
    cpi     r21, 1
    breq    .L_enc_params_e4m3
    ldi     r23, 2
    mov     r14, r23
    ldi     r23, 15
    mov     r15, r23
    ldi     r16, 0x7b
    ldi     r23, 0x7d
    mov     r13, r23
    clr     r17
    sbrc    r25, 7
    ldi     r17, 0x80
    rjmp    .L_enc_params_done
.L_enc_params_e4m3:
    ldi     r23, 3
    mov     r14, r23
    ldi     r23, 7
    mov     r15, r23
    ldi     r16, 0x7e
    ldi     r23, 0x7f
    mov     r13, r23
    clr     r17
    sbrc    r25, 7
    ldi     r17, 0x80
    rjmp    .L_enc_params_done
.L_enc_params_e3m2:
    ldi     r23, 2
    mov     r14, r23
    ldi     r23, 3
    mov     r15, r23
    ldi     r16, 0x1f
    clr     r13
    clr     r17
    sbrc    r25, 7
    ldi     r17, 0x20
.L_enc_params_done:
    cpi     r22, 0xff
    brne    .L_enc_finite
    mov     r23, r18
    or      r23, r19
    or      r23, r20
    brne    .L_enc_nan
    mov     r24, r16
    or      r24, r17
    rjmp    .L_enc_return
.L_enc_nan:
    mov     r24, r13
    rjmp    .L_enc_return
.L_enc_finite:
    tst     r22
    brne    .L_enc_source_normal
    mov     r24, r17
    rjmp    .L_enc_return
.L_enc_source_normal:
    mov     r12, r22
    ldi     r23, 127
    sub     r12, r23
    ori     r20, 0x80
    ldi     r23, 1
    sub     r23, r15
    cp      r12, r23
    brlt    .L_enc_subnormal
    ldi     r24, 23
    sub     r24, r14
    rcall   .L_round24_rne
    ldi     r21, 2
    cp      r14, r21
    breq    .L_enc_normal_m2
    cpi     r18, 16
    brne    .L_enc_normal_no_carry
    lsr     r18
    inc     r12
    rjmp    .L_enc_normal_no_carry
.L_enc_normal_m2:
    cpi     r18, 8
    brne    .L_enc_normal_no_carry
    lsr     r18
    inc     r12
.L_enc_normal_no_carry:
    mov     r23, r12
    add     r23, r15
    mov     r22, r16
    ldi     r21, 2
    cp      r14, r21
    breq    .L_enc_maxexp_m2
    lsr     r22
    lsr     r22
    lsr     r22
    rjmp    .L_enc_maxexp_ready
.L_enc_maxexp_m2:
    lsr     r22
    lsr     r22
.L_enc_maxexp_ready:
    cp      r22, r23
    brsh    .L_enc_exp_in_range
    mov     r24, r16
    rjmp    .L_enc_attach_sign
.L_enc_exp_in_range:
    ldi     r21, 2
    cp      r14, r21
    breq    .L_enc_build_m2
    lsl     r23
    lsl     r23
    lsl     r23
    mov     r24, r18
    subi    r24, 8
    rjmp    .L_enc_build_join
.L_enc_build_m2:
    lsl     r23
    lsl     r23
    mov     r24, r18
    subi    r24, 4
.L_enc_build_join:
    add     r24, r23
    cp      r16, r24
    brsh    .L_enc_attach_sign
    mov     r24, r16
    rjmp    .L_enc_attach_sign
.L_enc_subnormal:
    ldi     r24, 24
    sub     r24, r15
    sub     r24, r14
    sub     r24, r12
    cpi     r24, 25
    brsh    .L_enc_zero
    rcall   .L_round24_rne
    ldi     r21, 2
    cp      r14, r21
    breq    .L_enc_subnormal_m2
    cpi     r18, 8
    brlo    .L_enc_subnormal_keep
    ldi     r18, 8
    rjmp    .L_enc_subnormal_keep
.L_enc_subnormal_m2:
    cpi     r18, 4
    brlo    .L_enc_subnormal_keep
    ldi     r18, 4
.L_enc_subnormal_keep:
    mov     r24, r18
    rjmp    .L_enc_attach_sign
.L_enc_zero:
    clr     r24
.L_enc_attach_sign:
    or      r24, r17
.L_enc_return:
    pop     r17
    pop     r16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    ret
.L_round24_rne:
    clr     r22
    dec     r24
    breq    .L_round24_guard
.L_round24_sticky_loop:
    lsr     r20
    ror     r19
    ror     r18
    brcc    .L_round24_no_sticky
    ldi     r22, 1
.L_round24_no_sticky:
    dec     r24
    brne    .L_round24_sticky_loop
.L_round24_guard:
    lsr     r20
    ror     r19
    ror     r18
    brcc    .L_round24_done
    tst     r22
    brne    .L_round24_increment
    sbrs    r18, 0
    rjmp    .L_round24_done
.L_round24_increment:
    inc     r18
    brne    .L_round24_done
    inc     r19
    brne    .L_round24_done
    inc     r20
.L_round24_done:
    ret
.global e3m2_to_f32_bits
e3m2_to_f32_bits:
    ldi     r21, 0
    rjmp    .L_narrow_to_fp32
.global e4m3_to_f32_bits
e4m3_to_f32_bits:
    ldi     r21, 1
    rjmp    .L_narrow_to_fp32
.global e5m2_to_f32_bits
e5m2_to_f32_bits:
    ldi     r21, 2
    rjmp    .L_narrow_to_fp32
.L_narrow_to_fp32:
    push    r14
    push    r15
    push    r16
    push    r17
    tst     r21
    breq    .L_dec_params_e3m2
    cpi     r21, 1
    breq    .L_dec_params_e4m3
    ldi     r18, 2
    mov     r14, r18
    ldi     r18, 15
    mov     r15, r18
    ldi     r16, 7
    ldi     r17, 2
    rjmp    .L_dec_params_done
.L_dec_params_e4m3:
    ldi     r18, 3
    mov     r14, r18
    ldi     r18, 7
    mov     r15, r18
    ldi     r16, 7
    ldi     r17, 1
    rjmp    .L_dec_params_done
.L_dec_params_e3m2:
    ldi     r18, 2
    mov     r14, r18
    ldi     r18, 3
    mov     r15, r18
    ldi     r16, 5
    clr     r17
.L_dec_params_done:
    clr     r20
    cpi     r16, 7
    breq    .L_dec_sign7
    sbrc    r24, 5
    ldi     r20, 0x80
    andi    r24, 0x1f
    rjmp    .L_dec_split
.L_dec_sign7:
    sbrc    r24, 7
    ldi     r20, 0x80
    andi    r24, 0x7f
.L_dec_split:
    mov     r18, r24
    ldi     r21, 2
    cp      r14, r21
    breq    .L_dec_split_m2
    lsr     r18
    lsr     r18
    lsr     r18
    andi    r24, 7
    rjmp    .L_dec_special
.L_dec_split_m2:
    lsr     r18
    lsr     r18
    andi    r24, 3
.L_dec_special:
    cpi     r17, 2
    brne    .L_dec_check_e4m3
    cpi     r18, 31
    brne    .L_dec_regular
    tst     r24
    brne    .L_dec_nan
    clr     r22
    clr     r23
    ldi     r24, 0x80
    ldi     r25, 0x7f
    or      r25, r20
    rjmp    .L_dec_return
.L_dec_check_e4m3:
    cpi     r17, 1
    brne    .L_dec_regular
    cpi     r18, 15
    brne    .L_dec_regular
    cpi     r24, 7
    breq    .L_dec_nan
    rjmp    .L_dec_regular
.L_dec_nan:
    clr     r22
    clr     r23
    ldi     r24, 0xc0
    ldi     r25, 0x7f
    or      r25, r20
    rjmp    .L_dec_return
.L_dec_regular:
    tst     r18
    brne    .L_dec_normal
    tst     r24
    brne    .L_dec_subnormal
    clr     r22
    clr     r23
    clr     r24
    mov     r25, r20
    rjmp    .L_dec_return
.L_dec_normal:
    mov     r19, r18
    sub     r19, r15
    ldi     r18, 127
    add     r19, r18
    rjmp    .L_dec_pack
.L_dec_subnormal:
    ldi     r19, 1
    sub     r19, r15
    ldi     r21, 2
    cp      r14, r21
    breq    .L_dec_subnormal_m2
    ldi     r18, 8
    rjmp    .L_dec_subnormal_loop
.L_dec_subnormal_m2:
    ldi     r18, 4
.L_dec_subnormal_loop:
    mov     r22, r24
    and     r22, r18
    brne    .L_dec_subnormal_ready
    lsl     r24
    dec     r19
    rjmp    .L_dec_subnormal_loop
.L_dec_subnormal_ready:
    com     r18
    and     r24, r18
    ldi     r18, 127
    add     r19, r18
.L_dec_pack:
    clr     r22
    clr     r23
    mov     r18, r24
    mov     r25, r19
    lsr     r25
    andi    r19, 1
    lsl     r19
    lsl     r19
    lsl     r19
    lsl     r19
    lsl     r19
    lsl     r19
    lsl     r19
    ldi     r21, 2
    cp      r14, r21
    breq    .L_dec_pack_m2
    lsl     r18
    lsl     r18
    lsl     r18
    lsl     r18
    rjmp    .L_dec_pack_join
.L_dec_pack_m2:
    lsl     r18
    lsl     r18
    lsl     r18
    lsl     r18
    lsl     r18
.L_dec_pack_join:
    mov     r24, r19
    or      r24, r18
    or      r25, r20
.L_dec_return:
    pop     r17
    pop     r16
    pop     r15
    pop     r14
    ret
