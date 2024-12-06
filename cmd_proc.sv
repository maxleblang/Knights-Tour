module cmd_proc(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, send_resp, tour_go, heading, heading_rdy, strt_cal, cal_done, moving, lftIR, cntrIR, rghtIR, fanfare_go, frwrd, error);

    parameter FAST_SIM = 1;

    input clk, rst_n;
    input [15:0] cmd;
    input signed [11:0] heading;
    input cmd_rdy, heading_rdy, cal_done, lftIR, rghtIR, cntrIR;
    output logic clr_cmd_rdy, send_resp, tour_go, strt_cal, moving, fanfare_go;
    output logic signed [11:0] error;
    output logic [9:0] frwrd;
    
    //Frwrd register intermediate signals
    logic inc_frwrd, dec_frwrd, clr_frwrd;
    logic frwrd_zero;
    logic max_speed;
    logic [9:0] counter_inc, counter_dec;
   
    //Counting squares intermediate signals
    logic move_done, move_cmd;
    logic [3:0] squares_to_move; 
    logic [3:0] squares_moved_counter;   
    logic cntrIR1, cntrIR_rising_edge;

    //PID intermediate signals 
    logic abs_error;
    logic signed [11:0] cmd_ext, desired_heading, err_nudge;


    // -- START FRWRD REGISTER -- //


    assign max_speed = &frwrd[9:8];
    assign frwrd_zero = (frwrd == 10'h000);
    assign enable_counter =  heading_rdy & ((inc_frwrd & ~max_speed) | (dec_frwrd & ~frwrd_zero)); //oopsy

    generate if (FAST_SIM) begin
        assign counter_inc = 10'h20;
        assign counter_dec = 10'h40;
        end else begin
        assign counter_inc = 10'h03;
        assign counter_dec = 10'h06;
        end
    endgenerate


    always_ff@(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            frwrd <= 10'h000;
        end else if(clr_frwrd) begin
            frwrd <= 10'h000;
        end else if(enable_counter) begin
            if(inc_frwrd) begin
                frwrd <= frwrd + counter_inc;
            end else if(dec_frwrd) begin
                frwrd <= frwrd - counter_dec;
            end
        end
    end

    // -- END FRWRD REGISTER -- //


    // -- START COUNTING SQUARES LOGIC -- //

    always_ff@(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            cntrIR1 <= 0;
        end else begin
            cntrIR1 <= cntrIR;
        end
    end

    assign cntrIR_rising_edge = cntrIR & ~cntrIR1;

    always_ff@(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			squares_moved_counter <= 0;
		end
        else if (move_cmd) begin
            squares_moved_counter <= 0;
        end
        else if (cntrIR_rising_edge) begin
            squares_moved_counter <= squares_moved_counter + 1;
        end

    end

    always_ff@(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            squares_to_move <= 0;
        end else if(move_cmd) begin
            squares_to_move <= cmd[3:0];
        end
    end

    assign move_done = ({squares_to_move, 1'b0} == squares_moved_counter);

    // -- END COUNTING SQUARES LOGIC -- //

    
    // -- PID INTERFACE -- //
    
    assign cmd_ext = (cmd[11:4] == 8'h00) ? 0 : ({cmd[11:4], 4'hF});

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            desired_heading <= 12'h00;
        end else if(move_cmd) begin
            desired_heading <= cmd_ext;
            end
        end


    generate if (FAST_SIM) begin
        assign err_nudge = lftIR ? 12'h1FF : (rghtIR ? 12'hE00 : 0);
        end else begin
        assign err_nudge = lftIR ? 12'h05F : (rghtIR ? 12'hFA1 : 0);
        end
    endgenerate

    assign error = heading - desired_heading + err_nudge;

    // -- END PID INTERFACE -- //
    
    // -- STATE MACHINE -- //

    typedef enum logic [3:0] {
        IDLE, CAL, UPDATE_HEADING, RAMP_UP, RAMP_DOWN
    } state_t;

    state_t state, nxt_state;

    always_ff@(posedge clk, negedge rst_n)
    if(!rst_n)
        state <= IDLE;
    else
        state <= nxt_state;
 

    always_comb begin

        //defaults
        clr_cmd_rdy = 0;
        strt_cal = 0;
        send_resp = 0;
        inc_frwrd = 0;
        dec_frwrd = 0;
        fanfare_go = 0;
        tour_go = 0;
        move_cmd = 0;
        nxt_state = state;
        moving = 0;
        clr_frwrd = 0;

        case(state)

            default: begin //IDLE STATE
                if(cmd_rdy) begin
                    clr_cmd_rdy = 1;
                    if(cmd[14:13] == 2'b01) begin
                        strt_cal = 1;
                        clr_frwrd = 1;
                        nxt_state = CAL;
                    end else if(cmd[14:13] == 2'b10) begin
                        nxt_state = UPDATE_HEADING;
                        move_cmd = 1;
                    end else if(cmd[14:13] == 2'b11) begin
                        tour_go = 1;
                    end
                end
            end

            CAL: begin
                if(cal_done)begin
                    send_resp = 1;
                    nxt_state = IDLE;
                end
            end

            UPDATE_HEADING: begin
                moving = 1;
                if(error < $signed(12'h02C) && error > $signed(-12'h02C)) begin
                    nxt_state = RAMP_UP;
                end
            end
            
            RAMP_UP: begin
                moving = 1;
                inc_frwrd = 1;
                if(move_done) begin
                    nxt_state = RAMP_DOWN;
                    if(cmd[12] == 1'b1) begin
                        fanfare_go = 1;
                    end
                end
            end

            RAMP_DOWN: begin
                moving = 1;
                dec_frwrd = 1;
                if(frwrd_zero) begin
                    send_resp = 1;
                    nxt_state = IDLE;
                end
                    
            end
            
        endcase
    end

    // -- END STATE MACHINE -- //

endmodule