module pseudo_random_number_generator#(parameter W = 2) (
    //input [W:0] maxvalue,
    input next, rst,
    input [6:0] d,
    output [W:0] o
);

reg [6:0] q;
wire [6:0] w;

assign w = q >> (6 - W);
assign o = ~|w[W:0] ? {1'b1, q[5:6-W]}: w[W:0];

always @(posedge next or posedge rst)
    if (rst) q <= d;
    else q <= {q[5:0], q[6] ^ q[2]};
    
endmodule