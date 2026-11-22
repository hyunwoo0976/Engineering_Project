`default_nettype none
// Fixed seven-register latency; ADD/SUB and MUL retain separate cores.
module FPU #(parameter W = 32, parameter ISOLATE = 1)(
    input wire [W-1:0] IN_A, IN_B,
    input wire [1:0] op,
    input wire [2:0] rm,
    input wire FPU_en, clk, reset,
    output reg [W-1:0] result_out,
    output reg error, OF, UF, NV, NX,
    output wire ZF, sign,
    output reg valid_out
);
    wire special_in, illegal_in;
    wire [31:0] special_result_in;
    wire [4:0] special_flags_in;
    FP_special u_special(
        .a(IN_A),
        .b(IN_B),
        .op(op),
        .rm(rm),
        .FPU_en(FPU_en),
        .special(special_in),
        .result(special_result_in),
        .flags(special_flags_in),
        .illegal(illegal_in),
        .effective_EXPO_A(),
        .effective_EXPO_B()
    );

    // a1/b1 are arithmetic operand registers; the special packet is independent.
    reg [31:0] a1, b1;
    reg [5:0] valid_pipe;
    reg [38:0] special_packet[0:5];  // {special, illegal, flags[4:0], result[31:0]}
    reg [2:0] rm_pipe[0:5];
    reg [1:0] op_pipe[0:5];
    integer i;
    wire core_en = valid_pipe[0] && (!ISOLATE || !special_packet[0][38]);
    wire s1_SIGN_A, s1_SIGN_B;
    wire [7:0] s1_EXPO_A, s1_EXPO_B;
    wire [22:0] s1_FRAC_A, s1_FRAC_B;
    FPU_unpack unpack_a(
        .IN(a1),
        .FPU_en(1'b1),
        .SIGN(s1_SIGN_A),
        .EXPO(s1_EXPO_A),
        .FRAC(s1_FRAC_A)
    );
    FPU_unpack unpack_b(
        .IN(b1),
        .FPU_en(1'b1),
        .SIGN(s1_SIGN_B),
        .EXPO(s1_EXPO_B),
        .FRAC(s1_FRAC_B)
    );

    wire [31:0] add_result, mul_result;
    wire add_error, add_of, add_uf, add_nx, mul_of, mul_uf, mul_nx;
    FADD_core u_FADD_core(
        .clk(clk),
        .reset(reset),
        .s1_en(core_en),
        .s1_SIGN_A(s1_SIGN_A),
        .s1_SIGN_B(s1_SIGN_B),
        .s1_EXPO_A(s1_EXPO_A),
        .s1_EXPO_B(s1_EXPO_B),
        .s1_FRAC_A(s1_FRAC_A),
        .s1_FRAC_B(s1_FRAC_B),
        .s1_op(op_pipe[0][0]),
        .s6_rm(rm_pipe[5]),
        .s6_ADD_out(add_result),
        .s6_error(add_error),
        .s6_OF(add_of),
        .s6_UF(add_uf),
        .s6_NX(add_nx)
    );
    FMUL_core u_FMUL_core(
        .clk(clk),
        .reset(reset),
        .s1_en(core_en),
        .s1_SIGN_A(s1_SIGN_A),
        .s1_SIGN_B(s1_SIGN_B),
        .s1_EXPO_A(s1_EXPO_A),
        .s1_EXPO_B(s1_EXPO_B),
        .s1_FRAC_A(s1_FRAC_A),
        .s1_FRAC_B(s1_FRAC_B),
        .s4_rm(rm_pipe[3]),
        .s6_MUL_out(mul_result),
        .s6_OF(mul_of),
        .s6_UF(mul_uf),
        .s6_NX(mul_nx)
    );

    wire is_mul = (op_pipe[5] == 2'd2);
    wire [31:0] arithmetic_result = is_mul ? mul_result : add_result;
    wire [4:0] arithmetic_flags = is_mul ? {2'b0, mul_of, mul_uf, mul_nx} : {2'b0, add_of, add_uf, add_nx};
    wire [31:0] selected_result;
    Final_MUX final_mux(
        .special(special_packet[5][38]),
        .Final_out(arithmetic_result),
        .result(special_packet[5][31:0]),
        .Answer(selected_result)
    );
    wire [4:0] selected_flags = special_packet[5][38] ? special_packet[5][36:32] : arithmetic_flags;
    wire selected_error = special_packet[5][37] || selected_flags[4];
    assign ZF = (result_out[30:0] == 0);
    assign sign = result_out[31];

    always @(posedge clk or posedge reset)begin
        if(reset)begin
            a1 <= 0;
            b1 <= 0;
            valid_pipe <= 0;
            valid_out <= 0;
            result_out <= 0;
            error <= 0;
            OF <= 0;
            UF <= 0;
            NV <= 0;
            NX <= 0;
            for(i = 0; i < 6; i = i + 1)begin
                special_packet[i] <= 0;
                rm_pipe[i] <= 0;
                op_pipe[i] <= 0;
            end
        end
        else begin
            if(!ISOLATE || (FPU_en && !special_in))begin
                a1 <= IN_A;
                b1 <= IN_B;
            end
            valid_pipe <= {valid_pipe[4:0], FPU_en};
            special_packet[0] <= {special_in, illegal_in, special_flags_in, special_result_in};
            rm_pipe[0] <= rm;
            op_pipe[0] <= op;
            for(i = 1; i < 6; i = i + 1)begin
                special_packet[i] <= special_packet[i-1];
                rm_pipe[i] <= rm_pipe[i-1];
                op_pipe[i] <= op_pipe[i-1];
            end
            valid_out <= valid_pipe[5];
            if(valid_pipe[5])begin
                result_out <= selected_result;
                error <= selected_error;
                NV <= selected_flags[4];
                OF <= selected_flags[2];
                UF <= selected_flags[1];
                NX <= selected_flags[0];
            end
            else begin
                error <= 0;
                NV <= 0;
                OF <= 0;
                UF <= 0;
                NX <= 0;
            end
        end
    end
endmodule
`default_nettype wire
