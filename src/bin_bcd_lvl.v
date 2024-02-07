module bin_bcd_lvl(
    input clk, gen,
    input [5:0] bin,
    output reg [7:0] bcd
);
   
reg [3:0]cnt;

always @(posedge clk) begin
    if(gen) begin
        cnt <= 4'd1;
        bcd <= 0;
    end

    if(cnt > 4'd0 && cnt < 4'd13) begin
         if(cnt[0]) begin
            if (bcd[3:0] >= 4'd5) bcd[3:0] <= bcd[3:0] + 4'd3;	
            if (bcd[7:4] >= 4'd5) bcd[7:4] <= bcd[7:4] + 4'd3;
            cnt <= cnt + 1;
        end
        else begin
            bcd <= {bcd[6:0],bin[6-(cnt >> 1)]};
            cnt <= cnt + 1;
        end
    end
end

endmodule