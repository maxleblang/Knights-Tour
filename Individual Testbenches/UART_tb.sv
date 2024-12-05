module UART_tb();

    logic clk, rst_n;

    //UART_tx signals
    logic trmt; 
    logic [7:0] tx_data;   
    logic TX;       
    logic tx_done;   

    //UART_rx signals
    logic clr_rdy; 
    logic [7:0] rx_data;   
    logic RX;       
    logic rdy;   

    //Instantiate UART_tx
    UART_tx iUART_tx(.clk(clk), .rst_n(rst_n), .TX(TX), .trmt(trmt), .tx_data(tx_data), .tx_done(tx_done));

    //Instantiate UART_rx
    UART_rx iUART_rx(.clk(clk), .rst_n(rst_n), .RX(RX), .clr_rdy(clr_rdy), .rx_data(rx_data), .rdy(rdy));

    assign RX = TX;

     // Testbench 
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        trmt = 0;
        clr_rdy = 0;
        tx_data = 8'hFF;


        rst_n = 0;
        @(negedge clk);
        rst_n = 1;
        @(posedge clk);

        // Test Case 1: 

        trmt = 1'b1;
        tx_data = 8'h00;
        @(posedge clk);  
        trmt = 1'b0;
        @(posedge clk);

        //check tx_done
        @(posedge tx_done);
        $display("Transmitted 0x%h.", tx_data);

        //check rdy
        @(posedge rdy);
        $display("Received 0x%h.", rx_data);

        //Verify received data
        if (rx_data === tx_data)
            $display("Transmitted Data (0x%h) = Received Data(0x%h)", tx_data, rx_data);
        else begin
            $display("ERROR: Transmitted Data (0x%h) != Recieved Data (0x%h)", tx_data, rx_data);
            $stop();
            end

        //Clear rdy 
        @(posedge clk);
        clr_rdy = 1'b1;
        @(posedge clk);
        clr_rdy = 1'b0;
        @(posedge clk);
        if (rdy) begin
            $display("ERROR: rdy not cleared after clr_rdy");
            $stop();
        end else begin
            $display("clr_rdy cleared rdy signal");
        end

        // Test Case 2:
        trmt = 1'b1;
        tx_data = 8'hFF;
        repeat(5) @(posedge clk);  //trmt high for multiple clk cycles
        trmt = 1'b0;
        @(posedge clk);

        //check tx_done
        @(posedge tx_done);
        $display("Transmitted 0x%h.", tx_data);

        //check rdy
        @(posedge rdy);
        $display("Received 0x%h.", rx_data);

        //Verify received data
        if (rx_data === tx_data)
            $display("Transmitted Data (0x%h) = Received Data(0x%h)", tx_data, rx_data);
        else begin
            $display("ERROR: Transmitted Data (0x%h) != Recieved Data (0x%h)", tx_data, rx_data);
            $stop();
            end

        //Clear rdy 
        @(posedge clk);
        clr_rdy = 1'b1;
        @(posedge clk);
        clr_rdy = 1'b0;
        @(posedge clk);
        if (rdy) begin
            $display("ERROR: rdy not cleared after clr_rdy");
            $stop();
        end else begin
            $display("clr_rdy cleared rdy signal");
        end

        // Test Case 3: 
        trmt = 1'b1;
        tx_data = 8'hAA;
        @(posedge clk);  
        trmt = 1'b0;
        @(posedge clk);

        //check tx_done
        @(posedge tx_done);
        $display("Transmitted 0x%h.", tx_data);

        //check rdy
        @(posedge rdy);
        $display("Received 0x%h.", rx_data);

        //Verify received data
        if (rx_data === tx_data)
            $display("Transmitted Data (0x%h) = Received Data(0x%h)", tx_data, rx_data);
        else begin
            $display("ERROR: Transmitted Data (0x%h) != Recieved Data (0x%h)", tx_data, rx_data);
            $stop();
            end

        //Clear rdy 
        @(posedge clk);
        clr_rdy = 1'b1;
        @(posedge clk);
        clr_rdy = 1'b0;
        @(posedge clk);
        if (rdy) begin
            $display("ERROR: rdy not cleared after clr_rdy");
            $stop();
        end else begin
            $display("clr_rdy cleared rdy signal");
        end


        // Test Case 4: 
        trmt = 1'b1;
        tx_data = 8'h55;
        @(posedge clk);  
        trmt = 1'b0;
        @(posedge clk);

        //check tx_done
        @(posedge tx_done);
        $display("Transmitted 0x%h.", tx_data);

        //check rdy
        @(posedge rdy);
        $display("Received 0x%h.", rx_data);

        //Verify received data
        if (rx_data === tx_data)
            $display("Transmitted Data (0x%h) = Received Data(0x%h)", tx_data, rx_data);
        else begin
            $display("ERROR: Transmitted Data (0x%h) != Recieved Data (0x%h)", tx_data, rx_data);
            $stop();
            end

        //Clear rdy 
        @(posedge clk);
        clr_rdy = 1'b1;
        @(posedge clk);
        clr_rdy = 1'b0;
        @(posedge clk);
        if (rdy) begin
            $display("ERROR: rdy not cleared after clr_rdy");
            $stop();
        end else begin
            $display("clr_rdy cleared rdy signal");
        end


        // Test Case 5: 
        trmt = 1'b1;
        tx_data = 8'hB7;
        @(posedge clk);  
        trmt = 1'b0;
        @(posedge clk);

        //check tx_done
        @(posedge tx_done);
        $display("Transmitted 0x%h.", tx_data);

        //check rdy
        @(posedge rdy);
        $display("Received 0x%h.", rx_data);

        //Verify received data
        if (rx_data === tx_data)
            $display("Transmitted Data (0x%h) = Received Data(0x%h)", tx_data, rx_data);
        else begin
            $display("ERROR: Transmitted Data (0x%h) != Recieved Data (0x%h)", tx_data, rx_data);
            $stop();
            end

        //Clear rdy 
        @(posedge clk);
        clr_rdy = 1'b1;
        @(posedge clk);
        clr_rdy = 1'b0;
        @(posedge clk);
        if (rdy) begin
            $display("ERROR: rdy not cleared after clr_rdy");
            $stop();
        end else begin
            $display("clr_rdy cleared rdy signal");
        end


        $display("YAHOO! All tests Passed.");

        $stop();
        
    end


    always #5 clk = ~clk;


endmodule