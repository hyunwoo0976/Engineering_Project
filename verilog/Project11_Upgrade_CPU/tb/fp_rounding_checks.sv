`timescale 1ns / 1ps
module fp_rounding_checks;
    reg sign;
    reg [8:0] expo;
    reg [47:0] frac;
    reg [2:0] rm;
    wire [31:0] result;
    wire oflag, uf, nx;
    integer checks = 0;
    FP_rounding dut(
        .SIGN(sign),
        .EXPO(expo),
        .FRAC(frac),
        .rm(rm),
        .result(result),
        .OF(oflag),
        .UF(uf),
        .NX(nx),
        .final_FRAC(),
        .final_EXPO(),
        .count(),
        .inexact()
    );
    task check(input bit s, input [8:0] e, input [23:0] keep, input [23:0] tail, input [2:0] mode,
               input [31:0] expected, input [2:0] flags);
        begin
            sign = s;
            expo = e;
            frac = {keep, tail};
            rm = mode;
            #1;
            if(result !== expected || {oflag, uf, nx} !== flags)
                $fatal(
                    1,
                    "round boundary %0d result=%h expected=%h flags=%b expected=%b",
                    checks,
                    result,
                    expected,
                    {
                        oflag, uf, nx
                    },
                    flags
                );
            if(uf && !nx) $fatal(1, "UF must imply NX");
            checks = checks + 1;
        end
    endtask
    reg [47:0] sum;
    reg carry, eff_sub;
    reg [7:0] exponent_in;
    wire [7:0] shift_count;
    wire direction, doing, zero;
    wire [48:0] before_shift, after_shift;
    wire [8:0] normalized_exponent;
    Normalization_Controller #(.W(48)) norm(
        .Sum(sum),
        .Cout(carry),
        .eff_sub(eff_sub),
        .EXPO_in(exponent_in),
        .count(shift_count),
        .direction(direction),
        .doing(doing),
        .nor_FRAC(before_shift),
        .EXPO_break(zero)
    );
    barrel_shifter #(.W(49)) shifter(
        .direction(direction),
        .doing(doing),
        .count(shift_count),
        .shift(before_shift),
        .SHIFT(after_shift)
    );
    EXPO_CAL exponent_calc(
        .EXPO_in({1'b0, exponent_in}),
        .count(shift_count[5:0]),
        .direction(direction),
        .doing(doing),
        .EXPO_out(normalized_exponent)
    );
    initial begin
        // Exact negative value: directed rounding must not increment.
        check(1, 127, 24'h800000, 0, 2, 32'hbf800000, 0);
        check(0, 127, 24'h800000, 0, 3, 32'h3f800000, 0);
        // Halfway at an even and odd retained LSB.
        check(0, 127, 24'h800000, 24'h800000, 0, 32'h3f800000, 1);
        check(0, 127, 24'h800000, 24'h800000, 4, 32'h3f800001, 1);
        check(0, 127, 24'h800001, 24'h800000, 0, 32'h3f800002, 1);
        // Sticky alone affects directed rounding, but not nearest rounding.
        check(0, 127, 24'h800000, 1, 0, 32'h3f800000, 1);
        check(0, 127, 24'h800000, 1, 3, 32'h3f800001, 1);
        check(1, 127, 24'h800000, 1, 2, 32'hbf800001, 1);
        // Carry from the last fraction bit increments the exponent.
        check(0, 127, 24'hffffff, 24'h800000, 0, 32'h40000000, 1);
        check(0, 254, 24'hffffff, 24'h800000, 0, 32'h7f800000, 5);
        check(0, 255, 24'h800000, 0, 1, 32'h7f7fffff, 5);
        check(1, 255, 24'h800000, 0, 2, 32'hff800000, 5);
        check(1, 255, 24'h800000, 0, 3, 32'hff7fffff, 5);
        // Exact subnormal, promotion, halfway-to-zero, and tiny negative value.
        check(0, 1, 1, 0, 0, 32'h00000001, 0);
        check(0, 1, 24'h7fffff, 24'h800000, 0, 32'h00800000, 1);
        check(0, 1, 0, 24'h800000, 0, 32'h00000000, 3);
        check(0, 1, 0, 24'h800000, 4, 32'h00000001, 3);
        check(1, 1, 0, 1, 2, 32'h80000001, 3);
        check(1, 1, 0, 1, 1, 32'h80000000, 3);

        // Leading zeros=3 but exponent budget=1: shift only once.
        sum = 48'h100000000000;
        carry = 0;
        eff_sub = 1;
        exponent_in = 2;
        #1;
        if(shift_count !== 8'd1 || normalized_exponent !== 9'd1 || after_shift !== 49'h0200000000000)
            $fatal(1, "subnormal normalization boundary");
        checks = checks + 1;
        exponent_in = 10;
        #1;
        if(shift_count !== 8'd3 || normalized_exponent !== 9'd7 || after_shift !== 49'h0800000000000)
            $fatal(1, "normal normalization");
        checks = checks + 1;
        sum = 0;
        #1;
        if(!zero) $fatal(1, "exact cancellation");
        checks = checks + 1;
        // Carry-right-shift preserves a lost low bit for NX.
        sum = 1;
        carry = 1;
        eff_sub = 0;
        exponent_in = 254;
        #1;
        if(normalized_exponent !== 9'd255 || after_shift !== 49'h0800000000001)
            $fatal(1, "overflow exponent and sticky");
        checks = checks + 1;
        $display("ROUND/NORMALIZE PASS %0d", checks);
        $finish;
    end
endmodule
