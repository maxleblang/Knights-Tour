module UART_wrapper (clk, rst_n, RX, clr_cmd_rdy, trmt, tx_done, resp, cmd_rdy, cmd, TX);

    input wire clk, rst_n, RX, clr_cmd_rdy, trmt;  // input signals for clock, reset, and uart control
    input wire [7:0] resp;  // 8-bit response input
    output reg cmd_rdy;  // output to indicate command is ready
    output reg [15:0] cmd;  // 16-bit command output
    output wire TX, tx_done;  // uart transmission and done status outputs

    logic rx_rdy, select_high, clr_rdy;  // internal control signals
    logic [7:0] rx_data;  // stores received data byte

    // instantiate the uart module
    UART iDUT (
        .clk(clk), 
        .rst_n(rst_n), 
        .RX(RX), 
        .TX(TX), 
        .rx_rdy(rx_rdy), 
        .clr_rx_rdy(clr_rdy), 
        .rx_data(rx_data), 
        .trmt(trmt), 
        .tx_data(tx_data), 
        .tx_done(tx_done)
    );

    // define two states: high and low
    typedef enum logic { high, low } state_t;
    state_t current_state, next_state;  // current and next state registers

    // state transition logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)  // reset condition
            current_state <= high;  // set to high state on reset
        else 
            current_state <= next_state;  // update to next state
    end

    // internal signals for sr flop for command ready control
    logic clr_cmd_rdy_int;  // clear command ready signal internal
    logic set_cmd_rdy;  // set command ready signal

    // sr flop for command ready control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)  // reset condition
            cmd_rdy <= 1'b0;  // reset cmd_rdy
        else if (clr_cmd_rdy_int || clr_cmd_rdy)  // if either clear signal is high
            cmd_rdy <= 1'b0;  // clear cmd_rdy
        else if (set_cmd_rdy)  // if set signal is high
            cmd_rdy <= 1'b1;  // set cmd_rdy
    end

    logic [7:0] storing_high;  // register to hold the high byte

    // store the high byte when select_high is active
    always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			storing_high <= 0;
		end
        else if (select_high)  // if select_high is active
            storing_high <= rx_data;  // store received data
    end

    // concatenate high and low bytes to form the 16-bit command
    assign cmd = {storing_high, rx_data};

    // state machine logic to handle state transitions and control signals
    always_comb begin
        // default values for control signals
        clr_rdy = 1'b0;
        set_cmd_rdy = 1'b0;
        select_high = 1'b0;
        next_state = current_state;
        clr_cmd_rdy_int = 1'b0;

        // state transition cases
        case (current_state)
            default: begin  // high state behavior
                if (rx_rdy) begin  // if data is ready
                    clr_rdy = 1'b1;  // clear ready signal
                    select_high = 1'b1;  // select high byte
                    clr_cmd_rdy_int = 1'b1;  // clear cmd ready
                    next_state = low;  // move to low state
                end
            end

            low: begin  // low state behavior
                if (rx_rdy) begin  // if data is ready
                    clr_rdy = 1'b1;  // clear ready signal
                    set_cmd_rdy = 1'b1;  // set cmd ready
                    next_state = high;  // move to high state
                end
            end

        endcase
    end

endmodule

