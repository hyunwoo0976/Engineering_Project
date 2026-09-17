module FP_special(
    input [31:0] a, b,
    input [1:0] op,  // op 0/1/2 = ADD/SUB/MUL
    input [2:0] rm,
    input FPU_en,

    output reg special,
    output reg [31:0] result,
    output reg [4:0] flags,  //Flags = NV,DZ,OF,UF,NX.
    output reg illegal,
    output [7:0] effective_EXPO_A, effective_EXPO_B
);
    wire az, asub, an, ai, aq, asn, ah, bz, bsub, bn, bi, bq, bsn, bh;
    wire [7:0] ae, be;

    assign effective_EXPO_A = (FPU_en) ? ae : 8'b0;
    assign effective_EXPO_B = (FPU_en) ? be : 8'b0;

    FPU_classifier ca(
        .SIGN(a[31]),
        .EXPO(a[30:23]),
        .FRAC(a[22:0]),
        .is_zero(az),
        .is_subnormal(asub),
        .is_normal(an),
        .is_inf(ai),
        .is_nan(aq),
        .is_snan(asn),
        .hidden_bit(ah),
        .effective_exponent(ae)
    );

    FPU_classifier cb(
        .SIGN(b[31]),
        .EXPO(b[30:23]),
        .FRAC(b[22:0]),
        .is_zero(bz),
        .is_subnormal(bsub),
        .is_normal(bn),
        .is_inf(bi),
        .is_nan(bq),
        .is_snan(bsn),
        .hidden_bit(bh),
        .effective_exponent(be)
    );

    wire sb = b[31] ^ (op == 1);
    //EXPO=FF, FRAC=0   → Infinity
    //EXPO=FF, FRAC!=0  → NaN

    always @* begin
        special = 1;
        result = 0;
        flags = 0;
        illegal = (op == 2'd3 || rm > 4);
        if(illegal)begin  //op = 11, rm > 4 -> invalid value
            result = 32'h7fc00000;  //qNaN
        end
        else if(aq || bq)begin  //a = NaN or b = NaN
            result = 32'h7fc00000;  //qNaN
            flags[4] = asn || bsn;
        end
        else if(op == 2'd2)begin  //MUL case
            if((ai && bz) || (bi && az))begin
                result = 32'h7fc00000;
                flags[4] = 1;
            end
            else if(ai || bi)begin
                result = {a[31] ^ b[31], 8'hff, 23'b0};
            end
            else if(az || bz)begin
                result = {a[31] ^ b[31], 31'b0};
            end
            else begin
                special = 0;
            end
        end
        else begin
            if(ai && bi && (a[31] != sb))begin
                result = 32'h7fc00000;
                flags[4] = 1;
            end
            else if(ai)begin
                result = {a[31], 8'hff, 23'b0};
            end
            else if(bi)begin
                result = {sb, 8'hff, 23'b0};
            end
            else if(az && bz)begin
                result = {(a[31] == sb ? a[31] : rm == 2), 31'b0};
            end
            else if(az)begin
                result = {sb, b[30:0]};
            end
            else if(bz)begin
                result = a;
            end
            else begin
                special = 0;
            end
        end
    end
endmodule
