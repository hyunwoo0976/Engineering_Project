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

typedef class DependencyTracker;    //class가 선언될거라는 신호

class Generator;
    mailbox #(BaseTr) mb;
    DependencyTracker d_handle;
    bit[4:0] last_rd;
    bit have_last = 0;
    rand bit dep_c;
    int coin;
    bit write;



    function new(mailbox #(BaseTr)mb, DependencyTracker Tracker);
        this.mb = mb;
        d_handle = Tracker;
    endfunction


    task run;
        begin
            d_handle.write = 1'b0;
            coin = $urandom_range(4, 0);
            dep_c = $urandom_range(1, 0);

            case(coin)
                //R-type
                0: begin
                    R_type r_handle = new();
                    d_handle.write = 1'b1;
                    d_handle.choose_Rd();
                    if(d_handle.doing)begin
                        if(dep_c)begin
                            if(!r_handle.randomize() with{Rs1 == d_handle.target;})begin
                                $fatal(1,"ERROR");
                            end
                        end
                        else begin
                            if(!r_handle.randomize() with{Rs2 == d_handle.target;})begin
                                $fatal(1,"ERROR");
                            end
                        end
                    end
                    else begin
                        if(!r_handle.randomize())begin
                            $fatal(1,"ERROR");
                        end
                    end
                    d_handle.Rd = r_handle.Rd;
                    d_handle.print_q();
                    d_handle.run();
                    mb.put(r_handle);
                end

                //I_type
                1: begin
                    I_type i_handle = new();
                    d_handle.write = 1'b1;
                    d_handle.choose_Rd();
                    if(d_handle.doing)begin
                        if(!i_handle.randomize() with{Rs1 == d_handle.target;})begin
                            $fatal(1,"ERROR");
                        end
                    end
                    else begin
                        if(!i_handle.randomize())begin
                            $fatal(1,"ERROR");
                        end
                    end
                    d_handle.Rd = i_handle.Rd;
                    d_handle.print_q();
                    d_handle.run();
                    mb.put(i_handle);
                end

                //F_LW
                2: begin
                    F_LW l_handle = new();
                    d_handle.write = 1'b1;
                    d_handle.choose_Rd();
                    if($urandom_range(1,0))begin    //LW
                        if(d_handle.doing)begin
                            if(!l_handle.randomize() with{Rs1 == d_handle.target; opcode == 7'b0000011;})begin
                                $fatal(1,"ERROR");
                            end
                        end
                        else begin
                            if(!l_handle.randomize() with{opcode == 7'b0000011;})begin
                                $fatal(1,"ERROR");
                            end
                        end
                    end
                    else begin
                        d_handle.doing = 1'b0;
                        if(!l_handle.randomize() with{opcode == 7'b0000111;})begin
                            $fatal(1,"ERROR");
                        end
                    end
                    d_handle.print_q();
                    if(l_handle.opcode == 7'b0000011)begin
                        d_handle.Rd = l_handle.Rd;
                        d_handle.run();
                    end

                    mb.put(l_handle);
                end

                //F_SW
                3: begin
                    F_SW s_handle = new();
                    d_handle.write = 1'b0;
                    d_handle.choose_Rd();
                    if($urandom_range(1,0))begin    //SW
                        if(d_handle.doing)begin
                            if(dep_c)begin
                                if(!s_handle.randomize() with{Rs1 == d_handle.target; opcode == 7'b0100011;})begin
                                    $fatal(1,"ERROR");
                                end
                            end
                            else begin
                                if(!s_handle.randomize() with{Rs2 == d_handle.target; opcode == 7'b0100011;})begin
                                    $fatal(1,"ERROR");
                                end
                            end
                        end
                        else begin
                            if(!s_handle.randomize() with{opcode == 7'b0100011;})begin
                                $fatal(1,"ERROR");
                            end
                        end
                    end
                    else begin
                        d_handle.doing = 1'b0;
                        if(!s_handle.randomize() with{opcode == 7'b0100111;})begin
                            $fatal(1,"ERROR");
                        end
                    end
                    d_handle.print_q();
                    mb.put(s_handle);
                end

                //B-type
                4: begin
                    B_type b_handle = new();
                    d_handle.write = 1'b0;
                    d_handle.choose_Rd();
                    if(d_handle.doing)begin
                        if(dep_c)begin
                            if(!b_handle.randomize() with{Rs1 == d_handle.target;})begin
                                $fatal(1,"ERROR");
                            end
                        end
                        else begin
                            if(!b_handle.randomize() with{Rs2 == d_handle.target;})begin
                                $fatal(1,"ERROR");
                            end
                        end
                    end
                    else begin
                        if(!b_handle.randomize())begin
                            $fatal(1,"ERROR");
                        end
                    end
                    d_handle.print_q();
                    mb.put(b_handle);
                end
                default: $fatal(1,"ERROR");
            endcase
        end
    endtask
endclass

class DependencyTracker;
    bit[4:0] recent_x_Rd[$];
    int index;
    bit[4:0] target;
    bit coin;
    localparam MAXQ = 6;
    bit doing;
    bit write;
    bit[4:0] Rd;

    function void print_q();
        $write("q = [");
        foreach(recent_x_Rd[i]) $write(" %b ", recent_x_Rd[i]);
        $write("]");
    endfunction

    function void print();
        if(doing)begin
            $display(" -> ");
            $display("Dependent!!");
            $display("target = %b", target);
            $display("distance : %0d", index + 1);
        end
        else begin
            $display("NOT Dependent");
        end
    endfunction

    task choose_Rd;
        begin
            coin = $urandom_range(1 , 0);
            doing = coin && (recent_x_Rd.size() > 0);
            if(doing)begin
                index = $urandom_range (recent_x_Rd.size() - 1, 0);
                target = recent_x_Rd[index];
            end
        end
    endtask

    task run;
        begin
            if(write && Rd != 5'b0)begin
                recent_x_Rd.push_front(Rd);
            end
            if(recent_x_Rd.size() > MAXQ)begin
                recent_x_Rd.pop_back();
            end
        end
    endtask
endclass


class Scoreboard;
    mailbox #(BaseTr)mb;
    DependencyTracker d_handle;
    int It = 0;
    int Rt = 0;
    int Bt = 0;
    int SWt = 0;
    int FSWt = 0;
    int LWt = 0;
    int FLWt = 0;

    function new(mailbox #(BaseTr)mb, DependencyTracker Tracker);
        this.mb = mb;
        d_handle = Tracker;
    endfunction

    task run;
        begin
            BaseTr handle;
            mb.get(handle);
            d_handle.print();
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
    endtask
endclass

module Top;
    mailbox #(BaseTr)mb = new();

    DependencyTracker den = new();

    Generator gen = new(mb, den);
    Scoreboard scr = new(mb, den);

    initial begin
        repeat(50)begin
            $display("==============//////////////////////////==============");
            fork
                gen.run();
                scr.run();
            join
        end
        $display("R-type: %0d || I-type: %0d || B-type: %0d || LW: %0d || FLW: %0d || SW: %0d || FSW: %0d", scr.Rt, scr.It, scr.Bt, scr.LWt,scr.FLWt, scr.SWt, scr.FSWt);
    end
endmodule
