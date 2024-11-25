//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of robot.  Fusion correction comes    //
// from "gaurdrail" signals lftIR/rghtIR.       //
/////////////////////////////////////////////////
module inert_intf(clk, rst_n, strt_cal, cal_done, heading, rdy, lftIR,
                  rghtIR, SS_n, SCLK, MOSI, MISO, INT, moving);

  parameter FAST_SIM = 1;	// used to speed up simulation
  
  input clk, rst_n;
  input MISO;					// SPI input from inertial sensor
  input INT;					// goes high when measurement ready
  input strt_cal;				// initiate calibration of yaw readings
  input moving;					// Only integrate yaw when going
  input lftIR, rghtIR;			// guardrail sensors
  
  output cal_done;				// pulses high for 1 clock when calibration done
  output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n, SCLK, MOSI;		// SPI outputs

  //////////////////////////////////
  // Declare any internal signal //
  ////////////////////////////////
  logic vld;		// vld yaw_rt provided to inertial_integrator

  logic [15:0] cmd;
  logic rd, snd;
  logic [15:0] resp;
  logic done;

  logic C_Y_H, C_Y_L;
  logic  [7:0] hold_yaw_low;
  logic  [7:0] hold_yaw_high;
  logic [15:0] timer;

  logic signed [15:0] yaw_rt;

  SPI_mnrch ispi (.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .snd(snd), .cmd(cmd), .done(done), .resp(resp));

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        hold_yaw_high <= 8'h00;
    end
    else if (C_Y_H) begin
        hold_yaw_high <= resp[7:0];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        hold_yaw_low <= 8'h00;
    end
    else if (C_Y_L) begin
        hold_yaw_low <= resp[7:0];
    end
  end

assign yaw_rt = {hold_yaw_high, hold_yaw_low};


  typedef enum logic [2:0] { init1, init2, init3, check, read_yawl, read_yawh, ready } state_t;
  state_t current_state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        current_state <= init1;
    end
    else begin
        current_state <= next_state;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        timer <= 16'h0000;
    end
    else begin
        timer <= timer + 1;
    end
  end


  
  //double flop int
  logic INTff1, INTff2;

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        INTff1 <= 1'b0;
    end
    else begin
        INTff1 <= INT;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        INTff2 <= 1'b0;
    end
    else begin
        INTff2 <= INTff1;
    end
  end
 

   always_comb begin

        //DEFAULTS
        snd = 0;
        cmd = 16'h000;
        vld = 0;
        C_Y_L = 0;
        C_Y_H = 0;
        next_state = current_state;

        case(current_state)

            init2: begin
                cmd = 16'h1160;
                if(done) begin
                    next_state = init3;
                    snd = 1;
                end
            end

            init3: begin
                cmd = 16'h1440;
                if(done) begin
                    next_state = check;
                    snd = 1;
                end
            end

            check: begin
                cmd = 16'hA6xx;
                if(INTff2) begin
                    next_state = read_yawl;
                    snd = 1;
                end
            end

            read_yawl: begin
                cmd = 16'hA7xx;
                if(done) begin
                    next_state = read_yawh;
                    snd = 1;
                    C_Y_L = 1;
                end
            end

            read_yawh: begin
                if(done) begin
                    next_state = ready;
                    C_Y_H = 1;
                end
            end

            ready: begin
                next_state = check;
                vld = 1;
            end

            default: begin  //init1 state
                cmd = 16'h0D02;
                if(&timer) begin
                    next_state = init2;
                    snd = 1;
                end
            end


        endcase
    end

  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and acceleration info and produces a heading reading         //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),.vld(vld),
                           .rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),.lftIR(lftIR),
                           .rghtIR(rghtIR),.heading(heading), .LED(LED));

endmodule
