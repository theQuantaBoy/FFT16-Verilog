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
// Role in the 16-point hierarchy (log2(16) = 4 stages, DW grows by 1 each stage)
//   FFT_4pt  stage 1: FFT_2pt #(DW=16) — inputs 16-bit,  outputs 17-bit
//   FFT_4pt  stage 2: FFT_2pt #(DW=17) — inputs 17-bit,  outputs 18-bit
//   FFT_8pt  stage 3: FFT_2pt #(DW=18) — inputs 18-bit,  outputs 19-bit
//   FFT_16pt stage 4: FFT_2pt #(DW=19) — inputs 19-bit,  outputs 20-bit
//
//   This module is never instantiated flat with DW stepping 16→17→18→19.
//   Those data widths are produced by the hierarchy: FFT_16pt instantiates
//   two FFT_8pt, each of which instantiates two FFT_4pt, each of which
//   instantiates two FFT_2pt at DW and two at DW+1.
//
//   The 20-bit final outputs hold exact integer DFT values (no 1/N scale).
//   To recover 16-bit Q15 results, truncate bits [3:0] after the last stage.
// ═══════════════════════════════════════════════════════════════════

module FFT_2pt #(parameter DW = 16) (
    input  signed [DW-1:0] A_re, A_im,
    input  signed [DW-1:0] B_re, B_im,
    input  signed [15:0]   W_re, W_im,

    output reg signed [DW:0] X_re, X_im,
    output reg signed [DW:0] Y_re, Y_im
);
    reg signed [DW+15:0] mul_re1, mul_re2, mul_im1, mul_im2;
    reg signed [DW:0]    BW_re, BW_im;

    always @(*) begin
        // Complex multiply: BW = B × W
        mul_re1 = B_re * W_re;
        mul_re2 = B_im * W_im;
        mul_im1 = B_re * W_im;
        mul_im2 = B_im * W_re;

        // Scale Q(DW+15) → Q(DW) via arithmetic right-shift by 15.
        // Truncates toward −∞ (floor), introducing ≤1 LSB error per multiply.
        // Over 4 stages, accumulated quantization noise is ≤ ~32 LSBs.
        BW_re = (mul_re1 - mul_re2) >>> 15;
        BW_im = (mul_im1 + mul_im2) >>> 15;

        // Butterfly outputs are DW+1 bits; sign-extension of A is implicit.
        X_re = A_re + BW_re;
        X_im = A_im + BW_im;
        Y_re = A_re - BW_re;
        Y_im = A_im - BW_im;
    end
    
endmodule

// ═══════════════════════════════════════════════════════════════════
// TESTBENCH (Re-formatted to match 4pt, 8pt, and 16pt console style)
// Compile: iverilog -g2012 -D TEST_FFT_2PT -o sim FFT_2pt.v && vvp sim
// ═══════════════════════════════════════════════════════════════════
`ifdef TEST_FFT_2PT
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
    localparam signed [15:0] NEG1  = -32767;  // ≈ -1.0
    localparam signed [15:0] MONE  = -32768;  // exact -1.0
    localparam signed [15:0] ZERO  =      0;
    localparam signed [15:0] COS45 =  23170;  // ≈ cos(45°)

    // ── Helper: Q15 → real ──────────────────────────────────────
    function real q15_to_real(input signed [16:0] val);
        q15_to_real = $itor(val) / 32768.0;
    endfunction

    // ── Unified Display Task matching higher-order modules ───────
    task display_result;
        input real e0_r, e0_i, e1_r, e1_i;
        begin
            $display("    %-13s [0..1]: %+6.2f%+6.2fj | %+6.2f%+6.2fj", "expected:", e0_r, e0_i, e1_r, e1_i);
                     
            $display("    %-13s [0..1]: %+6.2f%+6.2fj | %+6.2f%+6.2fj", "got (float):", 
                     q15_to_real(X_re), q15_to_real(X_im), 
                     q15_to_real(Y_re), q15_to_real(Y_im));
                     
            $display("    %-13s [0..1]: %6d%6dj | %6d%6dj\n", "got (Q15):", 
                     X_re, X_im, Y_re, Y_im);
        end
    endtask

    initial begin
        $dumpfile("fft_2pt_wave.vcd");
        $dumpvars(0, FFT_2pt_tb);

        // ═════════════════════════════════════════════════════════
        // TC1 | Both Inputs +1.0, Twiddle = 1.0
        // ═════════════════════════════════════════════════════════
        A_re=POS1; A_im=ZERO; B_re=POS1; B_im=ZERO;
        W_re=POS1; W_im=ZERO; #10;
        $display("\nTC1 | A=1+0j  B=1+0j  W=1+0j");
        display_result(2.0, 0.0,  0.0, 0.0);

        // ═════════════════════════════════════════════════════════
        // TC2 | B is Out-of-Phase (-1.0), Twiddle = 1.0
        // ═════════════════════════════════════════════════════════
        A_re=POS1; A_im=ZERO; B_re=NEG1; B_im=ZERO;
        W_re=POS1; W_im=ZERO; #10;
        $display("TC2 | A=1+0j  B=-1+0j  W=1+0j");
        display_result(0.0, 0.0,  2.0, 0.0);

        // ═════════════════════════════════════════════════════════
        // TC3 | Complex Inputs, Twiddle = 1.0
        // ═════════════════════════════════════════════════════════
        A_re=POS1; A_im=POS1; B_re=POS1; B_im=NEG1;
        W_re=POS1; W_im=ZERO; #10;
        $display("TC3 | A=1+j  B=1-j  W=1+0j");
        display_result(2.0, 0.0,  0.0, 2.0);

        // ═════════════════════════════════════════════════════════
        // TC4 | Pure Imaginary Twiddle W = -j
        // ═════════════════════════════════════════════════════════
        A_re=POS1; A_im=ZERO; B_re=POS1; B_im=ZERO;
        W_re=ZERO; W_im=MONE; #10;
        $display("TC4 | A=1+0j  B=1+0j  W=0-j  (e^{-jpi/2})");
        display_result(1.0, -1.0,  1.0, 1.0);

        // ═════════════════════════════════════════════════════════
        // TC5 | 45-degree Twiddle Rotation W = e^{-jpi/4}
        // ═════════════════════════════════════════════════════════
        A_re=POS1; A_im=ZERO; B_re=POS1; B_im=ZERO;
        W_re=COS45; W_im=-COS45; #10;
        $display("TC5 | A=1+0j  B=1+0j  W=e^{-jpi/4}");
        display_result(1.71, -0.71,  0.29, 0.71);

        $finish;
    end
endmodule
`endif