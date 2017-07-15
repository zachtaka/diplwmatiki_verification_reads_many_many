/** 
 * @info AXI Response Merge Unit (Master NI)
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Simple merging of the Read and Write Response transactions, put by the External Slave at the B and R channels.
 *        Policy is Round Robin. The channel is unlocked after a single beat (unlike @see axi_merge_reqs at the Slave NI)
 *        Since the Slave may reorder data of responses with different TIDs
 *
 * @param HAS_WRITE specifies if the NI serves Write Requests (simplifies unit if it doesn't)
 * @param HAS_READ specifies if the NI serves Read Requests (simplifies unit if it doesn't)
 */

import axi4_duth_noc_pkg::*;


module axi_merge_resps
  #(parameter logic HAS_WRITE   = 1'b1,
    parameter logic HAS_READ    = 1'b1)
    (input logic clk,
     input logic rst,
     //   Input AXI Channels (valids only!)  
     //   Write Response
     input logic b_valid,
     // Read Data (response)
     input logic r_valid,
     //  Output (to packetizer)  
     output logic[1:0] active_channel,
     input  logic[1:0] update_pri);

logic[1:0] merge_reqs, merge_grants;
logic merge_anygnt;

assign merge_reqs = {r_valid , b_valid}; // concatenation
// localparam ArbForm ARB_NOW = 

generate

  if ( HAS_WRITE && HAS_READ ) begin
    // Read: 1 - Write: 0
    arbitration #( .N       (2),
                   .ARB_TYPE(ARB_TYPES_RR))
    axi_merge_arb (clk, rst,
                   merge_reqs, merge_grants,
                   merge_anygnt, update_pri);
  end  
    
  if ( HAS_WRITE && (!HAS_READ) ) begin
    assign merge_anygnt = b_valid;
    assign merge_grants[0] = b_valid;
    assign merge_grants[1] = 1'b0;
  end
    
  if ( (!HAS_WRITE) && HAS_READ ) begin
    assign merge_anygnt = r_valid;
    assign merge_grants[0] = 1'b0;
    assign merge_grants[1] = r_valid;
  end
    
  assign active_channel = merge_grants;
endgenerate

endmodule
