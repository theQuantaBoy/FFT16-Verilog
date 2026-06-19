// ═══════════════════════════════════════════════════════════════════
// FFT_8pt.v — structural 8-point FFT (Radix-2 DIT)
//
// Two FFT_4pt sub-FFTs (even/odd) + 4 final butterflies.
// Input: DW bits. Output: DW+3 bits. Requires: FFT_2pt, FFT_4pt, w_lut
// ═══════════════════════════════════════════════════════════════════
module FFT_8pt #(parameter DW = 16) (
    input  signed [DW-1:0] in_re0, in_im0,
    input  signed [DW-1:0] in_re1, in_im1,
    input  signed [DW-1:0] in_re2, in_im2,
    input  signed [DW-1:0] in_re3, in_im3,
    input  signed [DW-1:0] in_re4, in_im4,
    input  signed [DW-1:0] in_re5, in_im5,
    input  signed [DW-1:0] in_re6, in_im6,
    input  signed [DW-1:0] in_re7, in_im7,

    // Final outputs grow by 3 bits across 3 hierarchical stages
    output signed [DW+2:0] out_re0, out_im0,
    output signed [DW+2:0] out_re1, out_im1,
    output signed [DW+2:0] out_re2, out_im2,
    output signed [DW+2:0] out_re3, out_im3,
    output signed [DW+2:0] out_re4, out_im4,
    output signed [DW+2:0] out_re5, out_im5,
    output signed [DW+2:0] out_re6, out_im6,
    output signed [DW+2:0] out_re7, out_im7
);

    // ── Stage 3 Twiddle Factors (W_16^0, W_16^2, W_16^4, W_16^6) ──
    wire signed [15:0] w0_re, w0_im, w2_re, w2_im;
    wire signed [15:0] w4_re, w4_im, w6_re, w6_im;
    
    w_lut lut0 (.addr(3'd0), .W_re(w0_re), .W_im(w0_im));
    w_lut lut2 (.addr(3'd2), .W_re(w2_re), .W_im(w2_im));
    w_lut lut4 (.addr(3'd4), .W_re(w4_re), .W_im(w4_im));
    w_lut lut6 (.addr(3'd6), .W_re(w6_re), .W_im(w6_im));

    // ── Intermediate Wires from Stage 2 (DW+2 bits wide) ─────────
    wire signed [DW+1:0] s2_re_ev0, s2_im_ev0, s2_re_ev1, s2_im_ev1;
    wire signed [DW+1:0] s2_re_ev2, s2_im_ev2, s2_re_ev3, s2_im_ev3;
    
    wire signed [DW+1:0] s2_re_od0, s2_im_od0, s2_re_od1, s2_im_od1;
    wire signed [DW+1:0] s2_re_od2, s2_im_od2, s2_re_od3, s2_im_od3;

    // ═════════════════════════════════════════════════════════════
    // STAGES 1 & 2: Process Even and Odd Sub-arrays via FFT_4pt
    // ═════════════════════════════════════════════════════════════
    
    // Even Sub-array Engine (Processes indices 0, 2, 4, 6)
    FFT_4pt #(DW) fft_even (
        .in_re0(in_re0), .in_im0(in_im0),
        .in_re1(in_re2), .in_im1(in_im2),
        .in_re2(in_re4), .in_im2(in_im4),
        .in_re3(in_re6), .in_im3(in_im6),
        
        .out_re0(s2_re_ev0), .out_im0(s2_im_ev0),
        .out_re1(s2_re_ev1), .out_im1(s2_im_ev1),
        .out_re2(s2_re_ev2), .out_im2(s2_im_ev2),
        .out_re3(s2_re_ev3), .out_im3(s2_im_ev3)
    );

    // Odd Sub-array Engine (Processes indices 1, 3, 5, 7)
    FFT_4pt #(DW) fft_odd (
        .in_re0(in_re1), .in_im0(in_im1),
        .in_re1(in_re3), .in_im1(in_im3),
        .in_re2(in_re5), .in_im2(in_im5),
        .in_re3(in_re7), .in_im3(in_im7),
        
        .out_re0(s2_re_od0), .out_im0(s2_im_od0),
        .out_re1(s2_re_od1), .out_im1(s2_im_od1),
        .out_re2(s2_re_od2), .out_im2(s2_im_od2),
        .out_re3(s2_re_od3), .out_im3(s2_im_od3)
    );

    // ═════════════════════════════════════════════════════════════
    // STAGE 3: Final Butterfly Merge Layer (Stride = 4)
    // ═════════════════════════════════════════════════════════════
    
    // Butterfly 0: Combines components at index offset 0 and 4
    FFT_2pt #(DW+2) s3_btfy0 (
        .A_re(s2_re_ev0),  .A_im(s2_im_ev0),
        .B_re(s2_re_od0),  .B_im(s2_im_od0),
        .W_re(w0_re),     .W_im(w0_im),
        .X_re(out_re0),   .X_im(out_im0),
        .Y_re(out_re4),   .Y_im(out_im4)
    );

    // Butterfly 1: Combines components at index offset 1 and 5
    FFT_2pt #(DW+2) s3_btfy1 (
        .A_re(s2_re_ev1),  .A_im(s2_im_ev1),
        .B_re(s2_re_od1),  .B_im(s2_im_od1),
        .W_re(w2_re),     .W_im(w2_im),
        .X_re(out_re1),   .X_im(out_im1),
        .Y_re(out_re5),   .Y_im(out_im5)
    );

    // Butterfly 2: Combines components at index offset 2 and 6
    FFT_2pt #(DW+2) s3_btfy2 (
        .A_re(s2_re_ev2),  .A_im(s2_im_ev2),
        .B_re(s2_re_od2),  .B_im(s2_im_od2),
        .W_re(w4_re),     .W_im(w4_im),
        .X_re(out_re2),   .X_im(out_im2),
        .Y_re(out_re6),   .Y_im(out_im6)
    );

    // Butterfly 3: Combines components at index offset 3 and 7
    FFT_2pt #(DW+2) s3_btfy3 (
        .A_re(s2_re_ev3),  .A_im(s2_im_ev3),
        .B_re(s2_re_od3),  .B_im(s2_im_od3),
        .W_re(w6_re),     .W_im(w6_im),
        .X_re(out_re3),   .X_im(out_im3),
        .Y_re(out_re7),   .Y_im(out_im7)
    );

endmodule


// ── Testbench ─────────────────────────────────────────────────────────────────────────────────────────
// Compile: iverilog -D TEST_FFT_8PT -o build/sim FFT_8pt.v FFT_4pt.v FFT_2pt.v w_lut.v && vvp build/sim
// ──────────────────────────────────────────────────────────────────────────────────────────────────────
`ifdef TEST_FFT_8PT
module FFT_8pt_tb;
    reg signed [15:0] in_re0, in_im0, in_re1, in_im1, in_re2, in_im2, in_re3, in_im3;
    reg signed [15:0] in_re4, in_im4, in_re5, in_im5, in_re6, in_im6, in_re7, in_im7;
    
    // 19-bit outputs (DW=16 -> Stage 1=17 -> Stage 2=18 -> Stage 3=19)
    wire signed [18:0] out_re0, out_im0, out_re1, out_im1, out_re2, out_im2, out_re3, out_im3;
    wire signed [18:0] out_re4, out_im4, out_re5, out_im5, out_re6, out_im6, out_re7, out_im7;

    FFT_8pt #(.DW(16)) uut (
        .in_re0(in_re0), .in_im0(in_im0), .in_re1(in_re1), .in_im1(in_im1),
        .in_re2(in_re2), .in_im2(in_im2), .in_re3(in_re3), .in_im3(in_im3),
        .in_re4(in_re4), .in_im4(in_im4), .in_re5(in_re5), .in_im5(in_im5),
        .in_re6(in_re6), .in_im6(in_im6), .in_re7(in_re7), .in_im7(in_im7),
        
        .out_re0(out_re0), .out_im0(out_im0), .out_re1(out_re1), .out_im1(out_im1),
        .out_re2(out_re2), .out_im2(out_im2), .out_re3(out_re3), .out_im3(out_im3),
        .out_re4(out_re4), .out_im4(out_im4), .out_re5(out_re5), .out_im5(out_im5),
        .out_re6(out_re6), .out_im6(out_im6), .out_re7(out_re7), .out_im7(out_im7)
    );

    localparam signed [15:0] POS1 =  32767; // ≈ +1.0
    localparam signed [15:0] NEG1 = -32767; // ≈ -1.0
    localparam signed [15:0] ZERO =      0;

    function real q15_to_real(input signed [18:0] val);
        q15_to_real = $itor(val) / 32768.0;
    endfunction

    task display_result;
        input real e0_r, e0_i, e1_r, e1_i, e2_r, e2_i, e3_r, e3_i;
        input real e4_r, e4_i, e5_r, e5_i, e6_r, e6_i, e7_r, e7_i;
        begin
            $display("    %-13s [0..3]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj", "expected:", e0_r, e0_i, e1_r, e1_i, e2_r, e2_i, e3_r, e3_i);
            $display("                  [4..7]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj", e4_r, e4_i, e5_r, e5_i, e6_r, e6_i, e7_r, e7_i);
                     
            $display("    %-13s [0..3]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj", "got (float):", 
                     q15_to_real(out_re0), q15_to_real(out_im0), q15_to_real(out_re1), q15_to_real(out_im1),
                     q15_to_real(out_re2), q15_to_real(out_im2), q15_to_real(out_re3), q15_to_real(out_im3));
            $display("                  [4..7]: %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj | %+6.2f%+6.2fj", 
                     q15_to_real(out_re4), q15_to_real(out_im4), q15_to_real(out_re5), q15_to_real(out_im5),
                     q15_to_real(out_re6), q15_to_real(out_im6), q15_to_real(out_re7), q15_to_real(out_im7));
                     
            $display("    %-13s [0..3]: %6d%6dj | %6d%6dj | %6d%6dj | %6d%6dj", "got (Q15):", 
                     out_re0, out_im0, out_re1, out_im1, out_re2, out_im2, out_re3, out_im3);
            $display("                  [4..7]: %6d%6dj | %6d%6dj | %6d%6dj | %6d%6dj\n", 
                     out_re4, out_im4, out_re5, out_im5, out_re6, out_im6, out_re7, out_im7);
        end
    endtask

    initial begin
        $dumpfile("fft_8pt_wave.vcd");
        $dumpvars(0, FFT_8pt_tb);

        // ═════════════════════════════════════════════════════════
        // TC1: DC Signal (All 1s)
        // Expected: Bin 0 accumulates total size (8.0), rest are 0
        // ═════════════════════════════════════════════════════════
        in_re0=POS1; in_im0=ZERO; in_re1=POS1; in_im1=ZERO;
        in_re2=POS1; in_im2=ZERO; in_re3=POS1; in_im3=ZERO;
        in_re4=POS1; in_im4=ZERO; in_re5=POS1; in_im5=ZERO;
        in_re6=POS1; in_im6=ZERO; in_re7=POS1; in_im7=ZERO; #10;
        $display("\nTC1 | DC Signal: {1, 1, 1, 1, 1, 1, 1, 1}");
        display_result(8.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0,
                       0.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0);

        // ═════════════════════════════════════════════════════════
        // TC2: Nyquist Frequency (Alternating 1, -1, 1, -1...)
        // Expected: Bin 4 captures everything (8.0), rest are 0
        // ═════════════════════════════════════════════════════════
        in_re0=POS1; in_im0=ZERO; in_re1=NEG1; in_im1=ZERO;
        in_re2=POS1; in_im2=ZERO; in_re3=NEG1; in_im3=ZERO;
        in_re4=POS1; in_im4=ZERO; in_re5=NEG1; in_im5=ZERO;
        in_re6=POS1; in_im6=ZERO; in_re7=NEG1; in_im7=ZERO; #10;
        $display("TC2 | Nyquist Signal: {1, -1, 1, -1, 1, -1, 1, -1}");
        display_result(0.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0,
                       8.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0);

        // ═════════════════════════════════════════════════════════
        // TC3: Single Impulse (1, 0, 0, 0, 0, 0, 0, 0)
        // Expected: All bins excite uniformly to 1.0
        // ═════════════════════════════════════════════════════════
        in_re0=POS1; in_im0=ZERO; in_re1=ZERO; in_im1=ZERO;
        in_re2=ZERO; in_im2=ZERO; in_re3=ZERO; in_im3=ZERO;
        in_re4=ZERO; in_im4=ZERO; in_re5=ZERO; in_im5=ZERO;
        in_re6=ZERO; in_im6=ZERO; in_re7=ZERO; in_im7=ZERO; #10;
        $display("TC3 | Single Impulse: {1, 0, 0, 0, 0, 0, 0, 0}");
        display_result(1.0, 0.0,  1.0, 0.0,  1.0, 0.0,  1.0, 0.0,
                       1.0, 0.0,  1.0, 0.0,  1.0, 0.0,  1.0, 0.0);

        $finish;
    end
endmodule
`endif