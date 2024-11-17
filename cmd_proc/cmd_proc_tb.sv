module cmd_proc_tb();

    // general inputs //
    logic clk;                     // system clock
    logic rst_n;                   // asynchronous active-low reset
    
    // Command Processor (cmd_proc) //
    logic cntrIR;                 // Input to cmd_proc from outside (center IR sensor for obstacle detection)
    logic fanfare_go;             // from cmd_proc to outside (trigger for victory sound)
    logic [9:0] frwrd;            // from cmd_pro to outside (forward motion control value)
    logic [11:0] error;           // from cmd_pro to outside (error status code )
    logic tour_go;                // Output from cmd_proc to outside (start_tour)
    logic strt_cal;               // Output from cmd_proc / Input to inert_intf (start calibration sequence)
    logic moving;                 // Output from cmd_proc and outside / Input to inert_intf (robot movement status)
    logic [15:0] cmd_UART;        // Output from UART / Input to cmd_proc (cmd from UART from transmission with RemoteComm)
    logic cmd_rdy;                // Output from UART / Input to cmd_proc (cmd is read to be sent)
    logic clr_cmd_rdy;            // Output from UART / Input to cmd_proc (clear cmd_ready)
    logic send_resp;              // Input to cmd_proc / Output from UART (send resp)
    logic [11:0] heading;         // Output from inert_intf / Input to cmd_proc the (heading)
    logic heading_rdy;            // Output from inert_intf / Input to cmd_proc (stating new heading data available)
    logic cal_done;               // Output from inert_intf / Input to cmd_proc (calibration complete indicator)


    // RemoteComm //
    logic [7:0] resp;             // Output from RemoteComm to outside (response)
    logic resp_rdy;               // Output from RemoteComm to outside (resp is ready)
    logic TX_RX;                  // RemoteComm transmit to UART recieve
    logic [15:0] cmd;             // Input to RemoteComm from outside (cmd)
    logic snd_cmd;                // Input to RemoteComm from outside (high means command will be sent)
    logic cmd_snt;                // Output from RemoteComm to outside (command was sent)
    logic RX_TX;                  // UART transmit to RemoteComm recieve

    // SPI Interface Signals //
    logic SS_n;                   // Output from inert_intf / Input to iNEMO (SPI slave select active low)
    logic SCLK;                   // Output from inert_intf / Input to iNEMO (SPI clock)
    logic MOSI;                   // Output from inert_intf / Input to iNEMO (Master Out Slave In)
    logic INT;                    // Output from iNEMO / Input to inert_intf (interupt)
    logic MISO;                   // Output from iNEMO / Input to inert_intf (Master In Slave Out)
    
    // Fixed IR Inputs //
    logic lftIR;                  // left IR sensor (tied to 0)
    logic rghtIR;                 // right IR sensor (tied to 0)
    logic [7:0] resp_UART;        // Input to UART from outside (fixed to 8'hA5)

    // assign fixed values as per diagram
    assign lftIR = 0;
    assign rghtIR = 0;
    assign resp_UART = 8'hA5;

    // RemoteComm Instance//
    RemoteComm remote_comm_instf(
        .clk(clk), 
        .rst_n(rst_n), 
        .cmd(cmd), 
        .snd_cmd(snd_cmd),
        .TX(TX_RX), 
        .RX(RX_TX), 
        .resp(resp), 
        .resp_rdy(resp_rdy), 
        .cmd_snt(cmd_snt));

    // UART_Wrapper Instance //
    UART_wrapper uart_wrap_inst (
        .clk(clk), 
        .rst_n(rst_n), 
        .TX(RX_TX), 
        .RX(TX_RX), 
        .cmd(cmd_UART), 
        .cmd_rdy(cmd_rdy), 
        .clr_cmd_rdy(clr_cmd_rdy), 
        .trmt(send_resp), 
        .resp(resp_UART));

    // Inert Interface Instance //
    inert_intf inert_intf_inst (
        .clk(clk), 
        .rst_n(rst_n), 
        .INT(INT), 
        .SS_n(SS_n), 
        .SCLK(SCLK), 
        .MOSI(MOSI), 
        .MISO(MISO), 
        .lftIR(lftIR), 
        .rghtIR(rghtIR), 
        .heading(heading), 
        .rdy(heading_rdy), 
        .strt_cal(strt_cal), 
        .cal_done(cal_done), 
        .moving(moving));

    // SPI Instance //
    SPI_iNEMO3 spi_nemo_inst (
        .SS_n(SS_n), 
        .SCLK(SCLK), 
        .MOSI(MOSI), 
        .MISO(MISO), 
        .INT(INT));

    // DUT Instance //
    cmd_proc iDUT (
        .clk(clk), 
        .rst_n(rst_n), 
        .cmd(cmd_UART), 
        .cmd_rdy(cmd_rdy), 
        .clr_cmd_rdy(clr_cmd_rdy), 
        .send_resp(send_resp), 
        .tour_go(tour_go), 
        .heading(heading), 
        .heading_rdy(heading_rdy), 
        .strt_cal(strt_cal), .cal_done(cal_done), 
        .moving(moving), 
        .lftIR(lftIR), 
        .cntrIR(cntrIR), 
        .rghtIR(rghtIR), 
        .fanfare_go(fanfare_go), 
        .frwrd(frwrd), 
        .error(error));

    // start of tests
    initial begin
    
    // Initialize variables
    clk = 0;
    rst_n = 0;
    cmd = 16'h0000;
    snd_cmd = 0;
    cntrIR = 0;

    // Wait some clocks and release reset
    repeat(10) @(posedge clk);
    rst_n = 1;

    /////////////////////////
    // Test 1: Calibrate  //
    /////////////////////////
    cmd = 16'h2000;           // Calibrate command
    snd_cmd = 1;
    @(posedge clk);
    snd_cmd = 0;

    // Wait for cal_done with timeout
    fork
        begin: timeout_cal
            repeat(1000000) @(posedge clk);
            $display("ERROR: Timeout waiting for cal_done");
            $stop();
        end
        begin
            @(posedge cal_done);
            disable timeout_cal;
        end
    join

    // Wait for resp_rdy with timeout
    fork
        begin: timeout_resp1
            repeat(1000000) @(posedge clk);
            $display("ERROR: Timeout waiting for resp_rdy after calibration");
            $stop();
        end
        begin
            @(posedge resp_rdy);
            disable timeout_resp1;
        end
    join

    ////////////////////////////////
    // Test 2: Move North Square //
    ////////////////////////////////
    // Send move north command
    cmd = 16'h4001;           // Move north 1 square
    snd_cmd = 1;
    @(posedge clk);
    snd_cmd = 0;

    // Wait for cmd_snt 
    @(posedge cmd_snt);
    if (frwrd !== 10'h000 && frwrd !== 10'h020) begin
        $display("ERROR: frwrd should be 0 or 0x20 initially, not %h.", frwrd);
        $stop();
    end

    // Wait for 10 heading_rdy edges and check frwrd
    repeat(10) @(posedge heading_rdy);
    if (frwrd !== 10'h120 && frwrd !== 10'h140) begin
        $display("ERROR: frwrd should be 0x120 or 0x140, not %h.", frwrd);
        $stop();
    end

    // Check moving signal
    if (!moving) begin
        $display("ERROR: moving signal should be asserted.");
        $stop();
    end

    // Wait for 20 more heading_rdy edges
    repeat(20) @(posedge heading_rdy);
    
    // First cntrIR pulse (like crossing first line)
    cntrIR = 1;
    repeat(10) @(posedge clk);
    cntrIR = 0;
    repeat(100) @(posedge clk);

    // Verify frwrd is still at max
    if (frwrd !== 10'h3FF) begin
        $display("ERROR: frwrd should be at max speed, not %h.", frwrd);
        $stop();
    end

    // Second cntrIR pulse (like crossing second line)
    cntrIR = 1;
    repeat(10) @(posedge clk);
    cntrIR = 0;

    // Wait for move to complete (frwrd = 0)
    fork
        begin: timeout_move
            repeat(1000000) @(posedge clk);
            $display("ERROR: Timeout waiting for move to complete.");
            $stop();
        end
        begin
            wait(frwrd == 0);
            disable timeout_move;
        end
    join

    // Wait for resp_rdy with timeout
    fork
        begin: timeout_resp2
            repeat(1000000) @(posedge clk);
            $display("ERROR: Timeout waiting for resp_rdy after move.");
            $stop();
        end
        begin
            @(posedge resp_rdy);
            disable timeout_resp2;
        end
    join

    ////////////////////////////////////////////////
    // Test 3: Second Move North with IR Testing  //
    ////////////////////////////////////////////////
    cmd = 16'h4001;           // Move north 1 square again
    snd_cmd = 1;
    @(posedge clk);
    snd_cmd = 0;

    // Wait for robot to get up to speed
    repeat(30) @(posedge heading_rdy);

    // Test left IR interference
    force lftIR = 1; // ovverides the assign to make lftIR non zero
    repeat(100) @(posedge clk);
    release lftIR;

    // Check for error signal disturbance
    if (error === 12'h000) begin
        $display("ERROR: Expected error signal disturbance from left IR.");
        $stop();
    end

    // Test successful
    $display("YAHOO! All tests passed. :)");
    $stop();
    end

    // Clock generation (50MHz)
    always
        #10 clk = ~clk;

endmodule