module PID(clk, rst_n, moving, err_vld, error, frwrd, lft_spd, rght_spd);
    
    localparam signed P_COEFF = 6'h10;
    localparam signed D_COEFF = 5'h07;

    //Inputs and outputs
    input clk, rst_n;
    input moving, err_vld;
    input signed [11:0]error;
    input [9:0]frwrd;
    output logic [10:0] lft_spd, rght_spd;

    //Intermediate Signals
    logic signed [12:0] P_div2;
    logic signed [13:0] P_ext, I_ext, D_ext;
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

    //Pipeline flip flops
    logic signed [13:0] P_term_ff;
    logic signed [8:0] I_term_ff;
    logic signed [12:0] D_term_ff;
    logic signed [14:0] sum_ff; //used in I term
    logic signed [9:0] err_sat_ff;
    logic signed err_vld_ff;
    logic signed [9:0] frwrd_ff;
    logic signed moving_ff;
 
    // -- P_TERM -- //
    assign err_sat = (~error[11] & |error[10:9])? 10'h1FF: // +ve saturation
                 (error[11] & ~&error[10:9])? 10'h200: // -ve saturation
                 error[9:0];

    // Pipeline flip-flop for err_sat
    always_ff @(posedge clk) begin
            err_sat_ff <= err_sat;
            err_vld_ff <= err_vld;
            frwrd_ff <= frwrd;
            moving_ff <= moving;
    end


    assign P_term = $signed(err_sat_ff) * $signed(P_COEFF);

    //pipeline flip flop for P term
     always_ff @(posedge clk)
            P_term_ff <= P_term;

    // -- END P_TERM -- //

    // -- I_TERM -- //
    assign err_sign_ext = {{5{err_sat_ff[9]}},err_sat_ff}; 
    assign sum = err_sign_ext + integrator; // Add error to integrator

    //pipeline flip flop for sum
    always_ff @(posedge clk)
        sum_ff <= sum;

    assign ov = (err_sign_ext[14] & integrator[14] & ~sum_ff[14])? 1'b1 : // +ve overflow
                (~err_sign_ext[14] & ~integrator[14] & sum_ff[14]) ? 1'b1 : // -ve overflow
                1'b0;

    assign mux1 = (~ov & err_vld_ff) ? sum_ff : integrator; // Freeze integrator on overflow
    assign nxt_integrator = moving ? mux1 : 15'h0000; 

    always_ff @(posedge clk, negedge rst_n)
        if (!rst_n)
        integrator <= 15'h0000; // Reset integrator
        else
        integrator <= nxt_integrator; 
        

    assign I_term = integrator[14:6]; // Extract upper bits for I_term

    //pipeline flip flop for I term
      always_ff @(posedge clk)
        if (!rst_n)
            I_term_ff <= I_term;

    // -- END I_TERM -- //

    // -- D_TERM -- //

    //stage 1
    always_ff @(posedge clk, negedge rst_n)
        if(!rst_n)
            q1 <= 10'b0;
        else if(err_vld_ff)
            q1 <= err_sat_ff;
        
    //stage 2
    always_ff @(posedge clk, negedge rst_n)
        if(!rst_n)
            q2 <= 10'b0;
        else if(err_vld_ff)
            q2 <= q1;

    //stage 3    
    always_ff @(posedge clk, negedge rst_n)
        if(!rst_n)
            prev_err <= 10'b0;
        else if(err_vld_ff)
            prev_err <= q2; //store previous error        

    //Calculate difference b/w current and previous error
    assign D_diff = err_sat_ff - prev_err;

    assign D_diff_sat = (~D_diff[9] & |D_diff[8:7])? 8'h7F: // +ve saturatiom
                 (D_diff[9] & ~&D_diff[8:7])? 8'h80: //-ve saturation
                 D_diff[7:0]; // no saturation

    assign D_term = $signed(D_diff_sat) * $signed(D_COEFF); //calculate D_term

    //pipeline flip flop for D term
     always_ff @(posedge clk)
            D_term_ff <= D_term;

    // -- END D_TERM -- //

    // -- CALC PID -- //
    
    assign P_div2 = P_term_ff[13:1]; // Divide P_term by 2

    assign P_ext = {P_div2[12], P_div2 }; 
    assign I_ext = {{5{I_term_ff[8]}}, I_term_ff}; 
    assign D_ext = {D_term_ff[12], D_term_ff}; 

    assign frwrd_ext = {1'b0,frwrd_ff}; 

    assign PID = P_ext + I_ext + D_ext; // Combine P, I, and D terms

    // -- END CALC PID -- //

    // -- CALC LEFT SPEED -- //

    assign lft_calc = frwrd_ext + PID[13:3]; // Add PID to frwrd speed 

    assign lft_mux = moving_ff ? lft_calc : 11'h000; // Zero speed if not moving
    assign lft_spd = (~PID[13] & lft_mux[10]) ? 11'h3FF : lft_mux; // saturate left speed 

    // -- END CALC LEFT SPEED -- //

    // -- CALC RIGHT SPEED -- //

    assign rght_calc = frwrd_ext - PID[13:3]; // Subtract PID from frwrd speed

    assign rght_mux = moving_ff ? rght_calc : 11'h000; // Zero speed if not moving

    assign rght_spd = (PID[13] & rght_mux[10]) ? 11'h3FF : rght_mux; // saturate right speed

    // -- END CALC RIGHT SPEED -- //

endmodule
