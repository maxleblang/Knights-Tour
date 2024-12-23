`timescale 1ns/1ps
package tb_tasks;

  // local parameters for task configuration
  localparam WAIT_CYCLES = 50000000;       // Number of cycles to hold reset
  localparam UART_POS_ACK = 8'hA5;
  localparam MOVE_POS_ACK = 8'h5A;

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
	// Default all signals
      	clk = 0;
	cmd = 0;
	send_cmd = 0;
	// Reset DUT
	RST_n = 0;
	@(posedge clk);
	@(negedge clk); 
    
    RST_n = 1;   
    end
  endtask
  


  ////////////////////
  // Stimulus Tasks //
  ////////////////////

  task automatic SendCMD(
    ref reg clk,
    ref reg RST_n,
    input [15:0] input_cmd,
    ref reg [15:0] cmd,
    ref reg send_cmd,
    ref reg cmd_sent
  );
    begin

        // Send the command
	cmd = input_cmd;
        @(posedge clk);
        send_cmd = 1;

        // Deassert send_cmd
        @(posedge clk);
        send_cmd = 0;
        
        // Wait for cmd_sent (from BLE module)
	fork
            begin : cmd_timeout_1
                repeat(WAIT_CYCLES) @(posedge clk);
                $error("%t: Timeout waiting for cmd_sent assertion", $time);
                $stop;
            end
            
            begin 
                @(posedge cmd_sent);
                disable cmd_timeout_1;
                $display("Command %h has been sent!", cmd);
            end
        join

     end
  endtask

  task automatic CheckPositiveAck(
   ref reg clk,
   ref logic [7:0] resp,
   ref logic resp_rdy,
   output logic error
  );
   fork
       begin : timeout
           repeat(WAIT_CYCLES) @(posedge clk);
           $display("ERROR: No response received");
           error = 1;
           disable wait_ack;
       end
       
       begin : wait_ack
           @(posedge resp_rdy);
           if (resp !== UART_POS_ACK) begin
               $display("ERROR: Expected ack 0xA5, got %h", resp);
               error = 1;
           end else begin
               $display("Received positive ack");
               error = 0;
           end
           disable timeout;
       end
   join
  endtask

  /*
  task automatic WaitSig(
    ref reg clk,
    input string signal_name,
    input logic signal_to_wait,
    output logic error_sig
);
    fork
        begin : timeout_sig
            repeat(WAIT_CYCLES) @(posedge clk);
            error_sig = 1;
            $display("ERROR: Timeout waiting for %s at time %t", signal_name, $time);
            $stop();
            disable wait_block;
        end
        
        begin : wait_block
            @(posedge signal_to_wait);
            error_sig = 0;
            $display("%s detected at time %t", signal_name, $time);
            disable timeout_sig;
        end
    join
endtask
*/
  
  
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
        repeatWAIT_CYCLESS) @(posedge clk);
        
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
                repeatWAIT_CYCLESS) @(posedge clk);
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