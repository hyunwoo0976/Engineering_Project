module QueueDistancePractice;
    bit[4:0]recent_rd[$];
    localparam MAXQ = 3;
    int index;
    bit [4:0]arr[4] = '{5'd5, 5'd9, 5'd12, 5'd7};

    initial begin
        for(int i=0; i<4; i++)begin
            recent_rd.push_front(arr[i]);
            if(recent_rd.size() > MAXQ)begin
                recent_rd.pop_back();
            end
        end

        $write("final queue = ");
        foreach(recent_rd[index]) $write(" %d",recent_rd[index]);
        $display("  size = %0d", recent_rd.size());
        foreach(recent_rd[index]) $display("distance %0d, index %0d, Rd %0d", index + 1, index, recent_rd[index]);

    end
endmodule