/*
This is a simple test to make sure that the PWM and NEMO correctly set up
First we make sure PWM and NEMO are initialized correctly
Then we make sure that calibration is completed
*/
`timescale 1ns/1ps
module KnightsTour_tb();

  // import all tasks and functions
  import tb_tasks::*;
  
  ///////////////////////////
  // Stimulus of type reg //
  /////////////////////////
  reg clk, RST_n;
  reg [15:0] cmd;
  reg send_cmd;

  ///////////////////////////////////
  // Declare any internal signals //
  /////////////////////////////////
  wire SS_n,SCLK,MOSI,MISO,INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire TX_RX, RX_TX;
  logic cmd_sent;
  logic resp_rdy;
  logic [7:0] resp;
  wire IR_en;
  wire lftIR_n,rghtIR_n,cntrIR_n;

  //////////////////////
  //// Error Signals ///
  //////////////////////
  logic error_ack;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  KnightsTour iDUT(.clk(clk), .RST_n(RST_n), .SS_n(SS_n), .SCLK(SCLK),
                   .MOSI(MOSI), .MISO(MISO), .INT(INT), .lftPWM1(lftPWM1),
				   .lftPWM2(lftPWM2), .rghtPWM1(rghtPWM1), .rghtPWM2(rghtPWM2),
				   .RX(TX_RX), .TX(RX_TX), .piezo(piezo), .piezo_n(piezo_n),
				   .IR_en(IR_en), .lftIR_n(lftIR_n), .rghtIR_n(rghtIR_n),
				   .cntrIR_n(cntrIR_n));
				  
  /////////////////////////////////////////////////////
  // Instantiate RemoteComm to send commands to DUT //
  ///////////////////////////////////////////////////
  RemoteComm iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
             .send_cmd(send_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
				   
  //////////////////////////////////////////////////////
  // Instantiate model of Knight Physics (and board) //
  ////////////////////////////////////////////////////
  KnightPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                      .MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
					  .lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n)); 
				   
  initial begin
	initialize(.clk(clk), .RST_n(RST_n), .cmd(cmd), .send_cmd(send_cmd));
	@(posedge clk);
	@(negedge clk);

	// Make sure PWM is running and midrail
	if(lftPWM1 ^ lftPWM2 !== 1 && rghtPWM1 ^ rghtPWM2 !== 1) begin
		$display("PWM is either not running or not midrail");
		$stop;
	end
	if(iDUT.lft_spd !== 0 && iDUT.rght_spd !== 0) begin
		$display("PWM is not midrail");
	end
	
	// Check that NEMO_setup gets asserted
	fork
      		begin : timeout
        		repeat(WAIT_CYCLES) @(posedge clk); 
			@(negedge clk);
        		$display("ERROR: Timeout waiting for NEMO_setup");
        		$stop();                         
      		end

      		begin
        		@(posedge iPHYS.iNEMO.NEMO_setup);  
        		disable timeout;                   
        		$display("NEMO_setup detected!"); 
      		end
    	join

	// Calibrate sensor
	SendCMD(.clk(clk), .RST_n(RST_n), .input_cmd(16'h2000), .cmd(cmd), .send_cmd(send_cmd), .cmd_sent(cmd_sent));
	// Make sure cal_done gets asserted
	fork
        	begin : timeout_sig
            		repeat(WAIT_CYCLES) @(posedge clk);
			@(negedge clk);
            		$display("ERROR: Timeout waiting for cal_done");
            		$stop();
        	end
        
        	begin 
            		@(posedge iDUT.cal_done);
            		$display("cal_done detected!");
            		disable timeout_sig;
        	end
    	join
	
	// Check positive acknowledgement
	CheckPositiveAck(.clk(clk), .resp_rdy(resp_rdy), .resp(resp), .error(error_ack));
	if(error_ack) begin
		$display("Didn't receive Ack after calibration");
		$stop();
	end

	// All tests pass!
	$display("YAHOO!! All tests pass!!");
	$stop();
  end
  always
    #5 clk = ~clk;
  
endmodule




