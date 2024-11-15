module reset_synch(
	input RST_n, clk,
	output reg rst_n
);

// Double flop to produce our rst_n signal
reg rst_ff1_n;
always @(negedge clk, negedge RST_n) begin
	if(!RST_n) begin
		rst_ff1_n <= 0;
		rst_n <= 0;
	end
	else begin
		rst_ff1_n <= 1'b1;
		rst_n <= rst_ff1_n;
	end
end
endmodule
