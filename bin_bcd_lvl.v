module bin_bcd_lvl(
    input clk, gen,
    input [5:0] bin,
    output reg [7:0] bcd
);
   
reg [2:0]cnt;

always @(posedge clk) begin
    if(gen) begin
        cnt <= 3'd1;
        bcd <= 0;
    end

    if(cnt > 3'd0 && cnt < 3'd7) begin
        if (bcd[3:0] >= 4'd5) bcd[3:0] <= bcd[3:0] + 4'd3;	
        if (bcd[7:4] >= 4'd5) bcd[7:4] <= bcd[7:4] + 4'd3;
        bcd <= {bcd[6:0],bin[8-cnt]};
        cnt <= cnt + 1;
    end
end

endmodule