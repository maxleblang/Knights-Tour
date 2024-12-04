/*
This is a simple test to make sure that the PWM and NEMO correctly set up
First we make sure PWM and NEMO are initialized correctly
Then we make sure that calibration is completed
*/
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
  
  //////////////////
  // Task Signals //
  /////////////////
  logic success;
  logic [7:0] received_resp;
  logic error_sig;
  logic error_pwm;

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
  RemoteComm_e iRMT(.clk(clk), .rst_n(RST_n), .RX(RX_TX), .TX(TX_RX), .cmd(cmd),
             .send_cmd(send_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
				   
  //////////////////////////////////////////////////////
  // Instantiate model of Knight Physics (and board) //
  ////////////////////////////////////////////////////
  KnightPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                      .MOSI(MOSI),.INT(INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.IR_en(IR_en),
					  .lftIR_n(lftIR_n),.rghtIR_n(rghtIR_n),.cntrIR_n(cntrIR_n)); 
				   
  initial begin

    // init DUT using task 
    initialize(clk, RST_n, send_cmd, cmd);

    // check PWM’s running at midrail values just after reset
    CheckPWMInit(clk, error_pwm);
    if (error_pwm)
      $display("PWM initialization test failed");
    else 
      $display("PWM initialization test passed");
	
	  // check that NEMO.setup is asserted
    fork
      begin : timeout
        repeat(WAIT_CYCLES) @(posedge clk); 
        $display("ERROR: Timeout waiting for NEMO_setup");
        $stop();                         
      end

      begin
        @(posedge iPHYS.iNEMO.NEMO_setup);  
        disable timeout;                   
        $display("NEMO_setup detected!"); 
      end
    join

    // Calibrate the NEMO sensor
    cmd = 16'h2000;
    SendCMD(clk, RST_n, cmd, send_cmd, cmd_sent);

    fork
        begin : timeout_sig
            repeat(WAIT_CYCLES) @(posedge clk);
            $display("ERROR: Timeout waiting for cal_done");
            $stop();
        end
        
        begin
            @(posedge iDUT.iINERT_INTF.cal_done);
            $display("cal_done detected!");
            disable timeout_sig;
        end
    join
  end
  always
    #5 clk = ~clk;
  
endmodule




