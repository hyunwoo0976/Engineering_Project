module Top_module(
    input [3:0] alu0_a,alu0_b,
    input [3:0] alu1_a,alu1_b,
    input [1:0] mode,
    output [5:0] alu2,
    input clk,reset
);
    wire[4:0] alu0_reg0;
    wire[4:0] alu1_reg1;
    wire[4:0] reg0_alu2;
    wire[4:0] reg1_alu2;

    alu_Nbit #(.N(4)) ALU0(
        .a(alu0_a),
        .b(alu0_b),
        .result(alu0_reg0),
        .mode(mode),
        .cin(1'b0)
    );

    alu_Nbit #(.N(4)) ALU1(
        .a(alu1_a),
        .b(alu1_b),
        .result(alu1_reg1),
        .mode(mode),
        .cin(1'b0)
    );

    register_Nbit #(.N(4)) reg0(
        .d(alu0_reg0),
        .q(reg0_alu2),
        .clk(clk),
        .reset(reset)
    );

    register_Nbit #(.N(4)) reg1(
        .d(alu1_reg1),
        .q(reg1_alu2),
        .clk(clk),
        .reset(reset)
    );

    alu_Nbit #(.N(5)) ALU2(
        .a(reg0_alu2),
        .b(reg1_alu2),
        .result(alu2),
        .mode(mode),
        .cin(1'b0)
    );
endmodule
