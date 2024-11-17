module RemoteComm(clk, rst_n, snd_cmd, cmd, TX, RX, cmd_snt, resp_rdy, resp);
    input clk, rst_n;            // Clock and active low reset
    input snd_cmd;               // Command send signal
    input [15:0] cmd;            // Command data
    input RX;                    // Receive data
    output logic TX;             // Transmit data
    output logic cmd_snt;        // Command sent singal
    output logic resp_rdy;       // Response ready signal
    output logic [7:0] resp;     // Response data

    logic clr_rx_rdy;            // Clear receive ready signal
    logic trmt;                  // Transmit signal
    logic [7:0] tx_data;         // Data to send
    logic tx_done;               // Transmission complete signal
    logic [7:0] cmd_low;         // Lower byte of command
    logic sel_high;              // Select high byte 
    logic set_cmd_snt;           // Set command sent signal

    // Instantiate UART 
    UART iUART(
        .clk(clk),
        .rst_n(rst_n),
        .RX(RX),
        .TX(TX),
        .rx_rdy(resp_rdy),
        .clr_rx_rdy(clr_rx_rdy),
        .rx_data(resp),
        .trmt(trmt),
        .tx_data(tx_data),
        .tx_done(tx_done)
    );

    // Capture lower byte of command
    always_ff @(posedge clk) 
        if (snd_cmd) begin
        cmd_low <= cmd[7:0];
        end

    // Select data to transmit
    assign tx_data = sel_high ? cmd[15:8] : cmd_low;

    // State machine 
    typedef enum logic [1:0] { IDLE, HIGH, LOW } state_t;
    state_t state, nxt_state;

    always_ff @(posedge clk, negedge rst_n) 
        if (!rst_n) state <= IDLE; 
        else state <= nxt_state;    

    always_comb begin
        //defaults
        nxt_state = state;          
        sel_high = 0;         
        trmt = 0;                
        set_cmd_snt = 0;       

        case (state)
            HIGH: begin
            sel_high = 1;
            if (tx_done) begin
                sel_high = 0;       // Switch to low byte
                trmt = 1;           // Begin transmission
                nxt_state = LOW;    
            end
            end

            LOW: if (tx_done) begin
                set_cmd_snt = 1;    // Set command sent
                trmt = 0;           // Stop transmission
                nxt_state = IDLE; 
            end
            default: if (snd_cmd) begin
                sel_high = 1;       // Select high byte
                trmt = 1;           // Start transmission
                nxt_state = HIGH;  
            end
        endcase
    end

    // Update command sent flag
    always_ff @(posedge clk, negedge rst_n) 
        if (!rst_n) cmd_snt <= 1'b0;
        else if (set_cmd_snt) cmd_snt <= 1'b1; // assertt cmd_snt
        else if (snd_cmd) cmd_snt <= 1'b0; // Clear on new command
        
endmodule
