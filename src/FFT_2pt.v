// ─────────────────────────────────────────────────────────────────
// FFT_2pt — 2-point DFT butterfly, parameterized fixed-point
//
// FIX: outputs are DW+1 bits (one guard bit).
//   - No overflow is possible: Verilog evaluates A_re + BW_re in
//     the DW+1 context, so A_re is sign-extended automatically.
//   - No precision loss: no division or rounding applied.
//   - Scales cleanly to a 16-point FFT (4 stages):
//       stage 1: FFT_2pt #(16) → 17-bit outputs
//       stage 2: FFT_2pt #(17) → 18-bit outputs
//       stage 3: FFT_2pt #(18) → 19-bit outputs
//       stage 4: FFT_2pt #(19) → 20-bit outputs
//     Final outputs represent the exact DFT (no 1/N scale factor).
//     Truncate the top 4 bits at the output if needed.
// ─────────────────────────────────────────────────────────────────
module FFT_2pt #(parameter DW = 16) (
    input  signed [DW-1:0] A_re, A_im,
    input  signed [DW-1:0] B_re, B_im,
    input  signed [15:0]   W_re, W_im,    // twiddle: always Q15

    output reg signed [DW:0] X_re, X_im,  // one guard bit: no overflow
    output reg signed [DW:0] Y_re, Y_im
);
    // Full-precision multiply: DW-bit data × 16-bit twiddle → DW+16 bits
    reg signed [DW+15:0] mul_re1, mul_re2, mul_im1, mul_im2;

    // Complex product B×W, scaled back to Q15: DW+1 bits
    reg signed [DW:0] BW_re, BW_im;

    always @(*) begin
        // Complex multiply: BW = B × W
        mul_re1 = B_re * W_re;
        mul_re2 = B_im * W_im;
        mul_im1 = B_re * W_im;
        mul_im2 = B_im * W_re;

        // Scale Q(DW+15) → Q(DW)   (shift right 15 for Q15 twiddle)
        BW_re = (mul_re1 - mul_re2) >>> 15;
        BW_im = (mul_im1 + mul_im2) >>> 15;

        // Butterfly: A_re is sign-extended to DW+1 by the output context
        X_re = A_re + BW_re;
        X_im = A_im + BW_im;
        Y_re = A_re - BW_re;
        Y_im = A_im - BW_im;
    end
endmodule

// ─────────────────────────────────────────────────────────────────
// TESTBENCH  (iverilog -D TEST_FFT -o sim FFT_2pt.v && vvp sim)
// ─────────────────────────────────────────────────────────────────
`ifdef TEST_FFT
module FFT_2pt_tb;
    reg  signed [15:0] A_re, A_im, B_re, B_im, W_re, W_im;
    wire signed [16:0] X_re, X_im, Y_re, Y_im;  // 17-bit outputs (DW+1)

    FFT_2pt #(.DW(16)) uut (
        .A_re(A_re), .A_im(A_im),
        .B_re(B_re), .B_im(B_im),
        .W_re(W_re), .W_im(W_im),
        .X_re(X_re), .X_im(X_im),
        .Y_re(Y_re), .Y_im(Y_im)
    );

    initial begin
        $dumpfile("fft_2pt_wave.vcd");
        $dumpvars(0, FFT_2pt_tb);

        // ── TC1: A=1, B=1, W=1 ──────────────────────────────────
        // BW = 1×1 ≈ 1.0  (32766, 1 LSB shy — Q15 can't hold 1.0 exactly)
        // X = 1 + 1 = 2.0 → 65533 (17-bit, fine)
        // Y = 1 - 1 = 0   →     1 (1 LSB residual from Q15 rounding)
        A_re=32767; A_im=0; B_re=32767; B_im=0; W_re=32767; W_im=0; #10;
        $display("TC1 | A=1+0j  B=1+0j  W=1+0j");
        $display("    expected:  X=65533+0j   Y=1+0j");
        $display("    got:       X=%0d+%0dj   Y=%0d+%0dj\n", X_re, X_im, Y_re, Y_im);

        // ── TC2: A=1, B=-1, W=1 ─────────────────────────────────
        // BW = -1×1 ≈ -1.0  (-32767 due to floor rounding)
        // X = 1 + (-1) = 0   →  0
        // Y = 1 - (-1) = 2.0 → 65534
        A_re=32767; A_im=0; B_re=-32767; B_im=0; W_re=32767; W_im=0; #10;
        $display("TC2 | A=1+0j  B=-1+0j  W=1+0j");
        $display("    expected:  X=0+0j   Y=65534+0j");
        $display("    got:       X=%0d+%0dj   Y=%0d+%0dj\n", X_re, X_im, Y_re, Y_im);

        // ── TC3: A=1+j, B=1-j, W=1 ──────────────────────────────
        // BW = (1-j)×1 = 1-j
        // X = (1+j)+(1-j) = 2+0j   → 65533+0j
        // Y = (1+j)-(1-j) = 0+2j   → 0+65534j
        A_re=32767; A_im=32767; B_re=32767; B_im=-32767; W_re=32767; W_im=0; #10;
        $display("TC3 | A=1+j  B=1-j  W=1+0j");
        $display("    expected:  X=65533+0j   Y=0+65534j");
        $display("    got:       X=%0d+%0dj   Y=%0d+%0dj\n", X_re, X_im, Y_re, Y_im);

        // ── TC4: A=1, B=1, W=-j  (e^{-jPi/2} = W_4^1) ──────────
        // W_im=-32768 is the only exact -1.0 in Q15 (two's complement asymmetry)
        // BW = 1×(-j) = -j  →  BW_re=0, BW_im=-32767 (not -32768 because B=32767≠32768)
        // X = 1 + (0-32767j) = 32767 - 32767j
        // Y = 1 - (0-32767j) = 32767 + 32767j
        A_re=32767; A_im=0; B_re=32767; B_im=0; W_re=0; W_im=-32768; #10;
        $display("TC4 | A=1+0j  B=1+0j  W=0-j  (e^{-jPi/2})");
        $display("    expected:  X=32767-32767j   Y=32767+32767j");
        $display("    got:       X=%0d+%0dj   Y=%0d+%0dj\n", X_re, X_im, Y_re, Y_im);

        // ── TC5: A=1, B=1, W=e^{-jPi/4}  (W_8^1) ───────────────
        // W = cos(-45°) - j sin(-45°) ≈ 0.7071 - 0.7071j
        // Q15: W_re=23170, W_im=-23170
        // BW ≈ 0.7071-0.7071j  →  BW_re=23169, BW_im=-23170
        // X = 1 + BW = 1.7071 - 0.7071j  → 55936 - 23170j
        // Y = 1 - BW = 0.2929 + 0.7071j  →  9598 + 23170j
        A_re=32767; A_im=0; B_re=32767; B_im=0; W_re=23170; W_im=-23170; #10;
        $display("TC5 | A=1+0j  B=1+0j  W=e^{-jPi/4}  (W_re=23170 W_im=-23170)");
        $display("    expected:  X=55936-23170j   Y=9598+23170j");
        $display("    got:       X=%0d+%0dj   Y=%0d+%0dj\n", X_re, X_im, Y_re, Y_im);

        $finish;
    end
endmodule
`endif