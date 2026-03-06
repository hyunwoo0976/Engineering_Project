module alu_Nbit #(parameter N=4)(
    input [N-1:0]a,b,
    input [1:0]mode,
    input cin,
    output reg [N:0] result
);
    wire[N-1:0] add_sum;
    wire[N-1:0] sub_sum;
    wire sub_cout;
    wire add_cout;

    N_bit_adder #(.N(N)) uut0(
        .a(a),
        .b(b),
        .cout(add_cout),
        .sum(add_sum),
        .cin(cin)
    );

    calculate_sub  #(.N(N)) uut1(
        .a(a),
        .b(b),
        .cout(sub_cout),
        .cin(cin),
        .sum(sub_sum)
    );

    always @(*) begin
        case(mode)
            2'b00:result={add_cout, add_sum};
            2'b01:result={1'b0, sub_sum};
            2'b10:result={1'b0, a&b};
            2'b11:result={1'b0,a|b};
            default:result=0;
        endcase
    end
endmodule
