`default_nettype none
// FRAC[47]: hidden position; [46:24]: fraction; [23]: G; [22]: R.
// EXPO is biased but kept wide. Normalization clamps its minimum to 1;
// a zero hidden bit at that scale denotes a subnormal candidate.
module FP_rounding(
    input wire SIGN,
    input wire [8:0] EXPO,
    input wire [47:0] FRAC,
    input wire [2:0] rm,
    output wire [22:0] final_FRAC,
    output wire [7:0] final_EXPO,
    output wire count,
    output wire inexact,
    output wire OF, UF, NX,
    output wire [31:0] result
);
    wire LSB = FRAC[24];
    wire G = FRAC[23];
    wire R = FRAC[22];
    wire S = |FRAC[21:0];
    reg round_up;
    assign inexact = G | R | S;

    always @(*)begin
        round_up = 1'b0;
        case(rm)
            3'b000: begin
                round_up = G && (R || S || LSB);  // nearest, ties even
            end

            3'b001: begin
                round_up = 1'b0;  // toward zero
            end

            3'b010: begin
                round_up = SIGN && inexact;  // toward -infinity
            end

            3'b011: begin
                round_up = !SIGN && inexact;  // toward +infinity
            end

            3'b100: begin
                round_up = G;  // nearest, ties away
            end

            default: round_up = 1'b0;  // illegal mode handled by FP_special
        endcase
    end

    wire [24:0] temp_FRAC = {1'b0, FRAC[47:24]} + round_up;

    assign count = temp_FRAC[24];

    wire [23:0] rounded = count ? temp_FRAC[24:1] : temp_FRAC[23:0];
    // Also accepts encoded EXPO=0 from a subnormal producer.
    wire [8:0] temp_EXPO = ((EXPO == 0) ? 9'd1 : EXPO) + count;
    wire [7:0] encoded = rounded[23] ? temp_EXPO[7:0] : 8'd0;

    assign OF = (temp_EXPO >= 9'd255);

    wire to_inf = (rm == 0 || rm == 4 || (rm == 2 && SIGN) || (rm == 3 && !SIGN));

    assign final_EXPO = OF ? (to_inf ? 8'hff : 8'hfe) : encoded;
    assign final_FRAC = OF ? (to_inf ? 23'd0 : 23'h7fffff) : rounded[22:0];
    assign NX = OF || inexact;
    // Tininess after rounding: promotion into minimum normal clears UF.
    assign UF = !OF && (encoded == 0) && inexact;
    assign result = {SIGN, final_EXPO, final_FRAC};
endmodule
`default_nettype wire
