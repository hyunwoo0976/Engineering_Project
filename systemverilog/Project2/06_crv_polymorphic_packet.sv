/*
[작업지시서] 다형성과 제약 조건을 활용한 패킷 검증 환경 확장
1. 개요
본 작업은 SystemVerilog OOP(객체 지향 프로그래밍)의 다형성과 Constrained Random Verification(CRV) 기법을 활용하여,
상속 관계에 있는 패킷 클래스들의 무작위 생성 및 제약 조건 검증을 수행하는 실습 과제입니다.

2. 클래스 구조 및 요구 사항
① 부모 클래스 (BasePacket)
변수 선언:

rand bit [7:0] header

rand int unsigned id (음수 방지를 위한 unsigned 타입 적용)

메서드:

가상 함수(virtual function) print() 정의 (출력 포맷: header = %h || id = %0d)

② 자식 클래스 1: 데이터 패킷 (DataPacket)
추가 변수:

rand bit length

제약 조건 (constraint rand_data):

id는 항상 양수(id > 0)여야 함.

length는 가중치 분산(dist)을 적용하여 0은 80%, 1은 20% 확률로 생성할 것.

임플리케이션(->) 연산자를 사용하여 조건부 제약 적용:

(length == 0) -> (header inside {[8'd10 : 8'd50]});

(length == 1) -> (header inside {[8'd200 : 8'd250]});

③ 자식 클래스 2: 제어 패킷 (ControlPacket)
추가 변수:

rand bit [1:0] command

제약 조건 (constraint rand_ctrl):

id는 항상 양수(id > 0)여야 함.

command는 2'b00(reset), 2'b01(start), 2'b10(stop), 2'b11 중 하나로 무작위 생성.

조건부 제약 적용:

(command == 2'b00 || command == 2'b10) -> (header == 8'h00); (reset 또는 stop 명령일 때 header는 무조건 8'h00으로 고정)

그 외 명령일 때는 header가 8'h01부터 8'h05 사이의 값을 가질 것.

3. 테스트벤치(tb_rand) 제어 요구 사항
repeat(20) 루프를 사용하여 총 20개의 패킷을 생성할 것.

부모 핸들(BasePacket handle;)을 선언하고, $urandom_range(0, 1)을 이용해 50:50 확률로 DataPacket 또는 ControlPacket 객체를 동적으로 생성(new)하여 업캐스팅할 것.

handle.randomize() 결과가 실패(0)할 경우 $fatal(1, "Randomization Failed!")을 호출하여 시뮬레이션을 강제 중단할 것.

성공 시 handle.print()를 호출하여 결과를 콘솔에 출력할 것.

4. 검증 및 제출 기준
Vivado(XSim) 및 VS Code(Verilator) 환경 모두에서 문법 에러 및 경고(WIDTHTRUNC 등) 없이 컴파일 및 시뮬레이션이 성공해야 함.

출력 결과물에서 command가 00 또는 10일 때 header가 정확히 00으로 제어되는지, 그리고 id에 음수가 발생하지 않는지 로그로 증명할 것.
*/

`timescale 1ns/1ps

//////////////////////////////////////////////////////////////////////////////////////////
//                          SystemVerilog practice
//////////////////////////////////////////////////////////////////////////////////////////

class BasePacket;
    rand bit[7:0]header;
    rand int unsigned id;

    virtual function void print();
        $display("header = %h || id = %0d", header, id);
    endfunction

endclass

class DataPacket extends BasePacket;
    rand bit length;

    function void print();
        super.print();
        $display("     L DataPacket || length = %b", length);
    endfunction

    constraint rand_data{
        id > 0;
        length dist{0 := 8, 1 := 2};
        (length == 0) -> (header inside{[8'd0 : 8'd50]});   // ->이거 설명부탁
        (length == 1) -> (header inside{[8'd200 : 8'd250]});
    }
endclass

class ControlPacket extends BasePacket;
    rand bit [1:0]command;  //00:reset, 01:start, 10:stop, 11:none

    function void print();
        super.print();
        $display("     L ControlPacket || command = %b", command);
    endfunction

    constraint rand_ctrl{
        id > 0;
        if (command == 2'b00 || command == 2'b10)
            header == 8'h00;
        else
            header inside {[8'h01 : 8'h05]};
    }
endclass

module tb_rand;

    initial begin
        repeat(20)begin
            if($urandom_range(0,1))begin
                DataPacket d_handle;
                d_handle = new();
                if(d_handle.randomize() == 0)begin
                    $fatal(1, "Randomization Failed!");
                end
                d_handle.print();
            end
            else begin
                ControlPacket c_handle;
                c_handle = new();
                if(c_handle.randomize() == 0)begin
                    $fatal(1,"Randomization Failed!");
                end
                c_handle.print();
            end
        end
    end
endmodule