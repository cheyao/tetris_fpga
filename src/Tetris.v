// `define DEBUG
`define SYNTH

module Tetris(
	//////////// CLOCK //////////
	input 		          		clk,

	//////////// KEY //////////
	input 		     [3:0]		KEY,

	//////////// VGA //////////
	output		          		VGA_BLANK_N,
	output		     [7:0]		VGA_B, 
	input		          		VGA_CLK,
	output		     [7:0]		VGA_G,
	output		          		VGA_HS,
	output		     [7:0]		VGA_R, 
	output		          		VGA_SYNC_N,
	output		          		VGA_VS,

    output           [4:0]      led
);

//=======================================================
//  KEYS
//=======================================================

wire down; 
wire rotation;
wire left;
wire right;
wire [3:0] click; // clicking detectors

//synchronizer syn_key1(clk, ~KEY[0], right);
//synchronizer syn_key2(clk, ~KEY[1], left);
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

color_generator cg	(VGA_BLANK_N, r, c, block, next_block, 
					q, q_counting, ram_columns[board_column],
					sq1[3], sq1[2], sq1[1], sq1[0], sq2[3], sq2[2], sq2[1], sq2[0], 
					sq3[3], sq3[2], sq3[1], sq3[0], sq4[3], sq4[2], sq4[1], sq4[0],
					block_color, VGA_R, VGA_G, VGA_B);
VGA_sync vga(VGA_CLK, 0, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, r, c);

//=======================================================
//  HEX
//=======================================================

wire [15:0] bcd_dl;
wire [7:0] bcd_lvl;
reg gen_add_line;

bin_bcd_dl bbdl (clk, gen_add_line, distroyed_lines, bcd_dl);
bin_bcd_lvl bblvl (clk, gen_add_line, level, bcd_lvl);

//=======================================================
//  Memory
//=======================================================

wire [23:0] ram_columns [9:0];
reg [4:0] ram_row;
wire [23:0] d [9:0];
reg [23:0] d_reg [9:0];
reg we [9:0]; 
wire [23:0] block_color;

generate
	genvar i;
	for (i = 0; i < 10; i = i+1) begin : rams
		ram_single ram(ram_columns[i], ram_row, d[i], we[i], clk);
	end

	for(i = 0; i<10; i = i+1) begin : data
		assign d[i] = (q == CLEAN || q == DISTROY_LINE) ? 0 : (q == LINES_DOWN ? d_reg[i] : block_color);
	end
endgenerate


/********************************************************
					   GAME LOGIC
********************************************************/

//=======================================================
//  REG/WIRE/PARAM declarations
//=======================================================

localparam [2:0] 	I = 3'b111, T = 3'b001, O = 3'b010, L = 3'b011, 
					J = 3'b100, S = 3'b101, Z = 3'b110;

localparam [2:0]	START_SCREEN = 3'b000, COUNTING = 3'b001, 
					START_FALLING = 3'b010, FALLING = 3'b011, 
					DISTROY_LINE = 3'b100, CLEAN = 3'b101, 
					LINES_DOWN = 3'b110, FAIL = 3'b111;

reg [2:0] q; 						// state of game
reg [5:0] cnt; 						// controls the order of actions

reg [9:0] distroyed_lines;
reg [5:0] level;

reg [5:0] wait_cnt; 				// time (in frames) to stay in the same position
reg [5:0] speed; 					// the limit of wait_cnt

reg rand_rst;
reg [6:0] seed; 					// the seed to generate pseudorandom numbers

reg [2:0] block; 					// type of active block
wire [2:0] next_block; 				// type of the next block
reg gen_next_block;

reg [1:0] q_counting; 				// 3, 2, 1, 0 - time to start the game
reg [3:0] left_delay, right_delay; 	// delay (in frames) of sliding left/right

wire frame_passed; 					// goes high on the VGA_VS posedge

reg rotate; 						// associated with click[2]

reg [3:0] filling [19:0];			// how many fields of a row are taken
reg [2:0] distroy_nb;				// how many lines to distroy
reg [4:0] dl1, dl2, dl3, dl4;		// numbers of rows of lines to distroy

reg [9:0] sq1 [3:0], sq2 [3:0], sq3 [3:0], sq4 [3:0];		// localization points - borders: left, right up, down [3:0]
reg [9:0] sq1_buf [3:0], sq2_buf [3:0], sq3_buf [3:0], sq4_buf [3:0];
reg [8:0] x_centr, y_centr;			// rotation point
reg [8:0] x_centr_buf, y_centr_buf;
wire [4:0] pos1 [1:0], pos2 [1:0], pos3 [1:0], pos4[1:0];	// avtive block squares position: row, column

wire [9:0] b_col;
reg [3:0] board_column; 			// used in color generator to get to the memory

integer j;

//=======================================================
//  Modules' instances & combinational logic
//=======================================================

pseudo_random_number_generator ps_rand(gen_next_block, rand_rst, seed, next_block);

detect frame_det(clk, VGA_VS, frame_passed);

generate
	for(i = 0; i<10; i = i+1) begin : bc
		assign b_col[i] = c < 10'd240 + 20 * i;
	end
endgenerate

position_counter ps_c1(sq1[2], sq1[0], pos1[1], pos1[0]);
position_counter ps_c2(sq2[2], sq2[0], pos2[1], pos2[0]);
position_counter ps_c3(sq3[2], sq3[0], pos3[1], pos3[0]);
position_counter ps_c4(sq4[2], sq4[0], pos4[1], pos4[0]);

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

//=======================================================
//  State machine & sequential logic
//=======================================================

always @(posedge clk) begin

	seed <= seed + 1;
	rand_rst <= 0;
	gen_next_block <= 0;
	gen_add_line <= 0;
	
	for(j = 0; j<10; j= j+1) begin
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

		/* SIMULATION */
`ifndef SYNTH
		    speed <= 6'd1;
`else
            speed <= 6'd10;
`endif

		level <= 6'd0;
		distroyed_lines <= 10'd0;
		if(|click) begin
			q <= COUNTING;
			rand_rst <= 1; 
			wait_cnt <= 0;
			q_counting <= 2'd3;
		end
	end

	COUNTING: begin
		if(frame_passed) begin 

`ifndef SYNTH
            if(wait_cnt < 6'd5)
`else
            if(wait_cnt < 6'd40)
`endif
                wait_cnt <= wait_cnt + 1;
            else begin
                if(q_counting > 0) begin
                    q_counting <= q_counting - 1;
                    wait_cnt <= 0;
                end
                else begin
                    q <= START_FALLING;
                    ram_row <= 5'd0;
                    block <= next_block;
                    gen_next_block <= 1; 
                    wait_cnt <= 0;
                end
            end
		end			
	end

	START_FALLING: begin

		if(~|cnt) begin

			case(block)

			I: 	begin

				sq1[3] <= 10'd280; sq1[2] <= 10'd300; sq1[1] <= 10'd20; sq1[0] <= 10'd40;
				sq2[3] <= 10'd300; sq2[2] <= 10'd320; sq2[1] <= 10'd20; sq2[0] <= 10'd40;
				sq3[3] <= 10'd320; sq3[2] <= 10'd340; sq3[1] <= 10'd20; sq3[0] <= 10'd40;
				sq4[3] <= 10'd340; sq4[2] <= 10'd360; sq4[1] <= 10'd20; sq4[0] <= 10'd40;
				x_centr <= 9'd320; y_centr <= 9'd20;
				
				end

			T:	begin

				sq1[3] <= 10'd320; sq1[2] <= 10'd340; sq1[1] <= 10'd0; sq1[0] <= 10'd20;
				sq2[3] <= 10'd300; sq2[2] <= 10'd320; sq2[1] <= 10'd20; sq2[0] <= 10'd40;
				sq3[3] <= 10'd320; sq3[2] <= 10'd340; sq3[1] <= 10'd20; sq3[0] <= 10'd40;
				sq4[3] <= 10'd340; sq4[2] <= 10'd360; sq4[1] <= 10'd20; sq4[0] <= 10'd40;
				x_centr <= 9'd330; y_centr <= 9'd30;

				end

			O:	begin

				sq1[3] <= 10'd300; sq1[2] <= 10'd320; sq1[1] <= 10'd0; sq1[0] <= 10'd20;
				sq2[3] <= 10'd300; sq2[2] <= 10'd320; sq2[1] <= 10'd20; sq2[0] <= 10'd40;
				sq3[3] <= 10'd320; sq3[2] <= 10'd340; sq3[1] <= 10'd20; sq3[0] <= 10'd40;
				sq4[3] <= 10'd320; sq4[2] <= 10'd340; sq4[1] <= 10'd0; sq4[0] <= 10'd20;
				x_centr <= 9'd320; y_centr <= 9'd20;

				end

			L:	begin

				sq1[3] <= 10'd340; sq1[2] <= 10'd360; sq1[1] <= 10'd0; sq1[0] <= 10'd20;
				sq2[3] <= 10'd300; sq2[2] <= 10'd320; sq2[1] <= 10'd20; sq2[0] <= 10'd40;
				sq3[3] <= 10'd320; sq3[2] <= 10'd340; sq3[1] <= 10'd20; sq3[0] <= 10'd40;
				sq4[3] <= 10'd340; sq4[2] <= 10'd360; sq4[1] <= 10'd20; sq4[0] <= 10'd40;
				x_centr <= 9'd330; y_centr <= 9'd30;

				end

			J:	begin

				sq1[3] <= 10'd300; sq1[2] <= 10'd320; sq1[1] <= 10'd0; sq1[0] <= 10'd20;
				sq2[3] <= 10'd300; sq2[2] <= 10'd320; sq2[1] <= 10'd20; sq2[0] <= 10'd40;
				sq3[3] <= 10'd320; sq3[2] <= 10'd340; sq3[1] <= 10'd20; sq3[0] <= 10'd40;
				sq4[3] <= 10'd340; sq4[2] <= 10'd360; sq4[1] <= 10'd20; sq4[0] <= 10'd40;
				x_centr <= 9'd330; y_centr <= 9'd30;

				end

			S:	begin

				sq1[3] <= 10'd320; sq1[2] <= 10'd340; sq1[1] <= 10'd0; sq1[0] <= 10'd20;
				sq2[3] <= 10'd300; sq2[2] <= 10'd320; sq2[1] <= 10'd20; sq2[0] <= 10'd40;
				sq3[3] <= 10'd320; sq3[2] <= 10'd340; sq3[1] <= 10'd20; sq3[0] <= 10'd40;
				sq4[3] <= 10'd340; sq4[2] <= 10'd360; sq4[1] <= 10'd0; sq4[0] <= 10'd20;
				x_centr <= 9'd330; y_centr <= 9'd30;

				end

			Z:	begin

				sq1[3] <= 10'd320; sq1[2] <= 10'd340; sq1[1] <= 10'd20; sq1[0] <= 10'd40;
				sq2[3] <= 10'd300; sq2[2] <= 10'd320; sq2[1] <= 10'd0; sq2[0] <= 10'd20;
				sq3[3] <= 10'd320; sq3[2] <= 10'd340; sq3[1] <= 10'd0; sq3[0] <= 10'd20;
				sq4[3] <= 10'd340; sq4[2] <= 10'd360; sq4[1] <= 10'd20; sq4[0] <= 10'd40;
				x_centr <= 9'd330; y_centr <= 9'd30;

				end

			default: begin

				sq1[3] <= 10'd0; sq1[2] <= 10'd0; sq1[1] <= 10'd0; sq1[0] <= 10'd0;
				sq2[3] <= 10'd0; sq2[2] <= 10'd0; sq2[1] <= 10'd0; sq2[0] <= 10'd0;
				sq3[3] <= 10'd0; sq3[2] <= 10'd0; sq3[1] <= 10'd0; sq3[0] <= 10'd0;
				sq4[3] <= 10'd0; sq4[2] <= 10'd0; sq4[1] <= 10'd0; sq4[0] <= 10'd0;

				end
			endcase
			ram_row <= 0;
			cnt <= 6'd1;
		end
		else if(|ram_columns[pos1[0][3:0]] || |ram_columns[pos2[0][3:0]]
			|| |ram_columns[pos3[0][3:0]] || |ram_columns[pos4[0][3:0]]) 
			q <= FAIL;
		else begin
			q <= FALLING;
			cnt <= 0;
		end
		
	end

	FALLING: begin 		// all actions during the blank period
		
		if(click[2])
			rotate <= 1;
		
		case (cnt)

		6'd1:
			begin
				if(left && !right) begin

`ifndef SYNTH
					/* SIMULATION */
                    if(left_delay < 4'd2) begin
`else
					/* SYNTHESIS */
                    if(left_delay < 4'd6) begin
`endif
						left_delay <= left_delay + 1;
                    end else begin
						if (pos1[0] > 5'd0 && pos2[0] > 5'd0 && pos3[0] > 5'd0 && pos4[0] > 5'd0) begin
							sq1[2] <= sq1[2] - 20;
							sq1[3] <= sq1[3] - 20;
							sq2[2] <= sq2[2] - 20;
							sq2[3] <= sq2[3] - 20;
							sq3[2] <= sq3[2] - 20;
							sq3[3] <= sq3[3] - 20;
							sq4[2] <= sq4[2] - 20;
							sq4[3] <= sq4[3] - 20;
							x_centr <= x_centr - 20;
						end
						left_delay <= 0;
					end
				end
				else left_delay <= 4'd0;
				cnt <= 6'd2;
			end

		6'd2:
			begin
				if(right && !left) begin

`ifndef SYNTH
					/* SIMULATION */
                    if(right_delay < 4'd2) begin
`else
					/* SYNTHESIS */
                    if(right_delay < 4'd6) begin
`endif
						right_delay <= right_delay + 1;
                    end else begin
						if (pos1[0] < 5'd9 && pos2[0] < 5'd9 && pos3[0] < 5'd9 && pos4[0] < 5'd9)begin
							sq1[2] <= sq1[2] + 20;
							sq1[3] <= sq1[3] + 20;
							sq2[2] <= sq2[2] + 20;
							sq2[3] <= sq2[3] + 20;
							sq3[2] <= sq3[2] + 20;
							sq3[3] <= sq3[3] + 20;
							sq4[2] <= sq4[2] + 20;
							sq4[3] <= sq4[3] + 20;
							x_centr <= x_centr + 20;
						end
						right_delay <= 0;
					end
				end
				else right_delay <= 4'd0;
				cnt <= 6'd3;
			end

		6'd3:
			begin
				if(rotate) begin 
					sq1[3] <= sq1[1] - y_centr + x_centr;
					sq1[0] <= x_centr - sq1[3] + y_centr;
					sq1[2] <= sq1[0] - y_centr + x_centr;
					sq1[1] <= x_centr - sq1[2] + y_centr;

					sq2[3] <= sq2[1] - y_centr + x_centr;
					sq2[0] <= x_centr - sq2[3] + y_centr;
					sq2[2] <= sq2[0] - y_centr + x_centr;
					sq2[1] <= x_centr - sq2[2] + y_centr;

					sq3[3] <= sq3[1] - y_centr + x_centr;
					sq3[0] <= x_centr - sq3[3] + y_centr;
					sq3[2] <= sq3[0] - y_centr + x_centr;
					sq3[1] <= x_centr - sq3[2] + y_centr;

					sq4[3] <= sq4[1] - y_centr + x_centr;
					sq4[0] <= x_centr - sq4[3] + y_centr;
					sq4[2] <= sq4[0] - y_centr + x_centr;
					sq4[1] <= x_centr - sq4[2] + y_centr;

					rotate <= 0;
				end
				cnt <= 6'd4;
				ram_row <= pos1[1];
			end
		6'd4: 
			if (|ram_columns[pos1[0][3:0]] || pos1[0] > 5'd9 || pos2[0] > 5'd9 ||
				 pos3[0] > 5'd9 || pos4[0] > 5'd9) begin
				sq1[0] <= sq1_buf[0]; sq2[0] <= sq2_buf[0]; sq3[0] <= sq3_buf[0]; sq4[0] <= sq4_buf[0];
				sq1[1] <= sq1_buf[1]; sq2[1] <= sq2_buf[1]; sq3[1] <= sq3_buf[1]; sq4[1] <= sq4_buf[1];
				sq1[2] <= sq1_buf[2]; sq2[2] <= sq2_buf[2]; sq3[2] <= sq3_buf[2]; sq4[2] <= sq4_buf[2];
				sq1[3] <= sq1_buf[3]; sq2[3] <= sq2_buf[3]; sq3[3] <= sq3_buf[3]; sq4[3] <= sq4_buf[3];
				x_centr <= x_centr_buf;
				y_centr <= y_centr_buf;
				cnt <= 6'd8;
			end
			else begin
				ram_row <= pos2[1];
				cnt <= 6'd5;
			end
		6'd5: 
			if (|ram_columns[pos2[0][3:0]]) begin
				sq1[0] <= sq1_buf[0]; sq2[0] <= sq2_buf[0]; sq3[0] <= sq3_buf[0]; sq4[0] <= sq4_buf[0];
				sq1[1] <= sq1_buf[1]; sq2[1] <= sq2_buf[1]; sq3[1] <= sq3_buf[1]; sq4[1] <= sq4_buf[1];
				sq1[2] <= sq1_buf[2]; sq2[2] <= sq2_buf[2]; sq3[2] <= sq3_buf[2]; sq4[2] <= sq4_buf[2];
				sq1[3] <= sq1_buf[3]; sq2[3] <= sq2_buf[3]; sq3[3] <= sq3_buf[3]; sq4[3] <= sq4_buf[3];
				x_centr <= x_centr_buf;
				y_centr <= y_centr_buf;
				cnt <= 6'd8;
			end
			else begin
				ram_row <= pos3[1];
				cnt <= 6'd6;
			end
		6'd6: 
			if (|ram_columns[pos3[0][3:0]]) begin
				sq1[0] <= sq1_buf[0]; sq2[0] <= sq2_buf[0]; sq3[0] <= sq3_buf[0]; sq4[0] <= sq4_buf[0];
				sq1[1] <= sq1_buf[1]; sq2[1] <= sq2_buf[1]; sq3[1] <= sq3_buf[1]; sq4[1] <= sq4_buf[1];
				sq1[2] <= sq1_buf[2]; sq2[2] <= sq2_buf[2]; sq3[2] <= sq3_buf[2]; sq4[2] <= sq4_buf[2];
				sq1[3] <= sq1_buf[3]; sq2[3] <= sq2_buf[3]; sq3[3] <= sq3_buf[3]; sq4[3] <= sq4_buf[3];
				x_centr <= x_centr_buf;
				y_centr <= y_centr_buf;
				cnt <= 6'd8;
			end
			else begin
				ram_row <= pos4[1];
				cnt <= 6'd7;
			end
		6'd7: 
			begin
				if (|ram_columns[pos4[0][3:0]]) begin
					sq1[0] <= sq1_buf[0]; sq2[0] <= sq2_buf[0]; sq3[0] <= sq3_buf[0]; sq4[0] <= sq4_buf[0];
					sq1[1] <= sq1_buf[1]; sq2[1] <= sq2_buf[1]; sq3[1] <= sq3_buf[1]; sq4[1] <= sq4_buf[1];
					sq1[2] <= sq1_buf[2]; sq2[2] <= sq2_buf[2]; sq3[2] <= sq3_buf[2]; sq4[2] <= sq4_buf[2];
					sq1[3] <= sq1_buf[3]; sq2[3] <= sq2_buf[3]; sq3[3] <= sq3_buf[3]; sq4[3] <= sq4_buf[3];
					x_centr <= x_centr_buf;
					y_centr <= y_centr_buf;
				end
				else begin
					sq1_buf[0] <= sq1[0]; sq2_buf[0] <= sq2[0]; sq3_buf[0] <= sq3[0]; sq4_buf[0] <= sq4[0];
					sq1_buf[1] <= sq1[1]; sq2_buf[1] <= sq2[1]; sq3_buf[1] <= sq3[1]; sq4_buf[1] <= sq4[1];
					sq1_buf[2] <= sq1[2]; sq2_buf[2] <= sq2[2]; sq3_buf[2] <= sq3[2]; sq4_buf[2] <= sq4[2];
					sq1_buf[3] <= sq1[3]; sq2_buf[3] <= sq2[3]; sq3_buf[3] <= sq3[3]; sq4_buf[3] <= sq4[3];
					x_centr_buf <= x_centr;
					y_centr_buf <= y_centr;
				end
				cnt <= 6'd8;
			end	
		6'd8:
			begin	
				if(!down && wait_cnt < speed)
`ifdef SYNTH
					begin
						wait_cnt <= wait_cnt + 1;
					end
`endif
				else 
				begin
					sq1[0] <= sq1[0] + 1;
					sq1[1] <= sq1[1] + 1;
					sq2[0] <= sq2[0] + 1;
					sq2[1] <= sq2[1] + 1;
					sq3[0] <= sq3[0] + 1;
					sq3[1] <= sq3[1] + 1;
					sq4[0] <= sq4[0] + 1;
					sq4[1] <= sq4[1] + 1;
					y_centr <= y_centr + 1;
					wait_cnt <= 0;
				end
				cnt <= 6'd9;
			end
		6'd9:
			begin
				ram_row <= pos1[1];
				cnt <= 6'd10;
			end
		6'd10:  
			if (|ram_columns[pos1[0][3:0]]) begin //there's already something on the block's position
				cnt <= 6'd14;
				sq1[0] <= sq1_buf[0]; sq2[0] <= sq2_buf[0]; sq3[0] <= sq3_buf[0]; sq4[0] <= sq4_buf[0];
				sq1[1] <= sq1_buf[1]; sq2[1] <= sq2_buf[1]; sq3[1] <= sq3_buf[1]; sq4[1] <= sq4_buf[1];
				sq1[2] <= sq1_buf[2]; sq2[2] <= sq2_buf[2]; sq3[2] <= sq3_buf[2]; sq4[2] <= sq4_buf[2];
				sq1[3] <= sq1_buf[3]; sq2[3] <= sq2_buf[3]; sq3[3] <= sq3_buf[3]; sq4[3] <= sq4_buf[3];
				x_centr <= x_centr_buf;
				y_centr <= y_centr_buf;
			end
			else begin
				ram_row <= pos2[1];
				cnt <= 6'd11;
			end
		6'd11: 
			if (|ram_columns[pos2[0][3:0]]) begin
				cnt <= 6'd14;
				sq1[0] <= sq1_buf[0]; sq2[0] <= sq2_buf[0]; sq3[0] <= sq3_buf[0]; sq4[0] <= sq4_buf[0];
				sq1[1] <= sq1_buf[1]; sq2[1] <= sq2_buf[1]; sq3[1] <= sq3_buf[1]; sq4[1] <= sq4_buf[1];
				sq1[2] <= sq1_buf[2]; sq2[2] <= sq2_buf[2]; sq3[2] <= sq3_buf[2]; sq4[2] <= sq4_buf[2];
				sq1[3] <= sq1_buf[3]; sq2[3] <= sq2_buf[3]; sq3[3] <= sq3_buf[3]; sq4[3] <= sq4_buf[3];
				x_centr <= x_centr_buf;
				y_centr <= y_centr_buf;
			end
			else begin
				ram_row <= pos3[1];
				cnt <= 6'd12;
			end
		6'd12: 
			if (|ram_columns[pos3[0][3:0]]) begin
				ram_row <= pos1[1];
				cnt <= 6'd14;
				sq1[0] <= sq1_buf[0]; sq2[0] <= sq2_buf[0]; sq3[0] <= sq3_buf[0]; sq4[0] <= sq4_buf[0];
				sq1[1] <= sq1_buf[1]; sq2[1] <= sq2_buf[1]; sq3[1] <= sq3_buf[1]; sq4[1] <= sq4_buf[1];
				sq1[2] <= sq1_buf[2]; sq2[2] <= sq2_buf[2]; sq3[2] <= sq3_buf[2]; sq4[2] <= sq4_buf[2];
				sq1[3] <= sq1_buf[3]; sq2[3] <= sq2_buf[3]; sq3[3] <= sq3_buf[3]; sq4[3] <= sq4_buf[3];
				x_centr <= x_centr_buf;
				y_centr <= y_centr_buf;
			end
			else begin
				ram_row <= pos4[1];
				cnt <= 6'd13;
			end
		6'd13: 
			if (|ram_columns[pos4[0][3:0]]) begin
				cnt <= 6'd14;
				sq1[0] <= sq1_buf[0]; sq2[0] <= sq2_buf[0]; sq3[0] <= sq3_buf[0]; sq4[0] <= sq4_buf[0];
				sq1[1] <= sq1_buf[1]; sq2[1] <= sq2_buf[1]; sq3[1] <= sq3_buf[1]; sq4[1] <= sq4_buf[1];
				sq1[2] <= sq1_buf[2]; sq2[2] <= sq2_buf[2]; sq3[2] <= sq3_buf[2]; sq4[2] <= sq4_buf[2];
				sq1[3] <= sq1_buf[3]; sq2[3] <= sq2_buf[3]; sq3[3] <= sq3_buf[3]; sq4[3] <= sq4_buf[3];
				x_centr <= x_centr_buf;
				y_centr <= y_centr_buf;
			end
			else begin
				cnt <= 6'd0;
			end
		6'd14: 
			begin
				ram_row <= pos1[1];
				cnt <= 6'd15;
			end
		6'd15:
			begin
				filling[pos1[1]] <= filling[pos1[1]] + 1;
				we[pos1[0][3:0]] <= 1;
				cnt <= 6'd16;
			end
		6'd16: 
			begin
				ram_row <= pos2[1];
				cnt <= 6'd17;
			end
		6'd17: 
			begin
				filling[pos2[1]] <= filling[pos2[1]] + 1;
				we[pos2[0][3:0]] <= 1;
				cnt <= 6'd18;
			end
		6'd18: begin
				ram_row <= pos3[1];
				cnt <= 6'd19;
			end
		6'd19: begin
				filling[pos3[1]] <= filling[pos3[1]] + 1;
				we[pos3[0][3:0]] <= 1;
				cnt <= 6'd20;
			end
		6'd20: begin
				ram_row <= pos4[1];
				cnt <= 6'd21;
			end
		6'd21: begin
				filling[pos4[1]] <= filling[pos4[1]] + 1;
				we[pos4[0][3:0]] <= 1;
				cnt <= 6'd22;
			end
		6'd22: cnt <= 6'd23;
		6'd23: begin

			q <= DISTROY_LINE;
			ram_row <= pos1[1];
			distroy_nb <= 3'd0;
			cnt <= 6'd1;
		end
		default: cnt <= 0;

		endcase

		if(frame_passed) begin
			sq1_buf[0] <= sq1[0]; sq2_buf[0] <= sq2[0]; sq3_buf[0] <= sq3[0]; sq4_buf[0] <= sq4[0];
			sq1_buf[1] <= sq1[1]; sq2_buf[1] <= sq2[1]; sq3_buf[1] <= sq3[1]; sq4_buf[1] <= sq4[1];
			sq1_buf[2] <= sq1[2]; sq2_buf[2] <= sq2[2]; sq3_buf[2] <= sq3[2]; sq4_buf[2] <= sq4[2];
			sq1_buf[3] <= sq1[3]; sq2_buf[3] <= sq2[3]; sq3_buf[3] <= sq3[3]; sq4_buf[3] <= sq4[3];
			x_centr_buf <= x_centr;
			y_centr_buf <= y_centr;
			cnt <= 6'd1;
		end
		
	end
	
	DISTROY_LINE: 
		case(cnt)
			6'd1: begin
				if(filling[pos1[1]] == 4'd10) begin
					for(j = 0; j<10; j= j+1) begin
						we[j] <= 1;
					end
					filling[pos1[1]] <= 4'd0;
					distroyed_lines <= distroyed_lines + 1;
					distroy_nb <= 3'd1;
					dl1 <= pos1[1];
				end
				cnt <= 6'd2;
			end
			6'd2: begin
				ram_row <= pos2[1];
				cnt <= 6'd3;
			end
			6'd3: begin
				if(filling[pos2[1]] == 4'd10) begin
					for(j = 0; j<10; j= j+1) begin
						we[j] <= 1;
					end
					filling[pos2[1]] <= 4'd0;
					distroyed_lines <= distroyed_lines + 1;
					case (distroy_nb) 
					
					3'd0: 	begin
							distroy_nb <= 3'd1;
							dl1 <= pos2[1];
							end
					3'd1: 	begin
							distroy_nb <= 3'd2;
							if(pos2[1] > dl1)
								dl2 <= pos2[1];
							else begin
								dl1 <= pos2[1];
								dl2 <= dl1;
							end
							end
					default: distroy_nb <= 3'd0;
					endcase
				end
				cnt <= 6'd4;
			end
			6'd4: begin
				ram_row <= pos3[1];
				cnt <= 6'd5;
			end
			6'd5: begin
				if(filling[pos3[1]] == 4'd10) begin
					for(j = 0; j<10; j= j+1) begin
						we[j] <= 1;
					end
					distroyed_lines <= distroyed_lines + 1;
					filling[pos3[1]] <= 4'd0;
					case (distroy_nb) 
					
					3'd0: 	begin
							distroy_nb <= 3'd1;
							dl1 <= pos3[1];
							end
					3'd1: 	begin
							distroy_nb <= 3'd2;
							if(pos3[1] > dl1)
								dl2 <= pos3[1];
							else begin
								dl1 <= pos3[1];
								dl2 <= dl1;
							end
							end
					3'd2: 	begin
							distroy_nb <= 3'd3;
							if(pos3[1] > dl2)
								dl3 <= pos3[1];
							else if (pos3[1] > dl1) begin
								dl2 <= pos3[1];
								dl3 <= dl2;
							end
							else begin
								dl1 <= pos3[1];
								dl2 <= dl1;
								dl3 <= dl2;
							end
							end
					default: distroy_nb <= 3'd0;
					endcase
				end
				cnt <= 6'd6;
			end
			6'd6: begin
				ram_row <= pos4[1];
				cnt <= 6'd7;
			end
			6'd7: begin
				if(filling[pos4[1]] == 4'd10) begin
					for(j = 0; j<10; j= j+1) begin
						we[j] <= 1;
					end
					distroyed_lines <= distroyed_lines + 1;
					filling[pos4[1]] <= 4'd0;
					case (distroy_nb) 
					
					3'd0: 	begin
							distroy_nb <= 3'd1;
							dl1 <= pos4[1];
							end
					3'd1: 	begin
							distroy_nb <= 3'd2;
							if(pos4[1] > dl1)
								dl2 <= pos4[1];
							else begin
								dl1 <= pos4[1];
								dl2 <= dl1;
							end
							end
					3'd2: 	begin
							distroy_nb <= 3'd3;
							if(pos4[1] > dl2)
								dl3 <= pos4[1];
							else if (pos4[1] > dl1) begin
								dl2 <= pos4[1];
								dl3 <= dl2;
							end
							else begin
								dl1 <= pos4[1];
								dl2 <= dl1;
								dl3 <= dl2;
							end
							end
					3'd3: 	begin
							distroy_nb <= 3'd4;
							level <= level + 1;
							speed <= |speed ? speed - 1 : 0;
							if(pos4[1] > dl3)
								dl4 <= pos4[1];
							else if (pos4[1] > dl2) begin
								dl3 <= pos4[1];
								dl4 <= dl3;
							end
							else if (pos4[1] > dl1) begin
								dl2 <= pos4[1];
								dl3 <= dl2;
								dl4 <= dl3;
							end
							else begin
								dl1 <= pos4[1];
								dl2 <= dl1;
								dl3 <= dl2;
								dl4 <= dl3;
							end
							end
					default: distroy_nb <= 3'd0;
					endcase
				end
				cnt <= 6'd8;
			end
			6'd8: begin
				if(|distroy_nb) begin
					q <= LINES_DOWN; 
					wait_cnt <= 0;
					cnt <= 6'd0;
					gen_add_line <= 1;
				end
				else begin
					q <= START_FALLING; 
					ram_row <= 5'd0;
					block <= next_block;
					gen_next_block <= 1;
					wait_cnt <= 0;
					cnt <= 6'd0;
					gen_add_line <= 1;
				end
			end
			default: begin
				distroy_nb <= 0;
				cnt <= 6'd1;
			end		
		endcase

	LINES_DOWN: begin

		casez (cnt)

		6'b00????: begin
			if(frame_passed) cnt <= cnt + 1;
		end
		6'd16: begin
			if(|dl1) begin
				ram_row <= dl1 - 1;
				cnt <= cnt + 1;
				filling[dl1] <= filling[dl1 - 1];
			end
			else if (distroy_nb > 3'd1) begin
				cnt <= 6'd19;
				filling[dl1] <= 0;
			end
			else begin
				q <= START_FALLING; 
				ram_row <= 5'd0;
				block <= next_block;
				gen_next_block <= 1;
				wait_cnt <= 0;
				cnt <= 6'd0;
				filling[dl1] <= 0;
			end
		end
		6'd17: begin
			for(j = 0; j<10; j= j+1) begin
				d_reg[j] <= ram_columns[j];
			end
			ram_row <= dl1;
			dl1 <= dl1 - 1;
			cnt <= cnt + 1;
		end
		6'd18: begin
			for(j = 0; j<10; j= j+1) begin
				we[j] <= 1;
			end
			cnt <= 6'd16;
		end
		6'd19: begin
			if(|dl2) begin
				ram_row <= dl2 - 1;
				cnt <= cnt + 1;
				filling[dl2] <= filling[dl2 - 1];
			end
			else if (distroy_nb > 3'd2) begin
				cnt <= 6'd22;
				filling[dl2] <= 0;
			end
			else begin
				q <= START_FALLING; 
				ram_row <= 5'd0;
				block <= next_block;
				gen_next_block <= 1;
				wait_cnt <= 0;
				cnt <= 6'd0;
				filling[dl2] <= 0;
			end
		end
		6'd20: begin
			for(j = 0; j<10; j= j+1) begin
				d_reg[j] <= ram_columns[j];
			end
			ram_row <= dl2;
			dl2 <= dl2 - 1;
			cnt <= cnt + 1;
		end
		6'd21: begin
			for(j = 0; j<10; j= j+1) begin
				we[j] <= 1;
			end
			cnt <= 6'd19;
		end
		6'd22: begin
			if(|dl3) begin
				ram_row <= dl3 - 1;
				cnt <= cnt + 1;
				filling[dl3] <= filling[dl3 - 1];
			end
			else if (distroy_nb > 3'd3) begin
				cnt <= 6'd25;
				filling[dl3] <= 0;
			end
			else begin
				q <= START_FALLING; 
				ram_row <= 5'd0;
				block <= next_block;
				gen_next_block <= 1;
				wait_cnt <= 0;
				cnt <= 6'd0;
				filling[dl3] <= 0;
			end
		end
		6'd23: begin
			for(j = 0; j<10; j= j+1) begin
				d_reg[j] <= ram_columns[j];
			end
			ram_row <= dl3;
			dl3 <= dl3 - 1;
			cnt <= cnt + 1;
		end
		6'd24: begin
			for(j = 0; j<10; j= j+1) begin
				we[j] <= 1;
			end
			cnt <= 6'd22;
		end
		6'd25: begin
			if(|dl4) begin
				ram_row <= dl4 - 1;
				cnt <= cnt + 1;
				filling[dl4] <= filling[dl4 - 1];
			end
			else begin
				q <= START_FALLING; 
				ram_row <= 5'd0;
				block <= next_block;
				gen_next_block <= 1;
				wait_cnt <= 0;
				cnt <= 6'd0;
				filling[dl4] <= 0;
			end
		end
		6'd26: begin
			for(j = 0; j<10; j= j+1) begin
				d_reg[j] <= ram_columns[j];
			end
			ram_row <= dl4;
			dl4 <= dl4 - 1;
			cnt <= cnt + 1;
		end
		6'd27: begin
			for(j = 0; j<10; j= j+1) begin
				we[j] <= 1;
			end
			cnt <= 6'd25;
		end
		default: cnt <= 0;

		endcase
	end

	FAIL: begin
		if(|click) begin
			q <= CLEAN;
			wait_cnt <= 6'd0;
			ram_row <= 5'd0;
		end
	end

	CLEAN: begin
		if(wait_cnt >= 6'd39) begin
			
			for(j = 0; j<20; j= j+1) begin
				filling[j] <= 4'd0;
			end
			
			q <= START_SCREEN;
		end
		else 	casez(wait_cnt)
				
				6'b?????0: 	begin for(j = 0; j<10; j= j+1) begin
								we[j] <= 1;
							end
							wait_cnt <= wait_cnt + 1;
							end
				6'b?????1: 	begin
							ram_row <= ram_row + 1;
							wait_cnt <= wait_cnt + 1;
							end

				endcase
	end
	default: q <= START_SCREEN;

	endcase
end

endmodule
