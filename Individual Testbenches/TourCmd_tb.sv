module TourCmd_tb();

 logic clk, rst_n;
 logic start_tour;
 logic [4:0] mv_indx;
 logic [7:0] move;
 logic [15:0] cmd_UART;
 logic cmd_rdy_UART;
 logic [15:0] cmd;
 logic cmd_rdy;
 logic clr_cmd_rdy;
 logic [7:0] resp;
 logic send_resp;

 localparam NORTH = 8'h00;
 localparam SOUTH = 8'h7F;
 localparam WEST = 8'h3F; // (-X)
 localparam EAST = 8'hBF; // (+X)

 /* Move Encodings:
 8'b00000001: (+1X, +2Y) 
 8'b00000010: (-1X, +2Y)
 8'b00000100: (-2X, +1Y) 
 8'b00001000: (-2X, -1Y) 
 8'b00010000: (-1X, -2Y) 
 8'b00100000: (+1X, -2Y) 
 8'b01000000: (+2X, -1Y) 
 8'b10000000: (+2X, +1Y) 
 */

 /* 
     TourCmd Inputs: 
     [7:0] move: 8-bit one-hot encoded move
 */

 /* 
     TourCmd Outputs: 
     cmd = {3'b010, play_sponge, heading[7:0], num_moves[3:0]}
     [7:0] resp: Status response:
       0x5A (90): In progress
       0xA5 (165): Done
       0x00 (0): Default/idle
 */

// all 8 possible knight moves
// Initialize vertical and horizontal command arrays
// Format: {heading[7:0], moves[3:0]}
logic [11:0] vertical_cmds[8] = '{
    {NORTH, 4'h2},    // Move 0: +2Y
    {NORTH, 4'h2},    // Move 1: +2Y
    {NORTH, 4'h1},    // Move 2: +1Y
    {SOUTH, 4'h1},    // Move 3: -1Y
    {SOUTH, 4'h2},    // Move 4: -2Y
    {SOUTH, 4'h2},    // Move 5: -2Y
    {SOUTH, 4'h1},    // Move 6: -1Y
    {NORTH, 4'h1}     // Move 7: +1Y
};

logic [11:0] horizontal_cmds[8] = '{
    {EAST, 4'h1},   // Move 0: +1X
    {WEST, 4'h1},   // Move 1: -1X
    {WEST, 4'h2},   // Move 2: -2X
    {WEST, 4'h2},   // Move 3: -2X
    {WEST, 4'h1},   // Move 4: -1X
    {EAST, 4'h1},   // Move 5: +1X
    {EAST, 4'h2},   // Move 6: +2X
    {EAST, 4'h2}    // Move 7: +2X
};

 TourCmd iDUT(.clk(clk),
              .rst_n(rst_n),
              .start_tour(start_tour),
              .mv_indx(mv_indx),
              .move(move),
              .cmd_UART(16'h0000),
              .cmd_rdy_UART(1'b0),
              .cmd(cmd),
              .cmd_rdy(cmd_rdy),
              .clr_cmd_rdy(clr_cmd_rdy),
              .resp(resp),
              .send_resp(send_resp));

 // Clock generator (50MHz)
 always #10 clk = ~clk;

 initial begin
   // Initialize signals
   clk = 0;
   rst_n = 0;
   start_tour = 0;
   send_resp = 0;
   move = 8'h00;
   clr_cmd_rdy = 0;


   // Reset sequence
   @(posedge clk);
   rst_n = 1;
   @(posedge clk);

   // test each move
   for(int i = 0; i < 8; i++) begin
     $display("\nTesting Move %0d", i);
     start_tour = 1;
     move = 8'b00000001 << i;  // one-hot encoding

     @(posedge clk);
     start_tour = 0;
     @(posedge clk);
     
     // Wait for vertical move command
     wait(cmd_rdy);
     // Check vertical command
     if(cmd[11:4] !== vertical_cmds[i][11:4] || cmd[3:0] !== vertical_cmds[i][3:0]) begin
       $display("ERROR: Vertical command mismatch for move %b", move);
       $display("Expected: heading=%h, moves=%h", vertical_cmds[i][11:4], vertical_cmds[i][3:0]);
       $display("Got: heading=%h, moves=%h", cmd[11:4], cmd[3:0]);
     end 

     
     repeat(5) @(posedge clk);
     clr_cmd_rdy = 1;
     repeat(5) @(posedge clk);
     clr_cmd_rdy = 0;
     repeat(5) @(posedge clk);
     send_resp = 1;
     repeat(5) @(posedge clk);
     send_resp = 0;
     repeat(5) @(posedge clk);


     // Wait for horizontal move command
     wait(cmd_rdy);
     // Check horizontal command
     if(cmd[11:4] !== horizontal_cmds[i][11:4] || cmd[3:0] !== horizontal_cmds[i][3:0]) begin
       $display("ERROR: Horizontal command mismatch for move %b", move);
       $display("Expected: heading=%h, moves=%h", horizontal_cmds[i][11:4], horizontal_cmds[i][3:0]);
       $display("Got: heading=%h, moves=%h", cmd[11:4], cmd[3:0]);
     end
     
     repeat(5) @(posedge clk);
     clr_cmd_rdy = 1;
     repeat(5) @(posedge clk);
     clr_cmd_rdy = 0;
     repeat(5) @(posedge clk);
     send_resp = 1;
     repeat(5) @(posedge clk);
     send_resp = 0;
     repeat(5) @(posedge clk);
   end
   
   $display("\nTest Complete");
   $stop;
 end

endmodule