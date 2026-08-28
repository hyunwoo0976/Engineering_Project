module q_test;
    int q[$];                 // 빈 큐
    localparam int MAXQ = 4;  // 최대 3개만 유지

    initial begin
        for (int n = 1; n <= 6; n++) begin
            q.push_front(n);                    // 맨 앞에 n 추가
            if (q.size() > MAXQ) q.pop_back();  // 넘치면 맨 뒤(오래된 것) 버림
            $write("n=%0d  ->  q = ", n);
            foreach (q[i]) $write("%0d ", q[i]); // 큐 전체 훑어서 출력
            $display("(size=%0d)", q.size());
        end
        $display("recent q[0]=%0d,  old q[%0d]=%0d", q[0], q.size()-1, q[q.size()-1]);
    end
endmodule