module Rounding #(parameter W=48)(
    input [W-1:0] FRAC,
    input [2:0] rm,
    output [22:0] final_FRAC,
    output count,
    output error
);
    wire LSB = FRAC[24];
    wire G   = FRAC[23];
    wire R   = FRAC[22];
    wire S   = |FRAC[21:0];
    
    reg round_up;

    always @(*) begin
        case(rm)
            3'b000:  round_up = G & (R | S | LSB);
            3'b001:  round_up = 1'b0;
            default: round_up = 1'b0;
        endcase
    end

    wire [24:0] rounded_top = FRAC[47:24] + round_up;

    wire overflow = rounded_top[24]; 
    assign count = overflow; 

    assign final_FRAC = overflow ? rounded_top[23:1] : rounded_top[22:0];
    
    assign error = (~overflow) & (rounded_top[23] == 1'b0);

endmodule