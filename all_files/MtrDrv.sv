module MtrDrv(clk, rst_n, lft_spd, rght_spd, lftPWM1, lftPWM2, rghtPWM1,       rghtPWM2);

    input clk, rst_n;
    input signed [10:0]lft_spd;
    input signed [10:0]rght_spd;
    output logic lftPWM1, lftPWM2;
    output logic rghtPWM1, rghtPWM2;

    logic [10:0] add1;
    logic [10:0] add2;

    assign add1 = lft_spd + 11'h400;
    assign add2 = rght_spd + 11'h400;

    PWM11 PWM11_1(.clk(clk), .rst_n(rst_n), .duty(add1), .PWM_sig(lftPWM1), .PWM_sig_n(lftPWM2));

    PWM11 PWM11_2(.clk(clk), .rst_n(rst_n), .duty(add2), .PWM_sig(rghtPWM1), .PWM_sig_n(rghtPWM2));

endmodule


