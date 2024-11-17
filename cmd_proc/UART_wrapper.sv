module UART_wrapper(clk, rst_n, RX, TX, resp, trmt, tx_done, cmd, cmd_rdy, clr_cmd_rdy);

    input clk, rst_n;              // Clock and active-low reset
    input trmt, clr_cmd_rdy;       // Transmit signal and clear command ready signal
    input RX;                      // UART receive line
    input [7:0] resp;              // Data to transmit
    output logic TX, tx_done;      // UART transmit line and transmission done signal
    output logic [15:0] cmd;       // Combined 16-bit command
    output logic cmd_rdy;          // Command ready signal

    // Internal signals
    logic rx_rdy;                  // Receive ready signal from UART
    logic clr_rx_rdy;              // Clear receive ready signal
    logic cmd_high_rdy;            // Indicates readiness to capture the high byte of the command
    logic set_cmd_rdy;             // Sets command ready state

    logic [7:0] rx_data;           // Data received from UART
    logic [7:0] cmd_high;          // High byte of command
    logic [7:0] cmd_low;           // Low byte of command

    // UART instantiation
    UART iUART(
        .clk(clk),
        .rst_n(rst_n),
        .RX(RX),
        .TX(TX),
        .rx_rdy(rx_rdy),
        .clr_rx_rdy(clr_rx_rdy),
        .rx_data(rx_data),
        .trmt(trmt),
        .tx_data(resp),
        .tx_done(tx_done)
    );

    // Capture high byte of the command
    always_ff @(posedge clk)
        if (cmd_high_rdy)
            cmd_high <= rx_data;

    // Directly assign low byte of the command
    assign cmd_low = rx_data;

    // Combine high and low bytes into a 16-bit command
    assign cmd = {cmd_high, cmd_low};

    // Control command ready signal
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            cmd_rdy <= 1'b0;      // Reset command ready on reset
        else if (clr_cmd_rdy)
            cmd_rdy <= 1'b0;      // Clear command ready when requested
        else if (set_cmd_rdy)
            cmd_rdy <= 1'b1;      // Set command ready when command is complete

    // State machine definitions
    typedef enum logic [1:0] {
        HIGH, LOW
    } state_t;

    state_t state, nxt_state;

    // State transition logic
    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
            state <= HIGH;        // Start in HIGH state after reset
        else
            state <= nxt_state;

    // State machine logic
    always_comb begin
        // Default signal assignments
        nxt_state = state;
        cmd_high_rdy = 0;
        set_cmd_rdy = 0;
        clr_rx_rdy = 0;

        case (state)
            default: begin
                if (rx_rdy) begin
                    cmd_high_rdy = 1;   // Capture high byte
                    clr_rx_rdy = 1;     // Clear receive ready signal
                    nxt_state = LOW; 
                end
            end

            LOW: begin
                if (rx_rdy) begin
                    set_cmd_rdy = 1;    // Mark command as ready
                    clr_rx_rdy = 1;     // Clear receive ready signal
                    nxt_state = HIGH;   
                end
            end
        endcase
    end

endmodule
