//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of robot.  Fusion correction comes    //
// from "gaurdrail" signals lftIR/rghtIR.       //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,lftIR,
                  rghtIR,SS_n,SCLK,MOSI,MISO,INT,moving);

  parameter FAST_SIM = 1;	// used to speed up simulation
  
  input clk, rst_n;
  input MISO;					// SPI input from inertial sensor
  input INT;					// goes high when measurement ready
  input strt_cal;				// initiate claibration of yaw readings
  input moving;					// Only integrate yaw when going
  input lftIR,rghtIR;			// gaurdrail sensors
  
  output cal_done;				// pulses high for 1 clock when calibration done
  output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n,SCLK,MOSI;		// SPI outputs


  //////////////////////////////////
  // Declare any internal signal //
  ////////////////////////////////
  logic vld;		// vld yaw_rt provided to inertial_integrator
  
  // SM signals
  typedef enum logic [3:0] {INIT_1, INIT_2, INIT_3, WAIT_INT, HIGH, LOW, DONE} state_t;
  logic snd, done, CYH, CYL;
  logic [15:0] cmd;
  
  // Instantiate our SPI monarch
  logic [15:0] resp;
  SPI_mnrch monarch(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .resp(resp), .snd(snd), .cmd(cmd), .done(done));
  

  // Holding register logic
  logic [7:0] high_byte, low_byte;
  // High byte register
  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		high_byte <= 8'h00;
	else if (CYH)
		// When we want to store off high byte, store the DATA bits of MISO
		high_byte <= resp[7:0];
  end
  // Low byte register
  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		low_byte <= 8'h00;
	else if (CYL)
		// When we want to store off low byte, store the DATA bits of MISO
		low_byte <= resp[7:0];
  end
  // Combine yaw bytes to send to integrator
  logic [15:0] yaw_rt;
  assign yaw_rt = {high_byte, low_byte};

  
  // Timer logic
  logic [15:0] timer;
  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		timer <= 16'h0000;
	else
		timer <= timer + 1;
  end
	
  // Double flop INT
  logic INT_ff1, INT_ff2;
  always_ff @(posedge clk) begin
	INT_ff1 <= INT;
	INT_ff2 <= INT_ff1;
  end

  // SM Logic
  // FF SM logic
  state_t state, nxt_state;
  always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		// Default state is INIT 1
		state <= INIT_1;
	else
		state <= nxt_state;
  end
  // Combinational logic for SM
  always_comb begin
	// Default inputs
	snd = 0;
	cmd = 0;
	vld = 0;
	CYH = 0;
	CYL = 0;
	nxt_state = state; // Hold state
	
	case (state)
		INIT_1: begin
			cmd = 16'h0D02;
			if(&timer) begin
				snd = 1;
				nxt_state = INIT_2;
			end
		end
		INIT_2: begin
			cmd = 16'h1160;
			if(done) begin
				snd = 1;
				nxt_state = INIT_3;
			end
		end
		INIT_3: begin
			cmd = 16'h1440;
			if(done) begin
				snd = 1;
				nxt_state = WAIT_INT;
			end
		end
		WAIT_INT: begin
			cmd = 16'hA7xx; // yawH
			if(INT_ff2) begin
				snd = 1;
				nxt_state = HIGH;
			end
		end
		HIGH: begin
			cmd = 16'hA6xx; // yawL
			if(done) begin
				CYH = 1; // Store off high
				snd = 1;
				nxt_state = LOW;
			end
		end
		LOW: if(done) begin
			CYL = 1; // Store off low
			nxt_state = DONE;
		end
 		DONE: begin
			vld = 1;
			nxt_state = WAIT_INT;
		end
		default: nxt_state = INIT_1;
	endcase
  end

  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and acceleration info and produces a heading reading         //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),.vld(vld),
                           .rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),.lftIR(lftIR),
                           .rghtIR(rghtIR),.heading(heading));
						   

endmodule
	  