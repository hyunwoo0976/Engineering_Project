class r_inst;
    rand bit [6:0] opcode;
    rand bit [4:0] rs1, rs2, rd;
    rand bit [11:0] imm;
    rand bit [6:0]funct7;
    rand bit [2:0]funct3;

    constraint rand_value {
        opcode inside {7'b0110011, 7'b0010011};
    }
    

    function void print_inst();
        $display("opcode = %b || rs1 = %b | rs2 = %b | rd = %b", opcode, rs1, rs2, rd);
    endfunction
endclass

module rand_inst;
    initial begin
        r_inst handle;
        handle = new();
        repeat(5)begin
            if(handle.randomize() == 0)begin
                $fatal(1, "randomize 실패!");
            end
            handle.print_inst();
        end
        $finish;
    end
endmodule