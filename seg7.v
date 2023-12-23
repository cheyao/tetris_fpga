module seg7(input [3:0] n, output [6:0] o);
  
  assign o[0] = (n == 4'h1 || n == 4'h4);
  assign o[1] = (n == 4'h1 || n == 4'h5 || n == 4'h6 
                  || n == 4'hc || n == 4'he || n == 4'hf);
  assign o[2] = (n == 4'h1 || n == 4'h2 || n == 4'hc
                  || n == 4'he || n == 4'hf);
  assign o[3] = (n == 4'h1 || n == 4'h4 || n == 4'h7
                  || n == 4'ha || n == 4'hf);
  assign o[4] = (n == 4'h3 || n == 4'h5 || n == 4'h7
                  || n == 4'h9 || n == 4'h4);
  assign o[5] = (n == 4'h2 || n == 4'h3 || n == 4'h7);
  assign o[6] = (n == 4'h0 || n == 4'h1 || n == 4'h7
                  || n == 4'hc || n == 4'hd);
  
endmodule