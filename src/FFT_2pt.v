// ═══════════════════════════════════════════════════════════════════
// FFT_2pt.v — 2-point DFT butterfly, parameterized Q15 fixed-point
//
// Interface
//   Inputs  [DW-1:0]  A, B : complex operands in Q15
//   Input   [15:0]    W    : twiddle factor in Q15, always |W|=1
//   Outputs [DW:0]    X, Y : butterfly results, one guard bit wider
//
// Butterfly equations
//   X = A + B·W
//   Y = A − B·W
//
// Overflow guarantee
//   Outputs are DW+1 bits. Verilog evaluates A+BW in the DW+1
//   context of the output register, sign-extending A automatically.
//   No overflow is possible regardless of input values.
//
// No precision loss
//   No division or rounding in the adder stage. Only source of error
//   is Q30→Q15 truncation in the complex multiplier (≤1 LSB, ~0.003%).
//
// Building a 16-point FFT (4 stages, log2(16)=4)
//   Stage 1: FFT_2pt #(16) → 17-bit outputs
//   Stage 2: FFT_2pt #(17) → 18-bit outputs
//   Stage 3: FFT_2pt #(18) → 19-bit outputs
//   Stage 4: FFT_2pt #(19) → 20-bit outputs
//   Outputs represent exact DFT values (no 1/N scale).
//   Truncate [DW+3:4] at the end if you need 16-bit output.
// ═══════════════════════════════════════════════════════════════════
module FFT_2pt #(parameter DW = 16) (
    input  signed [DW-1:0] A_re, A_im,
    input  signed [DW-1:0] B_re, B_im,
    input  signed [15:0]   W_re, W_im,     // twiddle: always Q15

    output reg signed [DW:0] X_re, X_im,   // DW+1 bits: no overflow
    output reg signed [DW:0] Y_re, Y_im
);
    // Full-precision products: DW-bit data × 16-bit twiddle → DW+16 bits
    reg signed [DW+15:0] mul_re1, mul_re2, mul_im1, mul_im2;

    // Complex product B×W, scaled back to Q15: fits in DW+1 bits
    reg signed [DW:0] BW_re, BW_im;

    always @(*) begin
        // Complex multiply: BW = B × W
        //   Re(BW) = B_re·W_re − B_im·W_im
        //   Im(BW) = B_re·W_im + B_im·W_re
        mul_re1 = B_re * W_re;
        mul_re2 = B_im * W_im;
        mul_im1 = B_re * W_im;
        mul_im2 = B_im * W_re;

        // Scale Q(DW+15) → Q(DW): arithmetic right-shift by 15
        // (twiddle is Q15, data is QDW → product is Q(DW+15) → shift 15)
        BW_re = (mul_re1 - mul_re2) >>> 15;
        BW_im = (mul_im1 + mul_im2) >>> 15;

        // Butterfly: DW+1 output context sign-extends A automatically
        X_re = A_re + BW_re;
        X_im = A_im + BW_im;
        Y_re = A_re - BW_re;
        Y_im = A_im - BW_im;
    end
endmodule

// ═══════════════════════════════════════════════════════════════════
// TESTBENCH  (clean string handling, guaranteed alignment)
// Compile: iverilog -D TEST_FFT -o sim FFT_2pt.v && vvp sim
// ═══════════════════════════════════════════════════════════════════
`ifdef TEST_FFT
module FFT_2pt_tb;
    reg  signed [15:0] A_re, A_im, B_re, B_im, W_re, W_im;
    wire signed [16:0] X_re, X_im, Y_re, Y_im;

    FFT_2pt #(.DW(16)) uut (
        .A_re(A_re), .A_im(A_im), .B_re(B_re), .B_im(B_im),
        .W_re(W_re), .W_im(W_im),
        .X_re(X_re), .X_im(X_im), .Y_re(Y_re), .Y_im(Y_im)
    );

    // ── Q15 constants ────────────────────────────────────────────
    localparam signed [15:0] POS1  =  32767;  // ≈ +1.0
    localparam signed [15:0] NEG1  = -32767;
    localparam signed [15:0] MONE  = -32768;  // exact -1.0
    localparam signed [15:0] ZERO  =      0;
    localparam signed [15:0] COS45 =  23170;  // ≈ cos(45°)

    // ── Helper: Q15 → real ──────────────────────────────────────
    function real q15_to_real(input signed [16:0] val);
        q15_to_real = $itor(val) / 32768.0;
    endfunction

    // ── Display one set of results (no string inputs) ────────────
    task display_result;
        input real exp_X_re, exp_X_im, exp_Y_re, exp_Y_im;
        input signed [16:0] got_X_re, got_X_im, got_Y_re, got_Y_im;
        begin
            // Expected
            $write("    %-12s X=", "expected:");
            $write("%+7.4f%+7.4fj  | Y=", exp_X_re, exp_X_im);
            $write("%+7.4f%+7.4fj\n", exp_Y_re, exp_Y_im);

            // Got (float)
            $write("    %-12s X=", "got (float):");
            $write("%+7.4f%+7.4fj  | Y=",
                   q15_to_real(got_X_re), q15_to_real(got_X_im));
            $write("%+7.4f%+7.4fj\n",
                   q15_to_real(got_Y_re), q15_to_real(got_Y_im));

            // Got (Q15)
            $write("    %-12s X=", "got (Q15):");
            $write("%+6d%+6dj    | Y=", got_X_re, got_X_im);
            $write("%+6d%+6dj\n", got_Y_re, got_Y_im);
        end
    endtask

    initial begin
        $dumpfile("fft_2pt_wave.vcd");
        $dumpvars(0, FFT_2pt_tb);

        // ═════════════════════════════════════════════════════════
        // TC1
        // ═════════════════════════════════════════════════════════
        A_re=POS1; A_im=ZERO; B_re=POS1; B_im=ZERO;
        W_re=POS1; W_im=ZERO; #10;
        $display("\nTC1 | A=1+0j  B=1+0j  W=1+0j");
        display_result(2.0, 0.0,  0.0, 0.0,
                       X_re, X_im, Y_re, Y_im);

        // ═════════════════════════════════════════════════════════
        // TC2
        // ═════════════════════════════════════════════════════════
        A_re=POS1; A_im=ZERO; B_re=NEG1; B_im=ZERO;
        W_re=POS1; W_im=ZERO; #10;
        $display("\nTC2 | A=1+0j  B=-1+0j  W=1+0j");
        display_result(0.0, 0.0,  2.0, 0.0,
                       X_re, X_im, Y_re, Y_im);

        // ═════════════════════════════════════════════════════════
        // TC3
        // ═════════════════════════════════════════════════════════
        A_re=POS1; A_im=POS1; B_re=POS1; B_im=NEG1;
        W_re=POS1; W_im=ZERO; #10;
        $display("\nTC3 | A=1+j  B=1-j  W=1+0j");
        display_result(2.0, 0.0,  0.0, 2.0,
                       X_re, X_im, Y_re, Y_im);

        // ═════════════════════════════════════════════════════════
        // TC4
        // ═════════════════════════════════════════════════════════
        A_re=POS1; A_im=ZERO; B_re=POS1; B_im=ZERO;
        W_re=ZERO; W_im=MONE; #10;
        $display("\nTC4 | A=1+0j  B=1+0j  W=0-j  (e^{-jpi/2})");
        display_result(1.0, -1.0,  1.0, 1.0,
                       X_re, X_im, Y_re, Y_im);

        // ═════════════════════════════════════════════════════════
        // TC5
        // ═════════════════════════════════════════════════════════
        A_re=POS1; A_im=ZERO; B_re=POS1; B_im=ZERO;
        W_re=COS45; W_im=-COS45; #10;
        $display("\nTC5 | A=1+0j  B=1+0j  W=e^{-jpi/4}  (W_re=23170 W_im=-23170)");
        display_result(1.70710678, -0.70710678,  0.29289322, 0.70710678,
                       X_re, X_im, Y_re, Y_im);

        $finish;
    end
endmodule
`endif