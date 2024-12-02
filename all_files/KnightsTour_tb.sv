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
  logic error_prev;
  logic error_duty;
  logic error_omega;

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

    // check that NEMO.setup is asserted

    // Wait for NEMO_setup with timeout
    fork
      begin : timeout
        repeat(RESET_CYCLES) @(posedge clk); 
        $display("ERROR: Timeout waiting for NEMO_setup");
        $stop();                         
      end

      begin
        @(posedge iPHYS.iNEMO.NEMO_setup);  
        disable timeout;                   
        $display("NEMO_setup detected!"); 
      end
    join


    // send signals to DUT using SendCMD and call task to check resp
    // calabration command 
    cmd = 16'h2000;
    SendCMD(clk, RST_n, cmd, send_cmd, cmd_sent, resp_rdy, resp, success, received_resp);

    // self checking test to check if calibration was recieved
    if (success && received_resp == RESP_DONE) begin
        $display("Command completed successfully");
    end else begin
        $display("Command failed with response: %h", received_resp);
    end 

    // command Format:
      //   cmd[15:12] = command type:
      //                 0010 = calibrate: latter bits all 0
      //                 0100 = move command: bits[11:4] specify heading, bits [2:0] specify number of squares.
      //                 0101 = move with fanfare: same as move command for latter bits 
      //                 0110 = start Tour command: bits[7:4] specify the starting X and bits[3:0] specify the starting Y

    // headings: 
      // NORTH = 8'h00;
      // SOUTH = 8'h7F;
      // WEST = 8'h3F;
      // EAST = 8'hBF;

    // move west one square using task
    cmd = 16'h43F1;
    SendCMD(clk, RST_n, cmd, send_cmd, cmd_sent, resp_rdy, resp, success, received_resp);

    // self checking test to check if movement was recieved
    if (success && received_resp == RESP_DONE) begin
        $display("Command completed successfully");
    end else begin
        $display("Command failed with response: %h", received_resp);
    end

    /*
    // monitor west movment by using task
    MovementWest(clk, cntrIR_n, error_prev, error_duty, error_omega, iPHYS, iDUT);

    // self checking test to check that movment occured
    if (error_duty) begin
        $display("Duty is Incorrect");
    end else if (error_omega) begin
        $display("Omega didnt change accoringly");
    end else if (error_prev) begin
        $display("Errior did not change from its prior value");
    end else begin
        $display("West Movement was Dectected!");
    end

    // move east one square (cmd = 16'h4BF1)
    // move north one square (cmd = 16'h4001)
    // move south one square (cmd = 16'h4&F1)
    */

  end
  
  always
    #5 clk = ~clk;
  
endmodule



