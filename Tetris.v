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
	output		          		VGA_VS,

	///// wyjścia podglądowe ////
	output [2:0] next_block,
	output reg gen_next_block //
);

wire clk;
assign clk = CLOCK_50;
//WYRZUCONE DO SYMULACJI, MUSI WRÓCIĆ DO ODPALENIA SPRZĘTOWEGO
//clock_divider pll(clk, CLOCK_50, 0);

// delayed keys signals
wire down; 
wire rotation;
wire left;
wire right;
//muszę znaleźć inny reset
wire [3:0] click; // clicking detectors

synchronizer syn_key1(clk, ~KEY[0], right); //wymaga zmiany
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
wire board; //am i painting the board or not

assign VGA_CLK = clk;

//sprawdzić czy 0 czy 1 zadziała jako reset
color_generator cg(clk, 0, VGA_BLANK_N, r, c, block, next_block, sq1, sq2, sq3, sq4, board, VGA_R, VGA_G, VGA_B);
VGA_sync vga(clk, 0, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, r, c);

//=======================================================
//  Game memory
//=======================================================

wire [23:0] ram_columns [9:0];
reg [4:0] ram_row;
wire [23:0] d [9:0]; //zwykle kolor klocka, ale nie np przy burzeniu linii
reg we [9:0]; //!!!

generate
	genvar i;
	for (i = 0; i < 10; i = i+1) begin : rams
		ram_single ram(ram_columns[i], ram_row, d[i], we[i], clk);
	end
/*
	for(i = 0; i<10; i = i+1) begin : data
		assign d[i] = (q == )
	end*/
endgenerate



//colors
localparam [23:0]   LIGHT_ROSE = {8'd255, 8'd204, 8'd229}, 
					PURPLE = {8'd255, 8'd153, 8'd255},
					LIGHT_GREY = {8'd160, 8'd160, 8'd160},
					DARK_GREY = {8'd96, 8'd96, 8'd96},
					MINTY = {8'd153, 8'd255, 8'd204},
					BLUE = {8'd102, 8'd178, 8'd255},
					PINK = {8'd255, 8'd51, 8'd153},
					DARK_PURPLE = {8'd127, 8'd0, 8'd255},
					YELLOW = {8'd255, 8'd255, 8'd102},
					GREEN = {8'd102, 8'd255, 8'd102},
					PLUM = {8'd153, 8'd0, 8'd153};

wire [23:0] i_color, t_color, o_color, l_color, j_color, s_color, z_color;
assign i_color = MINTY;
assign t_color = BLUE;
assign o_color = PINK;
assign l_color = DARK_PURPLE;
assign j_color = YELLOW;
assign s_color = GREEN;
assign z_color = PLUM;

reg [23:0] block_color;

//=======================================================
//  Game logic
//=======================================================

localparam [2:0] 	I = 3'b111, T = 3'b001, O = 3'b010, L = 3'b011, 
					J = 3'b100, S = 3'b101, Z = 3'b110;

localparam [2:0]	START_SCREEN = 3'b000, COUNTING = 3'b001, 
					START_FALLING = 3'b010, STATIC_FALL = 3'b011, 
					DYNAMIC_FALL = 3'b100, DISTROY_LINE = 3'b101, FAIL = 3'b111;

reg [2:0] q;

reg [9:0] distroyed_lines; //rekord niejasny, koło 400
reg [10:0] score; //jak liczyć to kiedyś potem, rekord - 1,62 miliona
reg [5:0] level; //rekord 33

reg [5:0] wait_cnt; //licznik zatrzymania w jednym miejscu (w klatkach)
reg [5:0] speed; //granica oczekiwania (w klatkach)

reg [8:0] seed; //liczy czas od resetu/przegrania gry do startu i jest ziarnem dla generowania pseudolosowości
//wire [2:0] next_block;
//wire gen_next_block; //potem chyba jednak reg
reg [2:0] block;
reg rand_rst;

pseudo_random_number_generator ps_rand(gen_next_block, rand_rst, seed, next_block);

wire frame_passed;

detect frame_det(clk, VGA_VS, frame_passed);

//localization points
//borders: left, right up, down
reg [9:0] sq1 [3:0], sq2 [3:0], sq3 [3:0], sq4 [3:0];

always @(posedge clk or negedge KEY[3]) begin

	if(!KEY[3]) begin 
		rand_rst <= 1; 
		speed <= 6'd1; //żałosne tak naprawdę, ale żeby się nie zesrała ta symulacja
	end
	else begin
		seed <= seed + 1;
		rand_rst <= 0;
		gen_next_block <= 0;
		
		if(click[0]) begin
			block <= next_block;
			gen_next_block <= 1;
			wait_cnt <= 0;

			case(next_block)

			I: 	begin

				sq1 <= {10'd280, 10'd300, 10'd20, 10'd40};
				sq2 <= {10'd300, 10'd320, 10'd20, 10'd40};
				sq3 <= {10'd320, 10'd340, 10'd20, 10'd40};
				sq4 <= {10'd340, 10'd360, 10'd20, 10'd40};
				
				end

			T:	begin

				sq1 <= {10'd320, 10'd340, 10'd0, 10'd20};
				sq2 <= {10'd300, 10'd320, 10'd20, 10'd40};
				sq3 <= {10'd320, 10'd340, 10'd20, 10'd40};
				sq4 <= {10'd340, 10'd360, 10'd20, 10'd40};
				
				end

			O:	begin

				sq1 <= {10'd300, 10'd320, 10'd0, 10'd20};
				sq2 <= {10'd300, 10'd320, 10'd20, 10'd40};
				sq3 <= {10'd320, 10'd340, 10'd20, 10'd40};
				sq4 <= {10'd320, 10'd340, 10'd0, 10'd20};
				
				end

			L:	begin

				sq1 <= {10'd340, 10'd360, 10'd0, 10'd20};
				sq2 <= {10'd300, 10'd320, 10'd20, 10'd40};
				sq3 <= {10'd320, 10'd340, 10'd20, 10'd40};
				sq4 <= {10'd340, 10'd360, 10'd20, 10'd40};
				
				end

			J:	begin

				sq1 <= {10'd300, 10'd320, 10'd0, 10'd20};
				sq2 <= {10'd300, 10'd320, 10'd20, 10'd40};
				sq3 <= {10'd320, 10'd340, 10'd20, 10'd40};
				sq4 <= {10'd340, 10'd360, 10'd20, 10'd40};
				
				end

			S:	begin

				sq1 <= {10'd320, 10'd340, 10'd0, 10'd20};
				sq2 <= {10'd300, 10'd320, 10'd20, 10'd40};
				sq3 <= {10'd320, 10'd340, 10'd20, 10'd40};
				sq4 <= {10'd340, 10'd360, 10'd0, 10'd20};
				
				end

			Z:	begin

				sq1 <= {10'd320, 10'd340, 10'd20, 10'd40};
				sq2 <= {10'd300, 10'd320, 10'd0, 10'd20};
				sq3 <= {10'd320, 10'd340, 10'd0, 10'd20};
				sq4 <= {10'd340, 10'd360, 10'd20, 10'd40};
				
				end

			default: begin
				sq1 <= {10'd0, 10'd0, 10'd0, 10'd0};
				sq2 <= {10'd0, 10'd0, 10'd0, 10'd0};
				sq3 <= {10'd0, 10'd0, 10'd0, 10'd0};
				sq4 <= {10'd0, 10'd0, 10'd0, 10'd0};
				
				end

			endcase
		end

		//fall
		if(sq1[0] < 10'd439 && sq2[0] < 10'd439 && sq3[0] < 10'd439 && sq4[0] < 10'd439) begin
			if(wait_cnt < speed)
				begin
					if(frame_passed)
						wait_cnt <= wait_cnt + 1;
				end
			else begin
				sq1[0] <= sq1[0] + 1;
				sq1[1] <= sq1[1] + 1;
				sq2[0] <= sq2[0] + 1;
				sq2[1] <= sq2[1] + 1;
				sq3[0] <= sq3[0] + 1;
				sq3[1] <= sq3[1] + 1;
				sq4[0] <= sq4[0] + 1;
				sq4[1] <= sq4[1] + 1;
				wait_cnt <= 0;
			end
		end

	end

end

endmodule