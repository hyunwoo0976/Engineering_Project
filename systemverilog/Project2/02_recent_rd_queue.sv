/*
Project2/q_recent_practice.sv를 직접 작성해봐.
목표는 최근 생산자 Rd를 최대 3개까지만 기억하는 거야.
요구사항:
1. 5비트 레지스터 번호를 저장하는 큐 recent_rd를 선언한다.
2. 최대 크기를 나타내는 MAXQ=3을 선언한다.
3. 다음 Rd를 순서대로 큐의 앞에 넣는다.
x5 → x9 → x12 → x7
4. 하나를 넣을 때마다:
현재 크기가 MAXQ보다 크면
가장 오래된 원소를 뒤에서 제거
5. 모든 삽입이 끝나면 다음을 출력한다.
   - 큐 전체
   - 큐 크기
   - 거리 1의 Rd
   - 거리 2의 Rd
   - 거리 3의 Rd
뼈대만 보면 다음 구조야.
module q_recent_practice;

    // TODO: recent_rd 큐 선언
    // TODO: MAXQ 선언

    initial begin
        // TODO: x5 삽입 후 크기 제한
        // TODO: x9 삽입 후 크기 제한
        // TODO: x12 삽입 후 크기 제한
        // TODO: x7 삽입 후 크기 제한

        // TODO: 큐 크기와 각 거리의 Rd 출력
    end

endmodule
먼저 실행 결과를 예측해봐야 해.
- 마지막 큐 전체:
- 제거되는 Rd:
- 최종 size():
- 거리 2의 Rd:
그다음 코드를 직접 작성해서 보여줘. 반복문 사용 여부는 네가 결정하면 된다.
*/

module q_recent_practice;
    bit[4:0]recent_rd[$];
    localparam int MAXQ = 3;
    int distance = 1;
    bit [4:0]arr[4] = {5'd5, 5'd9, 5'd12, 5'd7};

    initial begin
        for(int i = 1;i<5;i++)begin
            recent_rd.push_front(arr[i-1]);
            if(recent_rd.size() > MAXQ) recent_rd.pop_back();
            $write("Q size = %0d", recent_rd.size());
            foreach(recent_rd[j]) $write(" || q = %0d", recent_rd[j]);
            $display("||");
            $display("distance %0d : Rd = recent_rd[%0d] = %0d", i, i - 1, recent_rd[0]);
            $display(" ");
        end

        // TODO: x5 삽입 후 크기 제한
        // TODO: x9 삽입 후 크기 제한
        // TODO: x12 삽입 후 크기 제한
        // TODO: x7 삽입 후 크기 제한
        $write("FINAL Q size = %0d", recent_rd.size());
        foreach(recent_rd[i]) $write(" || q = %0d", recent_rd[i]);
        // TODO: 큐 크기와 각 거리의 Rd 출력
    end

endmodule