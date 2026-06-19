// ═══════════════════════════════════════════════════════════════════
// testbench.v  —  Self-checking testbench for the 16-point FFT
//
// Compile & run:
//   iverilog -g2012 -o sim_tb \
//       testbench.v FFT_16pt.v FFT_8pt.v FFT_4pt.v FFT_2pt.v w_lut.v
//   vvp sim_tb
//
// Test cases (6 total, all purely real inputs):
//   TC1  DC signal              — all energy in X[0]
//   TC2  Nyquist signal         — all energy in X[8]
//   TC3  Unit impulse at n=0    — flat spectrum (all bins equal)
//   TC4  Impulse at n=4         — rotating ±1 / ±j spectrum
//   TC5  Cosine at bin-2        — X[2]=X[14]=N/2·POS1, rest ≈0
//   TC6  Sawtooth 0..POS1       — non-trivial multi-bin spectrum
//
// Pass/fail criterion:
//   |got − expected| ≤ TOLERANCE for every (re, im) component.
//   TOLERANCE = 64 LSBs covers the worst-case accumulated Q15
//   truncation error across 4 butterfly stages (empirically ≤32 LSBs
//   for all tested vectors; 64 gives safe headroom).
//
// Expected values were computed by numpy with POS1=32767 real inputs,
// matching the exact integer DFT (no 1/N normalisation).
// ═══════════════════════════════════════════════════════════════════

`timescale 1ns/1ps

module testbench;

    // ── DUT port declarations ────────────────────────────────────
    reg signed [15:0]
        in_re0,  in_im0,  in_re1,  in_im1,
        in_re2,  in_im2,  in_re3,  in_im3,
        in_re4,  in_im4,  in_re5,  in_im5,
        in_re6,  in_im6,  in_re7,  in_im7,
        in_re8,  in_im8,  in_re9,  in_im9,
        in_re10, in_im10, in_re11, in_im11,
        in_re12, in_im12, in_re13, in_im13,
        in_re14, in_im14, in_re15, in_im15;

    wire signed [19:0]
        out_re0,  out_im0,  out_re1,  out_im1,
        out_re2,  out_im2,  out_re3,  out_im3,
        out_re4,  out_im4,  out_re5,  out_im5,
        out_re6,  out_im6,  out_re7,  out_im7,
        out_re8,  out_im8,  out_re9,  out_im9,
        out_re10, out_im10, out_re11, out_im11,
        out_re12, out_im12, out_re13, out_im13,
        out_re14, out_im14, out_re15, out_im15;

    FFT_16pt #(.DW(16)) uut (
        .in_re0(in_re0),   .in_im0(in_im0),
        .in_re1(in_re1),   .in_im1(in_im1),
        .in_re2(in_re2),   .in_im2(in_im2),
        .in_re3(in_re3),   .in_im3(in_im3),
        .in_re4(in_re4),   .in_im4(in_im4),
        .in_re5(in_re5),   .in_im5(in_im5),
        .in_re6(in_re6),   .in_im6(in_im6),
        .in_re7(in_re7),   .in_im7(in_im7),
        .in_re8(in_re8),   .in_im8(in_im8),
        .in_re9(in_re9),   .in_im9(in_im9),
        .in_re10(in_re10), .in_im10(in_im10),
        .in_re11(in_re11), .in_im11(in_im11),
        .in_re12(in_re12), .in_im12(in_im12),
        .in_re13(in_re13), .in_im13(in_im13),
        .in_re14(in_re14), .in_im14(in_im14),
        .in_re15(in_re15), .in_im15(in_im15),
        .out_re0(out_re0),   .out_im0(out_im0),
        .out_re1(out_re1),   .out_im1(out_im1),
        .out_re2(out_re2),   .out_im2(out_im2),
        .out_re3(out_re3),   .out_im3(out_im3),
        .out_re4(out_re4),   .out_im4(out_im4),
        .out_re5(out_re5),   .out_im5(out_im5),
        .out_re6(out_re6),   .out_im6(out_im6),
        .out_re7(out_re7),   .out_im7(out_im7),
        .out_re8(out_re8),   .out_im8(out_im8),
        .out_re9(out_re9),   .out_im9(out_im9),
        .out_re10(out_re10), .out_im10(out_im10),
        .out_re11(out_re11), .out_im11(out_im11),
        .out_re12(out_re12), .out_im12(out_im12),
        .out_re13(out_re13), .out_im13(out_im13),
        .out_re14(out_re14), .out_im14(out_im14),
        .out_re15(out_re15), .out_im15(out_im15)
    );

    // ── Q15 constants ────────────────────────────────────────────
    localparam signed [15:0] POS1  =  32767;
    localparam signed [15:0] NEG1  = -32767;
    localparam signed [15:0] ZERO  =      0;
    localparam signed [15:0] COS45 =  23170;  // round(32767 * cos(45°))

    // ── Tolerance (LSBs, in the 20-bit output domain) ────────────
    // Worst-case Q15 twiddle truncation over 4 stages is ≤ 32 LSBs.
    // We set 64 for headroom.
    localparam integer TOLERANCE = 64;

    // ── Counters ─────────────────────────────────────────────────
    integer pass_cnt, fail_cnt;

    // ── Working arrays (integer to hold signed 20-bit values) ────
    // These are populated by capture_outputs and set_expected.
    integer got_re [0:15];
    integer got_im [0:15];
    integer exp_re [0:15];
    integer exp_im [0:15];

    // ── Helper: real ↔ Q15 display ───────────────────────────────
    function real q15_to_real;
        input signed [19:0] val;
        q15_to_real = $itor(val) / 32768.0;
    endfunction

    // ── Capture combinational DUT outputs into integer arrays ─────
    task capture_outputs;
        begin
            got_re[0]  = out_re0;  got_im[0]  = out_im0;
            got_re[1]  = out_re1;  got_im[1]  = out_im1;
            got_re[2]  = out_re2;  got_im[2]  = out_im2;
            got_re[3]  = out_re3;  got_im[3]  = out_im3;
            got_re[4]  = out_re4;  got_im[4]  = out_im4;
            got_re[5]  = out_re5;  got_im[5]  = out_im5;
            got_re[6]  = out_re6;  got_im[6]  = out_im6;
            got_re[7]  = out_re7;  got_im[7]  = out_im7;
            got_re[8]  = out_re8;  got_im[8]  = out_im8;
            got_re[9]  = out_re9;  got_im[9]  = out_im9;
            got_re[10] = out_re10; got_im[10] = out_im10;
            got_re[11] = out_re11; got_im[11] = out_im11;
            got_re[12] = out_re12; got_im[12] = out_im12;
            got_re[13] = out_re13; got_im[13] = out_im13;
            got_re[14] = out_re14; got_im[14] = out_im14;
            got_re[15] = out_re15; got_im[15] = out_im15;
        end
    endtask

    // ── Zero out all expected bins (useful before sparse assignments) ─
    task zero_expected;
        integer k;
        begin
            for (k = 0; k < 16; k = k + 1) begin
                exp_re[k] = 0; exp_im[k] = 0;
            end
        end
    endtask

    // ── Check & report one test case ─────────────────────────────
    // Call after setting inputs, waiting #SETTLE, and capture_outputs.
    task check_tc;
        input [8*60:1] name;  // test-case label (up to 60 chars)
        integer k;
        integer d_re, d_im;
        integer local_fails;
        begin
            local_fails = 0;
            $display("\n── %s", name);
            for (k = 0; k < 16; k = k + 1) begin
                d_re = got_re[k] - exp_re[k];
                d_im = got_im[k] - exp_im[k];
                if (d_re < 0) d_re = -d_re;
                if (d_im < 0) d_im = -d_im;

                // Always print the full spectrum in float
                $display("  X[%2d]: got %+8.3f%+8.3fj  |  exp %+8.3f%+8.3fj  %s",
                         k,
                         q15_to_real(got_re[k]), q15_to_real(got_im[k]),
                         $itor(exp_re[k]) / 32768.0,
                         $itor(exp_im[k]) / 32768.0,
                         (d_re <= TOLERANCE && d_im <= TOLERANCE) ? "  ok" : "  <<< FAIL");

                if (d_re > TOLERANCE || d_im > TOLERANCE)
                    local_fails = local_fails + 1;
            end

            if (local_fails == 0) begin
                $display("  >>> PASS (all %0d bins within ±%0d LSBs)", 16, TOLERANCE);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  >>> FAIL (%0d bin(s) exceeded ±%0d LSBs tolerance)", local_fails, TOLERANCE);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // ── SETTLE: time for combinational circuit to resolve ─────────
    // The design is fully combinational; any non-zero delay suffices.
    localparam SETTLE = 10;

    // ═════════════════════════════════════════════════════════════
    // MAIN TEST SEQUENCE
    // ═════════════════════════════════════════════════════════════
    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);

        pass_cnt = 0; fail_cnt = 0;

        $display("╔══════════════════════════════════════════════════════╗");
        $display("║         FFT_16pt Self-Checking Testbench             ║");
        $display("║  Input: Q15 (16-bit signed)   Output: 20-bit signed  ║");
        $display("║  Tolerance: ±%0d LSBs                                 ║", TOLERANCE);
        $display("╚══════════════════════════════════════════════════════╝");

        // ─────────────────────────────────────────────────────────
        // TC1 — DC Signal: x[n]=POS1 for all n
        //   Ideal: X[0]=16*POS1=524272, X[k]=0 for k≠0
        //   This tests that all energy accumulates correctly in bin 0.
        // ─────────────────────────────────────────────────────────
        in_re0=POS1; in_im0=ZERO; in_re1=POS1;  in_im1=ZERO;
        in_re2=POS1; in_im2=ZERO; in_re3=POS1;  in_im3=ZERO;
        in_re4=POS1; in_im4=ZERO; in_re5=POS1;  in_im5=ZERO;
        in_re6=POS1; in_im6=ZERO; in_re7=POS1;  in_im7=ZERO;
        in_re8=POS1; in_im8=ZERO; in_re9=POS1;  in_im9=ZERO;
        in_re10=POS1; in_im10=ZERO; in_re11=POS1; in_im11=ZERO;
        in_re12=POS1; in_im12=ZERO; in_re13=POS1; in_im13=ZERO;
        in_re14=POS1; in_im14=ZERO; in_re15=POS1; in_im15=ZERO;
        #SETTLE; capture_outputs;
        zero_expected;
        exp_re[0] = 524272;
        check_tc("TC1: DC Signal  x[n]=1  →  X[0]=16·POS1, rest=0");

        // ─────────────────────────────────────────────────────────
        // TC2 — Nyquist Alternating: x[n] = POS1 * (-1)^n
        //   Ideal: X[8]=16*POS1, all others=0.
        //   Validates the highest-frequency bin path.
        // ─────────────────────────────────────────────────────────
        in_re0=POS1; in_im0=ZERO; in_re1=NEG1;  in_im1=ZERO;
        in_re2=POS1; in_im2=ZERO; in_re3=NEG1;  in_im3=ZERO;
        in_re4=POS1; in_im4=ZERO; in_re5=NEG1;  in_im5=ZERO;
        in_re6=POS1; in_im6=ZERO; in_re7=NEG1;  in_im7=ZERO;
        in_re8=POS1; in_im8=ZERO; in_re9=NEG1;  in_im9=ZERO;
        in_re10=POS1; in_im10=ZERO; in_re11=NEG1; in_im11=ZERO;
        in_re12=POS1; in_im12=ZERO; in_re13=NEG1; in_im13=ZERO;
        in_re14=POS1; in_im14=ZERO; in_re15=NEG1; in_im15=ZERO;
        #SETTLE; capture_outputs;
        zero_expected;
        exp_re[8] = 524272;
        check_tc("TC2: Nyquist  x[n]=(-1)^n  →  X[8]=16·POS1, rest=0");

        // ─────────────────────────────────────────────────────────
        // TC3 — Unit Impulse at n=0
        //   Ideal: X[k]=POS1 for all k (flat spectrum).
        //   Validates that all butterfly paths are active and balanced.
        // ─────────────────────────────────────────────────────────
        in_re0=POS1; in_im0=ZERO; in_re1=ZERO;  in_im1=ZERO;
        in_re2=ZERO; in_im2=ZERO; in_re3=ZERO;  in_im3=ZERO;
        in_re4=ZERO; in_im4=ZERO; in_re5=ZERO;  in_im5=ZERO;
        in_re6=ZERO; in_im6=ZERO; in_re7=ZERO;  in_im7=ZERO;
        in_re8=ZERO; in_im8=ZERO; in_re9=ZERO;  in_im9=ZERO;
        in_re10=ZERO; in_im10=ZERO; in_re11=ZERO; in_im11=ZERO;
        in_re12=ZERO; in_im12=ZERO; in_re13=ZERO; in_im13=ZERO;
        in_re14=ZERO; in_im14=ZERO; in_re15=ZERO; in_im15=ZERO;
        #SETTLE; capture_outputs;
        begin : TC3_exp
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                exp_re[k] = 32767; exp_im[k] = 0;
            end
        end
        check_tc("TC3: Impulse at n=0  →  X[k]=POS1 for all k");

        // ─────────────────────────────────────────────────────────
        // TC4 — Impulse at n=4
        //   X[k] = POS1 * e^{-j*2pi*4*k/16} = POS1 * (-j)^k
        //   (rotates by exactly -90° per bin).
        //   Validates twiddle factor correctness throughout.
        //   k%4==0 → (+POS1, 0); k%4==1 → (0,-POS1);
        //   k%4==2 → (-POS1, 0); k%4==3 → (0,+POS1)
        // ─────────────────────────────────────────────────────────
        in_re0=ZERO; in_im0=ZERO; in_re1=ZERO;  in_im1=ZERO;
        in_re2=ZERO; in_im2=ZERO; in_re3=ZERO;  in_im3=ZERO;
        in_re4=POS1; in_im4=ZERO; in_re5=ZERO;  in_im5=ZERO;
        in_re6=ZERO; in_im6=ZERO; in_re7=ZERO;  in_im7=ZERO;
        in_re8=ZERO; in_im8=ZERO; in_re9=ZERO;  in_im9=ZERO;
        in_re10=ZERO; in_im10=ZERO; in_re11=ZERO; in_im11=ZERO;
        in_re12=ZERO; in_im12=ZERO; in_re13=ZERO; in_im13=ZERO;
        in_re14=ZERO; in_im14=ZERO; in_re15=ZERO; in_im15=ZERO;
        #SETTLE; capture_outputs;
        // Expected: (-j)^k pattern — set with a loop using k%4
        begin : TC4_exp
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                case (k % 4)
                    0: begin exp_re[k] =  32767; exp_im[k] =      0; end
                    1: begin exp_re[k] =      0; exp_im[k] = -32767; end
                    2: begin exp_re[k] = -32767; exp_im[k] =      0; end
                    3: begin exp_re[k] =      0; exp_im[k] =  32767; end
                endcase
            end
        end
        check_tc("TC4: Impulse at n=4  →  X[k]=POS1·(-j)^k  (twiddle stress)");

        // ─────────────────────────────────────────────────────────
        // TC5 — Real cosine at bin 2: x[n] = round(POS1·cos(2π·2n/16))
        //   Ideal: X[2] = X[14] = N/2·POS1 = 262137, rest ≈ 0.
        //   Validates multi-stage real-signal symmetry.
        //   Note: X[6] and X[10] will be ≈ -1 (rounding artifact);
        //   this is expected and within tolerance.
        // ─────────────────────────────────────────────────────────
        in_re0= POS1; in_im0=ZERO; in_re1= COS45; in_im1=ZERO;
        in_re2= ZERO; in_im2=ZERO; in_re3=-COS45; in_im3=ZERO;
        in_re4=-POS1; in_im4=ZERO; in_re5=-COS45; in_im5=ZERO;
        in_re6= ZERO; in_im6=ZERO; in_re7= COS45; in_im7=ZERO;
        in_re8= POS1; in_im8=ZERO; in_re9= COS45; in_im9=ZERO;
        in_re10=ZERO; in_im10=ZERO; in_re11=-COS45; in_im11=ZERO;
        in_re12=-POS1; in_im12=ZERO; in_re13=-COS45; in_im13=ZERO;
        in_re14=ZERO; in_im14=ZERO; in_re15= COS45; in_im15=ZERO;
        #SETTLE; capture_outputs;
        zero_expected;
        exp_re[2]  = 262137; exp_re[14] = 262137;
        exp_re[6]  = -1;     exp_re[10] = -1;    // rounding artifact, ≪ TOLERANCE
        check_tc("TC5: Cosine@bin2  →  X[2]=X[14]=262137, rest≈0");

        // ─────────────────────────────────────────────────────────
        // TC6 — Sawtooth 0..POS1: x[n] = round(POS1·n/15)
        //   Non-trivial spectrum with significant energy in all bins.
        //   Expected values computed by numpy. Tests broad numerical
        //   correctness, not just peak-bin cases.
        // ─────────────────────────────────────────────────────────
        in_re0=    0; in_im0=ZERO; in_re1= 2184; in_im1=ZERO;
        in_re2= 4369; in_im2=ZERO; in_re3= 6553; in_im3=ZERO;
        in_re4= 8738; in_im4=ZERO; in_re5=10922; in_im5=ZERO;
        in_re6=13107; in_im6=ZERO; in_re7=15291; in_im7=ZERO;
        in_re8=17476; in_im8=ZERO; in_re9=19660; in_im9=ZERO;
        in_re10=21845; in_im10=ZERO; in_re11=24029; in_im11=ZERO;
        in_re12=26214; in_im12=ZERO; in_re13=28398; in_im13=ZERO;
        in_re14=30583; in_im14=ZERO; in_re15=32767; in_im15=ZERO;
        #SETTLE; capture_outputs;
        exp_re[0]  =  262136; exp_im[0]  =       0;
        exp_re[1]  =  -17476; exp_im[1]  =   87858;
        exp_re[2]  =  -17476; exp_im[2]  =   42191;
        exp_re[3]  =  -17476; exp_im[3]  =   26155;
        exp_re[4]  =  -17476; exp_im[4]  =   17476;
        exp_re[5]  =  -17476; exp_im[5]  =   11677;
        exp_re[6]  =  -17476; exp_im[6]  =    7239;
        exp_re[7]  =  -17476; exp_im[7]  =    3476;
        exp_re[8]  =  -17472; exp_im[8]  =       0;
        exp_re[9]  =  -17476; exp_im[9]  =   -3476;
        exp_re[10] =  -17476; exp_im[10] =   -7239;
        exp_re[11] =  -17476; exp_im[11] =  -11677;
        exp_re[12] =  -17476; exp_im[12] =  -17476;
        exp_re[13] =  -17476; exp_im[13] =  -26155;
        exp_re[14] =  -17476; exp_im[14] =  -42191;
        exp_re[15] =  -17476; exp_im[15] =  -87858;
        check_tc("TC6: Sawtooth 0..POS1  (multi-bin stress test)");

        // ─────────────────────────────────────────────────────────
        // Summary
        // ─────────────────────────────────────────────────────────
        $display("\n╔══════════════════════════════════════════════════════╗");
        $display("║  SUMMARY: %0d / %0d test cases PASSED                    ║",
                 pass_cnt, pass_cnt + fail_cnt);
        if (fail_cnt == 0)
            $display("║  All tests PASSED.                                   ║");
        else
            $display("║  %0d test case(s) FAILED.                             ║", fail_cnt);
        $display("╚══════════════════════════════════════════════════════╝");

        $finish;
    end

endmodule