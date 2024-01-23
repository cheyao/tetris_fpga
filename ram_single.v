module ram_single( //powinno zmapować się na MLAB - jednoportowe z asnc odczytem
    output [23:0] q,
    input [4:0] a,
    input [23:0] d,
    input we, clk
);

reg [23:0] mem [20:0];

initial mem[20] = 24'hF;

assign q = mem[a];

    always @(posedge clk) begin
        if (we) mem[a] <= d;

    end
endmodule