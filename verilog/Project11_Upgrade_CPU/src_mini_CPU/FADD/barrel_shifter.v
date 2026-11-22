module barrel_shifter #(parameter W = 48)(
    input direction, doing,
    input [7:0] count,
    input [W-1:0] shift,
    output reg [W-1:0] SHIFT
);
    integer i;
    reg discarded;
    always @(*)begin
        discarded = 0;
        if(doing)begin
            if(direction)begin
                SHIFT = shift >> count;
                for(i = 0; i < W; i = i + 1) if(i < count) discarded = discarded | shift[i];
                SHIFT[0] = SHIFT[0] | discarded;
            end
            else begin
                SHIFT = shift << count;
            end
        end
        else begin
            SHIFT = shift;
        end
    end
endmodule
