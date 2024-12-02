module PWM11 (input clk, input rst_n, input [10:0] duty, output logic PWM_sig, output logic PWM_sig_n);

    logic [10:0] cnt;

    // flip flop for the counter 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 11'b0;  // reset the counter to 0
        end else begin
            cnt <= cnt + 11'b00000000001;  // increment the counter on positive clock edge
        end
    end

    // flip flop to output PWM signals
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PWM_sig <= 1'b0;    // reset PWM signal on reset
            PWM_sig_n <= 1'b1;  // reset complementary PWM signal
        end else begin
            PWM_sig <= (cnt < duty);
            PWM_sig_n <= ~PWM_sig;
        end
    end


endmodule
