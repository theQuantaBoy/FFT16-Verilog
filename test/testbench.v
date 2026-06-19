// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
// testbench.v — self-checking testbench for the 16-point FFT
//
// 6 test vectors, all real inputs, tolerance ±64 LSBs:
//   TC1: DC signal      TC2: Nyquist       TC3: Impulse at n=0
//   TC4: Impulse at n=4 TC5: Cosine@bin2   TC6: Sawtooth
//
// Hierarchical:
//   iverilog -o build/sim test/testbench.v src/FFT_16pt.v src/FFT_8pt.v src/FFT_4pt.v src/FFT_2pt.v src/w_lut.v
// Flat (add -D USE_FLAT):
//   iverilog -D USE_FLAT -o build/sim test/testbench.v src/FFT_16pt_flat.v src/FFT_2pt.v src/w_lut.v
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════

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

    // ── DUT instantiation — switch with -D USE_FLAT ───────────────
`ifdef USE_FLAT
    FFT_16pt_flat #(.DW(16)) uut (
`else
    FFT_16pt      #(.DW(16)) uut (
`endif
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
    // POS1=32767: max signed Q15 (≈+1.0; true +1.0 = 32768 overflows)
    // NEG1=−32767: amplitude-symmetric with POS1 (use for signal values)
    // MONE=−32768: exact Q15 −1.0 (use where precision matters)
    localparam signed [15:0] POS1  =  32767;
    localparam signed [15:0] NEG1  = -32767;
    localparam signed [15:0] MONE  = -32768;
    localparam signed [15:0] ZERO  =      0;
    localparam signed [15:0] COS45 =  23170;  // round(32767 * cos(45°))

    // ── Tolerance ────────────────────────────────────────────────
    // Q15 twiddle truncation accumulates ≤32 LSBs over 4 stages
    // empirically; 64 gives comfortable headroom.
    localparam integer TOLERANCE = 64;

    integer pass_cnt, fail_cnt;

    integer got_re [0:15];
    integer got_im [0:15];
    integer exp_re [0:15];
    integer exp_im [0:15];

    function real q15_to_real;
        input signed [19:0] val;
        q15_to_real = $itor(val) / 32768.0;
    endfunction

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

    task zero_expected;
        integer k;
        begin
            for (k = 0; k < 16; k = k + 1) begin
                exp_re[k] = 0; exp_im[k] = 0;
            end
        end
    endtask

    task check_tc;
        input [8*60:1] name;
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
                $display("  >>> PASS (all %0d bins within +/-%0d LSBs)", 16, TOLERANCE);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  >>> FAIL (%0d bin(s) exceeded +/-%0d LSBs tolerance)", local_fails, TOLERANCE);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    localparam SETTLE = 10;

    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);

        pass_cnt = 0; fail_cnt = 0;

`ifdef USE_FLAT
        $display("DUT: FFT_16pt_flat (32 x FFT_2pt, 4 explicit stages)");
`else
        $display("DUT: FFT_16pt (hierarchical: FFT_8pt -> FFT_4pt -> FFT_2pt)");
`endif
        $display("Tolerance: +/-%0d LSBs\n", TOLERANCE);

        // ── TC1: DC Signal ────────────────────────────────────────
        // All inputs = POS1; expect X[0] = 16*POS1, X[k]=0 for k≠0
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
        check_tc("TC1: DC Signal  x[n]=1  ->  X[0]=16*POS1, rest=0");

        // ── TC2: Nyquist ──────────────────────────────────────────
        // x[n] = POS1 * (-1)^n; expect X[8] = 16*POS1, rest = 0
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
        check_tc("TC2: Nyquist  x[n]=(-1)^n  ->  X[8]=16*POS1, rest=0");

        // ── TC3: Unit Impulse at n=0 ──────────────────────────────
        // x[0]=POS1, rest=0; expect X[k]=POS1 for all k (flat spectrum)
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
        check_tc("TC3: Impulse at n=0  ->  X[k]=POS1 for all k");

        // ── TC4: Impulse at n=4 ───────────────────────────────────
        // X[k] = POS1 * e^{-j*2pi*4*k/16} = POS1 * (-j)^k
        // Each bin rotates by -90 degrees relative to the previous.
        // k%4==0 -> (+POS1,0); k%4==1 -> (0,-POS1);
        // k%4==2 -> (-POS1,0); k%4==3 -> (0,+POS1)
        in_re0=ZERO; in_im0=ZERO; in_re1=ZERO;  in_im1=ZERO;
        in_re2=ZERO; in_im2=ZERO; in_re3=ZERO;  in_im3=ZERO;
        in_re4=POS1; in_im4=ZERO; in_re5=ZERO;  in_im5=ZERO;
        in_re6=ZERO; in_im6=ZERO; in_re7=ZERO;  in_im7=ZERO;
        in_re8=ZERO; in_im8=ZERO; in_re9=ZERO;  in_im9=ZERO;
        in_re10=ZERO; in_im10=ZERO; in_re11=ZERO; in_im11=ZERO;
        in_re12=ZERO; in_im12=ZERO; in_re13=ZERO; in_im13=ZERO;
        in_re14=ZERO; in_im14=ZERO; in_re15=ZERO; in_im15=ZERO;
        #SETTLE; capture_outputs;
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
        check_tc("TC4: Impulse at n=4  ->  X[k]=POS1*(-j)^k  (twiddle stress)");

        // ── TC5: Cosine at bin 2 ──────────────────────────────────
        // x[n] = round(POS1 * cos(2*pi*2*n/16))
        // X[2] = X[14] = 262137; all others ~0.
        // X[6] and X[10] are -1 due to COS45 rounding, within tolerance.
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
        exp_re[6]  = -1;     exp_re[10] = -1;
        check_tc("TC5: Cosine@bin2  ->  X[2]=X[14]=262137, rest~0");

        // ── TC6: Sawtooth ─────────────────────────────────────────
        // x[n] = round(POS1 * n / 15), a ramp from 0 to POS1.
        // Non-trivial multi-bin spectrum; expected values from numpy.
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

        // ── Summary ───────────────────────────────────────────────
        $display("\nSUMMARY: %0d / %0d test cases PASSED", pass_cnt, pass_cnt + fail_cnt);
        if (fail_cnt == 0)
            $display("All tests PASSED.");
        else
            $display("%0d test case(s) FAILED.", fail_cnt);

        $finish;
    end

endmodule