class BaseTr;
    rand bit[31:0]addr;
    randc bit[3:0]tid;      //0000,~1111까지 랜덤으로 한번씩 나오고 다시 랜덤

    constraint rand0{
        addr inside {[32'h1000 : 32'h1FFF]};
        addr % 4 == 0;
    }
    virtual function void print();
        $display("addr = %h || tid = %b", addr, tid);
    endfunction
endclass

class ReadTr extends BaseTr;
    rand int burst_len;
    constraint rand1{
        burst_len dist{[1:4] := 7, [5:16] := 3};
        (burst_len > 8) -> (addr inside {[32'h1800 : 32'h1FFF]});
    }
    function void print();
        super.print();
        $display("      burst_len = %d", burst_len);
    endfunction
endclass

class WriteTr extends BaseTr;
    rand int burst_len;
    rand bit [7:0]data[];
    bit [7:0]checksum;

    constraint c_data{
        burst_len inside{[1:16]};
        data.size() == burst_len;           //data의 크기는 burst_len, .size()는 배열의 내장함수.
        solve burst_len before data;        //data결정하기전에 burst_len 먼저 결정
        foreach(data[i]) data[i] != 8'b0;   //data의 각층은 전부 0이 아님.
    }
    function void post_randomize();         //randomize가 끝나고 자동호출
        checksum = addr[7:0];               // 32비트 addr 슬라이싱.
        foreach(data[i]) checksum ^= data[i];       //모든 바이트를 XOR로 뭉치면 하나라도 값이 바뀌면 결과가 바뀜 -> 데이터 변조/오류 감지에 딱임.
    endfunction

    function void print();
        super.print();
        $write("    data=[");
        foreach(data[i]) $write("%02h ", data[i]);
        $display("] cksum = %02h", checksum);
    endfunction
endclass


class Generator;
    mailbox #(BaseTr)mb;

    function new(mailbox #(BaseTr)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(16)begin
                if($urandom_range(0, 1))begin
                    ReadTr r_handle;
                    r_handle = new();
                    if(r_handle.randomize() == 0)begin
                        $fatal(1,"ERROR");
                    end
                    mb.put(r_handle);
                end
                else begin
                    WriteTr w_handle;
                    w_handle = new();
                    if(w_handle.randomize() == 0)begin
                        $fatal(1,"ERROR");
                    end
                    mb.put(w_handle);
                end
            end
        end
    endtask
endclass

class Scoreboard;
    mailbox #(BaseTr)mb;

    function new(mailbox #(BaseTr)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(16)begin
                BaseTr handle;
                mb.get(handle);
                handle.print();
            end
        end
    endtask
endclass

module Top;
    mailbox #(BaseTr)mb = new();
    Generator gen = new(mb);
    Scoreboard scr = new(mb);

    initial begin
        fork
            gen.run();
            scr.run();
        join
    end
endmodule
