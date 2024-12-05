module SPI_mnrch_tb();

    logic clk, rst_n;
    logic MISO;
    logic snd;
    logic [15:0] cmd;
    logic done;
    logic SS_n, SCLK, MOSI;
    logic [15:0] resp;

    logic INT;

    SPI_mnrch iSPI_mnrch(
        .clk(clk),
        .rst_n(rst_n),
        .SS_n(SS_n),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(MISO),
        .snd(snd),
        .cmd(cmd),
        .done(done),

    // Intermediate signals
    logic clk, rst_n;           
    logic MISO;                  
    logic snd;                  
    logic [15:0] cmd;           
    logic done;                  
    logic SS_n, SCLK, MOSI;     
    logic [15:0] resp;          

    logic INT;                   // Interrupt signal for the slave device

    // Instantiate SPI
    SPI_mnrch iSPI_mnrch(
        .clk(clk),
        .rst_n(rst_n),
        .SS_n(SS_n),
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(MISO),
        .snd(snd),
        .cmd(cmd),
        .done(done),
        .resp(resp)
    );

    // Instantiate SPI_iNEMO1
    SPI_iNEMO1 iSPI_NEMO1(
        .SS_n(SS_n),
        .SCLK(SCLK),
        .MISO(MISO),
        .MOSI(MOSI),
        .INT(INT)
    );    


    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;        
        rst_n = 0;          
        snd = 0;              
        cmd = 16'h0000;          

        @(negedge clk);          
        rst_n = 1;              
        @(posedge clk);           

        // Test 1:
        cmd = 16'h8Fxx;           // Set command for test
        snd = 1;                  // Set send signal to high
        @(posedge clk)          
        snd = 0;                  // Clear send signal

        @(posedge done);          // Wait for done signal
        @(posedge clk);           // Wait for the next clock edge

    
        if(resp !== 16'h006A) begin
            $display("ERROR: Test 1 - resp should be 16'h006A not %h.", resp);
            $stop();           
        end else begin
            $display("Test 1 - Who Am I register read - Passed");
        end

        repeat(2) @(posedge clk); 

        // Test 2:
        cmd = 16'h0D02;           // Set command
        snd = 1;                  // Set send signal to high
        @(posedge clk)          
        snd = 0;                  // Clear send signal

        @(posedge done);          // Wait for done signal
        @(posedge clk);         

        // Check NEMO 
        if(iSPI_NEMO1.NEMO_setup) begin
            $display("Test 2 - INT config register - Passed");
        end else begin
            $display("ERROR: INT config register failed");
            $stop();           
        end

        repeat(2) @(posedge clk); 

        // Test 3:
        wait(INT);                // Wait for the interrupt signal

        cmd = 16'hA2xx;           // Set command 
        snd = 1;                  // Set send signal to high
        @(posedge clk)       
        snd = 0;                  // Clear send signal

        wait(~INT);               // Wait until the interrupt signal is cleared
        $display("Test - INT cleared");

        @(posedge done);          // Wait for done signal
        @(posedge clk);         


        if(resp[7:0] !== 8'h63) begin
            $display("ERROR: Test 3 - resp should be 16'hxx63 not %h.", resp);
            $stop();            
        end else begin
            $display("Test 3 - ptchL -- pitch rate low from gyro - Passed");
        end

        repeat(2) @(posedge clk); 

        // Test 4:
        cmd = 16'hA3xx;           // Set command
        snd = 1;                  // Set send signal to high
        @(posedge clk)      
        snd = 0;                  // Clear send signal

        @(posedge done);          // Wait for done signal
        @(posedge clk);           

        if(resp[7:0] !== 8'h56) begin
            $display("ERROR: Test 4 - resp should be 16'hxx56 not %h.", resp);
            $stop();          
        end else begin
            $display("Test 4 - ptchH -- pitch rate high from gyro - Passed");
        end

        repeat(2) @(posedge clk); 

        // Test 5:
        wait(INT);                // Wait for the interrupt signal

        cmd = 16'hA3xx;           // Set command
        snd = 1;                  // Set send signal to high
        @(posedge clk)            
        snd = 0;                  // Clear send signal

        @(posedge done);          // Wait for done signal
        @(posedge clk);          


        if(resp[7:0] !== 8'hcd) begin
            $display("ERROR: Test 5 - resp should be 16'hxxcd not %h.", resp);
            $stop();          
        end else begin
            $display("Test 5 - ptchH -- pitch rate high from gyro - Passed");
        end

        // All tests passed
        $display("YAHOO! All tests Passed.");
        $stop();                 
        
    end 

endmodule

       