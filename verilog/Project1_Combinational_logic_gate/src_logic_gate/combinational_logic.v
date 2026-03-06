module combinational_logic(x,y,z,f);
    input x,y,z;
    output f;

    wire w_inv_x, w_inv_z;
    wire w_and3_0, w_and3_1, w_and2_0;

    not inv_x(w_inv_x,x);
    not inv_z(w_inv_z,z);

    and and3_0(w_and3_0,w_inv_x,y,z);
    and and3_1(w_and3_1,w_inv_x,y,w_inv_z);
    and and2_0(w_and2_0,x,z);

    or or3_0(f,w_and3_0,w_and3_1,w_and2_0);
endmodule