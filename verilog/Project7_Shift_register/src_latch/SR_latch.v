module SR_latch(
input S,R,
output Q,n_Q
);

assign Q= ~(R|n_Q);
assign n_Q= ~(S|Q);
endmodule