class Transaction;
    rand bit [4:0] addr, data;
    rand bit write, read;
    rand bit enable;

    constraint rand_value{
        enable dist{0 := 1, 1 := 9};
        write dist{0 := 5, 1:= 5};
        write != read;
        if(enable != 0) {addr ==5'b0; data == 5'b0;}
        if(!enable && write){addr !=5'b0; data == 5'b0;}
        if(!enable && read){addr == 5'b0; data != 5'b0;}  
    }
    function void print();
        $display("enable = %b || write = %b | read = %b || addr = %b | data = %b", enable, write, read, addr, data);
    endfunction
endclass

module top;
    mailbox #(Transaction) mb = new(5);   // 파이프 (이건 줄게요)

    initial begin
        fork
        // ===== 생산자 =====
        begin
            Transaction t;
            repeat(10)begin
                t = new();
                if(t.randomize() == 0)begin
                    $fatal(1, "시뮬 오류");
                end
                mb.put(t);
                t.print();
            end
        end
        // ===== 소비자 =====
        begin
            Transaction t;
            repeat(10)begin
                mb.get(t);
                t.print();
            end
            // TODO: repeat(5) begin
            //   mb.get(t); t.print();
            // end
        end
        join
        $finish;
    end
endmodule