module MUX #(parameter N=4)(
    input count,
    input [N:0]alu_v,
    input [N-1:0] TB_v,
    output [N:0]din
);
    assign din= (count==1) ? alu_v : {1'b0, TB_v};
    
endmodule