module standard_logic(
    input x,y,z,
    output f
);

assign f=(~x)&y|x&z;

endmodule