module barrel_shifter(
    input direction,
    input [7:0]count,
    input [47:0]shift,
    output reg [47:0] SHIFT
);
    always @(*)begin
        if(direction)begin
            SHIFT=shift>>count;
        end
        else begin
            SHIFT=shift<<count;
        end
    end
endmodule