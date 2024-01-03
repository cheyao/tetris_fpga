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
color_generator cg	(clk, 0, VGA_BLANK_N, r, c, block, next_block, 
					q, q_counting, ram_columns[board_column],
					sq1, sq2, sq3, sq4, board, block_color, VGA_R, VGA_G, VGA_B);
VGA_sync vga(clk, 0, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, r, c);

//=======================================================
//  Game memory
//=======================================================

wire [23:0] ram_columns [9:0];
reg [4:0] ram_row;
wire [23:0] d [9:0];
reg we [9:0]; 

generate
	genvar i;
	for (i = 0; i < 10; i = i+1) begin : rams
		ram_single ram(ram_columns[i], ram_row, d[i], we[i], clk);
	end

	for(i = 0; i<10; i = i+1) begin : data
		assign d[i] = block_color;
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
wire [23:0] block_color;
assign i_color = MINTY;
assign t_color = BLUE;
assign o_color = PINK;
assign l_color = DARK_PURPLE;
assign j_color = YELLOW;
assign s_color = GREEN;
assign z_color = PLUM;

//=======================================================
//  Game logic
//=======================================================

localparam [2:0] 	I = 3'b111, T = 3'b001, O = 3'b010, L = 3'b011, 
					J = 3'b100, S = 3'b101, Z = 3'b110;

localparam [2:0]	START_SCREEN = 3'b000, COUNTING = 3'b001, 
					START_FALLING = 3'b010, FALLING = 3'b011, 
					DISTROY_LINE = 3'b101, FAIL = 3'b111;

reg [2:0] q;

reg [9:0] distroyed_lines; //rekord niejasny, koło 400
reg [10:0] score; //jak liczyć to kiedyś potem, rekord - 1,62 miliona
reg [5:0] level; //rekord 33

reg [5:0] wait_cnt; //licznik zatrzymania w jednym miejscu (w klatkach)
reg [5:0] speed; //granica oczekiwania (w klatkach)

reg [8:0] seed; //liczy czas od resetu/przegrania gry do startu i jest ziarnem dla generowania pseudolosowości
wire [2:0] next_block;
reg gen_next_block; //potem chyba jednak reg
reg [2:0] block;
reg rand_rst;

reg [1:0] q_counting;
reg check_down;
reg [3:0] save;
//reg [2:0] down_sqares_nb; // 00 - 1, 01 - 2, 10 - 3, 11 - 4

pseudo_random_number_generator ps_rand(gen_next_block, rand_rst, seed, next_block);

wire frame_passed;
reg [4:0] nearest_board_row, nearest_down_left_column, nearest_down_right_column;

detect frame_det(clk, VGA_VS, frame_passed);

//localization points
//borders: left, right up, down [3:0]
reg [9:0] sq1 [3:0], sq2 [3:0], sq3 [3:0], sq4 [3:0];
//row, column
wire [4:0] pos1 [1:0], pos2 [1:0], pos3 [1:0], pos4[1:0];

wire [9:0] b_col;
reg [3:0] board_column;

generate
	for(i = 0; i<10; i = i+1) begin : bc
		assign b_col[i] = c < 10'd240 + 20 * i ;
	end
endgenerate

position_counter ps_c1(sq1, pos1);
position_counter ps_c2(sq2, pos2);
position_counter ps_c3(sq3, pos3);
position_counter ps_c4(sq4, pos4);

always @* 	casez(b_col)
			
			10'b?????????1: board_column = 4'd0;
			10'b????????10: board_column = 4'd1;
			10'b???????100: board_column = 4'd2;
			10'b??????1000: board_column = 4'd3;
			10'b?????10000: board_column = 4'd4;
			10'b????100000: board_column = 4'd5;
			10'b???1000000: board_column = 4'd6;
			10'b??10000000: board_column = 4'd7;
			10'b?100000000: board_column = 4'd8;
			10'b1000000000: board_column = 4'd9;
			default: board_column = 4'd9;

			endcase

integer j;
always @(posedge clk) begin

	seed <= seed + 1;
	rand_rst <= 0;
	gen_next_block <= 0;
	check_down <= 0;
	save <= 4'b0;

	
	for(j = 0; j<10; j++) begin
		we[j] <= 0;
	end

	if(r == 9'd39) ram_row <= 5'd0;
	if(c == 10'd210 && (r == 9'd60 || r == 9'd80 || r == 9'd100 || r == 9'd120
						|| r == 9'd140 || r == 9'd160 || r == 9'd180 || r == 9'd200
						|| r == 9'd220 || r == 9'd240 || r == 9'd260 || r == 9'd280
						|| r == 9'd300 || r == 9'd320 || r == 9'd340 || r == 9'd360
						|| r == 9'd380 || r == 9'd400 || r == 9'd420))
				ram_row <= ram_row + 1;

	case(q)

	START_SCREEN: begin		
		speed <= 6'd1; //żałosne tak naprawdę, ale żeby się nie zesrała ta symulacja
		if(|click) begin
			q <= COUNTING;
			rand_rst <= 1; 
			wait_cnt <= 0;
			q_counting <= 2'd3;
		end
	end

	COUNTING: begin
		if(frame_passed) begin 
			if(wait_cnt < 6'd10) //stałe do zmiany oczywiście
				wait_cnt <= wait_cnt + 1;
			else begin
				if(q_counting > 0) begin
					q_counting <= q_counting - 1;
					wait_cnt <= 0;
				end
				else begin
					q <= START_FALLING;
					block <= next_block;
					gen_next_block <= 1; 
					wait_cnt <= 0;
				end
			end
		end			
	end

	START_FALLING: begin

		q <= FALLING;
		nearest_board_row <= 5'd0;

		case(block)

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

	FALLING: begin //wszystie operacje na ramie wydarzają się po VS czyli na blank czasie
		
		case(save)
			4'd1: begin
				we[pos1[0][3:0]] <= 1;
				save <= 4'd2;
			end
			4'd2: begin
				ram_row <= pos2[1];
				save <= 4'd3;
			end
			4'd3: begin
				we[pos2[0][3:0]] <= 1;
				save <= 4'd4;
			end
			4'd4: begin
				ram_row <= pos3[1];
				save <= 4'd5;
			end
			4'd5: begin
				we[pos3[0][3:0]] <= 1;
				save <= 4'd6;
			end
			4'd6: begin
				ram_row <= pos4[1];
				save <= 4'd7;
			end
			4'd7: begin
				we[pos4[0][3:0]] <= 1;
				save <= 4'd0;
				q <= START_FALLING; // tu potencjalnie przechodzimy do innego stanu, wtedy być może nie warto nawet czasami wchodzić do save
				block <= next_block;
				gen_next_block <= 1; 
				wait_cnt <= 0;
			end
			default: save <= 4'd0;			
		endcase

		if(check_down && (pos1[1] == nearest_board_row - 1 && |ram_columns[pos1[0][3:0]]
						|| pos2[1] == nearest_board_row - 1 && |ram_columns[pos2[0][3:0]]
						|| pos3[1] == nearest_board_row - 1 && |ram_columns[pos3[0][3:0]]
						|| pos4[1] == nearest_board_row - 1 && |ram_columns[pos4[0][3:0]])) 
			begin
				if(nearest_board_row > 0) begin
					ram_row <= pos1[1];
					save <= 4'd1;
				end else q <= FAIL;
			end
		else if(check_down && sq1[0] < 10'd440 && sq2[0] < 10'd440 && sq3[0] < 10'd440 && sq4[0] < 10'd440) begin
				if(wait_cnt < speed)
					begin
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

		if(frame_passed) begin 

			//if(sq1[0] < 10'd440 && sq2[0] < 10'd440 && sq3[0] < 10'd440 && sq4[0] < 10'd440) begin
			if(sq1[0] < 10'd140 && sq2[0] < 10'd140 && sq3[0] < 10'd140 && sq4[0] < 10'd140) begin
				if(wait_cnt < speed)
					begin
						wait_cnt <= wait_cnt + 1;
					end
				else if	(sq1[0] == 10'd40 || sq2[0] == 10'd40 || sq3[0] == 10'd40 || sq3[0] == 10'd40
				|| sq1[0] == 10'd60 || sq2[0] == 10'd60 || sq3[0] == 10'd60 || sq3[0] == 10'd60
				|| sq1[0] == 10'd80 || sq2[0] == 10'd80 || sq3[0] == 10'd80 || sq3[0] == 10'd80
				|| sq1[0] == 10'd100 || sq2[0] == 10'd100 || sq3[0] == 10'd100 || sq3[0] == 10'd100
				|| sq1[0] == 10'd120 || sq2[0] == 10'd120 || sq3[0] == 10'd120 || sq3[0] == 10'd120
				|| sq1[0] == 10'd140 || sq2[0] == 10'd140 || sq3[0] == 10'd140 || sq3[0] == 10'd140
				|| sq1[0] == 10'd160 || sq2[0] == 10'd160 || sq3[0] == 10'd160 || sq3[0] == 10'd160
				|| sq1[0] == 10'd180 || sq2[0] == 10'd180 || sq3[0] == 10'd180 || sq3[0] == 10'd180
				|| sq1[0] == 10'd200 || sq2[0] == 10'd200 || sq3[0] == 10'd200 || sq3[0] == 10'd200
				|| sq1[0] == 10'd220 || sq2[0] == 10'd220 || sq3[0] == 10'd220 || sq3[0] == 10'd220
				|| sq1[0] == 10'd240 || sq2[0] == 10'd240 || sq3[0] == 10'd240 || sq3[0] == 10'd240
				|| sq1[0] == 10'd260 || sq2[0] == 10'd260 || sq3[0] == 10'd260 || sq3[0] == 10'd260
				|| sq1[0] == 10'd280 || sq2[0] == 10'd280 || sq3[0] == 10'd280 || sq3[0] == 10'd280
				|| sq1[0] == 10'd300 || sq2[0] == 10'd300 || sq3[0] == 10'd300 || sq3[0] == 10'd300
				|| sq1[0] == 10'd320 || sq2[0] == 10'd320 || sq3[0] == 10'd320 || sq3[0] == 10'd320
				|| sq1[0] == 10'd340 || sq2[0] == 10'd340 || sq3[0] == 10'd340 || sq3[0] == 10'd340
				|| sq1[0] == 10'd360 || sq2[0] == 10'd360 || sq3[0] == 10'd360 || sq3[0] == 10'd360
				|| sq1[0] == 10'd380 || sq2[0] == 10'd380 || sq3[0] == 10'd380 || sq3[0] == 10'd380
				|| sq1[0] == 10'd400 || sq2[0] == 10'd400 || sq3[0] == 10'd400 || sq3[0] == 10'd400
				|| sq1[0] == 10'd420 || sq2[0] == 10'd420 || sq3[0] == 10'd420 || sq3[0] == 10'd420)
				begin //ten if jest w złym miejscu w sensie odliczania klatek 
					ram_row <= nearest_board_row;
					check_down <= 1;
					nearest_board_row <= nearest_board_row + 1;
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
			else begin 
				save <= 4'd1;
				ram_row <= pos1[1];
			end
		end
	end
	
	// wchodzenie w stan distroy line będzie opierało się na liczniku zapełnionych klocków dla każdego rzędu
	// - jeśli licznik i nowe pola które mielibyśmy teraz zapisywać sumują się do 10 -> przechodzimy tu
	//DISTROY_LINE: 

	//w FAIL trzeba wyczyścić pamięć przed powrotem do startu
	FAIL: if(|click) q <= START_SCREEN;

	default: q <= START_SCREEN;

	endcase
end

endmodule