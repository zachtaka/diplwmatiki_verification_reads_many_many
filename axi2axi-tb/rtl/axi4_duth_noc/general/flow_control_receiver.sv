/** 
 * @info Receiver Flow Control
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Includes buffering if required, and any modifications to the flow control, according to parameters passed.
 *        The connection is assumed as following:
 *        ... --> Sender Flow Control --> [Link] Receiver Flow Control --> [processing]--> Sender Flow Control --> [Link] --> ...
 *        Parameters should be set with caution, in a way that Sender's and Receiver's flow control paramters match properly.
 *        @see axi4_duth_noc_pkg package to find some ready pre-set configurations
 *
 * @param LINK_WIDTH specifies the size of the link
 * @param LINK_FLOW_CONTROL specifies the flow control protocol: Elastic (ready/valid) or Credit-based.
 * @param BUFF_DEPTH specifies the number of buffer slots. Can take any non-negative value:
          0 spawns no buffer, 1 generates PEB (@see eb_one_slot), >1 generates a circular buffer (@see fifo_duth)
 * @param POP_CHECK_VALID Whether valid is checked before issuing a pop to the buffer. Set to 1 for safety
 * @param REG_CR_UPD [Credit-based only] Whether back-notification (credit update) is first registered before sent back
 * @param PUSH_CHECK_READY [Elastic only] Whether buffer readiness is checked before pushing. Set to 1 for safety
 */ 

import axi4_duth_noc_pkg::*;

module flow_control_receiver 
  #(parameter int LINK_WIDTH						= 16,
    parameter link_fc_params_rcv_type FC_RCV_PARAMS = RTR_CREDITS_3_FC_RCV)
  (input logic clk,
   input logic rst,
   // Input Channel
   input logic[LINK_WIDTH-1:0] data_in,
   input logic valid_in,
   output logic back_notify, // <- generic signal (ready or cr_update)
   // Output Channel
   output logic[LINK_WIDTH-1:0] data_out,
   output logic valid_out,
   input logic ready_in
   );

// workaround to avoid errors (can't pass hierarchical names as constants)
function flow_control_type get_LINK_FLOW_CONTROL();
	return FC_RCV_PARAMS.FC_TYPE;
endfunction
function int get_BUFF_DEPTH();
	return FC_RCV_PARAMS.BUFF_DEPTH;
endfunction
function logic get_POP_CHECK_VALID();
	return FC_RCV_PARAMS.POP_CHECK_VALID;
endfunction
function logic get_REG_CR_UPD();
	return FC_RCV_PARAMS.CR_REG_CR_UPD;
endfunction
function logic get_PUSH_CHECK_READY();
	return FC_RCV_PARAMS.RV_PUSH_CHECK_READY;
endfunction


localparam flow_control_type LINK_FLOW_CONTROL 	= get_LINK_FLOW_CONTROL();
localparam int BUFF_DEPTH						= get_BUFF_DEPTH();
localparam logic POP_CHECK_VALID                = get_POP_CHECK_VALID();
localparam logic REG_CR_UPD						= get_REG_CR_UPD();
localparam logic PUSH_CHECK_READY				= get_PUSH_CHECK_READY();

   
logic fifo_push, fifo_ready, fifo_valid, fifo_pop;

// No buffering
generate
  if (BUFF_DEPTH == 0) begin
	  assign data_out = data_in;
      assign valid_out = valid_in;
      assign fifo_ready = ready_in;
  end else
    if (BUFF_DEPTH == 1) begin
	    assign valid_out = fifo_valid;
        eb_one_slot #(
		.FULL_THROUGHPUT   (1'b1),
		.DATA_WIDTH        (LINK_WIDTH),
		.GATING_FRIENDLY   (1'b1))
		eb (
		.clk               (clk),
		.rst               (rst),
		.valid_in          (fifo_push),
		.ready_out         (fifo_ready),
		.data_in           (data_in),
		.valid_out         (fifo_valid),
		.ready_in          (fifo_pop),
		.data_out          (data_out)
		);
		assign fifo_pop = POP_CHECK_VALID ? (fifo_valid & ready_in) : ready_in;
    end else begin
	  // BUFF_DEPTH > 1
	    assign valid_out = fifo_valid;
		fifo_duth #(
		.DATA_WIDTH    (LINK_WIDTH),
        .RAM_DEPTH     (BUFF_DEPTH))
		fifox (
		.clk           (clk),
		.rst           (rst),
		.push_data     (data_in),
		.push          (fifo_push),
		.ready         (fifo_ready),
		.pop_data      (data_out),
		.valid         (fifo_valid),
		.pop           (fifo_pop)
		);
		assign fifo_pop = POP_CHECK_VALID ? (fifo_valid & ready_in) : ready_in;
	end
	  
	  
  // Credit-based fc at link
  if (LINK_FLOW_CONTROL == FLOW_CONTROL_CREDITS) begin 
      assign fifo_push = valid_in;
      // Register credit update before sending to the link
	  if (REG_CR_UPD) begin 
	      logic cr_upd_reg;
	      assign back_notify = cr_upd_reg;
	      always_ff @ (posedge clk, posedge rst)
		    if (rst) cr_upd_reg <= 0;
		    else 
		      cr_upd_reg <= fifo_pop;
      end else
        // Credit update as is	
	    assign back_notify = fifo_pop;
  end else 
    // Elastic fc at link
	if (LINK_FLOW_CONTROL == FLOW_CONTROL_ELASTIC) begin 
	    assign back_notify = fifo_ready;
		assign fifo_push = PUSH_CHECK_READY ? (valid_in & fifo_ready) : valid_in;
	end
	  
endgenerate

endmodule
