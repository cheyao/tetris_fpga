module top (
	input  wire        clk,
    input  wire  [1:0] button,
	output logic [3:0] gpdi_dp,
	output logic [4:0] led
);
	// Generate pixel and tmds clock (25MHz and 250MHz)
	wire clkp, clkt, clksys;

	pll1 pll_dvi(.clkin(clk), .clkt(clkt), .clkp(clkp), .locked(led[0]));
	pll2 pll_sys(.clkin(clk), .clk315(clksys), .locked(led[1]));

	// VGA input and output signals
	wire        vsync, hsync, de;
	wire  [7:0] vga_r, vga_g, vga_b;

	// VGA Signal generator
    Tetris tetris(
        .clk(clksys),

        .KEY({0, 0, ~button[0], ~button[1]}),

        .VGA_BLANK_N(de),
        .VGA_B(vga_b),
        .VGA_CLK(clksys),
        .VGA_G(vga_g),
        .VGA_HS(hsync),
        .VGA_R(vga_r),
        .VGA_SYNC_N(),
        .VGA_VS(vsync),

        .led(led)
    );

	// Convert the signal to DVI and send over HDMI
	vga2tmds tmds_generator(
		.clkp(clkp), .clkt(clkt),
		.vsync(vsync), .hsync(hsync), .de(de),
		.r(vga_r), .g(vga_g), .b(vga_b), .tmds(gpdi_dp));
endmodule

