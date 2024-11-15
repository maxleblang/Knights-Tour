module sponge_test(
	input clk,
	input GO, RST_n,
	output piezo, piezo_n
);

// Signals to connect PB with fanfare
logic go;
// Signals to connect Reset with fanfare
logic rst_n;

// Synchronize PB to start fanfare
PB_release Press_button(.clk(clk), .rst_n(RST_n), .PB(GO), .released(go));

// Synchronize Reset to reset ALL blocks
reset_synch reset(.clk(clk), .RST_n(RST_n), .rst_n(rst_n));

// Connect fanfare block
sponge #(0) fanfare(.clk(clk), .rst_n(rst_n), .go(go), .piezo(piezo), .piezo_n(piezo_n));


endmodule