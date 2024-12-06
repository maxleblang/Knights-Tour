
module KnightsTour_tb_yushi();

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
  logic error_IR_1;
  logic error_IR_2;
  logic error_IR_3;
  logic error_IR_4;
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


	if(iDUT.lft_spd !== 0 && iDUT.rght_spd !== 0) begin
		$display("ERROR #2: PWM is not midrail");
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
        		$display("PASSED: NEMO_setup detected!"); 
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

	// Make sure cal_done gets asserted
	fork
        begin : timeout_sig
            	repeat(WAIT_CYCLES) @(posedge clk);
            	$display("ERROR #4: Timeout waiting for cal_done");
            	$stop();
        end
        
        begin 
            @(posedge iDUT.cal_done);
            $display("PASSED: cal_done detected!");
            disable timeout_sig;
        end

    join
	
	// Check positive acknowledgement
	CheckPositiveAck(
		.clk(clk), 
		.resp_rdy(resp_rdy), 
		.resp(resp), 
		.error(error_ack));


	if(error_ack) begin
		$display("ERROR #5: Didn't receive Ack after calibration");
		$stop();
	end

	// -- END (2) -- //
	 
	// -- 3. TEST MOVE EAST 1 SQUARE -- //

	SendCMD(
		.clk(clk), 
		.RST_n(RST_n), 
		.input_cmd(16'h4BF1),  //East heading is BF
		.cmd(cmd), 
		.send_cmd(send_cmd), 
		.cmd_sent(cmd_sent));

	WaitSig(
		.clk(clk),
   		.signal_name("heading_rdy"),
    	.signal_to_wait(iDUT.heading_rdy),
    	.error_sig(error_sig));

	//TODO: Not sure where to check heading
	// CheckHeading(
	// 	.clk(clk),
	// 	.heading(iDUT.heading),
    // 	.error_move(error_move));

	CheckIR(
		.clk(clk),
		.cntrIR(cntrIR_n),
    	.error_IR(error_IR));

	CheckIR(
		.clk(clk),
		.cntrIR(cntrIR_n),
    	.error_IR(error_IR));

	CheckPositiveAck(
		.clk(clk), 
		.resp_rdy(resp_rdy), 
		.resp(resp), 
		.error(error_ack));

	if(error_sig || error_move || error_IR || error_ack) begin
		$display("ERROR #6: Unable to move East");
		$stop();
	end else begin
		$display("PASSED: Moved East 1 square.");
	end
	 
	// -- END (3) -- //


	// -- 4. HITTING GUARDRAILS -- //

	repeat(150000) @(posedge clk);

	SendCMD(
		.clk(clk), 
		.RST_n(RST_n), 
		.input_cmd(16'h4002),  //East heading is BF
		.cmd(cmd), 
		.send_cmd(send_cmd), 
		.cmd_sent(cmd_sent));

	fork

	begin
		CheckIR( .clk(clk), .cntrIR(cntrIR_n), .error_IR(error_IR_1));
		CheckIR( .clk(clk), .cntrIR(cntrIR_n), .error_IR(error_IR_2));
		CheckIR( .clk(clk), .cntrIR(cntrIR_n), .error_IR(error_IR_3));
		CheckIR( .clk(clk), .cntrIR(cntrIR_n), .error_IR(error_IR_4));

	end

	begin
		CheckIR( .clk(clk), .cntrIR(lftIR_n), .error_IR(error_IR_l));
	end

	begin
		CheckIR( .clk(clk), .cntrIR(rghtIR_n), .error_IR(error_IR_r));
	end

	join

	if(error_IR_1 & error_IR_2 & error_IR_3 & error_IR_4) begin
		$display("PASSED: Moved North 2 Squares");
		if (error_IR_l || error_IR_r)
		$display("PASSED: lftIR and rghtIR fired.");
	end else begin
		$display("ERROR #7: IR signals not working right.");
		$stop();
	end

	// -- END (4) -- //


	// -- 5. TEST TOUR LOGIC? -- //

	// -- END (5) -- //



	// -- YAY -- //

	// All tests pass!
	$display("YAHOO!! All tests pass!!");
	$stop();


  end
  always
    #5 clk = ~clk;
  
endmodule




