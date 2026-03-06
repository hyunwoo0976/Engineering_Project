module m_adder #(parameter W=4)(
    input[W-1:0]a,b,
    input cin,
    output[W-1:0]add_result,
    output cout
);
    wire [W:0]ci;
    assign ci[0]=cin;

    genvar i;
    generate
        for(i=0;i<W;i=i+1)begin:gen_add
            adder FA(
                .a(a[i]),
                .b(b[i]),
                .cin(ci[i]),
                .sum(add_result[i]),
                .cout(ci[i+1])
            );
        end
    endgenerate

    assign cout=ci[W];
endmodule