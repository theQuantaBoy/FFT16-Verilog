// ═══════════════════════════════════════════════════════════════════
// FFT_4pt.v — structural 4-point FFT (Radix-2 DIT)
//
// Two stages of 2 FFT_2pt butterflies each.
// Input: DW bits. Output: DW+2 bits. Requires: FFT_2pt, w_lut
// ═══════════════════════════════════════════════════════════════════
module FFT_4pt #(parameter DW = 16) (
    input  signed [DW-1:0] in_re0, in_im0,
    input  signed [DW-1:0] in_re1, in_im1,
    input  signed [DW-1:0] in_re2, in_im2,
    input  signed [DW-1:0] in_re3, in_im3,

    // Final outputs are 2 bits wider than input (2 stages of growth)
    output signed [DW+1:0] out_re0, out_im0,
    output signed [DW+1:0] out_re1, out_im1,
    output signed [DW+1:0] out_re2, out_im2,
    output signed [DW+1:0] out_re3, out_im3
);

    // ── Twiddle Factors (W_16^0 and W_16^4) ──────────────────────
    wire signed [15:0] w0_re, w0_im, w4_re, w4_im;
    
    w_lut lut0 (.addr(3'd0), .W_re(w0_re), .W_im(w0_im));
    w_lut lut4 (.addr(3'd4), .W_re(w4_re), .W_im(w4_im));

    // ── Stage 1 Intermediate Wires (DW+1 bits) ───────────────────
    wire signed [DW:0] s1_re0, s1_im0, s1_re1, s1_im1;
    wire signed [DW:0] s1_re2, s1_im2, s1_re3, s1_im3;

    // ═════════════════════════════════════════════════════════════
    // STAGE 1 (Stride = 1)
    // ═════════════════════════════════════════════════════════════
    // Butterfly 0: Processes lines 0 and 1 (Inputs 0 and 2 due to bit-reversal)
    FFT_2pt #(DW) s1_btfy0 (
        .A_re(in_re0), .A_im(in_im0),
        .B_re(in_re2), .B_im(in_im2),
        .W_re(w0_re),  .W_im(w0_im),
        .X_re(s1_re0), .X_im(s1_im0),
        .Y_re(s1_re1), .Y_im(s1_im1)
    );

    // Butterfly 1: Processes lines 2 and 3 (Inputs 1 and 3 due to bit-reversal)
    FFT_2pt #(DW) s1_btfy1 (
        .A_re(in_re1), .A_im(in_im1),
        .B_re(in_re3), .B_im(in_im3),
        .W_re(w0_re),  .W_im(w0_im),
        .X_re(s1_re2), .X_im(s1_im2),
        .Y_re(s1_re3), .Y_im(s1_im3)
    );

    // ═════════════════════════════════════════════════════════════
    // STAGE 2 (Stride = 2)
    // ═════════════════════════════════════════════════════════════
    // Butterfly 2: Processes lines 0 and 2 
    FFT_2pt #(DW+1) s2_btfy0 (
        .A_re(s1_re0),  .A_im(s1_im0),
        .B_re(s1_re2),  .B_im(s1_im2),
        .W_re(w0_re),   .W_im(w0_im),
        .X_re(out_re0), .X_im(out_im0),
        .Y_re(out_re2), .Y_im(out_im2)
    );

    // Butterfly 3: Processes lines 1 and 3 
    FFT_2pt #(DW+1) s2_btfy1 (
        .A_re(s1_re1),  .A_im(s1_im1),
        .B_re(s1_re3),  .B_im(s1_im3),
        .W_re(w4_re),   .W_im(w4_im),
        .X_re(out_re1), .X_im(out_im1),
        .Y_re(out_re3), .Y_im(out_im3)
    );

endmodule


// ── Testbench ─────────────────────────────────────────────────────────────────────────────────────
// Compile: iverilog -D TEST_FFT_4PT -o ../build/sim FFT_4pt.v FFT_2pt.v w_lut.v && vvp ../build/sim
// ──────────────────────────────────────────────────────────────────────────────────────────────────
`ifdef TEST_FFT_4PT
module FFT_4pt_tb;
    // 16-bit inputs
    reg signed [15:0] in_re0, in_im0, in_re1, in_im1;
    reg signed [15:0] in_re2, in_im2, in_re3, in_im3;
    
    // 18-bit outputs (DW=16 -> Stage 1=17 -> Stage 2=18)
    wire signed [17:0] out_re0, out_im0, out_re1, out_im1;
    wire signed [17:0] out_re2, out_im2, out_re3, out_im3;

    FFT_4pt #(.DW(16)) uut (
        .in_re0(in_re0), .in_im0(in_im0), .in_re1(in_re1), .in_im1(in_im1),
        .in_re2(in_re2), .in_im2(in_im2), .in_re3(in_re3), .in_im3(in_im3),
        .out_re0(out_re0), .out_im0(out_im0), .out_re1(out_re1), .out_im1(out_im1),
        .out_re2(out_re2), .out_im2(out_im2), .out_re3(out_re3), .out_im3(out_im3)
    );

    // ── Q15 constants ────────────────────────────────────────────
    localparam signed [15:0] POS1 =  32767;  // ≈ +1.0
    localparam signed [15:0] NEG1 = -32767;
    localparam signed [15:0] ZERO =      0;

    // ── Helper: Q15 → real (Scaled for 18-bit register) ──────────
    function real q15_to_real(input signed [17:0] val);
        q15_to_real = $itor(val) / 32768.0;
    endfunction

    // ── Display routine for 4 points ─────────────────────────────
    task display_result;
        input real e0_r, e0_i, e1_r, e1_i, e2_r, e2_i, e3_r, e3_i;
        begin
            $display("    %-13s [0]: %+6.2f%+6.2fj | [1]: %+6.2f%+6.2fj | [2]: %+6.2f%+6.2fj | [3]: %+6.2f%+6.2fj", 
                     "expected:", e0_r, e0_i, e1_r, e1_i, e2_r, e2_i, e3_r, e3_i);
                     
            $display("    %-13s [0]: %+6.2f%+6.2fj | [1]: %+6.2f%+6.2fj | [2]: %+6.2f%+6.2fj | [3]: %+6.2f%+6.2fj", 
                     "got (float):", 
                     q15_to_real(out_re0), q15_to_real(out_im0),
                     q15_to_real(out_re1), q15_to_real(out_im1),
                     q15_to_real(out_re2), q15_to_real(out_im2),
                     q15_to_real(out_re3), q15_to_real(out_im3));
                     
            $display("    %-13s [0]: %6d%6dj | [1]: %6d%6dj | [2]: %6d%6dj | [3]: %6d%6dj\n", 
                     "got (Q15):", 
                     out_re0, out_im0, out_re1, out_im1, 
                     out_re2, out_im2, out_re3, out_im3);
        end
    endtask

    initial begin
        $dumpfile("fft_4pt_wave.vcd");
        $dumpvars(0, FFT_4pt_tb);

        // ═════════════════════════════════════════════════════════
        // TC1: DC Signal (All 1s)
        // Expected: Bin 0 gets everything (4.0), rest are 0
        // ═════════════════════════════════════════════════════════
        in_re0=POS1; in_im0=ZERO; in_re1=POS1; in_im1=ZERO;
        in_re2=POS1; in_im2=ZERO; in_re3=POS1; in_im3=ZERO; #10;
        $display("\nTC1 | DC Signal: {1, 1, 1, 1}");
        display_result(4.0, 0.0,  0.0, 0.0,  0.0, 0.0,  0.0, 0.0);

        // ═════════════════════════════════════════════════════════
        // TC2: Nyquist Frequency (Alternating 1, -1, 1, -1)
        // Expected: Bin 2 gets everything (4.0), rest are 0
        // ═════════════════════════════════════════════════════════
        in_re0=POS1; in_im0=ZERO; in_re1=NEG1; in_im1=ZERO;
        in_re2=POS1; in_im2=ZERO; in_re3=NEG1; in_im3=ZERO; #10;
        $display("TC2 | Nyquist Signal: {1, -1, 1, -1}");
        display_result(0.0, 0.0,  0.0, 0.0,  4.0, 0.0,  0.0, 0.0);

        // ═════════════════════════════════════════════════════════
        // TC3: Single Impulse (1, 0, 0, 0)
        // Expected: All bins excite equally (1.0)
        // ═════════════════════════════════════════════════════════
        in_re0=POS1; in_im0=ZERO; in_re1=ZERO; in_im1=ZERO;
        in_re2=ZERO; in_im2=ZERO; in_re3=ZERO; in_im3=ZERO; #10;
        $display("TC3 | Single Impulse: {1, 0, 0, 0}");
        display_result(1.0, 0.0,  1.0, 0.0,  1.0, 0.0,  1.0, 0.0);

        $finish;
    end
endmodule
`endif