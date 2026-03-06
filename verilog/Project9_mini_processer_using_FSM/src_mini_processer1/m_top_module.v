module m_top_module #(parameter W=4)(
    input clk,reset,we,start,
    input [1:0]mode,
    input [1:0]w_add,r_add1,r_add2,
    input cin,
    input [W-1:0]din,
    input d_f,
    output V,N,Z,C
);
    wire [W-1:0]dout1_a, dout2_b;
    wire alu_n,alu_c;
    wire [W-1:0]alu_result;
    wire S_calc;

    m_FSM #(.W(W))uut0(
        .clk(clk), .reset(reset), .start(start),
        .result(alu_result), .C_cout(alu_c), .N_cout(alu_n),
        .S_calc(S_calc), .S_error(S_error),
        .a(dout1_a), .b(dout2_b),
        .d_f(d_f),.mode(mode),
        .V(V),.N(N),.C(C),.Z(Z)
    );
    
    m_ALU #(.W(W))uut1(
        .S_calc(S_calc), .a(dout1_a), .b(dout2_b), 
        .mode(mode), .cin(cin),.result(alu_result),
        .C_cout(alu_c),.N_cout(alu_n)
    );

    m_register #(.W(W))uut2(
        .clk(clk), .reset(reset), .we(we),
        .din(din),
        .w_add(w_add), .r_add1(r_add1), .r_add2(r_add2),
        .dout1(dout1_a), .dout2(dout2_b)
    );
endmodule
    