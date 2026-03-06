module Top_system #(parameter N=4)(
    input clk,reset,we,cin,count,
    input [1:0] w_add,r_add1,r_add2,
    input [1:0] mode,
    input [N-1:0] TB_v
);
    wire[N:0]MUX_reg;
    wire[N-1:0]dout1_a;
    wire[N-1:0]dout2_b;
    wire[N:0]alu_v;

    dual_port_reg #(.N(N)) uut0(
        .din(MUX_reg),.clk(clk), .reset(reset), .we(we),
        .w_add(w_add), .r_add1(r_add1), .r_add2(r_add2),
        .dout1(dout1_a), .dout2(dout2_b)  
    );

    alu_Nbit #(.N(N))uut1(
        .a(dout1_a),.b(dout2_b),
        .mode(mode), .result(alu_v),
        .cin(1'b0)
    );

    MUX #(.N(N)) uut2(
        .count(count), .alu_v(alu_v), .TB_v(TB_v),
        .din(MUX_reg)
    );
endmodule