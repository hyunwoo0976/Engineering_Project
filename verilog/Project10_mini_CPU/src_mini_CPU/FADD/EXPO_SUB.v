module EXPO_SUB #(parameter W=8)(
    input [W-1:0]EXPO_a,EXPO_b,
    output reg [W-1:0]count,
    output reg direction,
    output reg doing_A, doing_B,
    output [W-1:0]EXPO_big
);
    always @(*)begin
        if(EXPO_a>EXPO_b)begin
            count=EXPO_a-EXPO_b;
            direction=1;
            doing_A=0;
            doing_B=1;
        end
        else if(EXPO_b>EXPO_a)begin
            count=EXPO_b-EXPO_a;
            direction=1;
            doing_A=1;
            doing_B=0;
        end
        else begin
            count=0;
            direction=1;
            doing_A=0;
            doing_B=0;
        end
    end

    assign EXPO_big=(EXPO_a>EXPO_b)?EXPO_a:EXPO_b;
endmodule