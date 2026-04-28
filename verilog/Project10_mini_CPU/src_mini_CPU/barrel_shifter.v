module barrel_shifter #(parameter W=32)(
    input direction,doing,
    input [7:0]count,
    input [W-1:0]shift,
    output reg [W-1:0] SHIFT
);
    always @(*)begin
        if(doing)begin
            if(direction)begin
            SHIFT=shift>>count;
            end
            else begin
                SHIFT=shift<<count;
            end
        end
        else begin
            SHIFT=shift;
        end
    end
endmodule