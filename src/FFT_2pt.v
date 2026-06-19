// ═══════════════════════════════════════════════════════════════════
// FFT_2pt.v — behavioral 2-point FFT butterfly (Radix-2 DIT)
//
// X = A + B·W    Y = A − B·W    (complex arithmetic, Q15 twiddle)
// Outputs are DW+1 bits to prevent overflow.
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

        // Scale Q(DW+15) → Q(DW) via arithmetic right-shift by 15.
        // Truncates toward −∞ (floor): ≤1 LSB error per multiply.
        // Over 4 FFT stages, accumulated quantization noise is ≤~32 LSBs.
        BW_re = (mul_re1 - mul_re2) >>> 15;
        BW_im = (mul_im1 + mul_im2) >>> 15;

        // Butterfly: DW+1 output context sign-extends A automatically
        X_re = A_re + BW_re;
        X_im = A_im + BW_im;
        Y_re = A_re - BW_re;
        Y_im = A_im - BW_im;
    end
endmodule

// ── Testbench ───────────────────────────────────────────────────────────────────
// Compile: iverilog -D TEST_FFT_2PT -o ../build/sim FFT_2pt.v && vvp ../build/sim
// ────────────────────────────────────────────────────────────────────────────────
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
    localparam signed [15:0] NEG1  = -32767;
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