// Immediate assertion practice: fill in the TODOs.
class queue_test;
    int q[$];
    int removed;

    task run(input int value);
        q.push_back(value);
        if(q.size() > 3)begin
            removed = q.pop_front();
        end
        assert (q.size() <= 3)
            $display("PASS"); 
        else   
            $error("FAIL");
    endtask

    function void print();
        $display("q = %p", q);
        $display("removed = %0d", removed);
    endfunction
endclass

module Top;
    queue_test que;
    initial begin
        que = new();
        que.run(10);
        que.run(20);
        que.run(30);
        que.run(40);
        que.print();
        
        assert (que.removed == 10)
            $display("its 10"); 
        else    
            $error("no");
        $finish;
    end
endmodule
