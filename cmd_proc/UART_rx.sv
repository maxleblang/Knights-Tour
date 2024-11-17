module UART_rx(clk, rst_n, RX, clr_rdy, rx_data, rdy);

    //inputs and outputs
    input clk, rst_n;          //Clock and active-low reset
    input RX;                  //Serial data input
    input clr_rdy;             //Clear ready signal
    output logic [7:0] rx_data; //Byte received
    output logic rdy;          //Asserted when byte received. Stays high till
                               //start bit of next byte or until clr_rdy asserted.

    logic [3:0] bit_cnt;       //4 bit counter to track received bits
    logic [8:0] rx_shft_reg;   //9 bit shift register for receiving
    logic [11:0] baud_cnt;     //12 bit baud rate counter

    logic start, shift, receiving, set_rdy; //control signals

    //Handle RX Metastability 
    logic RX_1;
    logic RX_2;

    always_ff@(posedge clk, negedge rst_n)
        if(!rst_n) begin
            RX_1 <= 1'b1;      //Reset to idle state (high)
            RX_2 <= 1'b1;
        end else begin
            RX_1 <= RX;        //First flop
            RX_2 <= RX_1;      //Second flop
        end
        
    //Shift register logic
    always_ff@(posedge clk)
        if(shift) begin
           rx_shft_reg <= {RX_2, rx_shft_reg[8:1]}; //New bit + Shift right 
        end 

    assign rx_data = rx_shft_reg[7:0]; //Received data 

    //Baud rate counter
    always_ff@(posedge clk)
        if(start) begin
            baud_cnt <= 12'd1302; //Half bit time for start bit
        end else if (shift) begin
            baud_cnt <= 12'd2604; //Full bit time for data bits
        end else if (receiving) begin
            baud_cnt <= baud_cnt - 1; //Decrement counter
        end 

    assign shift = (baud_cnt == 0) ? 1 : 0; //Trigger shift at counter rollover

    //Bit counter
    always_ff@(posedge clk)
        if(start) begin
            bit_cnt <= 4'b0;   //Reset bit counter on start
        end else if (shift) begin
            bit_cnt <= bit_cnt + 1; //Increment counter
        end 

    //State Machine
    typedef enum logic [1:0] {
        IDLE, RECEIVE
    } state_t;

    state_t state, nxt_state;

    always_ff@(posedge clk, negedge rst_n)
    if(!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
    
    always_comb begin
        //defaults 
        nxt_state = state;
        start = 1'b0;
        receiving = 1'b0;
        set_rdy = 1'b0;

        case(state)
            RECEIVE: begin
                if(bit_cnt <= 4'd9) begin
                    receiving = 1'b1; //Keep receiving 
                    nxt_state = RECEIVE;
                end else begin
                    set_rdy = 1'b1; //All bits received
                    nxt_state = IDLE; 
                end
            end 

            default: begin //IDLE state
                if(~RX_2) begin
                    start = 1'b1; //Start receiving on falling edge
                    nxt_state = RECEIVE;
                end 
            end 
        endcase    
    end

    //Ready signal logic
    always_ff@(posedge clk, negedge rst_n)
        if(!rst_n) begin
            rdy <= 1'b0;       //Reset ready signal
        end else if (start | clr_rdy) begin
            rdy <= 1'b0;       //Clear ready on new start or clear signal
        end else if (set_rdy) begin
            rdy <= 1'b1;       //Set ready when reception complete
        end

endmodule