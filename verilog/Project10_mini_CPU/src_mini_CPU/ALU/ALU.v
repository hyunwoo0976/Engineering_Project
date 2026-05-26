module ALU #(parameter W=32)(
    input [W-1:0]A,
    input [W-1:0]B,
    input [3:0]ALU_Control,
    output [W-1:0]Result,
    output ZF,sign
);
    wire [W-1:0]logic_result, calculate_result, shift_result;

    logical_group #(.W(W)) logic(
        .A(A),
        .B(B),
        .ALU_Control(ALU_Control),
        .logic_result(logic_result)
    );

    calculate_group #(.W(W)) Adder(
        .A(A),
        .B(B),
        .ALU_Control(ALU_Control),
        .calculate_result(calculate_result),
        .ZF(ZF),
        .sign(sign)
    );

    shift_group #(.W(W)) shift(
        .A(A),
        .B(B),
        .ALU_Control(ALU_Control),
        .shift_result(shift_result)
    );

    ALU_MUX #(.W(W)) MUX(
        .logic_result(logic_result),
        .calculate_result(calculate_result),
        .shift_result(shift_result),
        .ALU_Control(ALU_Control),
        .ALU_result(Result)
    );
endmodule