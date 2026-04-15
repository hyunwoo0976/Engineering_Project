module LZD#(parameter W = 64)(
    input[47:0] Sum,
    input Cout,
    output reg [5:0]count,
    output reg all_zero
);

    wire [W-1:0]SUM={Cout,Sum,15'b0};

    reg [63:0] temp;

    always @(*) begin
        temp = SUM;
        count = 6'b0;
        all_zero = 1'b0;
        if (temp == 64'b0) begin
            all_zero = 1'b1;
            count = 6'd0;
        end
        else begin
            if (temp[63:32] == 32'b0) begin
                count[5] = 1'b1;
                temp = temp << 32;
            end
            if (temp[63:48] == 16'b0) begin
                count[4] = 1'b1;
                temp = temp << 16;
            end
            if (temp[63:56] == 8'b0) begin
                count[3] = 1'b1;
                temp = temp <<8;
            end
            if (temp[63:60] == 4'b0) begin
                count[2] = 1'b1;
                temp = temp <<4;
            end
            if (temp[63:62] == 2'b0) begin
                count[1] = 1'b1;
                temp = temp <<2;
            end
            if (temp[63] == 1'b0) begin
                count[0] = 1'b1;
            end
        end
    end
endmodule