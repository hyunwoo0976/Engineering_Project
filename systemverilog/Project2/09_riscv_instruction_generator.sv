class BaseTr;
    randc bit[4:0] Rd;
    bit[31:0]inst;

    virtual function void print();
        $write("%b",Rd);
    endfunction
endclass

class R_type extends BaseTr;                                                    //R-type: Rd / Rs1, Rs2
    rand bit[4:0] Rs1, Rs2;
    rand bit [2:0] funct3;
    rand bit [6:0]funct7;
    rand bit [6:0]opcode;

    constraint Rtype{
        funct3 inside{[3'b000:3'b001], 3'b010, [3'b100:3'b111]};
        if(funct3 == 3'b000) funct7 inside{7'b0000000, 7'b0100000};
        else funct7 == 7'b0000000;
        opcode == 7'b0110011;
    }
    function void post_randomize();
        inst = {funct7, Rs2, Rs1, funct3, Rd, opcode};
    endfunction

    function void print();
        $write("%b|%b|%b|%b|",funct7,Rs2,Rs1,funct3);
        super.print();
        $write("|%b", opcode);
        $display("-> R-type");
    endfunction
endclass

class I_type extends BaseTr;                                                    //I-type: Rd / Rs1, X
    rand bit[4:0]Rs1;
    rand bit [11:0] imm;
    rand bit [2:0]funct3;
    rand bit [6:0]opcode;

    constraint Itype{
        opcode == 7'b0010011;
        funct3 inside{3'b000, 3'b111};
    }
    function void post_randomize();
        inst = {imm, Rs1, funct3, Rd, opcode};
    endfunction


    function void print();
        $write("%b|%b|%b|",imm,Rs1,funct3);
        super.print();
        $write("|%b", opcode);
        $display("-> I-type");
    endfunction
endclass

class F_LW extends BaseTr;                                                       //F_LW: Rd / Rs1, X
    rand bit [11:0]imm;
    rand bit[4:0]Rs1;
    rand bit[2:0]funct3;
    rand bit [6:0]opcode;

    constraint FLW_LW{
        opcode inside{7'b0000011, 7'b0000111};
        funct3 == 3'b010;
    }

    function void post_randomize();
        inst = {imm, Rs1, funct3, Rd, opcode};
    endfunction

    function void print();
        $write("%b|%b|%b|",imm,Rs1,funct3);
        super.print();
        $write("|%b", opcode);
        if(opcode == 7'b0000011)begin
            $display("-> LW");
        end
        else if(opcode == 7'b0000111)begin
            $display("->FLW");
        end
    endfunction
endclass

class F_SW extends BaseTr;                                                      //F_SW: X / Rs1, Rs2
    rand bit [11:0]imm;
    rand bit[4:0] Rs1, Rs2;
    rand bit[2:0]funct3;
    rand bit [6:0]opcode;

    constraint FSW_SW{
        opcode inside{7'b0100011, 7'b0100111};
        funct3 == 3'b010;
    }

    function void post_randomize();
        inst = {imm[11:5], Rs2, Rs1, funct3, imm[4:0], opcode};
    endfunction

    function void print();
        $write("%b|%b|%b|%b|%b|%b",imm[11:5],Rs2,Rs1,funct3,imm[4:0],opcode);
        if(opcode == 7'b0100011)begin
            $display("-> SW");
        end
        else if(opcode == 7'b0100111)begin
            $display("->FSW");
        end
    endfunction
endclass

class B_type extends BaseTr;                                                    //B-type: X / Rs1,Rs2
    rand bit[11:0] imm;
    rand bit[4:0]Rs1, Rs2;
    rand bit[2:0]funct3;
    rand bit[6:0]opcode;

    constraint Btype{
        opcode == 7'b1100011;
        funct3 inside{3'b000, 3'b001, 3'b100, 3'b101};
    }

    function void post_randomize();
        inst = {imm[11], imm[9:4], Rs2, Rs1, funct3, imm[3:0], imm[10], opcode};
    endfunction

    function void print();
        $write("%b|%b|%b|%b|%b|%b|%b|%b",imm[11], imm[9:4], Rs2, Rs1, funct3, imm[3:0], imm[10], opcode);
        $display("->B-type");
    endfunction
endclass


class Generator;
    mailbox #(BaseTr) mb;
    bit[4:0] last_rd;
    bit have_last = 0;
    rand bit dep_c;

    function new(mailbox #(BaseTr)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(50)begin
                int sel = $urandom_range(0,4);
                int dice = $urandom_range(0,2);
                BaseTr handle;
                if(sel == 0)begin
                    R_type r_handle;
                    r_handle = new();
                    //
                    if($urandom_range(0,1) == 1 && have_last)begin
                        if(dice == 0)begin
                            if(!r_handle.randomize() with {Rs1 == last_rd;})begin
                                $fatal(1, "ERROR");
                            end
                        end
                        else if(dice == 1) begin
                            if(!r_handle.randomize() with {Rs2 == last_rd;})begin
                                $fatal(1, "ERROR");
                            end
                        end
                        else begin
                            if(!r_handle.randomize() with {Rs1 == last_rd; Rs2 == last_rd;})begin
                                $fatal(1, "ERROR");
                            end
                        end
                    end
                    else begin
                        if(r_handle.randomize() == 0)begin
                            $fatal(1, "ERROR");
                        end
                    end
                    //
                    last_rd = r_handle.Rd;
                    have_last = 1;
                    mb.put(r_handle);
                end
                else if(sel == 1)begin
                    I_type i_handle;
                    i_handle = new();
                    //
                    if($urandom_range(0,1) == 1 && have_last)begin
                        if(!i_handle.randomize() with {Rs1 == last_rd;})begin
                            $fatal(1, "ERROR");
                        end
                    end
                    else begin
                        if(i_handle.randomize() == 0)begin
                            $fatal(1, "ERROR");
                        end
                    end
                    //
                    last_rd = i_handle.Rd;
                    have_last = 1;
                    mb.put(i_handle);
                end
                else if(sel == 2)begin
                    B_type b_handle;
                    b_handle = new();
                    if($urandom_range(0,1) == 1 && have_last)begin
                        if(dice == 0)begin
                            if(!b_handle.randomize() with {Rs1 == last_rd;})begin
                                $fatal(1, "ERROR");
                            end
                        end
                        else if(dice == 1)begin
                            if(!b_handle.randomize() with {Rs2 == last_rd;})begin
                                $fatal(1, "ERROR");
                            end
                        end
                        else begin
                            if(!b_handle.randomize() with {Rs1 == last_rd; Rs2 == last_rd;})begin
                                $fatal(1, "ERROR");
                            end
                        end
                    end
                    else begin
                        if(b_handle.randomize() == 0)begin
                            $fatal(1, "ERROR");
                        end
                    end
                    mb.put(b_handle);
                end
                else if(sel == 3)begin
                    F_SW s_handle;
                    s_handle = new();
                    if($urandom_range(0,1) == 1 && have_last)begin
                        if(dice == 0)begin
                            if(!s_handle.randomize() with {Rs1 == last_rd;})begin
                                $fatal(1, "ERROR");
                            end
                        end
                        else if (dice == 1)begin
                            if(!s_handle.randomize() with {Rs2 == last_rd;})begin
                                $fatal(1, "ERROR");
                            end
                        end
                        else begin
                            if(!s_handle.randomize() with {Rs1 == last_rd; Rs2 == last_rd;})begin
                                $fatal(1, "ERROR");
                            end
                        end
                    end
                    else begin
                        if(s_handle.randomize() == 0)begin
                            $fatal(1, "ERROR");
                        end
                    end
                    mb.put(s_handle);
                end
                else begin
                    F_LW l_handle;
                    l_handle = new();
                    //
                    if($urandom_range(0,1) == 1 && have_last)begin
                        if(!l_handle.randomize() with{Rs1 == last_rd;})begin
                            $fatal(1, "ERROR");
                        end
                    end
                    else begin
                        if(l_handle.randomize() == 0)begin
                            $fatal(1, "ERROR");
                        end
                    end
                    //
                    last_rd = l_handle.Rd;
                    have_last = 1;
                    mb.put(l_handle);
                end
            end
        end
    endtask
endclass

class Scoreboard;
    mailbox #(BaseTr)mb;
    int It = 0;
    int Rt = 0;
    int Bt = 0;
    int SWt = 0;
    int FSWt = 0;
    int LWt = 0;
    int FLWt = 0;

    function new(mailbox #(BaseTr)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(50)begin
                BaseTr handle;
                mb.get(handle);
                handle.print();
                if(handle.inst[6:0] == 7'b0010011)begin
                    It++;
                end
                if(handle.inst[6:0] == 7'b0110011)begin
                    Rt++;
                end
                if(handle.inst[6:0] == 7'b1100011)begin
                    Bt++;
                end
                if(handle.inst[6:0] == 7'b0100011)begin
                    SWt++;
                end
                if(handle.inst[6:0] == 7'b0100111)begin
                    FSWt++;
                end
                if(handle.inst[6:0] == 7'b0000011)begin
                    LWt++;
                end
                if(handle.inst[6:0] == 7'b0000111)begin
                    FLWt++;
                end
            end
            $display("R-type: %0d || I-type: %0d || B-type: %0d || LW: %0d || FLW: %0d || SW: %0d || FSW: %0d", Rt, It, Bt, LWt,FLWt, SWt, FSWt);
        end
    endtask
endclass

module Top;
    mailbox #(BaseTr)mb = new();

    Generator gen = new(mb);
    Scoreboard scr = new(mb);

    initial begin
        fork
            gen.run();
            scr.run();
        join
    end
endmodule
