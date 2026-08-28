module QueueWarmup;
    bit[4:0] q[$];
    localparam MAXQ= 3;
    initial begin
        q.push_front(5'd5);
        if(q.size()>MAXQ)begin
            q.pop_back();
        end

        q.push_front(5'd9);
        if(q.size()>MAXQ)begin
            q.pop_back();
        end

        q.push_front(5'd12);
        if(q.size()>MAXQ)begin
            q.pop_back();
        end

        q.push_front(5'd7);
        if(q.size()>MAXQ)begin
            q.pop_back();
        end
        $write("q = [");
        foreach(q[i]) $write(" %d ", q[i]);
        $write("]");
        $display("///");

        $display("q size: %0d",q.size());
    end
endmodule