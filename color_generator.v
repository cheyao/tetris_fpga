module color_generator (
    input clk, rst, blank_n,
    input [8:0] row,
    input [9:0] column,
    output [7:0] red, green, blue
);

    reg [23:0] rgb;
    assign red = blank_n ? rgb [23:16] : 0;
    assign green = blank_n ? rgb [15:8] : 0;
    assign blue = blank_n ? rgb [7:0] : 0;

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

    //screen elements
    wire frames;
    wire board;
    wire next_block_field;
    assign frames = row >= 9'd20 && row < 9'd40 && 
                        (column >= 10'd200 && column < 10'd440 || column >= 10'd460 && column < 10'd620)
                    || row >= 9'd20 && row < 9'd460 && 
                        (column >= 10'd200 && column < 10'd220 || column >= 10'd420 && column < 10'd440)
                    || row >= 9'd20 && row < 9'd140 && 
                        (column >= 10'd460 && column < 10'd480 || column >= 10'd600 && column < 10'd620)
                    || row >= 9'd120 && row < 9'd140 && (column >= 10'd460 && column < 10'd620)
                    || row >= 9'd440 && row < 9'd460 && (column >= 10'd200 && column < 10'd440);
    assign board = column >= 10'd220 && column < 10'd420 && row >= 9'd40 && row < 9'd440;
    assign next_block_field = column >= 10'd480 && column < 10'd600 && row >= 9'd40 && row < 9'd120;

    //where are we now?
    wire [2:0] pos = {board, frames, next_block_field}; //do zmiany przy dodatkowych elementach
    localparam [2:0] BOARD = 3'b100, FRAME = 3'b010, NEXT_FIELD = 3'b001;


    always @* begin //trzeba zamienić na case
        
        case(pos)

        BOARD: rgb <= LIGHT_ROSE;

        FRAME: rgb <= LIGHT_GREY;

        NEXT_FIELD: rgb <= PURPLE;

        default: rgb <= DARK_GREY;

        endcase

    end

endmodule