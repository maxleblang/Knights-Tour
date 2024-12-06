package tb_tasks;

  // local parameters for task configuration
  localparam WAIT_CYCLES = 1000000;       // Number of cycles to hold reset
  localparam UART_POS_ACK = 8'hA5;
  localparam MOVE_POS_ACK = 8'h5A;

   // local parameters for movement and logic testing
   localparam ONE_SQUARE = 15'he80;
    localparam TWO_SQUARES = 15'h1d00;
    localparam START_XX = 15'h2800;
    localparam START_YY = 15'h2800;
    localparam signed POSITION_THRESHOLD = 15'h0350;

    // -- INITIALIZE -- //

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


    // -- SEND COMMAND -- //
    
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
        
   
	fork
            begin : cmd_timeout_1
                repeat(WAIT_CYCLES) @(posedge clk);
                $error("ERROR: %t Timeout waiting for cmd_sent assertion", $time);
                $stop;
            end
            
            begin 
                @(posedge cmd_sent);
                disable cmd_timeout_1;
                $display("CMD CHECK: Command %h has been sent!", cmd);
            end
        join

     end

    endtask
 
    // -- CHECK FOR POSITIVE ACK -- //

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
               $display("ACK CHECK: Received positive ack");
               error = 0;
           end
           disable timeout;
       end
    join

    endtask

    // -- WAIT FOR SIGNAL -- //
  
    task automatic WaitSig(
    ref reg clk,
    ref logic signal_to_wait,
    input string signal_name,
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
            wait(signal_to_wait);
            error_sig = 0;
            $display("SIG CHECK: %s detected", signal_name);
            disable timeout_sig;
        end
    join
    
    endtask

    // -- CHECK HEADING AFTER MOVE -- //

    task automatic CheckHeading(
    ref reg clk,
    input logic signed [11:0] heading,
    input logic signed [11:0] desired_heading,
    output logic error_move
    );

    begin
    
    fork
        begin : timeout_move
            repeat(10000000) @(posedge clk);
            error_move = 1;
            $display("ERROR: Timeout -> heading %h, desired heading %h; %d", heading, desired_heading, (desired_heading - heading));
            $stop();
            disable wait_block_move;
        end
        
        
        begin : wait_block_move
           if($unsigned(desired_heading) - $unsigned(heading) < 12'h02c) begin   
                //TODO: It's going less than 02c but it's still not passing? desired_heading - heading = 026
                error_move = 0;
                $display("HEADING CHECK: Heading dropped below threshold -> heading %h, desired heading %h ", heading, desired_heading);
                disable timeout_move;
                
            end
        end

    join

    end

    endtask

    // -- CHECK IR SIGNAL -- //

    task automatic CheckIR(
    ref reg clk,
    ref logic cntrIR,
    output logic error_IR
    );
    fork
    	begin : timeout_IR
            repeat(WAIT_CYCLES) @(posedge clk);
            error_IR = 1;
            $display("ERROR: Timeout waiting IR signal");
            $stop();
        end
        
        begin : wait_block_IR
	    // TODO: Make this an input variable
            repeat(2) @(posedge cntrIR);
	    $display("IR CHECK: Received cntrIR signals");
	    disable timeout_IR;
        end
    join
    endtask


task automatic Check_Position(
	input logic [14:0] pos,
	input logic [14:0] expected_pos
);
begin
	if($signed(expected_pos) - $signed(pos) > POSITION_THRESHOLD || $signed(pos) - $signed(expected_pos) > POSITION_THRESHOLD) begin
		$display("ERROR POSITION CHECK: position of %h not within threshold compared to %h", pos, expected_pos);
		$display("%h", $signed(expected_pos) - $signed(pos));
		$display("%h", $signed(pos) - $signed(expected_pos));
		$exit();
	end
end
endtask

task automatic CheckPositiveMoveAck(
        ref reg clk,
        ref logic [7:0] resp,
        ref logic resp_rdy
    );
    
    fork
       begin : timeout
           repeat(WAIT_CYCLES) @(posedge clk);
           $display("ERROR: No response received");
	   $stop();
       end
       
       begin : wait_ack
           @(posedge resp_rdy);
           if (resp !== MOVE_POS_ACK) begin
               $display("ERROR: Expected ack 0x5A, got %h", resp);
		$stop();
           end else begin
               $display("ACK CHECK: Received positive ack");
           end
           disable timeout;
       end
    join

endtask

endpackage