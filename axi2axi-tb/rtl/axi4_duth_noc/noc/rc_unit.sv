/** 
 * @info Routing Computation unit
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Routing Computation unit, gets the destination id ('dst') and returns the proper router port to be requested ('out_port').
 *        'out_port' is one-hot.
 *
 * @param NODE_ID the ID of the node in the topology (only for RC, not always required)
 * @param DST_ADDR_WIDTH the width of the destination ID vector, usually clog2(# of total destinations)
 * @param RC_ALGO determines the Routing Computation algorithm (@see axi4_duth_noc_pkg)
 * @param OUT_PORTS number of output ports of the current switch
 */
import axi4_duth_noc_pkg::*;

module rc_unit
   #(parameter int NODE_ID          = 0,
     parameter int DST_ADDR_WIDTH	= 2, 
     parameter rc_algo_type RC_ALGO	= RC_ALGO_XBAR,
     parameter int OUT_PORTS		= 4)
   (input logic[(DST_ADDR_WIDTH > 0 ? DST_ADDR_WIDTH : 1)-1:0] dst, // err protect
	output logic[OUT_PORTS-1:0] out_port);

// distr (radix = OUT_PORTS)
logic[OUT_PORTS-1:0] distr_port;
// xbar
logic[OUT_PORTS-1:0] xbar_port;
// merge
logic merge_port;

if (RC_ALGO == RC_ALGO_DISTRIBUTE_TREE) begin
    // Checking proper RC_ALGO to avoid dummy errors (e.g. << neg_val, log2(0) etc.) when called with a different RC_ALGO
    // DST_ADDR_WIDTH comparison to avoid dummy errors
    localparam integer MY_LEVEL     = DST_ADDR_WIDTH > 0 ? ( (RC_ALGO == RC_ALGO_DISTRIBUTE_TREE) ? (logBc(OUT_PORTS, (OUT_PORTS-1)*NODE_ID + OUT_PORTS) - 1) : 0)
                                                         :  1;
    localparam integer DISTR_BIT_LO = DST_ADDR_WIDTH > 0 ? ( (RC_ALGO == RC_ALGO_DISTRIBUTE_TREE) ? (DST_ADDR_WIDTH-(MY_LEVEL+1)*log2c(OUT_PORTS)) : 0)
                                                         : 1;
    localparam integer DISTR_BIT_HI = DST_ADDR_WIDTH > 0 ? ( (RC_ALGO == RC_ALGO_DISTRIBUTE_TREE) ? (DST_ADDR_WIDTH-MY_LEVEL*log2c(OUT_PORTS)-1) : 0)
                                                         : 1;
    assign out_port = (RC_ALGO == RC_ALGO_DISTRIBUTE_TREE) ? ( 1'b1 <<  dst[DISTR_BIT_HI : DISTR_BIT_LO] ) : {OUT_PORTS{1'b0}};
end else  if (RC_ALGO == RC_ALGO_XBAR) begin
    assign out_port = 1'b1 << dst;
end else begin // if (RC_ALGO == RC_ALGO_MERGE_TREE) begin
    assign out_port = 1'b1;
end

// assign out_port = (RC_ALGO == RC_ALGO_XBAR) ? xbar_port :
				  // (RC_ALGO == RC_ALGO_MERGE_TREE) ? merge_port :
				  // distr_port;


endmodule
