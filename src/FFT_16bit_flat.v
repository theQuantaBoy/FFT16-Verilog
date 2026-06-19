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

    // ── Twiddle factors (shared LUT, W_16^0 through W_16^7) ─────
    wire signed [15:0] w_re [0:7], w_im [0:7];
    w_lut lut0 (.addr(3'd0), .W_re(w_re[0]), .W_im(w_im[0]));
    w_lut lut1 (.addr(3'd1), .W_re(w_re[1]), .W_im(w_im[1]));
    w_lut lut2 (.addr(3'd2), .W_re(w_re[2]), .W_im(w_im[2]));
    w_lut lut3 (.addr(3'd3), .W_re(w_re[3]), .W_im(w_im[3]));
    w_lut lut4 (.addr(3'd4), .W_re(w_re[4]), .W_im(w_im[4]));
    w_lut lut5 (.addr(3'd5), .W_re(w_re[5]), .W_im(w_im[5]));
    w_lut lut6 (.addr(3'd6), .W_re(w_re[6]), .W_im(w_im[6]));
    w_lut lut7 (.addr(3'd7), .W_re(w_re[7]), .W_im(w_im[7]));

    // ── Intermediate wires ───────────────────────────────────────
    wire signed [DW:0]   s1_re [0:15], s1_im [0:15];  // after stage 1
    wire signed [DW+1:0] s2_re [0:15], s2_im [0:15];  // after stage 2
    wire signed [DW+2:0] s3_re [0:15], s3_im [0:15];  // after stage 3

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
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s1_re[0]), .X_im(s1_im[0]), .Y_re(s1_re[1]), .Y_im(s1_im[1])
    );
    FFT_2pt #(DW) s1_btfy1 ( // s1[2,3] ← (x[4], x[12])
        .A_re(in_re4),  .A_im(in_im4),  .B_re(in_re12), .B_im(in_im12),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s1_re[2]), .X_im(s1_im[2]), .Y_re(s1_re[3]), .Y_im(s1_im[3])
    );
    FFT_2pt #(DW) s1_btfy2 ( // s1[4,5] ← (x[2], x[10])
        .A_re(in_re2),  .A_im(in_im2),  .B_re(in_re10), .B_im(in_im10),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s1_re[4]), .X_im(s1_im[4]), .Y_re(s1_re[5]), .Y_im(s1_im[5])
    );
    FFT_2pt #(DW) s1_btfy3 ( // s1[6,7] ← (x[6], x[14])
        .A_re(in_re6),  .A_im(in_im6),  .B_re(in_re14), .B_im(in_im14),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s1_re[6]), .X_im(s1_im[6]), .Y_re(s1_re[7]), .Y_im(s1_im[7])
    );
    FFT_2pt #(DW) s1_btfy4 ( // s1[8,9] ← (x[1], x[9])
        .A_re(in_re1),  .A_im(in_im1),  .B_re(in_re9),  .B_im(in_im9),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s1_re[8]), .X_im(s1_im[8]), .Y_re(s1_re[9]), .Y_im(s1_im[9])
    );
    FFT_2pt #(DW) s1_btfy5 ( // s1[10,11] ← (x[5], x[13])
        .A_re(in_re5),  .A_im(in_im5),  .B_re(in_re13), .B_im(in_im13),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s1_re[10]), .X_im(s1_im[10]), .Y_re(s1_re[11]), .Y_im(s1_im[11])
    );
    FFT_2pt #(DW) s1_btfy6 ( // s1[12,13] ← (x[3], x[11])
        .A_re(in_re3),  .A_im(in_im3),  .B_re(in_re11), .B_im(in_im11),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s1_re[12]), .X_im(s1_im[12]), .Y_re(s1_re[13]), .Y_im(s1_im[13])
    );
    FFT_2pt #(DW) s1_btfy7 ( // s1[14,15] ← (x[7], x[15])
        .A_re(in_re7),  .A_im(in_im7),  .B_re(in_re15), .B_im(in_im15),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s1_re[14]), .X_im(s1_im[14]), .Y_re(s1_re[15]), .Y_im(s1_im[15])
    );

    // ═════════════════════════════════════════════════════════════
    // STAGE 2  (stride = 2,  W_4 twiddles: W_16^0 and W_16^4)
    //
    // Butterfly at position p takes s1[p] and s1[p+2].
    // X output goes back to s2[p], Y output to s2[p+2].
    // Twiddle: even-p group → W=1 (W_16^0), odd-p group → W=-j (W_16^4).
    // ═════════════════════════════════════════════════════════════

    FFT_2pt #(DW+1) s2_btfy0 ( // s2[0,2] ← (s1[0], s1[2])  W=1
        .A_re(s1_re[0]), .A_im(s1_im[0]), .B_re(s1_re[2]), .B_im(s1_im[2]),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s2_re[0]), .X_im(s2_im[0]), .Y_re(s2_re[2]), .Y_im(s2_im[2])
    );
    FFT_2pt #(DW+1) s2_btfy1 ( // s2[1,3] ← (s1[1], s1[3])  W=-j
        .A_re(s1_re[1]), .A_im(s1_im[1]), .B_re(s1_re[3]), .B_im(s1_im[3]),
        .W_re(w_re[4]), .W_im(w_im[4]),
        .X_re(s2_re[1]), .X_im(s2_im[1]), .Y_re(s2_re[3]), .Y_im(s2_im[3])
    );
    FFT_2pt #(DW+1) s2_btfy2 ( // s2[4,6] ← (s1[4], s1[6])  W=1
        .A_re(s1_re[4]), .A_im(s1_im[4]), .B_re(s1_re[6]), .B_im(s1_im[6]),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s2_re[4]), .X_im(s2_im[4]), .Y_re(s2_re[6]), .Y_im(s2_im[6])
    );
    FFT_2pt #(DW+1) s2_btfy3 ( // s2[5,7] ← (s1[5], s1[7])  W=-j
        .A_re(s1_re[5]), .A_im(s1_im[5]), .B_re(s1_re[7]), .B_im(s1_im[7]),
        .W_re(w_re[4]), .W_im(w_im[4]),
        .X_re(s2_re[5]), .X_im(s2_im[5]), .Y_re(s2_re[7]), .Y_im(s2_im[7])
    );
    FFT_2pt #(DW+1) s2_btfy4 ( // s2[8,10] ← (s1[8], s1[10])  W=1
        .A_re(s1_re[8]),  .A_im(s1_im[8]),  .B_re(s1_re[10]), .B_im(s1_im[10]),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s2_re[8]), .X_im(s2_im[8]), .Y_re(s2_re[10]), .Y_im(s2_im[10])
    );
    FFT_2pt #(DW+1) s2_btfy5 ( // s2[9,11] ← (s1[9], s1[11])  W=-j
        .A_re(s1_re[9]),  .A_im(s1_im[9]),  .B_re(s1_re[11]), .B_im(s1_im[11]),
        .W_re(w_re[4]), .W_im(w_im[4]),
        .X_re(s2_re[9]), .X_im(s2_im[9]), .Y_re(s2_re[11]), .Y_im(s2_im[11])
    );
    FFT_2pt #(DW+1) s2_btfy6 ( // s2[12,14] ← (s1[12], s1[14])  W=1
        .A_re(s1_re[12]), .A_im(s1_im[12]), .B_re(s1_re[14]), .B_im(s1_im[14]),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s2_re[12]), .X_im(s2_im[12]), .Y_re(s2_re[14]), .Y_im(s2_im[14])
    );
    FFT_2pt #(DW+1) s2_btfy7 ( // s2[13,15] ← (s1[13], s1[15])  W=-j
        .A_re(s1_re[13]), .A_im(s1_im[13]), .B_re(s1_re[15]), .B_im(s1_im[15]),
        .W_re(w_re[4]), .W_im(w_im[4]),
        .X_re(s2_re[13]), .X_im(s2_im[13]), .Y_re(s2_re[15]), .Y_im(s2_im[15])
    );

    // ═════════════════════════════════════════════════════════════
    // STAGE 3  (stride = 4,  W_8 twiddles: W_16^{0,2,4,6})
    //
    // Butterfly at position p takes s2[p] and s2[p+4].
    // X output to s3[p], Y output to s3[p+4].
    // Twiddle sequence W^0, W^2, W^4, W^6 repeats for the second group.
    // ═════════════════════════════════════════════════════════════

    FFT_2pt #(DW+2) s3_btfy0 ( // s3[0,4] ← (s2[0], s2[4])  W=W_16^0
        .A_re(s2_re[0]), .A_im(s2_im[0]), .B_re(s2_re[4]), .B_im(s2_im[4]),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s3_re[0]), .X_im(s3_im[0]), .Y_re(s3_re[4]), .Y_im(s3_im[4])
    );
    FFT_2pt #(DW+2) s3_btfy1 ( // s3[1,5] ← (s2[1], s2[5])  W=W_16^2
        .A_re(s2_re[1]), .A_im(s2_im[1]), .B_re(s2_re[5]), .B_im(s2_im[5]),
        .W_re(w_re[2]), .W_im(w_im[2]),
        .X_re(s3_re[1]), .X_im(s3_im[1]), .Y_re(s3_re[5]), .Y_im(s3_im[5])
    );
    FFT_2pt #(DW+2) s3_btfy2 ( // s3[2,6] ← (s2[2], s2[6])  W=W_16^4=-j
        .A_re(s2_re[2]), .A_im(s2_im[2]), .B_re(s2_re[6]), .B_im(s2_im[6]),
        .W_re(w_re[4]), .W_im(w_im[4]),
        .X_re(s3_re[2]), .X_im(s3_im[2]), .Y_re(s3_re[6]), .Y_im(s3_im[6])
    );
    FFT_2pt #(DW+2) s3_btfy3 ( // s3[3,7] ← (s2[3], s2[7])  W=W_16^6
        .A_re(s2_re[3]), .A_im(s2_im[3]), .B_re(s2_re[7]), .B_im(s2_im[7]),
        .W_re(w_re[6]), .W_im(w_im[6]),
        .X_re(s3_re[3]), .X_im(s3_im[3]), .Y_re(s3_re[7]), .Y_im(s3_im[7])
    );
    FFT_2pt #(DW+2) s3_btfy4 ( // s3[8,12] ← (s2[8], s2[12])  W=W_16^0
        .A_re(s2_re[8]),  .A_im(s2_im[8]),  .B_re(s2_re[12]), .B_im(s2_im[12]),
        .W_re(w_re[0]), .W_im(w_im[0]),
        .X_re(s3_re[8]), .X_im(s3_im[8]), .Y_re(s3_re[12]), .Y_im(s3_im[12])
    );
    FFT_2pt #(DW+2) s3_btfy5 ( // s3[9,13] ← (s2[9], s2[13])  W=W_16^2
        .A_re(s2_re[9]),  .A_im(s2_im[9]),  .B_re(s2_re[13]), .B_im(s2_im[13]),
        .W_re(w_re[2]), .W_im(w_im[2]),
        .X_re(s3_re[9]), .X_im(s3_im[9]), .Y_re(s3_re[13]), .Y_im(s3_im[13])
    );
    FFT_2pt #(DW+2) s3_btfy6 ( // s3[10,14] ← (s2[10], s2[14])  W=W_16^4=-j
        .A_re(s2_re[10]), .A_im(s2_im[10]), .B_re(s2_re[14]), .B_im(s2_im[14]),
        .W_re(w_re[4]), .W_im(w_im[4]),
        .X_re(s3_re[10]), .X_im(s3_im[10]), .Y_re(s3_re[14]), .Y_im(s3_im[14])
    );
    FFT_2pt #(DW+2) s3_btfy7 ( // s3[11,15] ← (s2[11], s2[15])  W=W_16^6
        .A_re(s2_re[11]), .A_im(s2_im[11]), .B_re(s2_re[15]), .B_im(s2_im[15]),
        .W_re(w_re[6]), .W_im(w_im[6]),
        .X_re(s3_re[11]), .X_im(s3_im[11]), .Y_re(s3_re[15]), .Y_im(s3_im[15])
    );

    // ═════════════════════════════════════════════════════════════
    // STAGE 4  (stride = 8,  W_16 twiddles: W_16^{0..7})
    //
    // Butterfly at position p takes s3[p] and s3[p+8].
    // X output to out[p], Y output to out[p+8].
    // ═════════════════════════════════════════════════════════════

    FFT_2pt #(DW+3) s4_btfy0 ( // out[0,8] ← (s3[0], s3[8])  W=W_16^0
        .A_re(s3_re[0]), .A_im(s3_im[0]), .B_re(s3_re[8]),  .B_im(s3_im[8]),
        .W_re(w_re[0]), .W_im(w_im[0]), .X_re(out_re0), .X_im(out_im0), .Y_re(out_re8),  .Y_im(out_im8)
    );
    FFT_2pt #(DW+3) s4_btfy1 ( // out[1,9] ← (s3[1], s3[9])  W=W_16^1
        .A_re(s3_re[1]), .A_im(s3_im[1]), .B_re(s3_re[9]),  .B_im(s3_im[9]),
        .W_re(w_re[1]), .W_im(w_im[1]), .X_re(out_re1), .X_im(out_im1), .Y_re(out_re9),  .Y_im(out_im9)
    );
    FFT_2pt #(DW+3) s4_btfy2 ( // out[2,10] ← (s3[2], s3[10])  W=W_16^2
        .A_re(s3_re[2]), .A_im(s3_im[2]), .B_re(s3_re[10]), .B_im(s3_im[10]),
        .W_re(w_re[2]), .W_im(w_im[2]), .X_re(out_re2), .X_im(out_im2), .Y_re(out_re10), .Y_im(out_im10)
    );
    FFT_2pt #(DW+3) s4_btfy3 ( // out[3,11] ← (s3[3], s3[11])  W=W_16^3
        .A_re(s3_re[3]), .A_im(s3_im[3]), .B_re(s3_re[11]), .B_im(s3_im[11]),
        .W_re(w_re[3]), .W_im(w_im[3]), .X_re(out_re3), .X_im(out_im3), .Y_re(out_re11), .Y_im(out_im11)
    );
    FFT_2pt #(DW+3) s4_btfy4 ( // out[4,12] ← (s3[4], s3[12])  W=W_16^4=-j
        .A_re(s3_re[4]), .A_im(s3_im[4]), .B_re(s3_re[12]), .B_im(s3_im[12]),
        .W_re(w_re[4]), .W_im(w_im[4]), .X_re(out_re4), .X_im(out_im4), .Y_re(out_re12), .Y_im(out_im12)
    );
    FFT_2pt #(DW+3) s4_btfy5 ( // out[5,13] ← (s3[5], s3[13])  W=W_16^5
        .A_re(s3_re[5]), .A_im(s3_im[5]), .B_re(s3_re[13]), .B_im(s3_im[13]),
        .W_re(w_re[5]), .W_im(w_im[5]), .X_re(out_re5), .X_im(out_im5), .Y_re(out_re13), .Y_im(out_im13)
    );
    FFT_2pt #(DW+3) s4_btfy6 ( // out[6,14] ← (s3[6], s3[14])  W=W_16^6
        .A_re(s3_re[6]), .A_im(s3_im[6]), .B_re(s3_re[14]), .B_im(s3_im[14]),
        .W_re(w_re[6]), .W_im(w_im[6]), .X_re(out_re6), .X_im(out_im6), .Y_re(out_re14), .Y_im(out_im14)
    );
    FFT_2pt #(DW+3) s4_btfy7 ( // out[7,15] ← (s3[7], s3[15])  W=W_16^7
        .A_re(s3_re[7]), .A_im(s3_im[7]), .B_re(s3_re[15]), .B_im(s3_im[15]),
        .W_re(w_re[7]), .W_im(w_im[7]), .X_re(out_re7), .X_im(out_im7), .Y_re(out_re15), .Y_im(out_im15)
    );

endmodule


// ── Testbench ────────────────────────────────────────────────────
// Compile: iverilog -g2012 -D TEST_FFT_16PT_FLAT -o sim FFT_16pt_flat.v FFT_2pt.v w_lut.v && vvp sim
`ifdef TEST_FFT_16PT_FLAT
module FFT_16pt_flat_tb;
    reg signed [15:0] in_re0, in_im0, in_re1, in_im1, in_re2, in_im2, in_re3, in_im3;
    reg signed [15:0] in_re4, in_im4, in_re5, in_im5, in_re6, in_im6, in_re7, in_im7;
    reg signed [15:0] in_re8, in_im8, in_re9, in_im9, in_re10, in_im10, in_re11, in_im11;
    reg signed [15:0] in_re12, in_im12, in_re13, in_im13, in_re14, in_im14, in_re15, in_im15;

    wire signed [19:0] out_re0, out_im0, out_re1, out_im1, out_re2, out_im2, out_re3, out_im3;
    wire signed [19:0] out_re4, out_im4, out_re5, out_im5, out_re6, out_im6, out_re7, out_im7;
    wire signed [19:0] out_re8, out_im8, out_re9, out_im9, out_re10, out_im10, out_re11, out_im11;
    wire signed [19:0] out_re12, out_im12, out_re13, out_im13, out_re14, out_im14, out_re15, out_im15;

    FFT_16pt_flat #(.DW(16)) uut (
        .in_re0(in_re0), .in_im0(in_im0), .in_re1(in_re1), .in_im1(in_im1),
        .in_re2(in_re2), .in_im2(in_im2), .in_re3(in_re3), .in_im3(in_im3),
        .in_re4(in_re4), .in_im4(in_im4), .in_re5(in_re5), .in_im5(in_im5),
        .in_re6(in_re6), .in_im6(in_im6), .in_re7(in_re7), .in_im7(in_im7),
        .in_re8(in_re8), .in_im8(in_im8), .in_re9(in_re9), .in_im9(in_im9),
        .in_re10(in_re10), .in_im10(in_im10), .in_re11(in_re11), .in_im11(in_im11),
        .in_re12(in_re12), .in_im12(in_im12), .in_re13(in_re13), .in_im13(in_im13),
        .in_re14(in_re14), .in_im14(in_im14), .in_re15(in_re15), .in_im15(in_im15),
        .out_re0(out_re0), .out_im0(out_im0), .out_re1(out_re1), .out_im1(out_im1),
        .out_re2(out_re2), .out_im2(out_im2), .out_re3(out_re3), .out_im3(out_im3),
        .out_re4(out_re4), .out_im4(out_im4), .out_re5(out_re5), .out_im5(out_im5),
        .out_re6(out_re6), .out_im6(out_im6), .out_re7(out_re7), .out_im7(out_im7),
        .out_re8(out_re8), .out_im8(out_im8), .out_re9(out_re9), .out_im9(out_im9),
        .out_re10(out_re10), .out_im10(out_im10), .out_re11(out_re11), .out_im11(out_im11),
        .out_re12(out_re12), .out_im12(out_im12), .out_re13(out_re13), .out_im13(out_im13),
        .out_re14(out_re14), .out_im14(out_im14), .out_re15(out_re15), .out_im15(out_im15)
    );

    localparam signed [15:0] POS1 =  32767;
    localparam signed [15:0] NEG1 = -32767;
    localparam signed [15:0] MONE = -32768;
    localparam signed [15:0] ZERO =      0;

    function real q15_to_real(input signed [19:0] val);
        q15_to_real = $itor(val) / 32768.0;
    endfunction

    task display_result;
        input real e0_r, e0_i, e1_r, e1_i, e2_r, e2_i, e3_r, e3_i;
        input real e4_r, e4_i, e5_r, e5_i, e6_r, e6_i, e7_r, e7_i;
        input real e8_r, e8_i, e9_r, e9_i, e10_r, e10_i, e11_r, e11_i;
        input real e12_r, e12_i, e13_r, e13_i, e14_r, e14_i, e15_r, e15_i;
        begin
            $display("    %-13s [ 0..3]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj", "expected:", e0_r, e0_i, e1_r, e1_i, e2_r, e2_i, e3_r, e3_i);
            $display("                  [ 4..7]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj", e4_r, e4_i, e5_r, e5_i, e6_r, e6_i, e7_r, e7_i);
            $display("                  [ 8..11]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj", e8_r, e8_i, e9_r, e9_i, e10_r, e10_i, e11_r, e11_i);
            $display("                  [12..15]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj", e12_r, e12_i, e13_r, e13_i, e14_r, e14_i, e15_r, e15_i);
            $display("    %-13s [ 0..3]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj", "got (float):",
                     q15_to_real(out_re0), q15_to_real(out_im0), q15_to_real(out_re1), q15_to_real(out_im1),
                     q15_to_real(out_re2), q15_to_real(out_im2), q15_to_real(out_re3), q15_to_real(out_im3));
            $display("                  [ 4..7]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj",
                     q15_to_real(out_re4), q15_to_real(out_im4), q15_to_real(out_re5), q15_to_real(out_im5),
                     q15_to_real(out_re6), q15_to_real(out_im6), q15_to_real(out_re7), q15_to_real(out_im7));
            $display("                  [ 8..11]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj",
                     q15_to_real(out_re8), q15_to_real(out_im8), q15_to_real(out_re9), q15_to_real(out_im9),
                     q15_to_real(out_re10), q15_to_real(out_im10), q15_to_real(out_re11), q15_to_real(out_im11));
            $display("                  [12..15]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj",
                     q15_to_real(out_re12), q15_to_real(out_im12), q15_to_real(out_re13), q15_to_real(out_im13),
                     q15_to_real(out_re14), q15_to_real(out_im14), q15_to_real(out_re15), q15_to_real(out_im15));
            $display("    %-13s [ 0..3]: %6d%6dj | %6d%6dj | %6d%6dj | %6d%6dj", "got (Q15):",
                     out_re0, out_im0, out_re1, out_im1, out_re2, out_im2, out_re3, out_im3);
            $display("                  [ 4..7]: %6d%6dj | %6d%6dj | %6d%6dj | %6d%6dj",
                     out_re4, out_im4, out_re5, out_im5, out_re6, out_im6, out_re7, out_im7);
            $display("                  [ 8..11]: %6d%6dj | %6d%6dj | %6d%6dj | %6d%6dj",
                     out_re8, out_im8, out_re9, out_im9, out_re10, out_im10, out_re11, out_im11);
            $display("                  [12..15]: %6d%6dj | %6d%6dj | %6d%6dj | %6d%6dj\n",
                     out_re12, out_im12, out_re13, out_im13, out_re14, out_im14, out_re15, out_im15);
        end
    endtask

    initial begin
        $dumpfile("fft_16pt_flat_wave.vcd");
        $dumpvars(0, FFT_16pt_flat_tb);

        in_re0=POS1; in_im0=ZERO; in_re1=POS1; in_im1=ZERO; in_re2=POS1; in_im2=ZERO; in_re3=POS1; in_im3=ZERO;
        in_re4=POS1; in_im4=ZERO; in_re5=POS1; in_im5=ZERO; in_re6=POS1; in_im6=ZERO; in_re7=POS1; in_im7=ZERO;
        in_re8=POS1; in_im8=ZERO; in_re9=POS1; in_im9=ZERO; in_re10=POS1; in_im10=ZERO; in_re11=POS1; in_im11=ZERO;
        in_re12=POS1; in_im12=ZERO; in_re13=POS1; in_im13=ZERO; in_re14=POS1; in_im14=ZERO; in_re15=POS1; in_im15=ZERO; #10;
        $display("\nTC1 | DC Signal: {1, 1, ..., 1}");
        display_result(16.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0,
                        0.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0,
                        0.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0,
                        0.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0);

        in_re0=POS1; in_im0=ZERO; in_re1=NEG1; in_im1=ZERO; in_re2=POS1; in_im2=ZERO; in_re3=NEG1; in_im3=ZERO;
        in_re4=POS1; in_im4=ZERO; in_re5=NEG1; in_im5=ZERO; in_re6=POS1; in_im6=ZERO; in_re7=NEG1; in_im7=ZERO;
        in_re8=POS1; in_im8=ZERO; in_re9=NEG1; in_im9=ZERO; in_re10=POS1; in_im10=ZERO; in_re11=NEG1; in_im11=ZERO;
        in_re12=POS1; in_im12=ZERO; in_re13=NEG1; in_im13=ZERO; in_re14=POS1; in_im14=ZERO; in_re15=NEG1; in_im15=ZERO; #10;
        $display("TC2 | Nyquist Signal: {1, -1, 1, -1, ...}");
        display_result(0.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0,
                        0.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0,
                       16.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0,
                        0.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0);

        in_re0=POS1; in_im0=ZERO; in_re1=ZERO; in_im1=ZERO; in_re2=ZERO; in_im2=ZERO; in_re3=ZERO; in_im3=ZERO;
        in_re4=ZERO; in_im4=ZERO; in_re5=ZERO; in_im5=ZERO; in_re6=ZERO; in_im6=ZERO; in_re7=ZERO; in_im7=ZERO;
        in_re8=ZERO; in_im8=ZERO; in_re9=ZERO; in_im9=ZERO; in_re10=ZERO; in_im10=ZERO; in_re11=ZERO; in_im11=ZERO;
        in_re12=ZERO; in_im12=ZERO; in_re13=ZERO; in_im13=ZERO; in_re14=ZERO; in_im14=ZERO; in_re15=ZERO; in_im15=ZERO; #10;
        $display("TC3 | Single Impulse: {1, 0, 0, 0, ...}");
        display_result(1.0, 0.0,  1.0, 0.0,  1.0, 0.0,  1.0, 0.0,
                        1.0, 0.0,  1.0, 0.0,  1.0, 0.0,  1.0, 0.0,
                        1.0, 0.0,  1.0, 0.0,  1.0, 0.0,  1.0, 0.0,
                        1.0, 0.0,  1.0, 0.0,  1.0, 0.0,  1.0, 0.0);

        $finish;
    end
endmodule
`endif