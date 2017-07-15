/**
 * @info Custom policy arbitration - Arbiter wrapper.
 *
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 *
 * @brief arbitrates among N requests ('reqs') producing a one-hot vector ('grants') 
 *        of the winner input, using the selected arbitration policy, set by the 
 *        ARB_TYPE parameter. Avoid OR-reducing  g r a n t s  to check if a winner 
 *        exists. Use 'anygnt' instead, which arrives earlier, since it checks if at 
 *        least one  r e q u e s t  was made. In RR policy, use 'update_pri' to update 
 *        the arbiter's priority. When input i is currently being granted and 
 *        update_pri[i] is asserted, priority will be updated to point to input i+1 
 *        in the next cycle. Signal ignored in case of Fixed Priority.
 * 
 * @param N specifies the number of input requests
 * @param ARB_TYPE (@see package axi4_duth_noc_pkg for type ArbForm) specifies the arbitration 
 *        policy. No arbitration (ARB_TYPES_NONE) is useful to avoid adding any 
 *        logic when the request vector is known to always be one-hot and no  
 *        actual arbitration takes place.
 * @param PRI_RST starting priority after reset (points to that position, i.e. can have
 *        a value 0...N-1)
 */

import axi4_duth_noc_pkg::*;

module arbitration 
  #(parameter int N             = 4,
    parameter ArbForm ARB_TYPE  = ARB_TYPES_RR,
    parameter int PRI_RST       = 0)
   (input  logic        clk, 
    input  logic        rst,
    input  logic[N-1:0] reqs,
    output logic[N-1:0] grants,
    output logic        anygnt,
    input  logic[N-1:0] update_pri);


generate
    if (N > 1) begin
        if (ARB_TYPE == ARB_TYPES_NONE) begin
            assign grants = reqs;
            assign anygnt = |reqs;
        end 
        
        if (ARB_TYPE == ARB_TYPES_FPA)
          fpa_smart #( .N (N))
            arb ( .request  (reqs),
                  .grant    (grants),
                  .anygrant (anygnt));
        
        if (ARB_TYPE == ARB_TYPES_RR)
          rr_arbiter #( .N      (N),
                        .PRI_RST(PRI_RST))
            arb ( .clk          (clk),
                  .rst          (rst),
                  .request      (reqs),
                  .grant        (grants),
                  .anygnt       (anygnt),
                  .update_pri   (update_pri));
    end
    
    // a single input (to avoid synth errors, especially in RR for signals of [-1:0], due to log2(1)-1=-1)
    if (N == 1) begin
        assign grants = reqs;
        assign anygnt = reqs[0];
    end
    
endgenerate

endmodule
