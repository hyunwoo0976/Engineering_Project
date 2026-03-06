module m_ALU #(parameter W=4)(
    input[W-1:0]a,b,
    input [1:0]mode,
    input cin,S_calc,S_error,
    output reg [W-1:0]result,
    output reg C_cout,N_cout
);
    wire[W-1:0]add_re,sub_re;
    wire add_c_wire;

    m_adder #(.W(W))uut_add(
        .a(a),
        .b(b),
        .add_result(add_re),
        .cout(add_c_wire),
        .cin(cin)
    );
    m_subtracter #(.W(W))uut_sub(
        .a(a),
        .b(b),
        .sub_result(sub_re),
        .cin(cin)
    );


    always @(*)begin
        C_cout=0; N_cout=0; result=0;
        if (S_error)begin
            result=4'b0000;
        end
        else if(S_calc) begin
            case (mode)
                2'b00:begin 
                    result=add_re;
                    C_cout=add_c_wire;
                end
                2'b01:begin
                    result=sub_re;
                    N_cout=sub_re[3];
                end
                2'b10:result=a&b;
                2'b11:result=a|b;
                default:result=0;
            endcase
        end 
    end
endmodule