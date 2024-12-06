package max_tb_tasks;

localparam ONE_SQUARE = 15'he80;
localparam TWO_SQUARES = 15'h1d00;
localparam START_XX = 15'h2800;
localparam START_YY = 15'h2800;
localparam signed POSITION_THRESHOLD = 15'h0350;

  // local parameters for task configuration
  localparam WAIT_CYCLES = 1000000;       // Number of cycles to hold reset
  localparam UART_POS_ACK = 8'hA5;
  localparam MOVE_POS_ACK = 8'h5A;




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