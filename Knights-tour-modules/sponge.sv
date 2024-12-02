module sponge(
	input clk, rst_n,
	input go,
	output piezo, piezo_n
);
parameter FAST_SIM = 1;

localparam freq = 50000000; // 50MHz
localparam duty_cycle = 1; // 50% duty cycle by shifting right

// Note frequencies
localparam D7 = 21285;
localparam E7 = 18960;
localparam F7 = 17895;
localparam A6 = 28409;

// Note lengths
localparam triplet_eighth = 8388608;
localparam dotted_eighth = 12582912;
localparam sixteenth = 4194304;


// Signals coming from SM
logic [23:0] duration;
logic [15:0] note_period;
logic start_note;
typedef enum logic [3:0] {IDLE, D7_0, E7_1, F7_2, E7_3, F7_4, D7_5, A6_6, D7_7} state_t;


// Frequency counter
logic [15:0] note_period_cnt;
logic restart_square_wave; // Keep generating the correct wave during the whole frequency
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) // asynch reset
		note_period_cnt <= 0;
	else if(start_note) // synch reset on every note
		note_period_cnt <= 0;
	else if(restart_square_wave)
		note_period_cnt <= 0;
	else
		note_period_cnt <= note_period_cnt + 1'b1;
end
// Create piezo square wave based on desired frequency and duty cycle
assign piezo = (note_period_cnt < (note_period>>duty_cycle)) ? 1'b0 : 1'b1;
assign piezo_n = (note_period_cnt < (note_period>>duty_cycle)) ? 1'b1 : 1'b0;
// Figure out if we need to restart the square wave once we've counted whole frequency
assign restart_square_wave = (note_period_cnt > note_period) ? 1'b1 : 1'b0;


// Duration counter
// increment by 1 or 16 based on fast sim
logic [4:0] increment;
generate if(FAST_SIM) begin
	assign increment = 16;
end
else begin
	assign increment = 1;
end
endgenerate

// Count until we've reached the desired duration
logic [23:0] duration_cnt;
logic note_done; // When we've played the full duration of the note
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) // asynch reset
		duration_cnt <= 0;
	else if(start_note) // synch reset on every note
		duration_cnt <= 0;
	else
		duration_cnt <= duration_cnt + increment;
end
assign note_done = (duration_cnt > duration) ? 1 : 0; // Check if the full note has been played


// SM logic
state_t state, nxt_state;
// FFs for SM
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		state <= IDLE; // default to IDLE state
	else
		state <= nxt_state;
end
// Combinational logic for SM
always_comb begin
	// Default outputs
	note_period = 0;
	duration = 0;
	start_note = 0;
	nxt_state = state; // Hold state

	case(state)
		IDLE: begin
			start_note = 1; // Make sure piezo and piezo_n don't toggle till we start
			if(go) begin // Go to first note of song
				start_note = 1;
				nxt_state = D7_0;
			end
		end
		D7_0: begin
			note_period = D7;
			duration = triplet_eighth;
			if(note_done) begin // Go to next note
				start_note = 1;
				nxt_state = E7_1;
			end
		end
		E7_1: begin
			note_period = E7;
			duration = triplet_eighth;
			if(note_done) begin // Go to next note
				start_note = 1;
				nxt_state = F7_2;
			end
		end
		F7_2: begin
			note_period = F7;
			duration = triplet_eighth;
			if(note_done) begin // Go to next note
				start_note = 1;
				nxt_state = E7_3;
			end
		end
		E7_3: begin
			note_period = E7;
			duration = dotted_eighth;
			if(note_done) begin // Go to next note
				start_note = 1;
				nxt_state = F7_4;
			end
		end
		F7_4: begin
			note_period = F7;
			duration = sixteenth;
			if(note_done) begin // Go to next note
				start_note = 1;
				nxt_state = D7_5;
			end
		end
		D7_5: begin
			note_period = D7;
			duration = dotted_eighth;
			if(note_done) begin // Go to next note
				start_note = 1;
				nxt_state = A6_6;
			end
		end
		A6_6: begin
			note_period = A6;
			duration = sixteenth;
			if(note_done) begin // Go to next note
				start_note = 1;
				nxt_state = D7_7;
			end
		end
		D7_7: begin
			note_period = D7;
			duration = triplet_eighth;
			if(note_done) begin // Done playing song
				nxt_state = IDLE;
			end
		end
		default: nxt_state = IDLE; // default to IDLE
	endcase
end



endmodule
