class MiniInstr;
    rand bit[4:0] Rd;
    rand bit[4:0] Rs1;

    constraint rand_con{
        Rd > 5'b0;
        Rs1 > 5'b0;
    }
    function void print();
        $display("| Rd = %b, Rs1 = %b", Rd, Rs1);
    endfunction
endclass


module Top;
    bit[4:0] recent_Rd[$];
    bit [4:0]arr [3] = '{5'd9, 5'd12, 5'd7};
    localparam MAXQ = 3;
    int index;
    int distance;
    int target;
    bit half_rand;

    initial begin
        for(int i = 0; i<3; i++)begin
            recent_Rd.push_front(arr[i]);
            if(recent_Rd.size() > MAXQ)begin
                recent_Rd.pop_back();
            end
        end
        repeat(10)begin
            half_rand = $urandom_range(1,0);
            if(recent_Rd.size() > 0)begin
                MiniInstr instr;
                instr = new();
                index = $urandom_range(recent_Rd.size() - 1 , 0);
                distance = index + 1;
                target = recent_Rd[index];

                if(half_rand)begin
                    if(!instr.randomize() with{instr.Rs1 == target;})begin
                        $fatal(1,"ERROR");
                    end
                end
                else begin
                    if(!instr.randomize() with{instr.Rs1 != target;})begin
                        $fatal(1,"ERROR");
                    end
                end

                $write("index = %0d, distance = %0d, target = %0d || half_rand = %b |",index, distance, target, half_rand);
                instr.print();

                if(instr.Rs1 == target)begin
                    $display("RAW Hazard!!");
                end
            end
        end
    end
endmodule

//index, distance, target, instr.Rs1, instr.Rd