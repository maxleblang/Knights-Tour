module UART_tx(clk, rst_n, TX, trmt, tx_data, tx_done);

    //inputs and outputs
    input clk, rst_n;       //Clock and active-low reset
    input trmt;             //Asserted for 1 clock to initiate transmission
    input [7:0]tx_data;     //Byte to transmit
    output logic TX;        //Serial data output
    output logic tx_done;   //Asserted when byte is done transmitting.
                            //Stays high till next byte transmitted. 
         
    logic [8:0]tx_shft_reg; //9 bit shift reg
    logic [11:0]baud_cnt;   //12 bit baud rate counter
    logic [3:0]bit_cnt;     //4 bit bit counter to track transmitted bits
  
    logic init, shift, set_done, transmitting; //control signals

    //shift register logic
    always_ff @(posedge clk, negedge rst_n )
    if(!rst_n) begin
        tx_shft_reg <= 9'hFFF; //reset shift register 
    end else if (init) begin
        tx_shft_reg <= {tx_data, 1'b0}; //load data with start bit on init
    end else if (shift) begin
        tx_shft_reg <= {1'b1, tx_shft_reg[8:1]}; //shift right
    end 

    assign TX = tx_shft_reg[0]; //Transmit LSB

    //Baud rate counter
    always_ff @(posedge clk)
    if(init | shift) begin 
        baud_cnt <= 12'b0; //Reset counter on init or after bit shift
    end else if (transmitting) begin
        baud_cnt <= baud_cnt + 1; //Increment counter
    end 


    assign shift = (baud_cnt == 12'd2604) ? 1 : 0; //trigger shift

    //Bit counter
    always_ff @(posedge clk)
    if(init) begin
        bit_cnt <= 4'b0; //Reset bit counter on init
    end else if (shift) begin
        bit_cnt <= bit_cnt + 1; //Increment counter
    end

    //State Machine
    typedef enum logic [1:0] {
        IDLE, SHIFT
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
        set_done = 1'b0;
        transmitting = 1'b0;
        init = 1'b0;

        case(state)

            SHIFT: begin

                if(bit_cnt != 4'd8) begin
                    transmitting = 1'b1; //Keep transmitting
                    nxt_state = SHIFT;
                end else if (bit_cnt == 4'd8) begin
                    set_done = 1'b1; //All bits transmitted 
                    nxt_state = IDLE; 
                end
            end 

            default: begin //IDLE state

                if(trmt) begin
                    init = 1'b1; //Start transmitting
                    nxt_state = SHIFT;
                end 
            end 

        endcase    
    end


    always_ff@(posedge clk, negedge rst_n)
    if(!rst_n) begin
        tx_done <= 1'b0; //reset tx_done
    end else if (init) begin
        tx_done <= 1'b0; //clear tx_done on init for new transmission
    end else if (set_done) begin
        tx_done <= 1'b1; //Transmission complete
    end


endmodule