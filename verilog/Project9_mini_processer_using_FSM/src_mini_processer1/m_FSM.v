module m_FSM #(parameter W=4)(
    input clk,reset,start,
    input [W-1:0]result,
    input [1:0]mode,
    input C_cout,N_cout,d_f,
    input [W-1:0]a,b,
    output N,Z,V,C,
    output reg S_idle,
    output reg S_calc,
    output reg S_error,
    output reg S_done
);
    reg [1:0]curr_state,next_state;

    localparam IDLE  = 2'b00;
    localparam CALC  = 2'b01;
    localparam DONE  = 2'b10;
    localparam ERROR = 2'b11;

    always @(posedge clk or posedge reset)begin
        if(reset)begin
            curr_state<=IDLE;
        end else begin
            curr_state<=next_state;
        end
    end

    always @(*)begin
        case(curr_state)
            IDLE:begin
                if(start) next_state=CALC;
                else next_state=IDLE;
            end
            CALC:begin
                if(V)
                    next_state=ERROR;
                else if(d_f) 
                    next_state=DONE;
                else
                    next_state=CALC;
            end
            ERROR:begin 
                next_state=ERROR;
            end
            DONE:begin
                next_state=DONE;
            end
        endcase
    end

    always @(*)begin
        S_idle=0;
        S_calc=0;
        S_error=0;
        S_done=0;
        case(curr_state)
            IDLE:S_idle=1;
            CALC:S_calc=1;
            ERROR:begin 
                S_error=1;
            end
            DONE:S_done=1;
        endcase
    end
    assign Z=(result==0)?1'b1:1'b0;
    assign N = (mode==2'b01) ? N_cout : 1'b0;
    assign C = (mode==2'b00) ? C_cout : 1'b0;
    assign V=(mode==2'b00)?((a[W-1]==b[W-1])&&(result[W-1]!=a[W-1])):
             (mode==2'b01)?((a[W-1]!=b[W-1])&&(result[W-1]!=a[W-1])):1'b0;

    always @(posedge clk)begin
        if(curr_state==ERROR)begin
            $display("OVERFLOW ERROR");
        end
    end

    initial begin
        $monitor ("idle=%b|calc=%b|ERROR=%b|DONE=%b",S_idle,S_calc,S_error,S_done);
    end
endmodule