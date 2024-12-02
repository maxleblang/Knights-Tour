module MtrDrv(clk, rst_n, lft_spd, rght_spd, lftPWM1, lftPWM2, rghtPWM1, rghtPWM2);

input logic signed [10:0] lft_spd;
input logic signed [10:0] rght_spd;
output logic lftPWM1, lftPWM2, rghtPWM1, rghtPWM2;
input logic clk, rst_n;

logic constant = 11'h400;

logic [10:0] intermediate_left;
logic [10:0] intermediate_right;

assign intermediate_left = lft_spd + constant;
assign intermediate_right = rght_spd + constant;

//first PWM11: left
PWM11 left_iDUT(.clk(clk), .rst_n(rst_n), .duty(intermediate_left), .PWM_sig(lftPWM1), .PWM_sig_n(lftPWM2));

//first PWM11: right
PWM11 right_iDUT(.clk(clk), .rst_n(rst_n), .duty(intermediate_right), .PWM_sig(rght), .PWM_sig_n(rght));

endmodule