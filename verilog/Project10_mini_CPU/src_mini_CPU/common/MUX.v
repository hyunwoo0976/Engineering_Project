module MUX #(parameter W=32)(
    input [W-1:0]ADD_out,MUL_out,
    input OF_ADD,UF_ADD,error_ADD,
    input OF_MUL,UF_MUL,
    input op,
    output reg OF,UF,error,
    output reg [W-1:0] Final_out
);

    always @(*)begin
        if(op)begin
            Final_out=MUL_out;
            OF=OF_MUL;
            UF=UF_MUL;
            error=1'b0;
        end
        else begin
            Final_out=ADD_out;
            OF=OF_ADD;
            UF=UF_ADD;
            error=error_ADD;
        end
    end

endmodule