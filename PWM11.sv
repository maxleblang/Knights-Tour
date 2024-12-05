module PWM11(clk, rst_n, duty, PWM_sig, PWM_sig_n);

    input clk, rst_n;
    input [10:0]duty;
    output logic PWM_sig, PWM_sig_n;

    logic [10:0]cnt;
    logic compare;

    always_ff @ (posedge clk or negedge rst_n)
        if(!rst_n)
            cnt <= 11'h00;
        else
            cnt <= cnt + 1;

    assign compare = cnt < duty ? 1'b1 : 1'b0;

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n) 
            PWM_sig <= 1'b0;
        else 
            PWM_sig <= compare;


    assign PWM_sig_n = ~PWM_sig;

endmodule
        