/** 
 * @info AXI Request Merge Unit (Slave NI)
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Allows only one transaction (Read or Write) to access the forward channel (i.e. packetizer).
 *        Merges Request transactions and preserves the connection until the whole transaction is received.
 *        Once at least one valid request appears an RR arbiter decides which one, Read or Write, will lock
 *        the channel. Once the whole transaction has gone through, the channel is released and arbitration
 *        can again take place.
 *        
 *        Note: Data are NOT checked! An outer controller (i.e. packetizer) is assumed to monitor the state
 *        of the transaction and asserts the corresponding update_pri signal once the whole transaction is
 *        received and the channel should be released (e.g LAST is asserted for Write Data).
 *        
 *        Write has a valid arbiter request when both AW and W are valid
 *        Read has a valid arbiter request when AR is valid
 *        Check below for different arbitration policies.
 *
 * @param HAS_WRITE specifies if the NI serves Write Requests (simplifies unit if it doesn't)
 * @param HAS_READ specifies if the NI serves Read Requests (simplifies unit if it doesn't)
 */

import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;

module axi_merge_reqs
  #(parameter logic HAS_WRITE   = 1'b1,
    parameter logic HAS_READ    = 1'b1)
   (input logic clk, 
    input logic rst,
	//---   Input AXI Channels (valids only!)   ---
    //-- Write Address
    input logic aw_valid,
    //-- Write Data
    input logic w_valid,
    //-- Read Address
    input logic ar_valid,
    //---   Output (to packetizer)   ---
    output logic[1:0] active_channel,
    output logic anyactive,
    input logic[1:0] update_pri);
	
	
logic write_eligible, read_eligible;
logic[1:0] merge_locked;
logic[1:0] merge_reqs, merge_grants;
logic merge_anygnt;
	
// Write is eligible only when both Addr & Data channels are valid. Policy can be altered* (see below)
assign write_eligible = (aw_valid & w_valid);
assign read_eligible = ar_valid;
// Make a request whenever (a) already locked, (b) now eligible	
assign merge_reqs = merge_locked | {read_eligible,write_eligible};
	
generate
  if (HAS_WRITE && HAS_READ) begin: w_r
    // Read: Req(1) - Write: Req(0)
	arbitration #(.N        (2), 
	              .ARB_TYPE (ARB_TYPES_RR))
    axi_merge_arb(.clk        (clk),
	              .rst        (rst),
				  .reqs       (merge_reqs),
				  .grants     (merge_grants),
				  .anygnt     (merge_anygnt),
				  .update_pri (update_pri));
  end else
    if (HAS_WRITE && (!(HAS_READ))) begin: w_only
	    assign merge_grants = {1'b0,merge_reqs[0]};
        assign merge_anygnt = merge_reqs[0];
	end else
	  if ((!HAS_WRITE) && HAS_READ) begin: r_only
		  assign merge_grants = {merge_reqs[1],1'b0};
		  assign merge_anygnt = merge_reqs[1];
      end
endgenerate

// Lock access
always_ff @(posedge clk, posedge rst) begin: state_lock
  if (rst)
    merge_locked <= 0;
  else if (update_pri[0] | update_pri[1])
    // reset lock whenever the whole transaction is read
    merge_locked <= 0;
  else if ((merge_anygnt) & (merge_locked == 2'b00))
	// checking of merge_locked can be omitted! If so, redundant writes are made
    merge_locked <= merge_grants;
end
assign active_channel = merge_grants;
assign anyactive = merge_anygnt;
//-------------------------------------------------------------------------------------------------------------------
// *On arbitration policy alternatives:
//  - Especially when not using Reorder Buffer, each Transaction can be checked for qualification
//    from the order unit, according to its TID. This can save some cases, e.g. current Write transaction
//    is allowed to move forward (no outstanding for the TID) but Read is not. Read is granted, and Write is
//    blocked, although it can move fwd.
//-------------------------------------------------------------------------------------------------------------------	
	
	
endmodule
