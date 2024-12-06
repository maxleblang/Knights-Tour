`timescale 1ns/1ps
module KnightsTour_tb_post();

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
  logic SS_n,SCLK,MOSI,MISO,INT;
  logic lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  logic TX_RX, RX_TX;
  logic cmd_sent;
  logic resp_rdy;
  logic [7:0] resp;
  logic IR_en;
  logic lftIR_n,rghtIR_n,cntrIR_n;

  //////////////////////
  //// Error Signals ///
  //////////////////////
  logic error_ack;
  logic error_sig;
  logic error_move;
  logic error_IR;
  logic error_IR_l;
  logic error_IR_r;


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

	// -- 1. TEST INITIALIZATION -- //

	initialize(
		.clk(clk), 
		.RST_n(RST_n), 
		.cmd(cmd), 
		.send_cmd(send_cmd));

	@(posedge clk);

	// Make sure PWM is running and midrail
	if(lftPWM1 ^ lftPWM2 !== 1 && rghtPWM1 ^ rghtPWM2 !== 1) begin
		$display("ERROR #1: PWM is either not running or not midrail");
		$stop;
	end

	// Check that NEMO_setup gets asserted
	fork
      		begin : timeout
        		repeat(WAIT_CYCLES) @(posedge clk); 
        		$display("ERROR #3: Timeout waiting for NEMO_setup");
        		$stop();                         
      		end

      		begin
        		@(posedge iPHYS.iNEMO.NEMO_setup);  
        		disable timeout;                   
        		$display("PASSED [1]: NEMO_setup detected!"); 
      		end
    	join

	// -- END (1)-- //

	// -- 2. TEST CALIBRATION -- //		

	// Calibrate sensor

	SendCMD(
		.clk(clk), 
		.RST_n(RST_n), 
		.input_cmd(16'h2000), 
		.cmd(cmd), 
		.send_cmd(send_cmd), 
		.cmd_sent(cmd_sent));

	WaitSig(
    	.clk(clk),
		.signal_to_wait(resp_rdy),
    	.signal_name("sig"),
		.error_sig(error_sig)
    );
	
	 
	// -- 3. MANUAL CHECK FOR HEADING -- //

	SendCMD(
		.clk(clk), 
		.RST_n(RST_n), 
		.input_cmd(16'h4BF1),  
		.cmd(cmd), 
		.send_cmd(send_cmd), 
		.cmd_sent(cmd_sent)
	);
	
	// -- YAY -- //

	// All tests pass!
	$display("YAHOO!! All tests pass!!");
	$stop();


  end
  always
    #5 clk = ~clk;
  
endmodule




