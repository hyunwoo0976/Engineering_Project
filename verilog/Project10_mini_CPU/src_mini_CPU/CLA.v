module CLA #(parameter W=48)(
    input [W-1:0]shift_FRAC_A,shift_FRAC_B,
    input Cin,
    output [W-1:0]Sum,
    output Cout
);
    wire [W-1:0]G=shift_FRAC_A&shift_FRAC_B;
    wire [W-1:0]P=shift_FRAC_A^shift_FRAC_B;
    wire [W:0]C;

    assign C[0] = Cin;
    genvar i;
    
    generate
        for(i=0;i<W/4;i=i+1)begin:cla_blocks
            assign C[4*i+1]=G[4*i]|(P[4*i]&C[4*i]);
            assign C[4*i+2]=G[4*i+1]|(P[4*i+1]&G[4*i])|(P[4*i+1]&P[4*i]&C[4*i]);
            assign C[4*i+3]=G[4*i+2]|(P[4*i+2]&G[4*i+1])|(P[4*i+2]&P[4*i+1]&G[4*i])|(P[4*i+2]&P[4*i+1]&P[4*i]&C[4*i]);
            assign C[4*i+4]=G[4*i+3]|(P[4*i+3]&G[4*i+2])|(P[4*i+3]&P[4*i+2]&G[4*i+1])|(P[4*i+3]&P[4*i+2]&P[4*i+1]&G[4*i])|(P[4*i+3]&P[4*i+2]&P[4*i+1]&P[4*i]&C[4*i]);
        end
    endgenerate

    assign Cout=C[W];
    assign Sum=P[W-1:0]^C[W-1:0];
endmodule