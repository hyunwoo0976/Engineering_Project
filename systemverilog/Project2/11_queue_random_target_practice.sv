module QueueRandomTargetPractice;
    bit[4:0] recent_rd[$];
    localparam MAXQ = 3;
    int index;
    int target, distance;
    bit[4:0] arr[4] = '{5'd5, 5'd9, 5'd12, 5'd7};

    initial begin
        for(int i = 0; i<4; i++)begin
            recent_rd.push_front(arr[i]);
            if(recent_rd.size()>MAXQ)begin
                recent_rd.pop_back();
            end
        end
        for(int j =0; j<10; j++)begin
            if(recent_rd.size() > 0)begin
                index = $urandom_range(recent_rd.size() - 1, 0);
                target = recent_rd[index];
                distance = index + 1;
                $display("index %0d, distance %0d, target %0d", index, distance, target);
            end
        end
    end
endmodule
