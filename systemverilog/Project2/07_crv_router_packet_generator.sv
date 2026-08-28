/*
1. 개요
본 과제는 SystemVerilog의 객체 지향 프로그래밍(OOP)과 제약 기반 무작위 생성(Constrained-Random) 핵심 문법을 종합적으로 활용하여,
가상의 네트워크 라우터용 패킷 생성기(Packet Generator)를 직접 설계하는 과제입니다.
제공되는 소스 코드 없이 아래 요구사항에 맞춰 빈 파일에서부터 직접 코드를 작성해야 합니다.

2. 세부 요구사항
클래스 설계 및 상속 (OOP)

부모 클래스인 BasePacket을 정의하고, 공통 속성으로 rand bit [7:0] header, rand int id를 선언합니다.

BasePacket을 상속받는 자식 클래스 DataPacket과 ControlPacket을 각각 구현합니다.

가상 메서드(virtual function)를 활용하여 각 패킷 종류별로 고유의 출력 동작을 수행하도록 합니다.

제약 조건 (Constraints)

DataPacket 클래스 내부에 다음 제약 조건을 반드시 포함해야 합니다.

header 값은 특정 범위(예: 10~50 또는 200~250) 내에 존재하도록 inside 연산자를 사용합니다.

패킷의 크기를 나타내는 rand int length는 가중치 분산(dist)을 적용하여 짧은 패킷과 긴 패킷의 생성 비율을 다르게 설정합니다
(예: 소형 패킷 80%, 대형 패킷 20%).

특정 조건 변수(예: rand bit is_urgent)의 상태에 따라 주소나 페이로드의 제약 조건이 동적으로 바뀌도록 조건부 제약문(if-else)
또는 변수 간 의존성(solve-before)을 적용합니다.

인라인 제약 및 후처리 함수 (post_randomize)

테스트벤치 본문에서 randomize()를 호출할 때 인라인 제약(Inline Constraint)(with { ... })을 사용하여 특정 테스트 케이스를 강제 주입합니다.

post_randomize() 함수를 클래스 내부에 정의하여, 무작위화가 완료된 직후 자동으로 패킷의 무결성 검증용 값(예: 체크섬)을 계산하거나
생성 완료 메시지를 출력하도록 합니다.

테스트벤치 (tb_comprehensive) 구조

최상위 모듈 내에서 initial 블록을 생성합니다.

다형성(Polymorphism)을 활용하여 부모 클래스 핸들러로 자식 클래스 객체들을 통제합니다.

repeat 반복문을 사용하여 총 20개의 패킷을 연속으로 생성하고, 매 반복마다 randomize()의 성공 여부를 검사하여 실패 시 $fatal로 중단시킵니다.

생성된 각 패킷의 필드 값들을 가독성 높은 형식의 $display 문으로 Tcl Console에 출력합니다.

3. 완료 기준 (Checklist)
상속, 다형성, constraint, dist, post_randomize, 인라인 제약이 모두 포함되어야 합니다.

Vivado 시뮬레이션 실행 시 컴파일 에러 없이 Tcl Console에 20개의 패킷 정보가 제약 조건 범위 내에서 무작위로 정상 출력되어야 합니다.
*/

//////////////////////////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2026/08/14 10:01:59
// Design Name:
// Module Name: tb_rand
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

class BasePacket;
    rand bit[7:0]header;
    rand int id;

    virtual function void print();
        $display("header = %h || id = %d", header, id);
    endfunction
endclass

class DataPacket extends BasePacket;
    rand bit length;
    constraint rand_data{
        header inside {[8'd10 : 8'd50], [8'd200 : 8'd250]};
        id > 0;
        length dist{0 := 8, 1 := 2};
        if (length == 0) header inside {[8'd10 : 8'd50]};
        if (length == 1) header inside {[8'd200 : 8'd250]};
    }

    function void print();
        super.print();
        $display("  length = %b", length);
    endfunction
endclass

class ControlPacket extends BasePacket;
    rand bit is_urgent;
    rand bit[1:0]command;

    constraint rand_urgent{
        if(command == 2'b00 || command == 2'b11) is_urgent == 0; //reset, Stop
        else is_urgent == 1; //read, write
        if(is_urgent == 0) header == 0;
    }

    function void print();
        super.print();
        $display("  command = %b || is_urgent = %b", command, is_urgent);
    endfunction
endclass

class Generator;
    mailbox #(BasePacket)mb;

    function new(mailbox #(BasePacket)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(10)begin
                BasePacket handle;
                if ($urandom_range(0, 1) == 32'b1) begin
                    DataPacket dp = new();
                    if(!dp.randomize() with{length == 1;})begin
                        $fatal(1,"BasePacket ERROR");
                    end
                    handle = dp;
                end
                else begin
                    ControlPacket cp = new();
                    if(!cp.randomize() with{is_urgent == 0;})begin
                        $fatal(1,"BasePacket ERROR");
                    end
                    handle = cp;
                end
                mb.put(handle);
            end
        end
    endtask
endclass

class Consumer;
    mailbox #(BasePacket)mb;

    function new(mailbox #(BasePacket)mb);
        this.mb = mb;
    endfunction

    task run;
        begin
            repeat(10)begin
                BasePacket handle;
                mb.get(handle);
                handle.print();
            end
        end
    endtask
endclass

module Top;
    mailbox #(BasePacket)mb = new();

    Generator gen = new(mb);
    Consumer con = new(mb);

    initial begin
        fork
            gen.run();
            con.run();
        join
    end
endmodule
