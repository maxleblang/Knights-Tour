module CommTB();
    logic clk, rst_n;
    logic trmt, clr_cmd_rdy, cmd_rdy, tx_done;
    logic snd_cmd, cmd_sent, resp_rdy; 
    logic RX_TX, TX_RX;
    logic [15:0] RC_cmd, UW_cmd;
    logic [7:0]resp;

    RemoteComm iRemoteComm(.clk(clk), .rst_n(rst_n), .snd_cmd(snd_cmd), .cmd(RC_cmd), .TX(TX_RX), .RX(RX_TX), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));

    UART_wrapper iUART_wrapper(.clk(clk), .rst_n(rst_n), .RX(TX_RX), .TX(RX_TX), .resp(resp), .trmt(trmt), .tx_done(tx_done), .cmd(UW_cmd), .cmd_rdy(cmd_rdy), .clr_cmd_rdy(clr_cmd_rdy));

    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        snd_cmd = 0;
        clr_cmd_rdy = 0;
        RC_cmd = 0;

        
        @(negedge clk);
        rst_n = 1;
        @(posedge clk);

        //Test Case 1:
        

        RC_cmd = 16'hFFFF;
        @(posedge clk);  
        snd_cmd = 1'b1;
        trmt = 1'b1;
        @(posedge clk);
        snd_cmd = 1'b0;
        trmt = 1'b0;

        @(posedge clk);

        wait(cmd_sent);

        @(posedge clk);

        if (RC_cmd === UW_cmd) begin 
            $display("RemoteComm CMD (0x%h) == UART_Wrapper CMD(0x%h)", RC_cmd, UW_cmd);
        end else begin
            $display("ERROR: RemoteComm CMD (0x%h) != UART_Wrapper CMD(0x%h)", RC_cmd, UW_cmd);
            $stop();
        end

        //Clear cmd_rdy 
        @(posedge clk);
        clr_cmd_rdy = 1'b1;
        @(posedge clk);
        clr_cmd_rdy = 1'b0;
        @(posedge clk);
        if (cmd_rdy) begin
            $display("ERROR: cmd_rdy not cleared after clr_cmd_rdy");
            $stop();
        end else begin
            $display("clr_cmd_rdy cleared rdy signal");
        end

        //Test Case 2:

        RC_cmd = 16'h1234;
        @(posedge clk);  
        snd_cmd = 1'b1;
        trmt = 1'b1;
        @(posedge clk);
        snd_cmd = 1'b0;
        trmt = 1'b0;

        @(posedge clk);

        wait(cmd_sent);

        @(posedge clk);

        if (RC_cmd === UW_cmd) begin 
            $display("RemoteComm CMD (0x%h) == UART_Wrapper CMD(0x%h)", RC_cmd, UW_cmd);
        end else begin
            $display("ERROR: RemoteComm CMD (0x%h) != UART_Wrapper CMD(0x%h)", RC_cmd, UW_cmd);
            $stop();
        end

        //Clear cmd_rdy 
        @(posedge clk);
        clr_cmd_rdy = 1'b1;
        @(posedge clk);
        clr_cmd_rdy = 1'b0;
        @(posedge clk);

        //Test Case 3:
        RC_cmd = 16'h8BA2;
        @(posedge clk);  
        snd_cmd = 1'b1;
        trmt = 1'b1;
        @(posedge clk);
        snd_cmd = 1'b0;
        trmt = 1'b0;

        @(posedge clk);

        wait(cmd_sent);

        @(posedge clk);

        if (RC_cmd === UW_cmd) begin 
            $display("RemoteComm CMD (0x%h) == UART_Wrapper CMD(0x%h)", RC_cmd, UW_cmd);
        end else begin
            $display("ERROR: RemoteComm CMD (0x%h) != UART_Wrapper CMD(0x%h)", RC_cmd, UW_cmd);
            $stop();
        end

        //Clear cmd_rdy 
        @(posedge clk);
        clr_cmd_rdy = 1'b1;
        @(posedge clk);
        clr_cmd_rdy = 1'b0;
        @(posedge clk);

        //Test Case 4:
        RC_cmd = 16'h0000;
        @(posedge clk);  
        snd_cmd = 1'b1;
        trmt = 1'b1;
        @(posedge clk);
        snd_cmd = 1'b0;
        trmt = 1'b0;

        @(posedge clk);

        wait(cmd_sent);

        @(posedge clk);

        if (RC_cmd === UW_cmd) begin 
            $display("RemoteComm CMD (0x%h) == UART_Wrapper CMD(0x%h)", RC_cmd, UW_cmd);
        end else begin
            $display("ERROR: RemoteComm CMD (0x%h) != UART_Wrapper CMD(0x%h)", RC_cmd, UW_cmd);
            $stop();
        end

        //Clear cmd_rdy 
        @(posedge clk);
        clr_cmd_rdy = 1'b1;
        @(posedge clk);
        clr_cmd_rdy = 1'b0;
        @(posedge clk);

        
        $display("YAHOO! All tests Passed.");
        $stop();

    end



endmodule