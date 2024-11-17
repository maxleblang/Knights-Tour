module reset_synch(clk, RST_n, rst_n);

input clk, RST_n;
output reg rst_n;

reg intermediate;

always @(posedge clk, negedge RST_n)
    if (!RST_n)
        intermediate <= 1'b0;
    else
        intermediate <= 1'b1;

always @(posedge clk, negedge rst_n)
    if (!rst_n)
        rst_n <= 1'b0;
    else
        rst_n <= intermediate;  

endmodule