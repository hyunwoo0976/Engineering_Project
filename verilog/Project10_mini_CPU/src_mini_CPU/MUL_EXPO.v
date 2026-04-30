module MUL_EXPO (
    input [8:0]EXPO_ADD,
    input count,round_carry,
    output reg [7:0]EXPO,
    output OF,UF
);
    wire [9:0]EXPO_etc={1'b0,EXPO_ADD}-10'd127+count+round_carry;
    assign OF=(EXPO_etc[9]==1'b0&&EXPO_etc>=10'd255)?1'b1:1'b0;
    assign UF=(EXPO_etc[9]==1'b1)?1'b1:1'b0;
    always @(*)begin
        if(OF)begin
            EXPO=8'hFF;
        end
        else if(UF)begin
            EXPO=8'h00;
        end
        else begin
            EXPO=EXPO_etc[7:0];
        end
    end
endmodule
