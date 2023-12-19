module synchronizer#(parameter N=2)( 
	input clk, sig,
	output synsig
);
	reg [N-1:0] buffer;
	assign synsig = buffer[N-1];
	always @(posedge clk)
	buffer <= {buffer[N-2:0], sig};
endmodule

//----------------------------------------------------------

module seg7(input [3:0] n, output [6:0] o);
  
  assign o[0] = (n == 4'h1 || n == 4'h4);
  assign o[1] = (n == 4'h1 || n == 4'h5 || n == 4'h6 
                  || n == 4'hc || n == 4'he || n == 4'hf);
  assign o[2] = (n == 4'h1 || n == 4'h2 || n == 4'hc
                  || n == 4'he || n == 4'hf);
  assign o[3] = (n == 4'h1 || n == 4'h4 || n == 4'h7
                  || n == 4'ha || n == 4'hf);
  assign o[4] = (n == 4'h3 || n == 4'h5 || n == 4'h7
                  || n == 4'h9 || n == 4'h4);
  assign o[5] = (n == 4'h2 || n == 4'h3 || n == 4'h7);
  assign o[6] = (n == 4'h0 || n == 4'h1 || n == 4'h7
                  || n == 4'hc || n == 4'hd);
  
endmodule

//----------------------------------------------------------

module detect(input clk, a, output out);
	reg q;
	always @(posedge clk)
		q <= a;
	assign out = !q && a;
endmodule

//----------------------------------------------------------

module Tetris(

	//////////// Audio //////////
	input 		          		AUD_ADCDAT,
	inout 		          		AUD_ADCLRCK,
	inout 		          		AUD_BCLK,
	output		          		AUD_DACDAT,
	inout 		          		AUD_DACLRCK,
	output		          		AUD_XCK,

	//////////// CLOCK //////////
	input 		          		CLOCK2_50,
	input 		          		CLOCK3_50,
	input 		          		CLOCK4_50,
	input 		          		CLOCK_50,

	//////////// I2C for Audio and Video-In //////////
	output		          		FPGA_I2C_SCLK,
	inout 		          		FPGA_I2C_SDAT,

	//////////// SEG7 //////////
	output		     [6:0]		HEX0,
	output		     [6:0]		HEX1,
	output		     [6:0]		HEX2,
	output		     [6:0]		HEX3,
	output		     [6:0]		HEX4,
	output		     [6:0]		HEX5,

	//////////// KEY //////////
	input 		     [3:0]		KEY,

	//////////// VGA //////////
	output		          		VGA_BLANK_N,
	output		     [7:0]		VGA_B, 
	output		          		VGA_CLK,
	output		     [7:0]		VGA_G,
	output		          		VGA_HS,
	output		     [7:0]		VGA_R, 
	output		          		VGA_SYNC_N,
	output		          		VGA_VS //
);

wire clk;
clock_divider pll(clk, CLOCK_50, !KEY[3]);

// delayed keys signals
wire down; 
wire rotation;
wire left;
wire right;
//muszę znaleźć inny reset
wire [3:0] click; // clicking detectors

synchronizer syn_key1(clk, ~KEY[0], right);
synchronizer syn_key2(clk, ~KEY[1], left);
synchronizer syn_key3(clk, ~KEY[2], rotation);
synchronizer syn_key4(clk, ~KEY[3], down);
detect click_det0(clk, right, click[0]);
detect click_det1(clk, left, click[1]);
detect click_det2(clk, rotation, click[2]);
detect click_det3(clk, down, click[3]);

//=======================================================
//  VGA controler
//=======================================================

wire [8:0] r; //row
wire [9:0] c; //column

assign VGA_CLK = clk;

color_generator cg(clk, !KEY[3], VGA_BLANK_N, r, c, VGA_R, VGA_G, VGA_B);
VGA_sync vga(clk, !KEY[3], VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, r, c);

//=======================================================
//  Game memory
//=======================================================

wire [23:0] columns [9:0];
wire [4:0] row;
wire [23:0] d [9:0]; //zwykle kolor klocka, ale nie np przy burzeniu linii
wire we [9:0];

generate
	genvar i;
	for (i = 0; i < 10; i = i+1) begin : rams
		ram_single ram(columns[i], row, d[i], we[i], clk);
	end
endgenerate

//=======================================================
//  Game logic
//=======================================================

localparam [2:0] 	I = 3'b000, T = 3'b001, O = 3'b010, L = 3'b011, 
					J = 3'b100, S = 3'b101, Z = 3'b111;

localparam [2:0]	START_SCREEN = 3'b000, COUNTING = 3'b001, 
					START_FALLING = 3'b010, STATIC_FALL = 3'b011, 
					DYNAMIC_FALL = 3'b100, DISTROY_LINE = 3'b101, FAIL = 3'b111;

reg [9:0] distroyed_lines; //rekord niejasny, koło 400
reg [10:0] score; //jak liczyć to kiedyś potem, rekord - 1,62 miliona
reg [5:0] level; //rekord 33


endmodule