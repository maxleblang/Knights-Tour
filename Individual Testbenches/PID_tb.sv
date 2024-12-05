module PID_tb();

    //Signals
    logic clk, rst_n;
    logic moving, err_vld;
    logic signed [11:0]error;
    logic [9:0]frwrd;
    logic [10:0] lft_spd, rght_spd;

    //Stimulus and Response memory
    logic [24:0] stim_array[1999:0];
    logic [21:0] resp_array[1999:0];
    
    //variable for current stim and resp in the loop
    logic [24:0] stim;
    logic [21:0] resp;

    integer i;

    //Instantiate PID
    PID iPID(
        .clk(clk),
        .rst_n(rst_n),
        .moving(moving),
        .err_vld(err_vld),
        .error(error),
        .frwrd(frwrd),
        .lft_spd(lft_spd),
        .rght_spd(rght_spd)
        );

    initial begin

        //read from files
        $readmemh("PID_stim.hex", stim_array);
        $readmemh("PID_resp.hex", resp_array);

        //start with clk low
        clk = 0;
        rst_n = 0;

        //initialize other signals
        moving = 0;
        err_vld = 0;
        error = 0;
        frwrd = 0;
        @(posedge clk);

        @(negedge clk);
        rst_n = 1;
        @(posedge clk);

        // loop through 2000 vectors
        for(i = 0; i < 2000; i++) begin

            stim = stim_array[i];
            resp = resp_array[i];
            
            //apply stim to inputs
            rst_n = stim[24];
            moving = stim[23];
            err_vld = stim[22];
            error = stim[21:10];
            frwrd = stim[9:0];

            //wait till #1 after rise of clk
            @(posedge clk) #1;

            //check if DUT outputs match resp
            if((lft_spd !== resp[21:11]) || (rght_spd !== resp[10:0])) begin
                $display("ERROR (%0d): {lft_spd (%h), rght_spd (%h)} != {%h, %h}.", i, lft_spd, rght_spd, resp[21:11], resp[10:0]);
                $stop();
            end
            
            //wait till fall of clock
            wait(~clk);

        end

        //YAY
        $display("YAHOO! All tests Passed :)");
        $display("Good Job Aayushi! - Prof. Hoffman (hopefully)");
        
        $stop();

    
    end

    always #5 clk = ~clk;

endmodule