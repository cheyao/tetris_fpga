module VGA_sync_states (
    input clk, rst,
    output hsync, vsync, blank_n, sync_n, 
    output reg [8:0] row, 
    output reg [9:0] column
);

// constants from https://www.intel.com/content/dam/support/us/en/programmable/support-resources/fpga-wiki/asset03/basic-vga-controller-design-example.pdf
localparam WIDTH = 640;
localparam HIGHT = 480;
localparam H_FP = 16;
localparam H_SP = 96;
localparam H_BP = 48;
localparam LINE = 800;
localparam V_FP = 10;
localparam V_SP = 2;
localparam V_BP = 33;

wire last_column;
wire last_row;
reg [9:0] cnt;      // counter of cycles
reg [5:0] cnt_l;    // counter of lines for vertical blanking period

localparam [2:0]  PRINT = 3'b000, H_FRONT_PORCH = 3'b001, H_SYNC_PULSE = 3'b010, 
            H_BACK_PORCH = 3'b011, V_FRONT_PORCH = 3'b100, V_SYNC_PULSE = 3'b101, 
            V_BACK_PORCH = 3'b110;
reg [2:0] q;

assign blank_n = q == PRINT;
assign hsync = q == H_SYNC_PULSE; 
assign vsync = q == V_SYNC_PULSE;
assign sync_n = !(hsync || vsync);

assign last_column = column == WIDTH - 1;
assign last_row = row == HIGHT - 1;

always @(posedge clk or posedge rst) begin
    
    if(rst) begin
        q <= PRINT;
        row <= 0;
        column <= 0;
        cnt <= 0;
        cnt_l <= 0;
    end
    else begin
        case(q)
        
        PRINT:  if(last_column) begin
                    q <= H_FRONT_PORCH;
                    cnt <= 0;
                end
                else 
                    column <= column + 1;

        H_FRONT_PORCH:  if(cnt < H_FP)
                            cnt <= cnt + 1;
                        else begin
                            q <= H_SYNC_PULSE;
                            cnt <= 0;
                        end

        H_SYNC_PULSE:    if(cnt < H_SP)
                            cnt <= cnt + 1;
                        else begin
                            q <= H_BACK_PORCH;
                            cnt <= 0;
                        end

        H_BACK_PORCH:   if(cnt < H_BP)
                            cnt <= cnt + 1;
                        else if(last_row) begin
                            q <= V_FRONT_PORCH;
                            cnt <= 0;
                            cnt_l <= 0;
                        end
                        else begin
                            q <= PRINT;
                            row <= row + 1;
                            column <= 0;
                        end

        V_FRONT_PORCH:  if(cnt_l < V_FP) begin
                            if(cnt < LINE)
                                cnt <= cnt + 1;
                            else begin
                                cnt <= 0;
                                cnt_l <= cnt_l + 1;
                            end
                        end
                        else begin
                            q <= V_SYNC_PULSE;
                            cnt <= 0;
                            cnt_l <= 0;
                        end

        V_SYNC_PULSE:   if(cnt_l < V_SP) begin
                            if(cnt < LINE)
                                cnt <= cnt + 1;
                            else begin
                                cnt <= 0;
                                cnt_l <= cnt_l + 1;
                            end
                        end
                        else begin
                            q <= V_BACK_PORCH;
                            cnt <= 0;
                            cnt_l <= 0;
                        end

        V_BACK_PORCH:   if(cnt_l < V_BP) begin
                            if(cnt < LINE)
                                cnt <= cnt + 1;
                            else begin
                                cnt <= 0;
                                cnt_l <= cnt_l + 1;
                            end
                        end
                        else begin
                            q <= PRINT;
                            row <= 0;
                            column <= 0;
                        end

        endcase
    end

end
    
endmodule