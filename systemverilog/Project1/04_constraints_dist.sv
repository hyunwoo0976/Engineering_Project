class Packet;
    rand bit [31:0]length;     // 패킷 길이 
    rand bit [7:0]src_id;      // 보내는 곳
    rand bit [7:0]dst_id;     // 받는 곳
    rand bit [1:0]prio;     // 0=low, 1=normal, 2=high, 3=urgent


    constraint rand_value{
        length inside{[32'd64 : 32'd1518]};
        length dist{[32'd64 : 32'd255] := 7, [32'd256 : 32'd1518] := 3};
        prio dist{[2'd0 : 2'd2] :/ 9, 2'd3 := 1};
        if(prio == 2'd3) length < 32'd255;
        src_id != dst_id;
    }

    function void print();
        $display("length = %b | src_id = %b | dst_id = %b | priority = %b", length, src_id, dst_id, prio);
    endfunction

endclass

module solv2;
    initial begin
        Packet handle;
        handle = new();
        repeat(100)begin
            if(handle.randomize() == 32'b0)begin
                $fatal(1, "시뮬레이션 오류");
            end
            handle.print();
        end
        $finish;
    end
endmodule