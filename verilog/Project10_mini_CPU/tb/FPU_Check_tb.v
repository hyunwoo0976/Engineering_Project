module FPU_Check_tb;
    reg clk, reset;
    reg [4:0]ID_Rs1, ID_Rs2;
    reg [4:0]EX_Rd;
    reg EX_is_FPU, ID_is_FPU;
    wire [2:0]FPU_Left;
    wire FPU_Valid;
    wire Rs1, Rs2;

    initial begin
        $dumpfile("FPU_Check.vcd");
        $dumpvars(0,FPU_Check_tb);
    end

    always #5 clk = ~clk;

    FPU_Check u_FPU_Check(
        .clk(clk),
        .reset(reset),
        .ID_Rs1(ID_Rs1),
        .ID_Rs2(ID_Rs2),
        .EX_Rd(EX_Rd),
        .ID_is_FPU(ID_is_FPU),
        .EX_is_FPU(EX_is_FPU),
        .FPU_Left(FPU_Left),
        .FPU_Valid(FPU_Valid),
        .Rs1(Rs1),
        .Rs2(Rs2)
    );

    initial begin
    clk = 1'b0;
    reset = 1'b1;
    {ID_Rs1, ID_Rs2, EX_Rd, EX_is_FPU} = 16'b0;
    ID_is_FPU = 1'b0;

    #13;
    reset = 1'b0;

    // ---- B(=20)를 먼저 밀어넣고 계속 시프트만 시킴 ----
    @(posedge clk);              // e1
    EX_is_FPU = 1'b1;
    EX_Rd     = 5'b10100;        // B = 20

    @(posedge clk);              // e2: Rd[0] <= B (valid)
    EX_is_FPU = 1'b0;            // 이후로는 새로 넣지 않고 시프트만

    @(posedge clk);              // e3: Rd[1] <= B

    @(posedge clk);              // e4: Rd[2] <= B

    @(posedge clk);              // e5: Rd[3] <= B

    @(posedge clk);              // e6: Rd[4] <= B
    EX_is_FPU = 1'b1;
    EX_Rd     = 5'b01010;        // A = 10  (다음 엣지에 Rd[0]로 새로 들어감)

    @(posedge clk);              // e7: Rd[5] <= B (거의 끝남, 2클럭 남음)
                                 //     Rd[0] <= A (방금 들어옴, 7클럭 남음)
    EX_is_FPU = 1'b0;

    // 이 시점에 Rd[0]=A(valid), Rd[5]=B(valid) 동시 존재
    ID_is_FPU = 1'b1;
    ID_Rs1 = 5'b01010;  // A → Rd[0]에서 매치 (x=0, 이론상 FPU_Left = 7-0 = 7)
    ID_Rs2 = 5'b10100;  // B → Rd[5]에서 매치 (x=5, 이론상 FPU_Left = 7-5 = 2)

    #1; // 조합 로직 안정화 대기

    $display("---- Result Check ----");
    $display("Rs1=%b, Rs2=%b, FPU_Left=%d",
               Rs1, Rs2, FPU_Left);
    $display("Expected: Rs1=1, Rs2=1, FPU_Left=7 (max of 7 and 2)");
    if (FPU_Left !== 3'd7)
        $display(">>> BUG CONFIRMED: FPU_Left=%d (Rs2 loop overwrote Rs1's larger value)", FPU_Left);
    else
        $display(">>> OK: FPU_Left correctly reflects the longer wait");

    @(posedge clk);
    ID_is_FPU = 1'b0;

    #100;
    $finish;
end

endmodule