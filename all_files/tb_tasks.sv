package tb_tasks;

  // local parameters for task configuration
  localparam RESET_CYCLES = 10000;       // Number of cycles to hold reset
  localparam FAST_SIM = 1;               // Enable fast simulation mode (currently unused)
  localparam RESP_TRMT = 8'h5A;
  localparam RESP_DONE = 8'hA5;

  //////////////////////////
  // Initialization Tasks //
  //////////////////////////

  task automatic initialize(
    ref reg clk,              
    ref reg RST_n,
    ref reg send_cmd,
    ref reg [15:0] cmd
  );
    begin
      // Only initialize reg/logic types
      clk = 0;                       
      RST_n = 0;                     
      send_cmd = 0;                  
      cmd = 16'h0000;                
      // Wait and deassert reset
      repeat(10) @(posedge clk);     
      @(negedge clk);             
      RST_n = 1;
      repeat(100) @(negedge clk);   
    end
  endtask

  ////////////////////
  // Stimulus Tasks //
  ////////////////////

  task automatic SendCMD(
    ref reg clk,
    ref reg RST_n,
    ref reg [15:0] cmd,
    ref reg send_cmd,
    ref logic cmd_sent,
    ref logic resp_rdy,
    ref logic [7:0] resp,
    output logic cmd_successful,
    output logic [7:0] actual_resp
  );
    begin
        // Initialize outputs
        cmd_successful = 0;
        actual_resp = 8'h00;

        // Send the command
        repeat (10) @(posedge clk);
        send_cmd = 1;

        // Deassert send_cmd
        repeat (10) @(posedge clk);
        send_cmd = 0;
        
        // Wait for cmd_sent
        fork
            begin : cmd_timeout
                repeat(RESET_CYCLES) @(posedge clk);
                $error("%t: Timeout waiting for cmd_sent assertion", $time);
                $stop;
            end
            
            begin 
                @(posedge cmd_sent);
                disable cmd_timeout;
            end
        join

        // Wait for DONE response
        fork
            begin : resp_timeout
                repeat(RESET_CYCLES) @(posedge clk);
                $error("%t: Timeout waiting for response to command %h", $time, cmd);
                $stop;
            end
            
            begin 
                @(posedge resp_rdy);
                if(resp === RESP_DONE) begin
                    actual_resp = resp;
                    cmd_successful = 1;
                    $display("%t: Command %h completed successfully", $time, cmd);
                    disable resp_timeout;
                end
            end
        join
    end
  endtask
  /*
  task automatic MovementWest(
    ref reg clk,
    ref logic cntrIR_n,
    output logic error_prev,
    output logic error_duty,
    output logic error_omega,
    ref virtual KnightPhysics iPHYS,    // Add interface reference
    ref virtual Knight_tb iDUT          // Add interface reference
  );
    // Declare all variables at the beginning of the block
    logic [10:0] prev_rght_duty, prev_lft_duty;
    logic signed [11:0] prev_error;
    logic [10:0] right_change, left_change;

    begin
        // Initialize outputs
        error_duty = 0;
        error_omega = 0;
        error_prev = 0;
        
        // Store initial values
        prev_rght_duty = iPHYS.duty_rght;
        prev_lft_duty = iPHYS.duty_lft;
        prev_error = iDUT.error;

        // Check error and wheel duties change
        repeat(RESET_CYCLES) @(posedge clk);
        
        // Check error changed
        if (iDUT.error === prev_error) begin
            error_prev = 1;
            $display("ERROR: Error signal not changing");
            $stop();
        end

        // Check right duty increases more than left for west turn
        // Get the amount each duty changed
        right_change = iPHYS.duty_rght - prev_rght_duty;
        left_change = iPHYS.duty_lft - prev_lft_duty;
        
        if (right_change <= left_change) begin
            error_duty = 1;
            $display("ERROR: Right duty should increase more than left for west turn");
            $stop();
        end

        // Monitor heading convergence and cntrIR_n
        fork 
            begin : timeout
                repeat(RESET_CYCLES) @(posedge clk);
                $display("ERROR: Movement did not complete in time");
                $stop();
            end
            begin
                // Wait for first cntrIR_n pulse (leaving square)
                @(negedge cntrIR_n);
                $display("Leaving current square detected");
                
                // Wait for second cntrIR_n pulse (entering new square)
                @(negedge cntrIR_n);
                $display("Entering new square detected");
                
                // Check omega_sum is ramping up (using correct threshold from KnightPhysics)
                if(iPHYS.omega_sum < 17'd22000) begin
                    error_omega = 1;
                    $display("ERROR: omega_sum not ramping up as expected");
                    $stop();
                end
                disable timeout;
            end
        join
    end
  endtask
  */

endpackage