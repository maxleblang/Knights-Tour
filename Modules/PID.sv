module PID(clk, rst_n, moving, err_vld, error, frwrd, lft_spd, rght_spd);
    
    localparam signed P_COEFF = 6'h10;
    localparam signed D_COEFF = 5'h07;

    //Inputs and outputs
    input clk, rst_n;
    input moving, err_vld;
    input signed [11:0]error;
    input [9:0] frwrd;
    output logic [10:0] lft_spd, rght_spd;

    //Intermediate Signals
    logic [10:0]frwrd_ext;
    logic signed [13:0] PID;
    logic signed [10:0] lft_calc, rght_calc;
    logic signed [10:0] lft_mux, rght_mux;


    //Signals for P_term
    logic signed [13:0]P_term;
    logic signed [9:0]err_sat;

    //Signals for I_term
    logic signed [8:0]I_term;
    logic signed [14:0]err_sign_ext;
    logic signed [14:0]integrator;
    logic signed [14:0]sum;
    logic signed [14:0] mux1;
    logic signed [14:0] nxt_integrator;
    logic ov;

    //Signals for D_term
    logic signed [12:0]D_term; 
    logic signed [9:0]D_diff;           //err_sat - prev_err
    logic signed [9:0]prev_err;         //previous error
    logic signed [7:0]D_diff_sat;       //saturated diff
    logic signed [9:0] q1, q2;

    logic signed [9:0] err_sat_ff;
    logic signed err_vld_ff;



    // -- P_TERM -- //
    assign err_sat = (~error[11] & |error[10:9])? 10'h1FF: // +ve saturation
                 (error[11] & ~&error[10:9])? 10'h200: // -ve saturation
                 error[9:0];

     // Pipeline flip-flop for err_sat
    always_ff @(posedge clk) begin
            err_sat_ff <= err_sat;
    end 

    assign P_term = (err_sat_ff) * (P_COEFF);

    // -- END P_TERM -- //

    // -- I_TERM -- //
    always_ff @(posedge clk) begin
            err_vld_ff <= err_vld;
    end

    assign err_sign_ext = {{5{err_sat_ff[9]}},err_sat_ff}; 
    assign sum = err_sign_ext + integrator; // Add error to integrator

    assign ov = (err_sign_ext[14] & integrator[14] & ~sum[14])? 1'b1 : // +ve overflow
                (~err_sign_ext[14] & ~integrator[14] & sum[14]) ? 1'b1 : // -ve overflow
                1'b0;

    assign mux1 = (~ov & err_vld_ff) ? sum : integrator; // Freeze integrator on overflow
    assign nxt_integrator = moving ? mux1 : 15'h0000; 

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
        integrator <= 15'h0000; // Reset integrator
        else
        integrator <= nxt_integrator; 

    assign I_term = integrator[14:6]; // Extract upper bits for I_term

    // -- END I_TERM -- //

    // -- D_TERM -- //

    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            q1 <= 10'b0;
            q2 <= 10'b0;
            prev_err <= 10'b0;
        end else if(err_vld_ff) begin
            q1 <= err_sat_ff;
            q2 <= q1;
            prev_err <= q2; //store previous error      
        end  
    end
 

    //Calculate difference b/w current and previous error
    assign D_diff = err_sat_ff - prev_err;

    assign D_diff_sat = (~D_diff[9] & |D_diff[8:7])? 8'h7F: // +ve saturatiom
                 (D_diff[9] & ~&D_diff[8:7])? 8'h80: //-ve saturation
                 D_diff[7:0]; // no saturation

    assign D_term = (D_diff_sat) * (D_COEFF); //calculate D_term

    // -- END D_TERM -- //

    // -- CALC PID -- //

    assign frwrd_ext = {1'b0,frwrd}; 
    
    always_ff @(posedge clk)
            PID <= {P_term[13], P_term[13:1] }+ {{5{I_term[8]}}, I_term} + {D_term[12], D_term}; // Combine P, I, and D terms


    // -- END CALC PID -- //

    // -- CALC LEFT SPEED -- //

    assign lft_calc = frwrd_ext + PID[13:3]; // Add PID to frwrd speed 
    assign lft_mux = moving ? lft_calc : 11'h000; // Zero speed if not moving
    
    assign lft_spd = (~PID[13] & lft_mux[10]) ? 11'h3FF : lft_mux; // saturate left speed 

    // -- END CALC LEFT SPEED -- //

    // -- CALC RIGHT SPEED -- //

    assign rght_calc = frwrd_ext - PID[13:3]; // Subtract PID from frwrd speed
    assign rght_mux = moving ? rght_calc : 11'h000; // Zero speed if not moving

    assign rght_spd = (PID[13] & rght_mux[10]) ? 11'h3FF : rght_mux; // saturate right speed

    // -- END CALC RIGHT SPEED -- //

endmodule

