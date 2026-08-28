class Request;
    int id;
    rand int a,b;
    rand bit op;     // 0:a+b, 1:a-b

    function  new(int id);
        this.id = id;
    endfunction

    constraint Request_rand{
        a inside {[0:10]};
        b inside {[0:10]};
    }

endclass

class Response;
    int id;
    int a;
    int b;
    bit op;
    int result;

    function void print();
        $display("n.%0d | a = %0d, b = %0d | op = %b | result = %0d",id,a,b,op,result);;
    endfunction

endclass

class Generator;
    mailbox #(Request) out_mb;

    function new(mailbox #(Request)mb_A);
        out_mb = mb_A;
    endfunction

    task run;
        begin
            for(int i = 1;i<=4;i++)begin
                Request handle = new(i);
                if(handle.randomize() == 0)begin
                    $fatal(1,"ERROR");
                end
                out_mb.put(handle);
            end
        end
    endtask

endclass

class ALUWorker;
    mailbox #(Request)  in_mb;
    mailbox #(Response) out_mb;
    int result;

    function new(mailbox #(Request)mb_A, mailbox #(Response)mb_B);
        in_mb = mb_A;
        out_mb = mb_B;
    endfunction

    task run;
        begin
            repeat(4)begin
                Request handle;
                Response r_handle = new();
                in_mb.get(handle);
                if(handle.op == 1'b0)begin
                    result = handle.a + handle.b;
                end
                else begin
                    result = handle.a - handle.b;
                end
                r_handle.id = handle.id;
                r_handle.a = handle.a;
                r_handle.b = handle.b;
                r_handle.op = handle.op;
                r_handle.result = result;
                out_mb.put(r_handle);
            end
        end
    endtask
endclass


class Scoreboard;
    mailbox #(Response) in_mb;
    int PASS = 0;
    int FAIL = 0;

    function new(mailbox #(Response)mb_B);
        in_mb = mb_B;
    endfunction

    task run;
        begin
            repeat(4)begin
                Response handle;
                in_mb.get(handle);
                handle.print();
                if(handle.op == 1'b0)begin
                    if((handle.a + handle.b) == handle.result)begin
                        PASS++;
                    end
                    else begin
                        FAIL++;
                    end
                end
                else begin
                    if((handle.a - handle.b) == handle.result)begin
                        PASS++;
                    end
                    else begin
                        FAIL++;
                    end
                end
            end
            $display("PASS : %0d | FAIL : %0d", PASS,FAIL);
        end
    endtask
endclass

module Top;
    mailbox #(Request)mb_A = new();
    mailbox #(Response)mb_B = new();

    Generator gen = new(mb_A);
    ALUWorker alu = new(mb_A, mb_B);
    Scoreboard src = new(mb_B);

    initial begin
        fork
            gen.run();
            alu.run();
            src.run();
        join
    end
endmodule