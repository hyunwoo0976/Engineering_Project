interface Router_if(input logic clk);
    logic reset;
    logic valid [0:2], ready [0:2], checksum [0:2], error [0:2];
    logic [1:0]dest [0:2], prio [0:2];
    logic [15:0]payload [0:2];
    logic [3:0]tag [0:2];
    logic out_valid [0:1], out_ready [0:1], out_checksum [0:1];
    logic [1:0]out_dest [0:1], out_prio [0:1];
    logic [15:0]out_payload [0:1];
    logic [3:0]out_tag [0:1];

    clocking cb @(posedge clk);
        default input #1step output #0;
        output reset, valid, dest, prio, payload, tag, checksum, out_ready;
        input ready, error, out_valid, out_dest, out_prio, out_payload, out_tag, out_checksum;
    endclocking

    modport DUT_Router(
        input clk, reset, valid, dest, prio, payload, tag, checksum, out_ready,
        output ready, error, out_valid, out_dest, out_prio, out_payload, out_tag, out_checksum
    );

    modport TB(
        clocking cb
    );
endinterface
