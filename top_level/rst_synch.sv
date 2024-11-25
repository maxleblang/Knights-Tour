module rst_synch(RST_n, rst_n)

input logic RST_n;
output logic rst_n;

logic intermediate;

always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
        intermediate <= 1'b0;
    else
        intermediate <= 1'b1;

always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
        rst_n <= 1'b0;
    else
        rst_n <= intermediate;  

endmodule