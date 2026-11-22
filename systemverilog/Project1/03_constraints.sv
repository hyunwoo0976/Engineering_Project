class mem_txn;
    rand bit [31:0]addr;
    rand bit [31:0]data;
    rand bit rw;                //0:read, 1:write
    rand bit [3:0] burst_len;


    constraint rand_value{
        addr inside{[32'h0 : 32'h0000FFFF]};
        addr[1:0] == 2'b0;                      //inside는 값의 집합전용, 조건은 붙이지 않음
        burst_len inside{4'd1, 4'd2, 4'd4, 4'd8};
        if(rw == 1'b0) data == 32'b0;   //같아야한다의 의미임. 값을 넣는다 X
    }
    function void print();
        $display("addr = %h | data = %h | rw = %b | burst_len = %b", addr, data, rw, burst_len);
        if(data == 32'b0)begin
            $display("data was gone");
        end
    endfunction
endclass

module top;
    initial begin
        mem_txn handle;
        handle = new();
        repeat(16)begin
            if(handle.randomize() == 32'b0)begin
                $fatal(1, "실패");
            end
            handle.print();
        end
        $finish;
    end
endmodule