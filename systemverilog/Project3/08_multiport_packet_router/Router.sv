module Router(Router_if.DUT_Router bus);
    logic bv [0:2], bc [0:2];
    logic [1:0]bd [0:2], bp [0:2];
    logic [15:0]bpay [0:2];
    logic [3:0]bt [0:2];
    logic consume [0:2], err [0:2], space [0:1], wen [0:1], ov [0:1];
    logic [24:0]wd [0:1], od [0:1];
    logic [1:0]rr, rr_next;

    detailed_Router arb(
        bv, bd, bp, bpay, bt, bc, space, rr, consume, err, wen, wd, rr_next
    );

    FIFOQ f0(
        bus.clk, bus.reset, wen[0], wd[0], space[0], ov[0], bus.out_ready[0], od[0]
    );

    FIFOQ f1(
        bus.clk, bus.reset, wen[1], wd[1], space[1], ov[1], bus.out_ready[1], od[1]
    );

    generate
        for(genvar i=0; i<3; i++)begin
            assign bus.ready[i] = !bv[i] || consume[i];
            assign bus.error[i] = err[i];
        end

        for(genvar q=0; q<2; q++)begin
            assign bus.out_valid[q] = ov[q];
            assign bus.out_dest[q] = od[q][24:23];
            assign bus.out_prio[q] = od[q][22:21];
            assign bus.out_payload[q] = od[q][20:5];
            assign bus.out_tag[q] = od[q][4:1];
            assign bus.out_checksum[q] = od[q][0];
        end
    endgenerate

    always_ff @(posedge bus.clk or posedge bus.reset)begin
        if(bus.reset)begin
            rr <= 0;
            for(int i=0; i<3; i++)begin
                bv[i] <= 0;
                bd[i] <= '0;
                bp[i] <= '0;
                bpay[i] <= '0;
                bt[i] <= '0;
                bc[i] <= 0;
            end
        end
        else begin
            rr <= rr_next;
            for(int i=0; i<3; i++)begin
                if(bus.ready[i])begin
                    bv[i] <= bus.valid[i];
                    if(bus.valid[i])begin
                        bd[i] <= bus.dest[i];
                        bp[i] <= bus.prio[i];
                        bpay[i] <= bus.payload[i];
                        bt[i] <= bus.tag[i];
                        bc[i] <= bus.checksum[i];
                    end
                end
            end
        end
    end
endmodule
