/*
This tests that the knight is moving correctly in response to the tour logic
*/
module KnightsTour_tb_logic();

  // import all tasks and functions
  import tb_tasks::*;
  //import logic_tb_tasks::*;
  
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
	/*
	INIT AND CAL
	*/
	// Initialize the DUT input signals and reset DUT
	initialize(.clk(clk), .RST_n(RST_n), .cmd(cmd), .send_cmd(send_cmd));
	@(posedge clk);
	// Calibrate sensor
	SendCMD(.clk(clk), .RST_n(RST_n), .input_cmd(16'h2000), .cmd(cmd), .send_cmd(send_cmd), .cmd_sent(cmd_sent));
	// Check positive acknowledgement
	CheckPositiveAck(.clk(clk), .resp_rdy(resp_rdy), .resp(resp), .error(error_ack));
	if(error_ack) begin
		$display("Didn't receive Ack after calibration");
		$stop();
	end
	
	/*
	TEST LOGIC
	*/
	// Tell DUT to start the command
	// Starting from the center of the board
	SendCMD(.clk(clk), .RST_n(RST_n), .input_cmd(16'h6022), .cmd(cmd), .send_cmd(send_cmd), .cmd_sent(cmd_sent));
	wait(iDUT.iTC.start_tour);
	repeat(100) @(posedge clk);

	/*
	CMD 1: move 0
	North 2
	Right 1
	*/
	// VERT
	wait(iDUT.iCMD.send_resp);
	// Check the cmd is right
	if(iDUT.iTC.cmd !== 16'h4002) begin
		$display("ERROR CMD: Expected %h but was %h.", 16'h4002, iDUT.iTC.cmd);
		$stop();
	end
	// Check that we're at the right position
	Check_Position(.pos(iPHYS.yy), .expected_pos(START_YY + TWO_SQUARES));
	repeat(100) @(posedge clk);

	// HOR
	wait(iDUT.iCMD.send_resp);
	// Check the cmd is right
	if(iDUT.iTC.cmd !== 16'h5bf1) begin
		$display("ERROR CMD: Expected %h but was %h.", 16'h5bf1, iDUT.iTC.cmd);
		$stop();
	end
	Check_Position(.pos(iPHYS.xx), .expected_pos(START_XX + ONE_SQUARE));
	
	// Check for move ack
	CheckPositiveMoveAck(.clk(clk), .resp(iRMT.resp), .resp_rdy(iRMT.resp_rdy));
	$display("MOVE 1 VERIFIED");
	
	/*
	CMD 2: move 3
	South 1
	Left 2
	*/
	// VERT
	wait(iDUT.iCMD.send_resp);
	// Check the cmd is right
	if(iDUT.iTC.cmd !== 16'h47f1) begin
		$display("ERROR CMD: Expected %h but was %h.", 16'h47f1, iDUT.iTC.cmd);
		$stop();
	end
	// Check that we're at the right position
	Check_Position(.pos(iPHYS.yy), .expected_pos(START_YY + ONE_SQUARE));
	repeat(100) @(posedge clk);

	// HOR
	wait(iDUT.iCMD.send_resp);
	// Check the cmd is right
	if(iDUT.iTC.cmd !== 16'h53f2) begin
		$display("ERROR CMD: Expected %h but was %h.", 16'h53f2, iDUT.iTC.cmd);
		$stop();
	end
	Check_Position(.pos(iPHYS.xx), .expected_pos(START_XX - ONE_SQUARE));
	
	// Check for move ack
	CheckPositiveMoveAck(.clk(clk), .resp(iRMT.resp), .resp_rdy(iRMT.resp_rdy));
	$display("MOVE 2 VERIFIED");

	/*
	CMD 3: move 4
	South 2
	Left 1
	*/
	// VERT
	wait(iDUT.iCMD.send_resp);
	// Check the cmd is right
	if(iDUT.iTC.cmd !== 16'h47f2) begin
		$display("ERROR CMD: Expected %h but was %h.", 16'h47f2, iDUT.iTC.cmd);
		$stop();
	end
	// Check that we're at the right position
	Check_Position(.pos(iPHYS.yy), .expected_pos(START_YY - ONE_SQUARE));
	repeat(100) @(posedge clk);

	// HOR
	wait(iDUT.iCMD.send_resp);
	// Check the cmd is right
	if(iDUT.iTC.cmd !== 16'h53f1) begin
		$display("ERROR CMD: Expected %h but was %h.", 16'h53f1, iDUT.iTC.cmd);
		$stop();
	end
	Check_Position(.pos(iPHYS.xx), .expected_pos(START_XX - TWO_SQUARES));
	
	// Check for move ack
	CheckPositiveMoveAck(.clk(clk), .resp(iRMT.resp), .resp_rdy(iRMT.resp_rdy));
	$display("MOVE 3 VERIFIED");


	/*
	CMD 4: move 4
	South 2
	Left 1
	*/
	// VERT
	wait(iDUT.iCMD.send_resp);
	// Check the cmd is right
	if(iDUT.iTC.cmd !== 16'h47f1) begin
		$display("ERROR CMD: Expected %h but was %h.", 16'h47f1, iDUT.iTC.cmd);
		$stop();
	end
	// Check that we're at the right position
	Check_Position(.pos(iPHYS.yy), .expected_pos(START_YY - TWO_SQUARES));
	repeat(100) @(posedge clk);

	// HOR
	wait(iDUT.iCMD.send_resp);
	// Check the cmd is right
	if(iDUT.iTC.cmd !== 16'h5bf2) begin
		$display("ERROR CMD: Expected %h but was %h.", 16'h5bf1, iDUT.iTC.cmd);
		$stop();
	end
	Check_Position(.pos(iPHYS.xx), .expected_pos(START_XX));
	
	// Check for move ack
	CheckPositiveMoveAck(.clk(clk), .resp(iRMT.resp), .resp_rdy(iRMT.resp_rdy));
	$display("MOVE 4 VERIFIED");


	/*
	CMD 5: move 7
	North 1
	Right 2
	*/
	// VERT
	wait(iDUT.iCMD.send_resp);
	// Check the cmd is right
	if(iDUT.iTC.cmd !== 16'h4001) begin
		$display("ERROR CMD: Expected %h but was %h.", 16'h4001, iDUT.iTC.cmd);
		$stop();
	end
	// Check that we're at the right position
	Check_Position(.pos(iPHYS.yy), .expected_pos(START_YY - ONE_SQUARE));
	repeat(100) @(posedge clk);

	// HOR
	wait(iDUT.iCMD.send_resp);
	// Check the cmd is right
	if(iDUT.iTC.cmd !== 16'h5bf2) begin
		$display("ERROR CMD: Expected %h but was %h.", 16'h5bf1, iDUT.iTC.cmd);
		$stop();
	end
	Check_Position(.pos(iPHYS.xx), .expected_pos(START_XX + TWO_SQUARES));
	
	// Check for move ack
	CheckPositiveMoveAck(.clk(clk), .resp(iRMT.resp), .resp_rdy(iRMT.resp_rdy));
	$display("MOVE 5 VERIFIED");

	
	// All tests pass!
	$display("YAHOO!! All tests pass!!");
	$stop();
  end
  always
    #5 clk = ~clk;
  
endmodule



