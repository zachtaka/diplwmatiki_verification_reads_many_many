/** 
 * @info Sender Flow Control
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Includes buffering if required, and any modifications to the flow control, according to parameters passed.
 *        The connection is assumed as following:
 *        ... --> Sender Flow Control --> [Link] Receiver Flow Control --> [processing]--> Sender Flow Control --> [Link] --> ...
 *        axi4_duth_noc_pkg should be set with caution, in a way that Sender's and Receiver's flow control paramters match properly.
 *        @see axi4_duth_noc_pkg package to find some ready pre-set configurations
 *
 * @param LINK_WIDTH specifies the size of each packet (in bits) 
 * @param LINK_FLOW_CONTROL specifies the flow control protocol: Elastic (ready/valid) or Credit-based.
 * @param PUSH_CHECK_READY specifies whether buffer readiness is checked before pushing to the buffer. Set to 1 for safety
 * @param CRFC_MAX_CREDITS [Credit-based only] specifies the number of slots of the receiver
 * @param CRFC_REG_DATA [Credit-based only] specifies if data are registered before sending (adds +1 to RTT)
 * @param CRFC_REG_CR_UPD [Credit-based only] specifies whether credit update notification is first registered upon reception (adds +1 RTT)
 * @param CRFC_USE_INCR [Credit-based only] specifies whether the credit update notification can be consumed immediately (@see credit_controller for details)
 * @param RVFC_BUFF_DEPTH [Elastic(ready/valid) only] specifies the number of buffer slots
 */ 

import axi4_duth_noc_pkg::*;

module flow_control_sender
  #(parameter int LINK_WIDTH						= 16,
    parameter link_fc_params_snd_type FC_SND_PARAMS = RTR_CREDITS_3_FC_SND)
    (input logic clk,
	 input logic rst,
	 // Input Channel
	 input logic[LINK_WIDTH-1:0] data_in,
	 input logic valid_in,
	 output logic ready_out,
     // Output Channel
     output logic[LINK_WIDTH-1:0] data_out,
	 output logic valid_out,
	 input logic front_notify  // <- generic signal (ready or cr_update)
	 );

// workaround to avoid errors (can't pass hierarchical names as constants)
function flow_control_type get_FC_TYPE();
	return FC_SND_PARAMS.FC_TYPE;
endfunction
function logic get_PUSH_CHECK_READY();
	return FC_SND_PARAMS.PUSH_CHECK_READY;
endfunction
function int get_CR_MAX_CREDITS();
	return FC_SND_PARAMS.CR_MAX_CREDITS;
endfunction
function logic get_CR_REG_DATA();
	return FC_SND_PARAMS.CR_REG_DATA;
endfunction
function logic get_CR_REG_CR_UPD();
	return FC_SND_PARAMS.CR_REG_CR_UPD;
endfunction
function logic get_CR_USE_INCR();
	return FC_SND_PARAMS.CR_USE_INCR;
endfunction
function int get_RV_BUFF_DEPTH();
	return FC_SND_PARAMS.RV_BUFF_DEPTH;
endfunction

localparam flow_control_type LINK_FLOW_CONTROL	= get_FC_TYPE();
localparam logic PUSH_CHECK_READY				= get_PUSH_CHECK_READY();
localparam int CRFC_MAX_CREDITS					= get_CR_MAX_CREDITS();
localparam logic CRFC_REG_DATA					= get_CR_REG_DATA();
localparam logic CRFC_REG_CR_UPD                = get_CR_REG_CR_UPD();
localparam logic CRFC_USE_INCR					= get_CR_USE_INCR();
localparam int RVFC_BUFF_DEPTH					= get_RV_BUFF_DEPTH();


logic ready_to_outp, valid_from_inp;
logic[LINK_WIDTH-1:0] data_to_outp;
logic valid_to_outp;

assign ready_out = ready_to_outp;

// Whether ready will be checked before buffering
assign valid_from_inp = PUSH_CHECK_READY ? (valid_in & ready_to_outp) : valid_in;

// Credit at the front link

generate
  if (LINK_FLOW_CONTROL == FLOW_CONTROL_CREDITS)
    begin
      // Credit controller
      credit_controller #(
        .MAX_CREDITS    (CRFC_MAX_CREDITS),
        .USE_INCR       (CRFC_USE_INCR),
        .BUFF_CR_INC    (CRFC_REG_CR_UPD))
	  cr_contr (
        .clk            (clk),
        .rst            (rst),
        .cr_consume     (valid_from_inp),
        .ready_out      (ready_to_outp),
        .cr_inc_in      (front_notify)
	  );
 
      // No Data Pipeline register
      if (!CRFC_REG_DATA) begin
          assign data_to_outp = data_in;
	      assign valid_to_outp = valid_from_inp;
      end else begin
          // Outp Buffer is Pipeline register for Credit-based
          pipeline_register #(
            .DATA_WIDTH        (LINK_WIDTH),
            .GATING_FRIENDLY   (CLOCK_GATING_FIRENDLY))
	     pipe_reg (
            .clk               (clk),
            .rst               (rst),
            .data_in           (data_in),
            .valid_in          (valid_from_inp),
            .data_out          (data_to_outp),
            .valid_out         (valid_to_outp)
	     );
      end
    end else
    // Elastic (ready/valid) at the front link
    if (LINK_FLOW_CONTROL == FLOW_CONTROL_ELASTIC) begin
        // No buffering at all
	    if (RVFC_BUFF_DEPTH == 0) begin
	        assign data_to_outp = data_in;
            assign valid_to_outp = valid_from_inp;
            assign ready_to_outp = front_notify;
	    end else
          if (RVFC_BUFF_DEPTH == 1)
		    // 1-slot with 100% throughput (combinational ready back-propagation)
		    eb_one_slot #(
		    .FULL_THROUGHPUT   (1'b1),
		    .DATA_WIDTH        (LINK_WIDTH),
		    .GATING_FRIENDLY   (1'b1))
		    eb (
		    .clk               (clk),
		    .rst               (rst),
		    .valid_in          (valid_from_inp),
		    .ready_out         (ready_to_outp),
		    .data_in           (data_in),
		    .valid_out         (valid_to_outp),
		    .ready_in          (front_notify),
		    .data_out          (data_to_outp)
		    );
	      else begin
		      // More slots - FIFO
		      logic fifo_pop;
		      fifo_duth #(
		      .DATA_WIDTH    (LINK_WIDTH),
              .RAM_DEPTH     (RVFC_BUFF_DEPTH))
		      fifox (
		      .clk           (clk),
		      .rst           (rst),
		      .push_data     (data_in),
		      .push          (valid_from_inp),
		      .ready         (ready_to_outp),
		      .pop_data      (data_to_outp),
		      .valid         (valid_to_outp),
		      .pop           (fifo_pop)
		      );
              assign fifo_pop = valid_to_outp & front_notify;
          end	
      end
endgenerate

assign data_out = data_to_outp;
assign valid_out = valid_to_outp;

endmodule
