module TourCmd(clk,rst_n,start_tour,move,mv_indx,
               cmd_UART,cmd,cmd_rdy_UART,cmd_rdy,
               clr_cmd_rdy,send_resp,resp);

input clk,rst_n;        // 50MHz clock and asynch active low reset
input start_tour;       // from done signal from TourLogic
input [7:0] move;       // encoded 1-hot move to perform
output reg [4:0] mv_indx;    // "address" to access next move
input [15:0] cmd_UART;       // cmd from UART_wrapper
input cmd_rdy_UART;          // cmd_rdy from UART_wrapper
output [15:0] cmd;           // multiplexed cmd to cmd_proc
output cmd_rdy;              // cmd_rdy signal to cmd_proc
input clr_cmd_rdy;          // from cmd_proc (goes to UART_wrapper too)
input send_resp;            // lets us know cmd_proc is done with the move command
output [7:0] resp;          // either 0xA5 (done) or 0x5A (in progress)

// State declaration
typedef enum logic [2:0] {
    IDLE,            // waiting for start_tour signal
    VERT_MOVE,       // processing vertical move command
    VERT_WAIT,       // waiting for vertical move to complete
    HOR_MOVE,        // processing horizontal move command
    HOR_WAIT         // waiting for horizontal move to complete
} state_t;

// Which part of the move we're decomposing
typedef enum {
    VERT,           // Decompose Vertical part of move
    HOR             // Decompose Horizontal part of move
} move_part_t;

// Input signals for move index counter
logic zero_mv_indx;
logic incr_mv_indx;

// Counter logic
always_ff @(posedge clk) begin
    if(zero_mv_indx) // Synch reset
        mv_indx <= 0;
    else if(incr_mv_indx) // SM controls when we want to move to the next move
        mv_indx <= mv_indx + 1;
end

// Command selection muxes
logic cmd_from_uart; // Whether we want to send the cmd from the uart or the cmd from tour logic
logic [15:0] tour_cmd; // Decomposed moved from TourLogic
logic tour_cmd_rdy; // Whether the command coming from TourLogic is ready (from SM)

// Muxes
assign cmd = cmd_from_uart ? cmd_UART : tour_cmd;
assign cmd_rdy = cmd_from_uart ? cmd_rdy_UART : tour_cmd_rdy;

// UART response logic
assign resp = (mv_indx < 23) && !cmd_from_uart ? 8'h5A : (mv_indx == 23) && cmd_from_uart ? 8'hA5 : 8'h00;

// Move decomposition logic
move_part_t move_part; // Whether we're decomposing the vertical or horizontal component of the move
logic play_sponge; // Whether we play fanfare or not
logic [7:0] heading; // 8-bit heading
logic [3:0] num_moves; // How many squares we move

always_comb begin

	heading = 8'h00;
    num_moves = 4'h0;
    play_sponge = 0;

    case(move_part)
        VERT: begin // Decompose vertical part of the move
            if((move == 8'b00000001) || (move == 8'b00000010)) begin // Moves 1 and 0
                heading = 8'h00;
                num_moves = 4'h2;
                play_sponge = 0;
            end
            else if((move == 8'b00000100) || (move == 8'b10000000)) begin // Moves 2 and 7
                heading = 8'h00;
                num_moves = 4'h1;
                play_sponge = 1;
            end
            else if((move == 8'b00001000) || (move == 8'b01000000)) begin // Moves 3 and 6
                heading = 8'h7F;
                num_moves = 4'h1;
                play_sponge = 1;
            end
            else if((move == 8'b00010000) || (move == 8'b00100000)) begin // Moves 4 and 5
                heading = 8'h7F;
                num_moves = 4'h2;
                play_sponge = 0;
            end
        end
        HOR: begin // Decompose horizontal part of the move
            if((move == 8'b00000010) || (move == 8'b00010000)) begin // Moves 1 and 4
                heading = 8'h3F;
                num_moves = 4'h1;
                play_sponge = 1;
            end
            else if((move == 8'b00000100) || (move == 8'b00001000)) begin // Moves 2 and 3
                heading = 8'h3F;
                num_moves = 4'h2;
                play_sponge = 0;
            end
            else if((move == 8'b00000001) || (move == 8'b00100000)) begin // Moves 0 and 5
                heading = 8'hBF;
                num_moves = 4'h1;
                play_sponge = 1;
            end
            else if((move == 8'b10000000) || (move == 8'b01000000)) begin // Moves 7 and 6
                heading = 8'hBF;
                num_moves = 4'h2;
                play_sponge = 0;
            end
        end
    endcase
end

// Construct cmd from decomposed signals
assign tour_cmd = {3'b010, play_sponge, heading, num_moves}; // NOTE: 010 MSB tells cmd_proc we're moving

// State machine signals
state_t state, nxt_state;

// State machine FF logic
always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
end

// State machine combinational logic
always_comb begin
    // Default assignments
    zero_mv_indx = 0;
    incr_mv_indx = 0;
    tour_cmd_rdy = 0;
    move_part = VERT;
    cmd_from_uart = 1; // Default to UART commands
    nxt_state = state; // Hold state

    case (state)
        IDLE: begin
            cmd_from_uart = 1;
            if(start_tour) begin
                zero_mv_indx = 1;
                nxt_state = VERT_MOVE;
            end
        end
        VERT_MOVE: begin
            cmd_from_uart = 0;
            move_part = VERT; // Decompose the vertical part of move
            tour_cmd_rdy = 1;
            if(clr_cmd_rdy)
                nxt_state = VERT_WAIT;
        end
        VERT_WAIT: begin
            cmd_from_uart = 0;
            move_part = VERT; // Make sure we hold the vertical command
            if(send_resp)
                nxt_state = HOR_MOVE;
        end
        HOR_MOVE: begin
            cmd_from_uart = 0;
            move_part = HOR; // Decompose the horizontal part of move
            tour_cmd_rdy = 1;
            if(clr_cmd_rdy)
                nxt_state = HOR_WAIT;
        end
        HOR_WAIT: begin
            cmd_from_uart = 0;
            move_part = HOR; // Make sure we hold the horizontal command
            if(send_resp && (mv_indx == 23)) // That was the last move
                nxt_state = IDLE;
            else if(send_resp) begin // Go to the next move
                incr_mv_indx = 1;
                nxt_state = VERT_MOVE;
            end
        end
        default: nxt_state = IDLE; // Default to IDLE
    endcase
end

endmodule