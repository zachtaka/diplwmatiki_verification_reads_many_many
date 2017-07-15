/** 
 * @info Per-output Router logic
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief The logic required per-output in a switch. Includes arbiter, multiplexer and manages multi-flit packet format, locks input connection etc.
 *
 * @param IN_PORTS number of input ports connected to this output
 * @param FLIT_WIDTH width of flit
 * @param NO_RETURNS determines whether input i is allowed to reach output i. Safe choice: false.
 *        If asserted, certain input-output connections are forbidden, thus removing logic and usually relaxing critical path.
 */

import axi4_duth_noc_pkg::*;

module rtr_out_logic
   #(parameter int IN_PORTS     = 4, 
     parameter int FLIT_WIDTH	= 16, 
     parameter logic NO_RETURNS	= 1'b0)
   (input logic clk, 
    input logic rst,
	// Output state
	output logic outp_avail,
	// SA 
	input logic[(IN_PORTS-NO_RETURNS)-1:0] sa_reqs,
	output logic[(IN_PORTS-NO_RETURNS)-1:0] sa_grants,
	// Input data
	input logic[(IN_PORTS-NO_RETURNS)*FLIT_WIDTH-1:0] data_in,
	// Output data
	output logic[FLIT_WIDTH-1:0] data_out,
	output logic valid_out);
	

// SA
logic[(IN_PORTS-NO_RETURNS)-1:0] sa_grants_s, update_pri;
logic anygnt;
logic tail_at_outp;
// States
logic outp_avail_s, outp_ready_s;
// Data from inps
logic [FLIT_WIDTH-1:0] data_from_inps [(IN_PORTS-NO_RETURNS)-1:0];
logic[FLIT_WIDTH-1:0] data_from_mux;

assign sa_grants = sa_grants_s;

// arbitrate requests per output
assign update_pri = { (IN_PORTS-NO_RETURNS){anygnt} };

// sa: rr_arbiter
arbitration #( .N       (IN_PORTS-NO_RETURNS),
			   .ARB_TYPE(ARB_TYPES_RR))
			sa( .clk        (clk),
			    .rst        (rst),
			    .reqs       (sa_reqs),
			    .grants     (sa_grants_s),
			    .anygnt     (anygnt),
			    .update_pri (update_pri));

genvar i;
// Data type conversion
generate
for(i=0; i < (IN_PORTS-NO_RETURNS); i=i+1) begin: for_i1
   assign data_from_inps[i] = data_in[(i+1)*FLIT_WIDTH-1 : i*FLIT_WIDTH]; // [i*FLIT_WIDTH-1 +: FLIT_WIDTH];
end
// Tail
logic[(IN_PORTS-NO_RETURNS)-1:0] temp;

for(i=0; i < (IN_PORTS-NO_RETURNS); i=i+1) begin: for_i2
   assign temp[i]=sa_reqs[i] & flit_is_tail(data_from_inps[i][FLIT_FIELD_WIDTH-1:0]);
end
assign tail_at_outp = |temp;
endgenerate


// Monitor Available
always_ff @ (posedge clk, posedge rst)
   if (rst) outp_avail <= 1;
   else 
      if (tail_at_outp | flit_is_single(data_from_mux[FLIT_FIELD_WIDTH-1:0]))
	     outp_avail <= 1; 
      else
	     if (anygnt)
	        outp_avail <= 0;
   
// get data from all inputs and select one per output
and_or_multiplexer #( .INPUTS       (IN_PORTS-NO_RETURNS),
					  .DATA_WIDTH   (FLIT_WIDTH))
       mux_data ( .data_in  (data_in),
                  .sel      (sa_grants_s),
                  .data_out (data_from_mux));

assign data_out = data_from_mux;
assign valid_out = anygnt;
   
endmodule
