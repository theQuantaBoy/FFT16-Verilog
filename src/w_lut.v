// ─────────────────────────────────────────────────────────────────
// w_lut — Combinational Look-Up Table for 16-point FFT roots
// Inputs:  3-bit address index k (0 to 7)
// Outputs: 16-bit Q15 signed fixed-point constants for W_16^k
// ─────────────────────────────────────────────────────────────────
module w_lut (
    input  wire [2:0]  addr,   // Index 'k' for W_16^k
    output reg signed [15:0] W_re, W_im
);
    always @(*) begin
        case (addr)
            3'd0: begin W_re = 16'h7FFF; W_im = 16'h0000; end // W_16^0 = +1.00000 +0.00000j
            3'd1: begin W_re = 16'h7642; W_im = 16'hCF04; end // W_16^1 = +0.92388 -0.38268j
            3'd2: begin W_re = 16'h5A82; W_im = 16'hA57E; end // W_16^2 = +0.70711 -0.70711j
            3'd3: begin W_re = 16'h30FC; W_im = 16'h89BE; end // W_16^3 = +0.38268 -0.92388j
            3'd4: begin W_re = 16'h0000; W_im = 16'h8000; end // W_16^4 =  0.00000 -1.00000j
            3'd5: begin W_re = 16'hCF04; W_im = 16'h89BE; end // W_16^5 = -0.38268 -0.92388j
            3'd6: begin W_re = 16'hA57E; W_im = 16'hA57E; end // W_16^6 = -0.70711 -0.70711j
            3'd7: begin W_re = 16'h89BE; W_im = 16'hCF04; end // W_16^7 = -0.92388 -0.38268j
            default: begin W_re = 16'h7FFF; W_im = 16'h0000; end
        endcase
    end
endmodule