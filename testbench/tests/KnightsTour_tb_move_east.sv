/*
This is a simple test to make sure that the PWM and NEMO correctly set up
First we make sure PWM and NEMO are initialized correctly
Then we make sure that calibration is completed
*/
module KnightsTour_tb_chance();

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
    $display("ERROR: Didn't receive Ack after calibration");
    $stop();
  end

  // Send and check movement EAST
  SendCMD(.clk(clk), .RST_n(RST_n), .input_cmd(16'h4BF1), .cmd(cmd), .send_cmd(send_cmd), .cmd_sent(cmd_sent));
  
  // Wait until frwrd register from CMD proc starts to ramp up
  // Check that heading is close to -1024 (within threshold specified in cmd_proc)
  // Check to make sure cntrIR fires twice (count two positive edges)
  // Once second cntrIR fires and frwrd goes down to zero, make sure we get a postive acknowledgement
  // Check that xx is now in the range of 0x3680
  // Check that yy hasn't changed (or changed very little)

  // Checking xx and yy for moving 1 square EAST
  fork
   begin
       prev_yy = iPHYS.yy;             // Store initial y position
       repeat(1000000) begin
           // Check xx is in correct range
           if ((iPHYS.xx >= 12'h3680 - 12'h0050) && (iDUT.xx <= 12'h3680 + 12'h0050)) begin
               $display("xx coordinate in correct range around 0x3680");
           end else begin
               $display("Error: xx coordinate not within +/-0x50 of 0x3680");
               $stop();
           end
           
           // Check yy hasn't changed significantly 
           if ((iPHYS.yy >= 12'h2800 - 12'h0050) && (iDUT.yy <= 12'h2800 + 12'h0050)) begin
               $display("yy coordinate remained stable within +/-0x50");
           end else begin
               $display("Error: yy coordinate changed by more than +/-0x50");
               $stop();
           end

           @(posedge clk);
       end
   end
 join

 // checking xx yy after moving 2 squares north
 // Check position 2: xx = 0x3680, yy = 0x0800             

fork
    begin
        repeat(1000000) begin
            if ((iPHYS.xx >= 12'h3680 - 12'h0050) && (iPHYS.xx <= 12'h3680 + 12'h0050)) begin
                $display("xx coordinate in correct range around 0x3680");
            end else begin
                $display("Error: xx coordinate not within +/-0x50 of 0x3680");
                $stop();
            end
            
            if ((iPHYS.yy >= 12'h0800 - 12'h0050) && (iPHYS.yy <= 12'h0800 + 12'h0050)) begin
                $display("yy coordinate in correct range around 0x1040");
            end else begin
                $display("Error: yy coordinate not within +/-0x50 of 0x1040");
                $stop();
            end
            @(posedge clk);
        end
    end
join

// Check position 3: xx = 0x1040, yy = 0x1040
fork
    begin
        repeat(1000000) begin
            if ((iPHYS.xx >= 12'h0800 - 12'h0050) && (iPHYS.xx <= 12'h0800 + 12'h0050)) begin
                $display("xx coordinate in correct range around 0x1040");
            end else begin
                $display("Error: xx coordinate not within +/-0x50 of 0x1040");
                $stop();
            end
            
            if ((iPHYS.yy >= 12'h0800 - 12'h0050) && (iPHYS.yy <= 12'h0800 + 12'h0050)) begin
                $display("yy coordinate in correct range around 0x1040");
            end else begin
                $display("Error: yy coordinate not within +/-0x50 of 0x1040");
                $stop();
            end
            @(posedge clk);
        end
    end
  join

// Check position 4: xx = 0x1040, yy = 0x4860
  fork
    begin
        repeat(1000000) begin
            if ((iPHYS.xx >= 12'h0800 - 12'h0050) && (iPHYS.xx <= 12'h0800 + 12'h0050)) begin
                $display("xx coordinate in correct range around 0x1040");
            end else begin
                $display("Error: xx coordinate not within +/-0x50 of 0x1040");
                $stop();
            end
            
            if ((iPHYS.yy >= 12'h4800 - 12'h0050) && (iPHYS.yy <= 12'h4800 + 12'h0050)) begin
                $display("yy coordinate in correct range around 0x4860");
            end else begin
                $display("Error: yy coordinate not within +/-0x50 of 0x4860");
                $stop();
            end
            @(posedge clk);
        end
    end
  join



  // All tests pass!
  $display("YAHOO!! All tests pass!!");
  $stop();
  end
  always
    #5 clk = ~clk;
  
endmodule