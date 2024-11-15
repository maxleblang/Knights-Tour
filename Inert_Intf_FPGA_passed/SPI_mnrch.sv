module SPI_mnrch(
    input clk, rst_n,
    input snd,
    input [15:0] cmd,
    output logic done,
    output [15:0] resp,
    output logic SS_n, SCLK, MOSI,
    input MISO
);
// SM states
typedef enum logic [1:0] {IDLE, SHIFT, BACK_PORCH} state_t;
// Signals coming from SM
logic ld_SCLK, init, set_done, done16;


/*
SCLK Count register:
- Load in 10111 to account for front porch
- Count to 10001 to account for 2 clk delay
*/
// Count Register
logic [4:0] SCLK_div;
always_ff @(posedge clk) begin
    if(ld_SCLK)
        SCLK_div <= 5'b10111;
    else
        SCLK_div <= SCLK_div + 1; // Count up
end
// Decode logic
logic full, shft;
assign shft = (SCLK_div == 5'b10001) ? 1 : 0; // Detect when we've counted to 10001
assign full = &SCLK_div; // Detect when register is full
// Finally extract SCLK (MSB of count reg)
assign SCLK = SCLK_div[4];


/*
Bit count count register
*/
logic [4:0] bit_cntr;
always_ff @(posedge clk) begin
    if(init)
        bit_cntr <= 5'b00000;
    else if(shft)
        bit_cntr <= bit_cntr + 1;
end
// See if we've shifted 16 bits yet
assign done16 = bit_cntr[4]; // 16 in binary


/*
Shift register:
- Parallel load in MOSI cmd on init
- Shift in 16-bit MISO while we shift out 16-bit MOSI
*/
logic [15:0] shft_reg;
always_ff @(posedge clk) begin
    // Parallel load
    if(init)
        shft_reg <= cmd;

    // Shift logic
    else if(shft)
        shft_reg <= {shft_reg[14:0], MISO};
        MOSI <= shft_reg[15];
end
assign resp = shft_reg; // Received MISO is in shft_reg after all 16-bits are shifted in


/*
SM Logic
*/
// FF for state
state_t state, nxt_state;
always_ff @(posedge clk, negedge rst_n) begin
    // Default to IDLE
    if(!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end
// Comb logic from bubble diagram (I drew)
always_comb begin
    // Default all outputs
    ld_SCLK = 0;
    init = 0;
    set_done = 0;
    nxt_state = state; // Hold state

    case (state)
        IDLE: begin
            ld_SCLK = 1; // Don't want to start SCLK yet
            if(snd) begin // Wait till we want to send data
                init = 1;
                nxt_state = SHIFT;
            end
        end
        SHIFT: if(done16) begin // Wait till we've shifted all 16 bits in/out
            nxt_state = BACK_PORCH;
        end
        BACK_PORCH: if(full) begin // Wait until SCLK counter is full to account for back porch
            set_done = 1;
	    ld_SCLK = 1;
            nxt_state = IDLE;
        end
        default: nxt_state = IDLE;
    endcase
end


/*
Done and SS_n logic:
- Similar except on rst_n done is reset, SS_n is preset
*/
// Done logic
always_ff @(posedge clk, negedge rst_n) begin
    // Asynch reset
    if(!rst_n)
        done <= 0;
    // Synch clear
    else if(init)
        done <= 0;
    // Synch set
    else if(set_done)
        done <= 1;
end
// SS_n logic
always_ff @(posedge clk, negedge rst_n) begin
    // Asynch preset
    if(!rst_n)
        SS_n <= 1;
    // Synch clear
    else if(init)
        SS_n <= 0;
    // Synch set
    else if(set_done)
        SS_n <= 1;
end

endmodule