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

//sprawdzić czy 0 czy 1 zadziała jako reset
color_generator cg(clk, !KEY[3], VGA_BLANK_N, r, c, VGA_R, VGA_G, VGA_B);
VGA_sync vga(clk, !KEY[3], VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, r, c);

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

	for(i = 0; i<10; i = i+1) begin : data
		assign d[i] = (q == )
	end
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

localparam [2:0] 	I = 3'b000, T = 3'b001, O = 3'b010, L = 3'b011, 
					J = 3'b100, S = 3'b101, Z = 3'b111;

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
wire [2:0] block;
reg next_block;
reg rand_rst;
pseudo_random_number_generator rand(next_block, rand_rst, seed, block);
//10 cykli oczekiwania na info czy coś jest z boku nie zakoli jeśli tak długo maluję ekran
//być może trzeba by było dodać reset
always @(posedge clk or negedge KEY[3]) begin

	if(!KEY[3]) begin

		seed <= 0;
		q <= START_SCREEN;
		speed <= 5'd60;
		wait_cnt <= 0;

	end
	else begin
		seed <= seed + 1;
		next_block <= 0;
		rand_rst <= 0;
		we <= 0;
		//ram_row <= row;

		case(q)

		START_SCREEN: 	begin
							speed <= 5'd30;
							wait_cnt <= 0;
							row <= 0;
							ram_row <= 0;
							if(rotation) begin 
								q <= START_FALLING; //key[2] (rotation) jako start spadania
								rand_rst <= 1; //wprowadzam ziarno pseudolosowości
							end
						end

		//będę tu modyfikować tylko ram, a całe wyświetlanie wydarzy się gdzieś indziej

		START_FALLING: 	begin
							//next_block <= 1; to się musi pojawiać przy wchodzeniu do tego stanu
							//row <= 0; to też
							
							wait_cnt <= 0;

							if(q == START_SCREEN) begin
								case(block)

								I: block_color <= i_color;
								T: block_color <= t_color;
								O: block_color <= o_color;
								L: block_color <= l_color;
								J: block_color <= j_color;
								S: block_color <= s_color;
								Z: block_color <= z_color;

								endcase
							end
							else begin
								case(block)
								
								
								//tło oznaczane jako 0
								I: 	begin
										if(!|ram_columns[4]) begin
											we <= 1;
											q <= STATIC_FALL;
										end
										else q <= FAIL;
									end

								T:	begin
										if(!|ram_columns[5]) begin
											we <= 1;
											q <= STATIC_FALL;
										end
										else q <= FAIL;
									end

								O:	begin
										if(!|ram_columns[4] && !|ram_columns[5]) begin
											we <= 1;
											q <= STATIC_FALL;
										end
										else q <= FAIL;
									end

								L:	begin
										if(!|ram_columns[5] && !|ram_columns[6]) begin
											we <= 1;
											q <= STATIC_FALL;
										end
										else q <= FAIL;
									end

								J:	begin
										if(!|ram_columns[5] && !|ram_columns[6]) begin
											we <= 1;
											q <= STATIC_FALL;
										end
										else q <= FAIL;
									end

								S:	begin
										if(!|ram_columns[4] && !|ram_columns[5]) begin
											we <= 1;
											q <= STATIC_FALL;
										end
										else q <= FAIL;
									end

								Z:	begin
										if(!|ram_columns[4] && !|ram_columns[5]) begin
											we <= 1;
											q <= STATIC_FALL;
										end
										else q <= FAIL;
									end

								endcase
							end
						end

		DYNAMIC_FALL:	begin //row i column zapamiętają koordynaty MIEJSCA W KTÓRE CHCĘ PRZESUNĄĆ najbardziej wysunięty w dół (i w lewo jeśli robi różnicę) element, po rodzaju i rotacji odtworzę resztę klocka
							case(block)								
								
							//tło oznaczane jako 0
							I: 	begin
									if(!|ram_columns[column]) begin //jestem w row, tam gdzie chcę
										we <= 1;
									end
									else q <= FAIL;
								end

							T:	begin
									if(!|ram_columns[column]) begin
										we <= 1;
									end
									else q <= FAIL;
								end

							O:	begin
									if(!|ram_columns[column] && !|ram_columns[column + 1]) begin
										we <= 1;
									end
									else q <= FAIL;
								end

							L:	begin
									if(!|ram_columns[column] && !|ram_columns[column + 1]) begin
										we <= 1;
									end
									else q <= FAIL;
								end

							J:	begin
									if(!|ram_columns[column] && !|ram_columns[column + 1]) begin
										we <= 1;
									end
									else q <= FAIL;
								end

							S:	begin
									if(!|ram_columns[column] && !|ram_columns[column + 1]) begin
										we <= 1;
									end
									else q <= FAIL;
								end

							Z:	begin
									if(!|ram_columns[column] && !|ram_columns[column + 1]) begin
										we <= 1;
									end
									else q <= FAIL;
								end

							endcase
						end

		STATIC_FALL:	begin //to jest miejsce w którym mogę przesuwać klocek
							if(wait_cnt > speed) begin
								q <= DYNAMIC_FALL;
								row <= row + 1; //najbardziej wysunięty rząd
								ram_row <= row + 1;
							end
							else begin
								if(VGA_VS) //to zdubluje wynik, pozbyłabym się tego duble jakimś rejestrem, więc wszystko jedno, mogę trzymać o bit więcej speed'a
									wait_cnt <= wait_cnt + 1; //!! to nie zadziała
							end
						end

		endcase
	end
end

endmodule