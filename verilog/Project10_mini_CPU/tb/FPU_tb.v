module FPU_tb #(parameter W=32);
    reg Stage_in;
    reg [W-1:0] EX_F_A, EX_F_B;
    reg [1:0] EX_FPU_Control;
    reg [2:0] EX_rm;
    reg EX_FPU_en;
    reg clk,reset;
    wire [W-1:0] EX_FPU_Result;
    wire error, EX_FPU_OF, EX_FPU_UF;
    wire EX_FPU_ZF, EX_FPU_sign;
    wire [7:1]Stage_out;

    always #5 clk = ~clk;

    initial begin
        $dumpfile("FPU.vcd");
        $dumpvars(0,FPU_tb);
    end

    FPU #(.W(32)) u_FPU(
        .IN_A(EX_F_A),
        .IN_B(EX_F_B),
        .clk(clk),
        .reset(reset),
        .op(EX_FPU_Control),
        .FPU_en(EX_FPU_en),
        .rm(EX_rm),
        .ZF(EX_FPU_ZF),
        .sign(EX_FPU_sign),
        .OF(EX_FPU_OF),
        .UF(EX_FPU_UF),
        .error(error),
        .result_out(EX_FPU_Result)
    );

    STAGE #(.STAGE_COUNT(7))u_Stage(
        .Stage_in(Stage_in),
        .clk(clk),
        .reset(reset),
        .s(Stage_out)
    );
    

    initial begin
        clk = 1'b0; 
        reset = 1'b1;
        EX_F_A = 32'd0;
        EX_F_B = 32'd0;
        EX_FPU_Control = 2'b11;
        EX_rm = 3'b0;
        EX_FPU_en = 1'b0;
        Stage_in = 1'b0;

        #9;
        EX_FPU_en = 1'b1;
        
        reset = 1'b0;

        @(negedge clk);
        Stage_in = 1'b1;
        EX_F_A = 32'h4069999A;
        EX_F_B = 32'h3FA6CA66;
        EX_FPU_Control = 2'b10;
       
        @(negedge clk);
        EX_F_A = 32'h4069999A;
        EX_F_B = 32'h3FA6CA66;
        EX_FPU_Control = 2'b01;
        
        @(negedge clk);
        EX_F_A = 32'h4069999A;
        EX_F_B = 32'h3FA6CA66;
        EX_FPU_Control = 2'b00;


        #100;
        EX_FPU_en = 1'b0;

        #30;

        $finish;
    end
endmodule