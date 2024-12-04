module TourLogic(clk,rst_n,x_start,y_start,go,done,indx,move);

  //TODO: run sometimes doesn't print?

  input clk,rst_n;				        // 50MHz clock and active low asynch reset
  input [2:0] x_start, y_start;	  // starting position on 5x5 board
  input go;						            // initiate calculation of solution
  input [4:0] indx;				        // used to specify index of move to read out
  output logic done;			        // pulses high for 1 clock when solution complete
  output [7:0] move;			        // the move addressed by indx (1 of 24 moves)
  
  ////////////////////////////////////////
  // Declare needed internal registers //
  //////////////////////////////////////
  
  // << some internal registers to consider: >>
  // << These match the variables used in knightsTourSM.pl >>
  reg board[0:4][0:4];				// keeps track if position visited
  reg [7:0] last_move[0:23];		    // last move tried from this spot
  reg [7:0] poss_moves[0:23];		    // stores possible moves from this position as 8-bit one hot
  reg [7:0] move_try;				        // one hot encoding of move we will try next
  reg [4:0] move_num;				        // keeps track of move we are on
  reg [2:0] xx,yy;					        // current x & y position  
 
  // << 2-D array of 5-bit vectors that keep track of where on the board the knight
  //    has visited.  Will be reduced to 1-bit boolean after debug phase >>
  // << 1-D array (of size 24) to keep track of last move taken from each move index >>
  // << 1-D array (of size 24) to keep track of possible moves from each move index >>
  // << move_try ... not sure you need this.  I had this to hold move I would try next >>
  // << move number...when you have moved 24 times you are done.  Decrement when backing up >>
  // << xx, yy couple of 3-bit vectors that represent the current x/y coordinates of the knight>>
  
  logic [2:0] nxt_xx, nxt_yy;
  logic move_valid;

  logic zero;
  logic init;
  logic check_possible;
  logic update_position;
  logic backup;
  logic try_nxt_move;
  // logic next_state;
  
  // << Your magic occurs here >> //
  assign move = last_move[indx];
  // -- BOARD REGISTER LOGIC -- //
  
  always_ff @(posedge clk) begin
    if (zero) begin
	    board <= '{'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0},'{0,0,0,0,0}};
    end else if (init) begin
	    board[x_start][y_start] <= 1;	// mark starting position
    end else if (update_position) begin 
      board[nxt_xx][nxt_yy] <= 1;	// mark as visited 
    end else if (backup)
	    board[xx][yy] <= 0;			// mark as unvisited
  end

  // -- END BOARD REGISTER LOGIC -- //

  // -- XX AND YY LOGIC -- //

  always_ff @(posedge clk) begin
    if (zero) begin
      xx <= 8'h0;
      yy <= 8'h0;
    end else if (init) begin
	    xx <= x_start;
      yy <= y_start;
    end else if (update_position) begin
      xx <= nxt_xx;
      yy <= nxt_yy;
    end else if (backup) begin
      xx <= xx - off_x(last_move[move_num - 1]);
      yy <= yy - off_y(last_move[move_num - 1]);
    end
  end

  // -- END XX AND YY LOGIC -- //

  // -- POSSIBLE MOVES LOGIC -- //

  always_ff @(posedge clk) begin
    if (zero) begin
      poss_moves[move_num] <= 8'b0;
    end else if(init) begin
      poss_moves[move_num] <= 8'b0;
    end else if(check_possible) begin
      poss_moves[move_num] <= calc_poss(xx, yy);
    end
  end

  // -- END POSSIBLE MOVES LOGIC -- //
  

  // -- MOVE_TRY LOGIC -- //
  
  always_ff @ (posedge clk) begin
    if (zero) begin
      move_try <= 8'h0;
    end else if (check_possible) begin
      move_try <= 8'h01;
    end else if (try_nxt_move) begin
      move_try <= move_try << 1;
    end else if (backup) begin
      move_try <= (last_move[move_num - 1]) << 1;
    end
  end

  // -- END MOVE_TRY LOGIC -- //

  // -- MOVE_NUM LOGIC -- //

  always_ff @(posedge clk) begin
    if(zero) begin
      move_num <= 5'b0;
    end else if (update_position) begin
      move_num <= move_num + 1;
    end else if (backup) begin
      move_num <= move_num - 1;
    end
  end
  // -- END MOVE_NUM LOGIC -- //

  // -- LAST_MOVE LOGIC -- //
  
  always_ff @(posedge clk) begin
    if (update_position) begin
        last_move[move_num] <= move_try; // Save the current move
    end
  end

  // -- END LAST_MOVE LOGIC -- //


  // -- ASSIGNING STUFF -- //

  assign nxt_xx = xx + off_x(move_try);
  assign nxt_yy = yy + off_y(move_try);
  assign move_valid = (poss_moves[move_num] & move_try) && (board[nxt_xx][nxt_yy] == 0);

  // -- END ASSIGNING STUFF -- //

  // -- STATE MACHINE -- //
 
  typedef enum logic [2:0]  { IDLE, INIT, POSSIBLE, MAKE_MOVE, BACKUP } state_t;
  state_t current_state, next_state;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
    current_state <= IDLE;
    end else begin
    current_state <= next_state;
    end
  end
  

 //state machine logic
  always_comb begin
    zero = 0;
    init = 0;
    check_possible = 0;
    update_position = 0;
    backup = 0;
    try_nxt_move = 0;
    next_state = current_state;
    done = 0;


    case (current_state)
      

      IDLE: begin
        if (go) begin
          zero = 1;
          next_state = INIT;
        end
      end

      INIT: begin
          init = 1;
          next_state = POSSIBLE;
      end


      POSSIBLE: begin
          check_possible = 1;
          next_state = MAKE_MOVE;
      end

      MAKE_MOVE: begin
        if(move_valid) begin
          update_position = 1;
          if(move_num != 5'd23) begin
            next_state = POSSIBLE;
          end else begin
            next_state = IDLE; //TODO: deassert go?
            done = 1;
          end          
        end else begin
          if(move_try != 8'h80) begin
            try_nxt_move = 1;
          end else begin
            next_state = BACKUP;
          end
        end
      end
      
      BACKUP: begin
        backup = 1;
        if(last_move[move_num-1] != 8'h80) begin
          next_state = MAKE_MOVE;
        end

      end
    endcase
  end 
  
  // --  END STATE MACHINE STUFF -- //  

  // -- FUNCTIONS -- //

  //function that returns all possible moves given xx and yy
  function [7:0] calc_poss(input [2:0] xpos,ypos);
    
    calc_poss[0] = move_possible((xpos + off_x(8'b00000001)), (ypos + off_y(8'b00000001)));
    calc_poss[1] = move_possible((xpos + off_x(8'b00000010)), (ypos + off_y(8'b00000010)));
    calc_poss[2] = move_possible((xpos + off_x(8'b00000100)), (ypos + off_y(8'b00000100)));
    calc_poss[3] = move_possible((xpos + off_x(8'b00001000)), (ypos + off_y(8'b00001000)));
    calc_poss[4] = move_possible((xpos + off_x(8'b00010000)), (ypos + off_y(8'b00010000)));
    calc_poss[5] = move_possible((xpos + off_x(8'b00100000)), (ypos + off_y(8'b00100000)));
    calc_poss[6] = move_possible((xpos + off_x(8'b01000000)), (ypos + off_y(8'b01000000)));
    calc_poss[7] = move_possible((xpos + off_x(8'b10000000)), (ypos + off_y(8'b10000000)));
  
  endfunction

  //helper function to check if move is within bounds
  function move_possible(input [2:0] x_try, y_try);

    if((x_try >= 3'd0 && x_try <= 3'd4) && (y_try >= 3'd0 && y_try <= 3'd4)) begin
      move_possible = 1'b1;
    end else begin
      move_possible = 1'b0;
    end

  endfunction
  
  //function that returns a the x-offset given the encoding of the move 
  function signed [2:0] off_x(input [7:0] try);

    case(try)

      8'b00000001: off_x = 3'b001; //+1
      8'b00000010: off_x = 3'b111; //-1
      8'b00000100: off_x = 3'b110; //-2
      8'b00001000: off_x = 3'b110; //-2
      8'b00010000: off_x = 3'b111; //-1
      8'b00100000: off_x = 3'b001; //+1
      8'b01000000: off_x = 3'b010; //+2
      8'b10000000: off_x = 3'b010; //+2

    endcase   

  endfunction
  
  //function that returns a the y-offset given the encoding of the move 
  function signed [2:0] off_y(input [7:0] try);

    case(try)

      8'b00000001: off_y = 3'b010; //+2
      8'b00000010: off_y = 3'b010; //+2
      8'b00000100: off_y = 3'b001; //+1
      8'b00001000: off_y = 3'b111; //-1
      8'b00010000: off_y = 3'b110; //-2
      8'b00100000: off_y = 3'b110; //-2
      8'b01000000: off_y = 3'b111; //-1
      8'b10000000: off_y = 3'b001; //+1

    endcase 

  endfunction

  // -- END FUNCTIONS -- //
  
endmodule
	  