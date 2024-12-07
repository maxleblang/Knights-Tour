module PID (
	input clk,
	input rst_n,
	input moving,
	input err_vld,
	input signed [11:0] error,
	input [9:0] frwrd,
	output [10:0] lft_spd,
	output [10:0] rght_spd
);

////////////////////////////
// P TERM IMPLEMENTATION //
///////////////////////////
logic signed [13:0] P_term; // Output for the P term
logic signed [9:0] err_sat_p1; // Pipelined version of err_sat
localparam signed [5:0] P_COEFF = 6'h10;

// Saturating Logic
logic signed [9:0] err_sat;
assign err_sat = (error[11] && !(error[10] && error[9])) ? 10'h200 : // Saturate most negative number
	(!error[11] && (error[10] || error[9])) ? 10'h1FF :  // Saturate most positive number
	error[9:0]; // Number in range

// ADDED THIS PIPELINE 
// Add pipeline stage for err_sat
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		err_sat_p1 <= 10'h000;
	else
		err_sat_p1 <= err_sat;
end

// Compute P_term using pipelined err_sat
assign P_term = err_sat_p1 * P_COEFF;

////////////////////////////
// I TERM IMPLEMENTATION //
///////////////////////////
logic signed [8:0] I_term; // Output for the I term
logic signed [14:0] err_sign_ext, acc_rslt, valid_acc, integrator, nxt_integrator;
logic ov_rslt;
logic err_vld_p1; // Pipelined err_vld for integrator logic

// ADDED THIS PIPELINE since it should be in sync with the err_sat_p1!
// Pipeline err_vld 
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		err_vld_p1 <= 1'b0;
	else
		err_vld_p1 <= err_vld;
end

// Sign extending err saturation
assign err_sign_ext = {{5{err_sat_p1[9]}}, err_sat_p1};

// Accumulator result
assign acc_rslt = integrator + err_sign_ext;

// Overflow logic
assign ov_rslt = (err_sign_ext[14] === integrator[14]) ? ((err_sign_ext[14] === acc_rslt[14]) ? 0 : 1) : 0;

// Accumulate status mux
assign valid_acc = ~ov_rslt & err_vld_p1 ? acc_rslt : integrator;

// Moving mux
assign nxt_integrator = moving ? valid_acc : 15'h0000;

// Output 
assign I_term = integrator[14:6];

// Integrator register
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		integrator <= 15'h0000;
	else
		integrator <= nxt_integrator;
end

////////////////////////////
// D TERM IMPLEMENTATION //
///////////////////////////
logic signed [12:0] D_term; // Output for the D term
logic signed [9:0] q1, q2, prev_err; // Triple flops for err_sat
localparam D_COEFF = 5'h07;
logic signed [9:0] D_diff;
logic signed [7:0] D_sat;

// Triple flop for prev_err
always_ff @(posedge clk) begin
	if (!rst_n) begin
		q1 <= 0;
		q2 <= 0;
		prev_err <= 0;
	end else if (err_vld_p1) begin
		q1 <= err_sat_p1;
		q2 <= q1;
		prev_err <= q2;
	end
end

// ALU subtraction operator
assign D_diff = err_sat_p1 - prev_err;

// Saturation logic to make D_diff 8 bits
assign D_sat = (D_diff[9] && !(D_diff[8] && D_diff[7])) ? 8'h80 : // Saturate most negative number
	(!D_diff[9] && (D_diff[8] || D_diff[7])) ? 8'h7F :  // Saturate most positive number
	D_diff[7:0]; // Number in range

// Compute signed multiply
assign D_term = D_sat * $signed(D_COEFF);

////////////////////////////
// PID INTEGRATION LOGIC //
///////////////////////////

// ADDED THIS PIPELINE 
logic [13:0] PID_stage1, PID;
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		PID <= 14'h0000;
	else
		PID <= {P_term[13], P_term[13:1]} + {{5{I_term[8]}}, I_term} + {D_term[12], D_term};
end 

/////////////////////////////
// LEFT SPEED CALCULATION //
///////////////////////////
logic [10:0] lft_sum, lft_sat_in;
assign lft_sum = PID[13:3] + {1'b0, frwrd};
assign lft_sat_in = moving ? lft_sum : 11'h000;

// Left saturation logic
assign lft_spd = (~PID[13] & lft_sat_in[10]) ? 11'h3FF : lft_sat_in;

//////////////////////////////
// RIGHT SPEED CALCULATION //
///////////////////////////
logic [10:0] rght_sum, rght_sat_in;
assign rght_sum = {1'b0, frwrd} - PID[13:3];
assign rght_sat_in = moving ? rght_sum : 11'h000;

// Right saturation logic
assign rght_spd = (PID[13] & rght_sat_in[10]) ? 11'h3FF : rght_sat_in;

endmodule
