module synchronizer#(parameter N=2)( 
	input clk, sig,
	output synsig
);
	reg [N-1:0] buffer;
	assign synsig = buffer[N-1];
	always @(posedge clk)
	buffer <= {buffer[N-2:0], sig};
endmodule