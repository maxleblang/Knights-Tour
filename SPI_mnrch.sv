module SPI_mnrch(clk, rst_n, SS_n, SCLK, MOSI, MISO, snd, cmd, done, resp);
    input clk, rst_n;                // Clock and reset signal
    input MISO;                      
    input snd;                       // Start sending signal
    input [15:0] cmd;                // Command data to be sent
    output logic done;               // Transmission done
    output logic SS_n, SCLK, MOSI;   
    output logic [15:0] resp;        // Response data 

    logic [4:0] bit_cntr, SCLK_div; // Bit counter and SCLK divider
    logic [15:0] shft_reg;           // Shift 

    logic done16, full, ld_SCLK;     // Status and control
    logic init, set_done, shft;      // Control signals for state machine

    // Bit counter logic
    always_ff @ (posedge clk)
        if(init) begin
            bit_cntr <= 5'b00000;     // Reset bit counter
        end else if (shft) begin
            bit_cntr <= bit_cntr + 1; // Increment bit counter
        end 

    assign done16 = (bit_cntr == 5'h10) ? 1'b1 : 1'b0; // Check if 16 bits have been shifted

    // SCLK divider logic
    always_ff @ (posedge clk)
        if(ld_SCLK) begin
            SCLK_div <= 5'b10111;     
        end else begin
            SCLK_div <= SCLK_div + 1; // Increment SCLK divider
        end

    assign shft = (SCLK_div == 5'b10001)? 1'b1 : 1'b0; // Signal to shift data
    assign full = (SCLK_div == 5'b11111)? 1'b1 : 1'b0; // SCLK divider is full
    assign SCLK = SCLK_div[4];

    // Shift register logic 
    always_ff @(posedge clk)
        if(init) begin
            shft_reg <= cmd;           // Load command into shift register
        end else if (shft) begin
            shft_reg <= {shft_reg[14:0], MISO}; // Shift in data from MISO
        end

    assign MOSI = shft_reg[15];      // Output the MSB of shift register to MOSI
    assign resp = shft_reg;          // Assign shift register to resp

    // State machine
    typedef enum logic [1:0] {
        IDLE, NEXT, FINAL            // Define states
    } state_t;

    state_t state, nxt_state;       

    // State transition logic
    always_ff@(posedge clk, negedge rst_n)
    if(!rst_n)
        state <= IDLE;                // Reset state to IDLE
    else
        state <= nxt_state;           // Update current state

    // Next state and control logic
    always_comb begin

        //set defaults
        nxt_state = state; 
        set_done = 1'b0; 
        ld_SCLK = 1'b0;        
        init = 1'b0;              
        
        case(state)
        NEXT: begin
            if(done16)              
                nxt_state = FINAL; 
        end
        
        FINAL: begin
            if(full) begin
                set_done = 1'b1;      
                ld_SCLK = 1'b1;        
                nxt_state = IDLE;     
            end
        end

        default: begin //IDLE state
            if(!snd)
                ld_SCLK = 1'b1;        
            else if (snd) begin
                init = 1'b1;          
                nxt_state = NEXT;      
            end
        end
        endcase
    end

    // Done signal logic
    always_ff@(posedge clk, negedge rst_n)
        if(!rst_n) begin
            done <= 1'b0;               // Reset done signal
        end else if (init) begin
            done <= 1'b0;               // Clear done on init for new transmission
        end else if (set_done) begin
            done <= 1'b1;               // Set done signal
        end

    // SS_n logic
    always_ff@(posedge clk, negedge rst_n)
        if(!rst_n) begin
            SS_n <= 1'b1;               // Preset SS_n (active low)
        end else if (init) begin
            SS_n <= 1'b0;               // Clear SS_n to start transmission
        end else if (set_done) begin
            SS_n <= 1'b1;               // Set SS_n high after transmission
        end

endmodule