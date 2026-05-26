module Instruction_Memory #(parameter W=32)(
    input [W-1:0] pc,
    output[W-1:0] instruction
);

    reg [W-1:0] mem[0:31];

    initial begin
        $readmemh("./verilog/Project10_mini_CPU/memo/program.txt", mem);
    end

    assign instruction = mem [pc[6:2]];
endmodule