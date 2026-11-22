class instruction #(parameter W = 32);
  // (1) 필드들: opcode, rs1, rs2, rd, imm  ← 비트폭은 RV32I 기준 알아서
    bit [6:0] opcode;
    bit [4:0] rs1, rs2, rd;
    bit [11:0] imm;
    bit [6:0]funct7;
    bit [2:0]funct3;
     
    function new(input [W-1:0] inst);
        // (2) 필드들 0으로 초기화
        case(inst[6:0])
            7'b0110011: /*정수 ALU연산*/begin
                this.funct7 = inst[W-1 -:7];
                this.rs2 = inst[W-8 -:5];
                this.rs1 = inst[W-13 -:5];
                this.funct3 = inst[W-18 -:3];
                this.rd = inst[W-21 -:5];
                this.opcode = inst[W-26 -:7];
            end
            7'b0010011 , 7'b0000011 , 7'b1100111 , 7'b0000111: /*상수 ALU연산, LW, JALR, FLW*/begin
                this.imm = inst[W-1 -:12];
                this.rs1 = inst[W-13 -:5];
                this.funct3 = inst[W-18 -:3];
                this.rd = inst[W-21 -:5];
                this.opcode = inst[W-26 -:7];
            end
            default: ;
        endcase
    endfunction

    function void print();
        // (3) $display로 필드들 출력
        $display("opcode = %b, rs1 = %b, rs2 = %b, rd = %b 입니다.", opcode, rs1, rs2, rd);
    endfunction
endclass

module top;
  initial begin
    instruction inst = new(32'h002081B3);   // 객체 생성
    inst.print();               // 출력
    $finish;
  end
endmodule