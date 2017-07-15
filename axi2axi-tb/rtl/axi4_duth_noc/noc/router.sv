/** 
 * @info Router
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Parameterized Router (switch) used to build any kind of NoC topology, given the right parameters and routing algorithm.
 *
 * @param FLIT_WIDTH width of flit
 * @param IN_PORTS number of input ports
 * @param OUT_PORTS number of output ports
 * @param NODE_ID the ID of the node in the topology. Not always required.
 * @param RC_ALGO determines the Routing Computation algorithm (@see axi4_duth_noc_pkg)
 * @param DST_PNT the position of the first bit of the destination ID (determined at the NIs)
 * @param DST_ADDR_WIDTH the width of the destination ID vector, usually clog2(# of total destinations)
 * @param NO_RETURNS determines whether input i is allowed to reach output i. Safe choice: false.
 *        If asserted, certain input-output connections are forbidden, thus removing logic and usually relaxing critical path.
 * @param INP_FC_PARAMS input buffering and flow control (@see flow_control_receiver)
 * @param OUT_FC_PARAMS output buffering and flow control (@see flow_control_sender)
 */

import axi4_duth_noc_pkg::*;

module router
   #(parameter int FLIT_WIDTH                           = 16,
     parameter int IN_PORTS                             = 4,
     parameter int OUT_PORTS                            = 4,
     // Routing & switching
     parameter int NODE_ID                              = 0,
     parameter rc_algo_type RC_ALGO                     = RC_ALGO_XBAR,
     parameter int DST_PNT                              = 4,
     parameter int DST_ADDR_WIDTH                       = 2,
     parameter logic NO_RETURNS                         = 1'b0,
     // Input Flow Control & Buffering
     parameter link_fc_params_rcv_type INP_FC_PARAMS    = RTR_CREDITS_3_FC_RCV,
     // Output Flow Control & Buffering
     parameter link_fc_params_snd_type OUT_FC_PARAMS    = RTR_CREDITS_3_FC_SND)
    (input  logic clk, 
     input  logic rst,
     // Input Channel
     input  logic[IN_PORTS*FLIT_WIDTH-1:0] data_in,
     input  logic[IN_PORTS-1:0] valid_in,
     output logic[IN_PORTS-1:0] back_notify,
     //Output Channel
     output logic[OUT_PORTS*FLIT_WIDTH-1:0] data_out,
     output logic[OUT_PORTS-1:0] valid_out,
     input  logic[OUT_PORTS-1:0] front_notify);

// From/to FIFO (Inp Contr)
logic [FLIT_WIDTH-1:0] data_to_inps [IN_PORTS-1:0];
logic [FLIT_WIDTH-1:0] data_from_inp_buff [IN_PORTS-1:0];
logic [IN_PORTS-1:0] valid_from_inp_buff, pop_to_inp_buff;

// Input To/From SA
logic [(OUT_PORTS-NO_RETURNS)-1:0] reqs_per_inp [IN_PORTS-1:0];
logic [(OUT_PORTS-NO_RETURNS)-1:0] grants_per_inp [IN_PORTS-1:0];
logic [(IN_PORTS-NO_RETURNS)-1:0] reqs_per_outp [OUT_PORTS-1:0];
logic [(IN_PORTS-NO_RETURNS)-1:0] grants_per_outp [OUT_PORTS-1:0];
logic [OUT_PORTS-1:0] anygnt_outp;
logic [IN_PORTS-1:0] input_granted;

// Outp state
logic [OUT_PORTS-1:0] outp_avail, outp_ready;
logic [(OUT_PORTS-NO_RETURNS)-1:0] outp_avail_to_inp [IN_PORTS-1:0];
logic [(OUT_PORTS-NO_RETURNS)-1:0] outp_ready_to_inp [IN_PORTS-1:0];

// Data to switch
logic [FLIT_WIDTH-1:0] data_from_inps [IN_PORTS-1:0];
logic [(IN_PORTS-NO_RETURNS)*FLIT_WIDTH-1:0] data_to_switch [OUT_PORTS-1:0];

// To outp buff
logic [FLIT_WIDTH-1:0] data_to_outp [OUT_PORTS-1:0];
logic [OUT_PORTS-1:0] valid_to_outp;
logic [FLIT_WIDTH-1:0] data_out_tmp [OUT_PORTS-1:0];

genvar i, j;
generate
    //////////////////////////
    ///   For each Input   ///
    //////////////////////////
   for(i=0; i < IN_PORTS; i=i+1) begin: for_inp
      assign data_to_inps[i] = data_in[(i+1)*FLIT_WIDTH-1 : i*FLIT_WIDTH];
      // Input Buffering (receiver)
      flow_control_receiver #(
      .LINK_WIDTH          (FLIT_WIDTH),
	  .FC_RCV_PARAMS		(INP_FC_PARAMS))
      // .LINK_FLOW_CONTROL   (INP_FC_PARAMS[0]),//.FC_TYPE),
      // .BUFF_DEPTH          (INP_FC_PARAMS[1]),//.BUFF_DEPTH),
      // .POP_CHECK_VALID     (INP_FC_PARAMS[2]),//.POP_CHECK_VALID),
      // .REG_CR_UPD          (INP_FC_PARAMS[3]),//.CR_REG_CR_UPD),
      // .PUSH_CHECK_READY    (INP_FC_PARAMS[4]))//.RV_PUSH_CHECK_READY))
      inp_buf(
      .clk          (clk),
      .rst          (rst),
      .data_in      (data_to_inps[i]),
      .valid_in     (valid_in[i]),
      .back_notify  (back_notify[i]),
      .data_out     (data_from_inp_buff[i]),
      .valid_out    (valid_from_inp_buff[i]),
      .ready_in     (pop_to_inp_buff[i])
      );
      // Input Controller
      rtr_inp_logic #(
      .FLIT_WIDTH      (FLIT_WIDTH),
      .NODE_ID         (NODE_ID),
      .MY_INP_ID       (i),
      .DST_PNT         (DST_PNT),
      .DST_ADDR_WIDTH  (DST_ADDR_WIDTH),
      .RC_ALGO         (RC_ALGO),
      .OUT_PORTS       (OUT_PORTS),
      .NO_RETURNS      (NO_RETURNS))
      inp_contr(
      .clk             (clk),
      .rst             (rst),
      .data_in         (data_from_inp_buff[i]),
      .valid_in        (valid_from_inp_buff[i]),
      .back_pop        (pop_to_inp_buff[i]),
      .sa_req          (reqs_per_inp[i]),
      .sa_grant        (input_granted[i]),
      .ready_outps     (outp_ready_to_inp[i]),
      .avail_outps     (outp_avail_to_inp[i]),
      .data_out        (data_from_inps[i])
      );
      
      // Onehot Check
      assign input_granted[i] = |grants_per_inp[i];
   end

///////////////////////////
///   For each Output   ///
///////////////////////////

//generate
   for(j=0; j < OUT_PORTS; j=j+1) begin: for_outp
      rtr_out_logic #(
      .IN_PORTS      (IN_PORTS),
      .FLIT_WIDTH    (FLIT_WIDTH),
      .NO_RETURNS    (NO_RETURNS))
      outp_contr(
      .clk           (clk),
      .rst           (rst),
      .outp_avail    (outp_avail[j]),
      .sa_reqs       (reqs_per_outp[j]),
      .sa_grants     (grants_per_outp[j]),
      .data_in       (data_to_switch[j]),
      .data_out      (data_to_outp[j]),
      .valid_out     (valid_to_outp[j])
      );
      
      flow_control_sender #(
      .LINK_WIDTH         (FLIT_WIDTH),
	  .FC_SND_PARAMS	  (OUT_FC_PARAMS))
      // .LINK_FLOW_CONTROL  (OUT_FC_PARAMS[0]),//.FC_TYPE),
      // .PUSH_CHECK_READY   (OUT_FC_PARAMS[1]),//.PUSH_CHECK_READY),
      // .CRFC_MAX_CREDITS   (OUT_FC_PARAMS[2]),//.CR_MAX_CREDITS),
      // .CRFC_REG_DATA      (OUT_FC_PARAMS[3]),//.CR_REG_DATA),
      // .CRFC_REG_CR_UPD    (OUT_FC_PARAMS[4]),//.CR_REG_CR_UPD),
      // .CRFC_USE_INCR      (OUT_FC_PARAMS[5]),//.CR_USE_INCR),
      // .RVFC_BUFF_DEPTH    (OUT_FC_PARAMS[6]))//.RV_BUFF_DEPTH))
      outp_buf (
      .clk                (clk),
      .rst                (rst),
      .data_in            (data_to_outp[j]),
      .valid_in           (valid_to_outp[j]),
      .ready_out          (outp_ready[j]),
      .data_out           (data_out_tmp[j]),
      .valid_out          (valid_out[j]),
      .front_notify       (front_notify[j])
      );
      
      assign data_out[(j+1)*FLIT_WIDTH-1 : j*FLIT_WIDTH] = data_out_tmp[j];
   end


//////////////////
///   Wiring   ///
//////////////////

//generate
    for(i=0; i < IN_PORTS; i=i+1) begin: wire_i
        for(j=0; j < OUT_PORTS; j=j+1) begin: wire_j
            if (!NO_RETURNS) begin: rets
                assign reqs_per_outp[j][i] = reqs_per_inp[i][j];
                assign grants_per_inp[i][j] = grants_per_outp[j][i];
                assign outp_ready_to_inp[i][j] = outp_ready[j];
                assign outp_avail_to_inp[i][j] = outp_avail[j];
                assign data_to_switch[j][(i+1)*FLIT_WIDTH-1 : i*FLIT_WIDTH] = data_from_inps[i];
            end else begin: no_rets
                if (i < j) begin
                    assign reqs_per_outp[j][i] = reqs_per_inp[i][j-1];
                    assign grants_per_inp[i][j-1] = grants_per_outp[j][i];
                    assign outp_ready_to_inp[i][j-1] = outp_ready[j];
                    assign outp_avail_to_inp[i][j-1] = outp_avail[j];
                    assign data_to_switch[j][(i+1)*FLIT_WIDTH-1 : i*FLIT_WIDTH] = data_from_inps[i];
                end else if (i > j) begin
                    assign reqs_per_outp[j][i-1] = reqs_per_inp[i][j];
                    assign grants_per_inp[i][j] = grants_per_outp[j][i-1];
                    assign outp_ready_to_inp[i][j] = outp_ready[j];
                    assign outp_avail_to_inp[i][j] = outp_avail[j];
                    assign data_to_switch[j][i*FLIT_WIDTH-1 : (i-1)*FLIT_WIDTH] = data_from_inps[i];
                end
            end
        end
    end
endgenerate

endmodule
