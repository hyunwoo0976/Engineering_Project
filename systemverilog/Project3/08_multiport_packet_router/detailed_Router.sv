module detailed_Router(
    input logic bv [0:2],
    input logic [1:0]bd [0:2], bp [0:2],
    input logic [15:0]bpay [0:2],
    input logic [3:0]bt [0:2],
    input logic bc [0:2],
    input logic space [0:1],
    input logic [1:0]rr,
    output logic consume [0:2], err [0:2], wen [0:1],
    output logic [24:0]wdata [0:1],
    output logic [1:0]rr_next
);
    logic good [0:2], u0, u1;
    integer p, o, k;

    always_comb begin
        for(int i=0; i<3; i++)begin
            good[i] = bc[i] == ^{bd[i], bp[i], bpay[i], bt[i]};
            consume[i] = 0;
            err[i] = 0;
        end

        wen[0] = 0; wen[1] = 0; wdata[0] = '0; wdata[1] = '0;
        u0 = 0; u1 = 0; rr_next = rr;

        for(int i=0; i<3; i++)begin
            if(bv[i] && (!good[i] || bd[i] == 3))begin
                consume[i] = 1;
                err[i] = 1;
            end
        end

        for(p=0; p<4; p++)begin
            for(o=0; o<3; o++)begin
                k = rr + o;
                if(k >= 3)begin
                    k = k - 3;
                end

                if(bv[k] && good[k] && bd[k] != 3 && bp[k] == p && !consume[k])begin
                    case(bd[k])
                        0:begin
                            if(space[0] && !u0)begin
                                consume[k] = 1;
                                u0 = 1;
                                wen[0] = 1;
                                wdata[0] = {bd[k], bp[k], bpay[k], bt[k], bc[k]};
                                rr_next = (k == 2) ? 0 : k + 1;
                            end
                        end

                        1:begin
                            if(space[1] && !u1)begin
                                consume[k] = 1;
                                u1 = 1;
                                wen[1] = 1;
                                wdata[1] = {bd[k], bp[k], bpay[k], bt[k], bc[k]};
                                rr_next = (k == 2) ? 0 : k + 1;
                            end
                        end

                        2:begin
                            if(space[0] && space[1] && !u0 && !u1)begin
                                consume[k] = 1;
                                u0 = 1;
                                u1 = 1;
                                wen[0] = 1;
                                wen[1] = 1;
                                wdata[0] = {bd[k], bp[k], bpay[k], bt[k], bc[k]};
                                wdata[1] = wdata[0];
                                rr_next = (k == 2) ? 0 : k + 1;
                            end
                        end

                        default:;
                    endcase
                end
            end
        end
    end
endmodule
