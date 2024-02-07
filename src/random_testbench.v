module testbench;
  
  reg clk;
  
  always #1 clk = ~clk;
  
  reg [8:0] d;
  reg rst;
  wire [4:0] o;
  
  pseudo_random_number_generator #(4) PRNG(clk, rst, d, o); //parametryzujemy LICZBA_BITOW - 1
  
  initial begin
    clk = 0;
    rst = 1;
    d = 9'd413;
    #1 rst = 0;

    #500 $finish;
  end
  
initial $monitor($time, "  ", o);

endmodule