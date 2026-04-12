module calculate_sub #(parameter N=4)(
    input[N-1:0]a,b,
    output[N-1:0]sum,
    input cin,
    output cout
);
    wire [N-1:0] val_a=(a>=b)?a:b;
    wire [N-1:0] pre_b=(a>=b)?b:a;
    wire [N-1:0] val_b=~pre_b;
    wire [N:0] ci;
    assign ci[0]=1'b1;
    genvar i;
    generate
        for(i=0;i<N;i=i+1)begin:gen_cal
        adder FA(
            .a(val_a[i]),
            .b(val_b[i]),
            .cin(ci[i]),
            .sum(sum[i]),
            .cout(ci[i+1])
        );
        end
    endgenerate

    assign cout=ci[N];
endmodule
