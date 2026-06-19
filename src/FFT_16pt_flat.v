// ═══════════════════════════════════════════════════════════════════
// FFT_16pt_flat.v — structural 16-point FFT (Radix-2 DIT, flat)
//
// 32 FFT_2pt instances across 4 explicit stages; bit-reversal at input.
// Same interface and results as FFT_16pt.
// Input: DW bits. Output: DW+4 bits. Requires: FFT_2pt, w_lut
// ═══════════════════════════════════════════════════════════════════
module FFT_16pt_flat #(parameter DW = 16) (
    input  signed [DW-1:0] in_re0,  in_im0,  in_re1,  in_im1,
    input  signed [DW-1:0] in_re2,  in_im2,  in_re3,  in_im3,
    input  signed [DW-1:0] in_re4,  in_im4,  in_re5,  in_im5,
    input  signed [DW-1:0] in_re6,  in_im6,  in_re7,  in_im7,
    input  signed [DW-1:0] in_re8,  in_im8,  in_re9,  in_im9,
    input  signed [DW-1:0] in_re10, in_im10, in_re11, in_im11,
    input  signed [DW-1:0] in_re12, in_im12, in_re13, in_im13,
    input  signed [DW-1:0] in_re14, in_im14, in_re15, in_im15,

    output signed [DW+3:0] out_re0,  out_im0,  out_re1,  out_im1,
    output signed [DW+3:0] out_re2,  out_im2,  out_re3,  out_im3,
    output signed [DW+3:0] out_re4,  out_im4,  out_re5,  out_im5,
    output signed [DW+3:0] out_re6,  out_im6,  out_re7,  out_im7,
    output signed [DW+3:0] out_re8,  out_im8,  out_re9,  out_im9,
    output signed [DW+3:0] out_re10, out_im10, out_re11, out_im11,
    output signed [DW+3:0] out_re12, out_im12, out_re13, out_im13,
    output signed [DW+3:0] out_re14, out_im14, out_re15, out_im15
);

    // ── Twiddle factors (W_16^0 through W_16^7) ──────────────────
    wire signed [15:0] w_re0, w_im0, w_re1, w_im1, w_re2, w_im2, w_re3, w_im3;
    wire signed [15:0] w_re4, w_im4, w_re5, w_im5, w_re6, w_im6, w_re7, w_im7;
    w_lut lut0 (.addr(3'd0), .W_re(w_re0), .W_im(w_im0));
    w_lut lut1 (.addr(3'd1), .W_re(w_re1), .W_im(w_im1));
    w_lut lut2 (.addr(3'd2), .W_re(w_re2), .W_im(w_im2));
    w_lut lut3 (.addr(3'd3), .W_re(w_re3), .W_im(w_im3));
    w_lut lut4 (.addr(3'd4), .W_re(w_re4), .W_im(w_im4));
    w_lut lut5 (.addr(3'd5), .W_re(w_re5), .W_im(w_im5));
    w_lut lut6 (.addr(3'd6), .W_re(w_re6), .W_im(w_im6));
    w_lut lut7 (.addr(3'd7), .W_re(w_re7), .W_im(w_im7));

    // ── Stage 1 outputs (DW+1 bits) ──────────────────────────────
    wire signed [DW:0] s1_re0,  s1_im0,  s1_re1,  s1_im1;
    wire signed [DW:0] s1_re2,  s1_im2,  s1_re3,  s1_im3;
    wire signed [DW:0] s1_re4,  s1_im4,  s1_re5,  s1_im5;
    wire signed [DW:0] s1_re6,  s1_im6,  s1_re7,  s1_im7;
    wire signed [DW:0] s1_re8,  s1_im8,  s1_re9,  s1_im9;
    wire signed [DW:0] s1_re10, s1_im10, s1_re11, s1_im11;
    wire signed [DW:0] s1_re12, s1_im12, s1_re13, s1_im13;
    wire signed [DW:0] s1_re14, s1_im14, s1_re15, s1_im15;

    // ── Stage 2 outputs (DW+2 bits) ──────────────────────────────
    wire signed [DW+1:0] s2_re0,  s2_im0,  s2_re1,  s2_im1;
    wire signed [DW+1:0] s2_re2,  s2_im2,  s2_re3,  s2_im3;
    wire signed [DW+1:0] s2_re4,  s2_im4,  s2_re5,  s2_im5;
    wire signed [DW+1:0] s2_re6,  s2_im6,  s2_re7,  s2_im7;
    wire signed [DW+1:0] s2_re8,  s2_im8,  s2_re9,  s2_im9;
    wire signed [DW+1:0] s2_re10, s2_im10, s2_re11, s2_im11;
    wire signed [DW+1:0] s2_re12, s2_im12, s2_re13, s2_im13;
    wire signed [DW+1:0] s2_re14, s2_im14, s2_re15, s2_im15;

    // ── Stage 3 outputs (DW+3 bits) ──────────────────────────────
    wire signed [DW+2:0] s3_re0,  s3_im0,  s3_re1,  s3_im1;
    wire signed [DW+2:0] s3_re2,  s3_im2,  s3_re3,  s3_im3;
    wire signed [DW+2:0] s3_re4,  s3_im4,  s3_re5,  s3_im5;
    wire signed [DW+2:0] s3_re6,  s3_im6,  s3_re7,  s3_im7;
    wire signed [DW+2:0] s3_re8,  s3_im8,  s3_re9,  s3_im9;
    wire signed [DW+2:0] s3_re10, s3_im10, s3_re11, s3_im11;
    wire signed [DW+2:0] s3_re12, s3_im12, s3_re13, s3_im13;
    wire signed [DW+2:0] s3_re14, s3_im14, s3_re15, s3_im15;

    // ═════════════════════════════════════════════════════════════
    // STAGE 1  (stride = 1,  W = 1 for all butterflies)
    //
    // Inputs are fed in bit-reversed order. The 4-bit reversal maps:
    //   pos  0↔x[0]   1↔x[8]   2↔x[4]   3↔x[12]
    //        4↔x[2]   5↔x[10]  6↔x[6]   7↔x[14]
    //        8↔x[1]   9↔x[9]  10↔x[5]  11↔x[13]
    //       12↔x[3]  13↔x[11] 14↔x[7]  15↔x[15]
    // Each butterfly takes adjacent positions (2k, 2k+1).
    // ═════════════════════════════════════════════════════════════

    FFT_2pt #(DW) s1_btfy0 ( // s1[0,1] ← (x[0], x[8])
        .A_re(in_re0),  .A_im(in_im0),  .B_re(in_re8),  .B_im(in_im8),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s1_re0), .X_im(s1_im0), .Y_re(s1_re1), .Y_im(s1_im1)
    );
    FFT_2pt #(DW) s1_btfy1 ( // s1[2,3] ← (x[4], x[12])
        .A_re(in_re4),  .A_im(in_im4),  .B_re(in_re12), .B_im(in_im12),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s1_re2), .X_im(s1_im2), .Y_re(s1_re3), .Y_im(s1_im3)
    );
    FFT_2pt #(DW) s1_btfy2 ( // s1[4,5] ← (x[2], x[10])
        .A_re(in_re2),  .A_im(in_im2),  .B_re(in_re10), .B_im(in_im10),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s1_re4), .X_im(s1_im4), .Y_re(s1_re5), .Y_im(s1_im5)
    );
    FFT_2pt #(DW) s1_btfy3 ( // s1[6,7] ← (x[6], x[14])
        .A_re(in_re6),  .A_im(in_im6),  .B_re(in_re14), .B_im(in_im14),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s1_re6), .X_im(s1_im6), .Y_re(s1_re7), .Y_im(s1_im7)
    );
    FFT_2pt #(DW) s1_btfy4 ( // s1[8,9] ← (x[1], x[9])
        .A_re(in_re1),  .A_im(in_im1),  .B_re(in_re9),  .B_im(in_im9),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s1_re8), .X_im(s1_im8), .Y_re(s1_re9), .Y_im(s1_im9)
    );
    FFT_2pt #(DW) s1_btfy5 ( // s1[10,11] ← (x[5], x[13])
        .A_re(in_re5),  .A_im(in_im5),  .B_re(in_re13), .B_im(in_im13),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s1_re10), .X_im(s1_im10), .Y_re(s1_re11), .Y_im(s1_im11)
    );
    FFT_2pt #(DW) s1_btfy6 ( // s1[12,13] ← (x[3], x[11])
        .A_re(in_re3),  .A_im(in_im3),  .B_re(in_re11), .B_im(in_im11),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s1_re12), .X_im(s1_im12), .Y_re(s1_re13), .Y_im(s1_im13)
    );
    FFT_2pt #(DW) s1_btfy7 ( // s1[14,15] ← (x[7], x[15])
        .A_re(in_re7),  .A_im(in_im7),  .B_re(in_re15), .B_im(in_im15),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s1_re14), .X_im(s1_im14), .Y_re(s1_re15), .Y_im(s1_im15)
    );

    // ═════════════════════════════════════════════════════════════
    // STAGE 2  (stride = 2,  W_4 twiddles: W_16^0 and W_16^4)
    //
    // Butterfly at position p takes s1[p] and s1[p+2].
    // X output to s2[p], Y output to s2[p+2].
    // Even-p → W=1,  odd-p → W=-j (W_16^4).
    // ═════════════════════════════════════════════════════════════

    FFT_2pt #(DW+1) s2_btfy0 ( // s2[0,2] ← (s1[0], s1[2])  W=1
        .A_re(s1_re0), .A_im(s1_im0), .B_re(s1_re2), .B_im(s1_im2),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s2_re0), .X_im(s2_im0), .Y_re(s2_re2), .Y_im(s2_im2)
    );
    FFT_2pt #(DW+1) s2_btfy1 ( // s2[1,3] ← (s1[1], s1[3])  W=-j
        .A_re(s1_re1), .A_im(s1_im1), .B_re(s1_re3), .B_im(s1_im3),
        .W_re(w_re4), .W_im(w_im4),
        .X_re(s2_re1), .X_im(s2_im1), .Y_re(s2_re3), .Y_im(s2_im3)
    );
    FFT_2pt #(DW+1) s2_btfy2 ( // s2[4,6] ← (s1[4], s1[6])  W=1
        .A_re(s1_re4), .A_im(s1_im4), .B_re(s1_re6), .B_im(s1_im6),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s2_re4), .X_im(s2_im4), .Y_re(s2_re6), .Y_im(s2_im6)
    );
    FFT_2pt #(DW+1) s2_btfy3 ( // s2[5,7] ← (s1[5], s1[7])  W=-j
        .A_re(s1_re5), .A_im(s1_im5), .B_re(s1_re7), .B_im(s1_im7),
        .W_re(w_re4), .W_im(w_im4),
        .X_re(s2_re5), .X_im(s2_im5), .Y_re(s2_re7), .Y_im(s2_im7)
    );
    FFT_2pt #(DW+1) s2_btfy4 ( // s2[8,10] ← (s1[8], s1[10])  W=1
        .A_re(s1_re8),  .A_im(s1_im8),  .B_re(s1_re10), .B_im(s1_im10),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s2_re8), .X_im(s2_im8), .Y_re(s2_re10), .Y_im(s2_im10)
    );
    FFT_2pt #(DW+1) s2_btfy5 ( // s2[9,11] ← (s1[9], s1[11])  W=-j
        .A_re(s1_re9),  .A_im(s1_im9),  .B_re(s1_re11), .B_im(s1_im11),
        .W_re(w_re4), .W_im(w_im4),
        .X_re(s2_re9), .X_im(s2_im9), .Y_re(s2_re11), .Y_im(s2_im11)
    );
    FFT_2pt #(DW+1) s2_btfy6 ( // s2[12,14] ← (s1[12], s1[14])  W=1
        .A_re(s1_re12), .A_im(s1_im12), .B_re(s1_re14), .B_im(s1_im14),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s2_re12), .X_im(s2_im12), .Y_re(s2_re14), .Y_im(s2_im14)
    );
    FFT_2pt #(DW+1) s2_btfy7 ( // s2[13,15] ← (s1[13], s1[15])  W=-j
        .A_re(s1_re13), .A_im(s1_im13), .B_re(s1_re15), .B_im(s1_im15),
        .W_re(w_re4), .W_im(w_im4),
        .X_re(s2_re13), .X_im(s2_im13), .Y_re(s2_re15), .Y_im(s2_im15)
    );

    // ═════════════════════════════════════════════════════════════
    // STAGE 3  (stride = 4,  W_8 twiddles: W_16^{0,2,4,6})
    //
    // Butterfly at position p takes s2[p] and s2[p+4].
    // X output to s3[p], Y output to s3[p+4].
    // Twiddle sequence W^0, W^2, W^4, W^6 repeats for the second group.
    // ═════════════════════════════════════════════════════════════

    FFT_2pt #(DW+2) s3_btfy0 ( // s3[0,4] ← (s2[0], s2[4])  W=W_16^0
        .A_re(s2_re0), .A_im(s2_im0), .B_re(s2_re4), .B_im(s2_im4),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s3_re0), .X_im(s3_im0), .Y_re(s3_re4), .Y_im(s3_im4)
    );
    FFT_2pt #(DW+2) s3_btfy1 ( // s3[1,5] ← (s2[1], s2[5])  W=W_16^2
        .A_re(s2_re1), .A_im(s2_im1), .B_re(s2_re5), .B_im(s2_im5),
        .W_re(w_re2), .W_im(w_im2),
        .X_re(s3_re1), .X_im(s3_im1), .Y_re(s3_re5), .Y_im(s3_im5)
    );
    FFT_2pt #(DW+2) s3_btfy2 ( // s3[2,6] ← (s2[2], s2[6])  W=W_16^4=-j
        .A_re(s2_re2), .A_im(s2_im2), .B_re(s2_re6), .B_im(s2_im6),
        .W_re(w_re4), .W_im(w_im4),
        .X_re(s3_re2), .X_im(s3_im2), .Y_re(s3_re6), .Y_im(s3_im6)
    );
    FFT_2pt #(DW+2) s3_btfy3 ( // s3[3,7] ← (s2[3], s2[7])  W=W_16^6
        .A_re(s2_re3), .A_im(s2_im3), .B_re(s2_re7), .B_im(s2_im7),
        .W_re(w_re6), .W_im(w_im6),
        .X_re(s3_re3), .X_im(s3_im3), .Y_re(s3_re7), .Y_im(s3_im7)
    );
    FFT_2pt #(DW+2) s3_btfy4 ( // s3[8,12] ← (s2[8], s2[12])  W=W_16^0
        .A_re(s2_re8),  .A_im(s2_im8),  .B_re(s2_re12), .B_im(s2_im12),
        .W_re(w_re0), .W_im(w_im0),
        .X_re(s3_re8), .X_im(s3_im8), .Y_re(s3_re12), .Y_im(s3_im12)
    );
    FFT_2pt #(DW+2) s3_btfy5 ( // s3[9,13] ← (s2[9], s2[13])  W=W_16^2
        .A_re(s2_re9),  .A_im(s2_im9),  .B_re(s2_re13), .B_im(s2_im13),
        .W_re(w_re2), .W_im(w_im2),
        .X_re(s3_re9), .X_im(s3_im9), .Y_re(s3_re13), .Y_im(s3_im13)
    );
    FFT_2pt #(DW+2) s3_btfy6 ( // s3[10,14] ← (s2[10], s2[14])  W=W_16^4=-j
        .A_re(s2_re10), .A_im(s2_im10), .B_re(s2_re14), .B_im(s2_im14),
        .W_re(w_re4), .W_im(w_im4),
        .X_re(s3_re10), .X_im(s3_im10), .Y_re(s3_re14), .Y_im(s3_im14)
    );
    FFT_2pt #(DW+2) s3_btfy7 ( // s3[11,15] ← (s2[11], s2[15])  W=W_16^6
        .A_re(s2_re11), .A_im(s2_im11), .B_re(s2_re15), .B_im(s2_im15),
        .W_re(w_re6), .W_im(w_im6),
        .X_re(s3_re11), .X_im(s3_im11), .Y_re(s3_re15), .Y_im(s3_im15)
    );

    // ═════════════════════════════════════════════════════════════
    // STAGE 4  (stride = 8,  W_16 twiddles: W_16^{0..7})
    //
    // Butterfly at position p takes s3[p] and s3[p+8].
    // X output to out[p], Y output to out[p+8].
    // ═════════════════════════════════════════════════════════════

    FFT_2pt #(DW+3) s4_btfy0 ( // out[0,8] ← (s3[0], s3[8])  W=W_16^0
        .A_re(s3_re0), .A_im(s3_im0), .B_re(s3_re8),  .B_im(s3_im8),
        .W_re(w_re0), .W_im(w_im0), .X_re(out_re0), .X_im(out_im0), .Y_re(out_re8),  .Y_im(out_im8)
    );
    FFT_2pt #(DW+3) s4_btfy1 ( // out[1,9] ← (s3[1], s3[9])  W=W_16^1
        .A_re(s3_re1), .A_im(s3_im1), .B_re(s3_re9),  .B_im(s3_im9),
        .W_re(w_re1), .W_im(w_im1), .X_re(out_re1), .X_im(out_im1), .Y_re(out_re9),  .Y_im(out_im9)
    );
    FFT_2pt #(DW+3) s4_btfy2 ( // out[2,10] ← (s3[2], s3[10])  W=W_16^2
        .A_re(s3_re2), .A_im(s3_im2), .B_re(s3_re10), .B_im(s3_im10),
        .W_re(w_re2), .W_im(w_im2), .X_re(out_re2), .X_im(out_im2), .Y_re(out_re10), .Y_im(out_im10)
    );
    FFT_2pt #(DW+3) s4_btfy3 ( // out[3,11] ← (s3[3], s3[11])  W=W_16^3
        .A_re(s3_re3), .A_im(s3_im3), .B_re(s3_re11), .B_im(s3_im11),
        .W_re(w_re3), .W_im(w_im3), .X_re(out_re3), .X_im(out_im3), .Y_re(out_re11), .Y_im(out_im11)
    );
    FFT_2pt #(DW+3) s4_btfy4 ( // out[4,12] ← (s3[4], s3[12])  W=W_16^4=-j
        .A_re(s3_re4), .A_im(s3_im4), .B_re(s3_re12), .B_im(s3_im12),
        .W_re(w_re4), .W_im(w_im4), .X_re(out_re4), .X_im(out_im4), .Y_re(out_re12), .Y_im(out_im12)
    );
    FFT_2pt #(DW+3) s4_btfy5 ( // out[5,13] ← (s3[5], s3[13])  W=W_16^5
        .A_re(s3_re5), .A_im(s3_im5), .B_re(s3_re13), .B_im(s3_im13),
        .W_re(w_re5), .W_im(w_im5), .X_re(out_re5), .X_im(out_im5), .Y_re(out_re13), .Y_im(out_im13)
    );
    FFT_2pt #(DW+3) s4_btfy6 ( // out[6,14] ← (s3[6], s3[14])  W=W_16^6
        .A_re(s3_re6), .A_im(s3_im6), .B_re(s3_re14), .B_im(s3_im14),
        .W_re(w_re6), .W_im(w_im6), .X_re(out_re6), .X_im(out_im6), .Y_re(out_re14), .Y_im(out_im14)
    );
    FFT_2pt #(DW+3) s4_btfy7 ( // out[7,15] ← (s3[7], s3[15])  W=W_16^7
        .A_re(s3_re7), .A_im(s3_im7), .B_re(s3_re15), .B_im(s3_im15),
        .W_re(w_re7), .W_im(w_im7), .X_re(out_re7), .X_im(out_im7), .Y_re(out_re15), .Y_im(out_im15)
    );

endmodule