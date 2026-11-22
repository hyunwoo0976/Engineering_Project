`timescale 1ns/1ps
/*
부모 BaseTr, 자식 ExtTr,
[7:0]data를 랜덤생성, 자식에서 추가 tag붙임.
$display("[기본]  data=%h", data); - 부모
$display("        (+) tag=%h", tag); - 자식
*/

class BaseTr;
    rand bit [7:0]data;

    virtual function void print();
        $display("[기본]  data=%h", data);
    endfunction
endclass

class ExtTr extends BaseTr;
    rand bit [7:0]tag;
    function void print();
        super.print();
        $display("        (+) tag=%h", tag);
    endfunction
endclass

module Top;
    BaseTr arr[4];
    ExtTr e0, e1;
    initial begin
        arr[0] = new();
        arr[1] = new();

        e0 = new(); arr[2] = e0;
        e1 = new(); arr[3] = e1;

        foreach(arr[i])begin 
            if(arr[i].randomize() == 0)begin
                $fatal(1,"ERROR");
            end
            arr[i].print();
        end
    end
endmodule
  