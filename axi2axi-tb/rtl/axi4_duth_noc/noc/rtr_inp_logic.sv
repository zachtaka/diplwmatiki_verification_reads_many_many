/** 
 * @info Per-input Router logic
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief The logic required per-input in a switch. Calculates output port, manages multi-flit packet format, locks output connection etc.
 *
 * @param FLIT_WIDTH width of flit
 * @param NODE_ID the ID of the node in the topology. Not always required.
 * @param MY_INP_ID the ID of the input in the switch (used only when NO_RETURNS is asserted).
 * @param DST_PNT the position of the first bit of the destination ID (determined at the NIs)
 * @param DST_ADDR_WIDTH the width of the destination ID vector, usually clog2(# of total destinations)
 * @param RC_ALGO determines the Routing Computation algorithm (@see axi4_duth_noc_pkg)
 * @param OUT_PORTS number of output ports of the current switch
 * @param NO_RETURNS determines whether input i is allowed to reach output i. Safe choice: false.
 *        If asserted, certain input-output connections are forbidden, thus removing logic and usually relaxing critical path.
 */
 
import axi4_duth_noc_pkg::*;

module rtr_inp_logic
   #(parameter int FLIT_WIDTH		= 16,
     parameter int NODE_ID		    = 0,
     parameter int MY_INP_ID		= 0,
     parameter int DST_PNT		    = 4,
     parameter int DST_ADDR_WIDTH	= 2,
     parameter rc_algo_type RC_ALGO	= RC_ALGO_XBAR,
     parameter int OUT_PORTS		= 4,
     parameter logic NO_RETURNS		= 1'b0)
   (input logic clk, 
    input logic rst,
	
	// Channel side
	input logic[FLIT_WIDTH-1:0] data_in,
    input logic valid_in,
    output logic back_pop,
	
    // To/from SA
    output logic[(OUT_PORTS-NO_RETURNS)-1:0] sa_req,
    input logic sa_grant,
	
    // Outputs
    input logic[(OUT_PORTS-NO_RETURNS)-1:0] ready_outps,
    input logic[(OUT_PORTS-NO_RETURNS)-1:0] avail_outps,
    
	// Router side
    output logic[FLIT_WIDTH-1:0] data_out);
	
// If no dst width, ignore
logic[(DST_ADDR_WIDTH > 0 ? DST_ADDR_WIDTH : 1)-1:0] dst;
logic[OUT_PORTS-1:0] req_rc_tmp;
logic[(OUT_PORTS-NO_RETURNS)-1:0] req_from_rc, req_lrc, out_port, out_port_r;
logic out_lock_r;

assign  back_pop = sa_grant;

// RC stage

// Routing Logic
if (DST_ADDR_WIDTH > 0) begin: if_dstw_gt0
    assign dst = data_in[DST_PNT +: (DST_ADDR_WIDTH > 0 ? DST_ADDR_WIDTH : 1)]; //-1 : DST_PNT];

    rc_unit #(.NODE_ID          (NODE_ID),
              .DST_ADDR_WIDTH   (DST_ADDR_WIDTH),
              .RC_ALGO          (RC_ALGO),
              .OUT_PORTS        (OUT_PORTS)) 
    rc       (.dst      (dst),
              .out_port (req_rc_tmp));
    
    no_x_dst: assert property (@(posedge clk) disable iff(rst) valid_in && (flit_is_head(data_in) || flit_is_single(data_in)) |-> ^(dst) !== 1'bx) else
        $fatal(1, "[header check] Invalid destination node in flit's header! Check for X's @ dst!");
end else begin: if_dstw_eq0
    assign req_rc_tmp = 1'b1;
    // pragma synthesis_off
    // pragma translate_off
    initial begin
        assert (OUT_PORTS == 1) else $fatal(1, "one dst but more than 1 ports??");
        assert (!NO_RETURNS) else $fatal(1, "one dst but no returns??");
    end
    // pragma translate_on
    // pragma synthesis_on
end

genvar i;
generate 
   if (NO_RETURNS)
      for(i=0; i < OUT_PORTS; i=i+1) begin: for_i
	     if (i < MY_INP_ID) // if_lt
	        assign req_from_rc[i] = req_rc_tmp[i];
	     else
	       if (i > MY_INP_ID) // if_gt
	         assign req_from_rc[i-1] = req_rc_tmp[i];
      end
   else
	  assign req_from_rc = req_rc_tmp;
endgenerate

always_ff @(posedge clk, posedge rst)
   if (rst) out_lock_r <= 0;
   else
      if (sa_grant & (flit_is_tail(data_in) | flit_is_single(data_in))) 
          out_lock_r <= 0;
      else
         if (valid_in & (flit_is_head(data_in) | flit_is_single(data_in)))
         begin		 
            out_lock_r <= sa_grant;
            out_port_r <= req_from_rc;
	     end
	
assign out_port = (!out_lock_r) ? req_from_rc : out_port_r;
logic[(OUT_PORTS-NO_RETURNS)-1:0] temp;
assign temp = { (OUT_PORTS-NO_RETURNS){valid_in} };
assign sa_req = (!out_lock_r) ? (avail_outps & ready_outps & out_port & temp):
								(out_port & ready_outps & temp);


assign data_out = data_in;




no_x_ft: assert property (@(posedge clk) disable iff(rst) valid_in |->  ^(data_in[1:0]) !== 1'bx) else // (data_in[1:0]0]==1'b0 || data_in[0]==1'b1) && (data_in[1]==1'b0 || data_in[1]==1'b1) )) else
    $fatal(1, "[header check] Invalid Flit Type! Check for X's @ data_in[1:0]!");
endmodule
