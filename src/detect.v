module detect(input clk, a, output out);
	reg q;
	always @(posedge clk)
		q <= a;
	assign out = !q && a;
endmodule