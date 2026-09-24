.text
.global bits8_add
bits8_add:
        add.b   r13, r12
        ret
.global bits8_sub
bits8_sub:
        sub.b   r13, r12
        ret
.global bits8_mul
bits8_mul:
        mov.b   r12, r14
        clr     r12
        mov     #8, r15
.L_bits8_mul_loop:
        bit.b   #1, r13
        jz      .L_bits8_mul_skip
        add.b   r14, r12
.L_bits8_mul_skip:
        rla.b   r14
        clrc
        rrc.b   r13
        dec     r15
        jne     .L_bits8_mul_loop
        ret
.global f32_bits_to_e5m3
f32_bits_to_e5m3:
        sub     #0x3800, r13
        mov     r13, r12
        clrc
        rrc     r12
        clrc
        rrc     r12
        clrc
        rrc     r12
        clrc
        rrc     r12
        and     #0x00ff, r12
        ret
.global e5m3_to_f32_bits
e5m3_to_f32_bits:
        and     #0x00ff, r12
        rla     r12
        rla     r12
        rla     r12
        rla     r12
        add     #0x3808, r12
        mov     r12, r13
        clr     r12
        ret
.global f32_bits_to_e3m2_sat_rne
f32_bits_to_e3m2_sat_rne:
        clr     r15
        jmp     .L_fp32_to_narrow
.global f32_bits_to_e4m3_sat_rne
f32_bits_to_e4m3_sat_rne:
        mov     #1, r15
        jmp     .L_fp32_to_narrow
.global f32_bits_to_e5m2_sat_rne
f32_bits_to_e5m2_sat_rne:
        mov     #2, r15
        jmp     .L_fp32_to_narrow
.L_fp32_to_narrow:
        push    r4
        push    r5
        push    r6
        push    r7
        push    r8
        push    r9
        push    r10
        mov     r15, r10
        clr     r8
        bit     #0x8000, r13
        jz      .L_enc_select
        cmp     #0, r10
        jne     .L_enc_sign8
        mov     #0x20, r8
        jmp     .L_enc_select
.L_enc_sign8:
        mov     #0x80, r8
.L_enc_select:
        cmp     #0, r10
        jeq     .L_enc_params_e3m2
        cmp     #1, r10
        jeq     .L_enc_params_e4m3
        mov     #2, r4
        mov     #15, r5
        mov     #0x7b, r6
        mov     #0x7d, r7
        jmp     .L_enc_params_done
.L_enc_params_e4m3:
        mov     #3, r4
        mov     #7, r5
        mov     #0x7e, r6
        mov     #0x7f, r7
        jmp     .L_enc_params_done
.L_enc_params_e3m2:
        mov     #2, r4
        mov     #3, r5
        mov     #0x1f, r6
        clr     r7
.L_enc_params_done:
        mov     r13, r14
        and     #0x7f80, r14
        mov     #7, r15
.L_enc_exp_shift:
        clrc
        rrc     r14
        dec     r15
        jne     .L_enc_exp_shift
        and     #0x007f, r13
        cmp     #255, r14
        jne     .L_enc_finite
        mov     r12, r15
        bis     r13, r15
        jne     .L_enc_nan
        mov     r6, r12
        bis     r8, r12
        jmp     .L_enc_return
.L_enc_nan:
        mov     r7, r12
        jmp     .L_enc_return
.L_enc_finite:
        tst     r14
        jne     .L_enc_source_normal
        mov     r8, r12
        jmp     .L_enc_return
.L_enc_source_normal:
        mov     r14, r9
        sub     #127, r9
        bis     #0x0080, r13
        mov     #1, r15
        sub     r5, r15
        cmp     r15, r9
        jl      .L_enc_subnormal
        mov     #23, r14
        sub     r4, r14
        call    #.L_round32_rne
        cmp     #2, r4
        jeq     .L_enc_normal_m2
        cmp     #16, r12
        jne     .L_enc_normal_no_carry
        clrc
        rrc     r12
        inc     r9
        jmp     .L_enc_normal_no_carry
.L_enc_normal_m2:
        cmp     #8, r12
        jne     .L_enc_normal_no_carry
        clrc
        rrc     r12
        inc     r9
.L_enc_normal_no_carry:
        mov     r9, r14
        add     r5, r14
        mov     r6, r15
        cmp     #2, r4
        jeq     .L_enc_maxexp_m2
        clrc
        rrc     r15
        clrc
        rrc     r15
        clrc
        rrc     r15
        jmp     .L_enc_maxexp_ready
.L_enc_maxexp_m2:
        clrc
        rrc     r15
        clrc
        rrc     r15
.L_enc_maxexp_ready:
        cmp     r14, r15
        jhs     .L_enc_exp_in_range
        mov     r6, r12
        jmp     .L_enc_attach_sign
.L_enc_exp_in_range:
        cmp     #2, r4
        jeq     .L_enc_build_m2
        rla     r14
        rla     r14
        rla     r14
        sub     #8, r12
        jmp     .L_enc_build_join
.L_enc_build_m2:
        rla     r14
        rla     r14
        sub     #4, r12
.L_enc_build_join:
        add     r14, r12
        cmp     r12, r6
        jhs     .L_enc_attach_sign
        mov     r6, r12
        jmp     .L_enc_attach_sign
.L_enc_subnormal:
        mov     #24, r14
        sub     r5, r14
        sub     r4, r14
        sub     r9, r14
        cmp     #25, r14
        jhs     .L_enc_zero
        call    #.L_round32_rne
        cmp     #2, r4
        jeq     .L_enc_subnormal_m2
        cmp     #8, r12
        jlo     .L_enc_attach_sign
        mov     #8, r12
        jmp     .L_enc_attach_sign
.L_enc_subnormal_m2:
        cmp     #4, r12
        jlo     .L_enc_attach_sign
        mov     #4, r12
        jmp     .L_enc_attach_sign
.L_enc_zero:
        clr     r12
.L_enc_attach_sign:
        bis     r8, r12
.L_enc_return:
        pop     r10
        pop     r9
        pop     r8
        pop     r7
        pop     r6
        pop     r5
        pop     r4
        ret
.L_round32_rne:
        clr     r15
        dec     r14
        jeq     .L_round32_guard
.L_round32_sticky:
        clrc
        rrc     r13
        rrc     r12
        jnc     .L_round32_no_sticky
        mov     #1, r15
.L_round32_no_sticky:
        dec     r14
        jne     .L_round32_sticky
.L_round32_guard:
        clrc
        rrc     r13
        rrc     r12
        jnc     .L_round32_done
        tst     r15
        jne     .L_round32_inc
        bit     #1, r12
        jeq     .L_round32_done
.L_round32_inc:
        add     #1, r12
        addc    #0, r13
.L_round32_done:
        ret
.global e3m2_to_f32_bits
e3m2_to_f32_bits:
        clr     r15
        jmp     .L_narrow_to_fp32
.global e4m3_to_f32_bits
e4m3_to_f32_bits:
        mov     #1, r15
        jmp     .L_narrow_to_fp32
.global e5m2_to_f32_bits
e5m2_to_f32_bits:
        mov     #2, r15
        jmp     .L_narrow_to_fp32
.L_narrow_to_fp32:
        push    r4
        push    r5
        push    r6
        push    r7
        push    r8
        push    r9
        mov     r15, r9
        cmp     #0, r9
        jeq     .L_dec_params_e3m2
        cmp     #1, r9
        jeq     .L_dec_params_e4m3
        mov     #2, r4
        mov     #15, r5
        mov     #7, r6
        jmp     .L_dec_params_done
.L_dec_params_e4m3:
        mov     #3, r4
        mov     #7, r5
        mov     #7, r6
        jmp     .L_dec_params_done
.L_dec_params_e3m2:
        mov     #2, r4
        mov     #3, r5
        mov     #5, r6
.L_dec_params_done:
        clr     r8
        cmp     #7, r6
        jeq     .L_dec_sign7
        bit     #0x20, r12
        jz      .L_dec_sign_done5
        mov     #0x8000, r8
.L_dec_sign_done5:
        and     #0x1f, r12
        jmp     .L_dec_split
.L_dec_sign7:
        bit     #0x80, r12
        jz      .L_dec_sign_done7
        mov     #0x8000, r8
.L_dec_sign_done7:
        and     #0x7f, r12
.L_dec_split:
        mov     r12, r14
        mov     r12, r15
        cmp     #2, r4
        jeq     .L_dec_split_m2
        clrc
        rrc     r14
        clrc
        rrc     r14
        clrc
        rrc     r14
        and     #7, r15
        jmp     .L_dec_special
.L_dec_split_m2:
        clrc
        rrc     r14
        clrc
        rrc     r14
        and     #3, r15
.L_dec_special:
        cmp     #2, r9
        jne     .L_dec_check_e4m3
        cmp     #31, r14
        jne     .L_dec_regular
        tst     r15
        jne     .L_dec_nan
        clr     r12
        mov     #0x7f80, r13
        bis     r8, r13
        jmp     .L_dec_return
.L_dec_check_e4m3:
        cmp     #1, r9
        jne     .L_dec_regular
        cmp     #15, r14
        jne     .L_dec_regular
        cmp     #7, r15
        jeq     .L_dec_nan
        jmp     .L_dec_regular
.L_dec_nan:
        clr     r12
        mov     #0x7fc0, r13
        bis     r8, r13
        jmp     .L_dec_return
.L_dec_regular:
        tst     r14
        jne     .L_dec_normal
        tst     r15
        jne     .L_dec_subnormal
        clr     r12
        mov     r8, r13
        jmp     .L_dec_return
.L_dec_normal:
        sub     r5, r14
        add     #127, r14
        jmp     .L_dec_pack
.L_dec_subnormal:
        mov     #1, r14
        sub     r5, r14
        mov     #1, r7
        cmp     #2, r4
        jeq     .L_dec_hidden_m2
        rla     r7
        rla     r7
        rla     r7
        jmp     .L_dec_normalize
.L_dec_hidden_m2:
        rla     r7
        rla     r7
.L_dec_normalize:
        bit     r7, r15
        jne     .L_dec_normalized
        rla     r15
        dec     r14
        jmp     .L_dec_normalize
.L_dec_normalized:
        inv     r7
        and     r7, r15
        add     #127, r14
.L_dec_pack:
        rla     r14
        rla     r14
        rla     r14
        rla     r14
        rla     r14
        rla     r14
        rla     r14
        cmp     #2, r4
        jeq     .L_dec_pack_m2
        rla     r15
        rla     r15
        rla     r15
        rla     r15
        jmp     .L_dec_pack_join
.L_dec_pack_m2:
        rla     r15
        rla     r15
        rla     r15
        rla     r15
        rla     r15
.L_dec_pack_join:
        bis     r15, r14
        bis     r8, r14
        mov     r14, r13
        clr     r12
.L_dec_return:
        pop     r9
        pop     r8
        pop     r7
        pop     r6
        pop     r5
        pop     r4
        ret
