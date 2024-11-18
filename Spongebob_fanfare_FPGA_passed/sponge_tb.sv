module sponge_tb();
// Signals for the DUT
logic clk, rst_n;
logic go;
logic piezo, piezo_n;
int note_cnt;

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
	
	// Make sure we play every note
	note_cnt = 0;
	fork
		begin: timeout
			repeat(fast_song_length + 100) @(posedge clk);
			$display("ERROR: timed out waiting to play the whole song");
			$stop();
		end
		begin
			@(posedge (note_cnt == 8));
			disable timeout;
		end
	join

	$display("Done running! Go and inspect now");
	$stop();
	
end
always @(posedge fanfare.start_note) // Count when every note was played
	note_cnt <= note_cnt + 1;
always
	#20 clk = ~clk; // 50MHz clock

endmodule