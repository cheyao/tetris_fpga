module VGA_sync (
    input clk, rst,
    output hsync, vsync, blank_n, sync_n, 
    output [8:0] row, 
    output [9:0] column
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
localparam V_BP = 15;

reg [9:0] cnt_c;    // counter of columns
reg [9:0] cnt_r;    // counter of rows

assign blank_n = cnt_c < WIDTH && cnt_r < HIGHT;
assign hsync = cnt_c >= WIDTH + H_FP && cnt_c < WIDTH + H_FP + H_SP;
assign vsync = cnt_r >= HIGHT + V_FP && cnt_r < HIGHT + V_FP + V_SP;
assign sync_n = !(hsync || vsync);

assign row = cnt_r < HIGHT ? cnt_r : HIGHT - 1;
assign column = cnt_c < WIDTH ? cnt_c : WIDTH - 1;

always @(posedge clk or posedge rst) begin
    
    if(rst) begin
        cnt_c <= 0;
        cnt_r <= 0;
    end
    else begin
        if(cnt_c < WIDTH + H_FP + H_SP + H_BP)
            cnt_c <= cnt_c + 1;
        else if (cnt_r < HIGHT + V_FP + V_SP + V_BP) begin
            cnt_c <= 0;
            cnt_r <= cnt_r + 1;
        end
        else begin
            cnt_c <= 0;
            cnt_r <= 0;
        end
    end

end
    
endmodule