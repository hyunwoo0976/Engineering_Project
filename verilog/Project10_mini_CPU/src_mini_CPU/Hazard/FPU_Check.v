module FPU_Check(
    input ID_is_FPU, EX_is_FPU, ID_is_FSW,
    input [4:0]EX_Rd,
    input [4:0]ID_Rs1, ID_Rs2,
    input clk, reset,
    output FPU_Valid,
    output reg FPU_6clk,  //FPU End
    output reg [2:0]FPU_Left,     //How many left
    output reg Rs1, Rs2
);
    wire [5:0] Rd0_next;
    reg [5:0] Rd[0:6];

    assign Rd0_next = (EX_is_FPU) ? {EX_Rd, 1'b1} : 6'b0;


    integer i;
    always @(posedge clk or posedge reset) begin
        if(reset)begin
            for(i=0; i<7; i=i+1)begin
                Rd[i][5:0] <= 6'b0;
            end
            Rd[5][0] <= 1'b0;
        end
        else begin
            for(i=0; i<6; i=i+1)begin
                Rd[i+1][5:0] <= Rd[i][5:0];
            end
            Rd[0][5:0] <= Rd0_next;
            FPU_6clk <= Rd[5][0];
        end
    end
    assign FPU_Valid = Rd[6][0];

    integer x;
    always @(*) begin
        FPU_Left = 3'b0;
        {Rs1, Rs2} = 2'b0;
        if(ID_is_FPU)begin
            if(EX_is_FPU && (EX_Rd == ID_Rs1)) begin 
                FPU_Left = 3'd7;
            end
            if(EX_is_FPU && (EX_Rd == ID_Rs2)) begin
                FPU_Left = 3'd7; 
            end
            for(x=0; x<7; x=x+1)begin
                if(Rd[x][0] && (Rd[x][5:1] == ID_Rs1))begin
                    if ((6 - x) > FPU_Left) begin
                        Rs1 = 1'b1;
                        FPU_Left = 6 - x;
                    end
                end
            end
            for(x=0; x<7; x=x+1)begin
                if(Rd[x][0] && Rd[x][5:1] == ID_Rs2)begin
                    if ((6 - x) > FPU_Left) begin
                        Rs2 = 1'b1;
                        FPU_Left = 6 - x;
                    end
                end
            end
        end
        else if(ID_is_FSW)begin
            if(EX_is_FPU && (EX_Rd == ID_Rs2)) begin
                Rs2 = 1'b1;
                FPU_Left = 3'd7;
            end
            for(x=0; x<7; x=x+1)begin
                if(Rd[x][0] && Rd[x][5:1] == ID_Rs2)begin
                    Rs2 = 1'b1;
                    if ((6 - x) > FPU_Left) FPU_Left = 6 - x;
                end
            end
        end
        else begin
            FPU_Left = 3'b0;
            {Rs1, Rs2} = 2'b0;
        end
    end
    
endmodule