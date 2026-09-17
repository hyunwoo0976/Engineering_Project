// Minimal synthesis environment check, not part of the CPU/FPU.
module synthesis_probe(
    input clk,
    input a,
    output reg q
);
    always @(posedge clk) q <= a;
endmodule
