module intert_intf_tb();

    logic clk, rst_n;
    logic strt_cal, cal_done, rdy;
    logic lftIR, rghtIR;
    logic moving;
    logic SS_n, SCLK, MOSI, MISO, INT;
    logic [11:0] heading;
    
    inert_intf iINERT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal), .cal_done(cal_done), .heading(heading), .rdy(rdy), .lftIR(lftIR),
                  .rghtIR(rghtIR), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .INT(INT), .moving(moving));

    SPI_iNEMO2 ispi2 (.SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .INT(INT));

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        strt_cal = 0;
        moving = 0;
        lftIR = 0;
        rghtIR = 0;
        rst_n = 0;
        @(negedge clk);
        rst_n = 1;
        @(negedge clk);
        moving = 1;
        lftIR  = 1;
        rghtIR = 1;

         // fork for checking interrupt and timeout handling
        fork
            begin : timeout1
                repeat(70000) @(posedge clk); 
                if (!ispi2.NEMO_setup) begin
                    $display("NEMO_setup was not asserted");
                    $stop();
                end
            end
            begin
                @(posedge ispi2.NEMO_setup) 
                disable timeout1;
            end
        join 

        @(negedge clk);
        strt_cal = 1;
        @(negedge clk);
        strt_cal = 0;


        fork
            begin : timeout2
                repeat(1500000) @(posedge clk); 
                if (!cal_done) begin
                    $display("cal_done was not asserted");
                    $stop();
                end
            end
            begin
                @(posedge cal_done) 
                disable timeout2;
            end
        join 
    

    repeat(8000000) @(posedge clk);

    $display("Testbench done");
    $stop();
    end



endmodule
