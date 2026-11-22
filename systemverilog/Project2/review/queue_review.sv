/*class queue;
    int q[$];

    function void print();
        $display("q = %p", q);
    endfunction

    task add_value(input int value);
        begin
            q.push_back(value);
            if(q.size() > 4)begin
                q.pop_front();
            end
        end
    endtask
endclass

module Top;
    queue que;

    initial begin
        que = new();

        que.add_value(30);
        que.print();

        que.add_value(20);
        que.print();

        que.add_value(10);
        que.print();

        que.add_value(34);
        que.print();

        que.add_value(40);
        que.print();

        que.add_value(60);
        que.print();

        que.add_value(50);
        que.print();

        que.add_value(70);
        que.print();

        $finish;
    end
endmodule
*/

class queue_test;
    int q[$];
    int removed;

    function void print();
        $display("q = %p", q);
        $display("removed = %0d", removed);
    endfunction

    task run(input int value);
        begin
            q.push_back(value);
            if(q.size() > 3)begin
                removed = q.pop_front();
            end
        end
    endtask
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
        $finish;
    end
endmodule