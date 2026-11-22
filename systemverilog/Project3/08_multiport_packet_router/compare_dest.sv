module compare_dest(Router_if.DUT_Router bus,output logic [24:0]out0,out1);
    logic f0,f1;
    logic [1:0]p0,p1;
    always_comb begin 
        out0 = '0; out1 = '0; f0 = 0; f1 = 0; p0 = 3; p1 = 3;
        for(int i=0; i<3; i++)begin
            if(bus.valid[i] && bus.checksum[i] == ^{bus.dest[i], bus.prio[i], bus.payload[i], bus.tag[i]})begin
                if((bus.dest[i] == 0 || bus.dest[i] == 2) && (!f0 || bus.prio[i] < p0))begin 
                    f0 = 1; p0 = bus.prio[i]; out0 = {bus.dest[i], bus.prio[i], bus.payload[i], bus.tag[i], bus.checksum[i]};
                end
                if((bus.dest[i] == 1 || bus.dest[i] == 2) && (!f1 || bus.prio[i] < p1))begin
                    f1 = 1; p1 = bus.prio[i]; out1 = {bus.dest[i], bus.prio[i], bus.payload[i], bus.tag[i], bus.checksum[i]};
                end
            end
        end
    end
endmodule
