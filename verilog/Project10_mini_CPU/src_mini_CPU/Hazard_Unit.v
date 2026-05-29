module Hazard_Unit (
    input ID_PCSrc, EX_PCSrc,
    output reg IF_ID_flush,
    output reg ID_EX_flush
);

    always @(*)begin
        IF_ID_flush = 1'b0;
        ID_EX_flush = 1'b0;
        if(EX_PCSrc)begin
            IF_ID_flush = 1'b1;
            ID_EX_flush = 1'b1;
        end
        else if(ID_PCSrc)begin
            IF_ID_flush = 1'b1;
            ID_EX_flush = 1'b0;
        end
    end

endmodule
