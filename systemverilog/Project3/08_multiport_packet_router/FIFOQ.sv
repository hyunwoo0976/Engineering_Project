module FIFOQ #(parameter int WIDTH = 25, parameter int DEPTH = 4)(
    input logic clk, reset, wr_en,
    input logic [WIDTH-1:0]wr_data,
    output logic can_accept, out_valid,
    input logic out_ready,
    output logic [WIDTH-1:0]out_data
);
    localparam int PW = $clog2(DEPTH);
    logic [WIDTH-1:0]mem [0:DEPTH-1];
    logic [PW-1:0]rp, wp;
    logic [PW:0]count;
    logic push, pop;

    assign out_valid = count != 0;
    assign out_data = mem[rp];
    assign pop = out_valid && out_ready;
    assign can_accept = (count < DEPTH) || pop;
    assign push = wr_en && can_accept;

    always_ff @(posedge clk or posedge reset)begin
        if(reset)begin
            rp <= '0;
            wp <= '0;
            count <= '0;
            for(int i=0; i<DEPTH; i++)begin
                mem[i] <= '0;
            end
        end
        else begin
            case({push, pop})
                2'b10:begin
                    mem[wp] <= wr_data;
                    wp <= wp + 1'b1;
                    count <= count + 1'b1;
                end

                2'b01:begin
                    rp <= rp + 1'b1;
                    count <= count - 1'b1;
                end

                2'b11:begin
                    mem[wp] <= wr_data;
                    wp <= wp + 1'b1;
                    rp <= rp + 1'b1;
                end

                default:;
            endcase
        end
    end
endmodule
