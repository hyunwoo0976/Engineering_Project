class Producer;
    mailbox #(int)out_mb;

    function new(mailbox #(int) temp_mb1);
        out_mb = temp_mb1;
    endfunction

    task run;
        begin
            out_mb.put(42);
        end
    endtask

endclass

class Consumer;
    mailbox #(int)get_mb;
    int result;

    function new(mailbox #(int)temp_mb2);
        get_mb = temp_mb2;
    endfunction

    task run;
        begin
            get_mb.get(result);
            $display("get = %0d", result);
        end
    endtask
endclass

module Top;
    mailbox #(int)mb = new();
    Producer pro = new(mb);
    Consumer con = new(mb);

    initial begin
        fork
            pro.run();
            con.run();
        join
    end
endmodule