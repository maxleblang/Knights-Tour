module sponge_tb();
// Signals for the DUT
logic clk, rst_n;
logic go;
logic piezo, piezo_n;

localparam song_length = 8388608 + 8388608 + 8388608 + 8388608 + 12582912 + 12582912 + 4194304 + 4194304; // Duration of 62914560 clks but with FAST SIM (divide 16)
localparam fast_song_length = song_length / 16;


// Instantiate DUT
sponge fanfare(.clk(clk), .rst_n(rst_n), .go(go), .piezo(piezo), .piezo_n(piezo_n));


initial begin
	clk = 0;
	go = 0;
	// Reset the DUT
	rst_n = 0;
	@(posedge clk);
	@(negedge clk); rst_n = 1;
	
	// Start TB
	go = 1;
	@(posedge clk);
	go = 0;
	@(posedge clk);
	
	// TODO: fork join
	while(fanfare.start_note !== 1)
		@(posedge clk);

	$display("Done running! Go and inspect now");
	$stop();
	
end
always
	#20 clk = ~clk; // 50MHz clock

endmodule