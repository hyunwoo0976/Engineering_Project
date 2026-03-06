module m_subtracter #(parameter W=4)(
    input[W-1:0] a,b,
    input cin,
    output [W-1:0] sub_result,
    output cout
);
    wire[W-1:0]val_a=a;
    wire[W-1:0]val_b=~b;
    wire[W:0]ci;

    assign ci[0]=cin;

    genvar i;
    generate
        for(i=0;i<W;i=i+1)begin:gen_sub
            adder FA(
                .a(val_a[i]),
                .b(val_b[i]),
                .cin(ci[i]),
                .sum(sub_result[i]),
                .cout(ci[i+1])
            );
        end
    endgenerate

    assign cout=ci[W];
endmodule