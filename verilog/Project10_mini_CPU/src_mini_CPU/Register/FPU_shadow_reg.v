module FPU_shadow_reg #(parameter W=32)(
    input clk, reset,
    input EX_is_FPU,
    input FPU_Valid,
    input [W-1:0]D,
    output [W-1:0]Q
);
    reg [W-1:0]FPU_7clk[0:6];
    reg [W-1:0]A;

    integer i;
    always @(posedge clk or posedge reset) begin
        if(reset)begin
            for(i=0; i<7; i=i+1)begin
                FPU_7clk[i][W-1:0] <= {W{1'b0}};
            end
        end
        else begin
            if(EX_is_FPU)begin
                FPU_7clk[0][W-1:0] <= D;
            end
            else begin
                FPU_7clk[0][W-1:0] <= {W{1'b0}};
            end
            for(i=0; i<6; i=i+1)begin
                FPU_7clk[i+1][W-1:0] <= FPU_7clk[i][W-1:0];
            end
        end
    end
    always @(*) begin
        if(EX_is_FPU == 1'b0)begin
            A = D;
        end
        else begin
            A = {W{1'b0}};
        end
    end

    assign Q = (FPU_Valid) ? FPU_7clk[6][W-1:0] : A;
endmodule
