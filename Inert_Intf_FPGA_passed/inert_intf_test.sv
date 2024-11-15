module inert_intf_test(
	input clk, RST_n,
	input MISO, INT,
	output SS_n, SCLK, MOSI,
	output [7:0] LED
);
// States for SM
typedef enum logic [1:0] {IDLE, CAL, DISP} state_t;

// Instantiate rst_n synchronizer
logic rst_n;
reset_synch synch(.clk(clk), .RST_n(RST_n), .rst_n(rst_n));

// Instantiate intertial interface
logic cal_done, strt_cal;
logic [11:0] heading;
inert_intf #(0) inert(.clk(clk), .rst_n(rst_n), .moving(1), .lftIR(0), .rghtIR(0), .cal_done(cal_done), .strt_cal(strt_cal), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .INT(INT), .heading(heading));

// SM logic
logic sel;
state_t state, nxt_state;
// FF logic for SM
always_ff @(posedge clk) begin
	// Default to IDLE state
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
end
// Comb logic for SM (Bubble diagram supplied
always_comb begin
	// Default outputs
	strt_cal = 0;
	sel = 0;
	nxt_state = state; // Hold state
	case(state)
		IDLE: begin
			sel = 0;
			// Go right to CAL
			strt_cal = 1;
			nxt_state = CAL;
		end
		CAL: begin
			sel = 1;
			if(cal_done)// Wait till the calibration has completed
				nxt_state = DISP;
		end
		DISP: sel = 0;
		default: nxt_state = IDLE; // Default to IDLE
	endcase
end


// LED output mux
assign LED = sel ? 8'hA5 : heading[11:4];

endmodule