/** 
 * @info Slave NI
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief The Slave NI contains:
 *        (a) Buffers for AXI AW, W, B and R channels (removed appropriately if Write or Read channels are not present)
 *        (b) Request path, which is followed by transactions, before entering the NoC (@see axi_slave_ni_req_path)
 *        (c) Response path, which is followed by returning response transactions of B and R channels
 *            at the other side (@see axi_slave_ni_resp_path)
 *        (d) The reordering unit, which is controlled by both request and response transactions (@see axi_reordering_unit)
 *
 * @param MASTER_ID specifies the ID of the External Master, attached to the Slave NI
 * @param TIDS_M specifies the number of AXI Transaction IDs
 * @param ADDRESS_WIDTH specifies the address filed width of the transactions (AxADDR)
 * @param DATA_LANES specifies the number of byte lanes of the Write Data channel (W)
 * @param USER_WIDTH specifies the width of the US field of the AXI channels
 * @param EXT_MASTERS specifies the number of the system's External Masters
 * @param EXT_SLAVES specifies the number of External AXI Slave
 * @param HAS_WRITE specifies if the NI serves Write Requests (simplifies unit if it doesn't)
 * @param HAS_READ specifies if the NI serves Read Requests (simplifies unit if it doesn't)
 * @param MAX_LINK_WIDTH_REQ specifies the maximum tolerated link width of the NoC request path (@see axi_req_packetizer)
 * @param MAX_LINK_WIDTH_RESP specifies the maximum tolerated link width of the NoC response path (@see axi_slave_ni_resp_path)
 * @param MAX_PENDING_SAME_DST specifies the maximum number of transactions that are allowed to be in-flight for a single destination.
 * @param ADDRS_LO specifies the lower address bound served by each slave. (@see axi_address_lut)
 *        The lower address bound of Slave[i] should be found in ADDRS_LO[(i+1)*ADDRESS_WIDTH-1 : i*ADDRESS_WIDTH]
 * @param ADDRS_HI specifies the higher address bound served by each slave. (@see axi_address_lut)
 *        The higher address bound of Slave[i] should be found in ADDRS_HI[(i+1)*ADDRESS_WIDTH-1 : i*ADDRESS_WIDTH]
 * @param OVERLAPPING_ADDRS specifies if the address ranges between different external Slaves. The reordering operation
 *        changes when==true, in which case load-balancing is also activated.
 * @param AW_FIFO_DEPTH specifies the buffer slots of the AW channel input FIFO buffer
 * @param W_FIFO_DEPTH specifies the buffer slots of the W channel input FIFO buffer
 * @param AR_FIFO_DEPTH specifies the buffer slots of the AR channel input FIFO buffer
 * @param B_FIFO_DEPTH specifies the buffer slots of the B channel output FIFO buffer
 * @param R_FIFO_DEPTH specifies the buffer slots of the R channel output FIFO buffer
 * @param FLIT_WIDTH_REQ_C specifies the width of the request flit. This is redundantly passed here, since it is also found inside the module.
 *        It is used, however, to avoid doing all those calculations on the module's interface
 * @param FLIT_WIDTH_RESP_C specifies the width of the response. This is redundantly passed here, since it is also found inside the module.
 *        It is used, however, to avoid doing all those calculations on the module's interface
 * @param NI_NOC_FC_SND specifies buffering and flow control (@see flow_control_receiver) of the NI->NoC link (request path)
 * @param NOC_NI_FC_RCV specifies buffering and flow control (@see flow_control_sender) of the NoC->NI link (response path)
 */


import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;


module axi_slave_ni
  #(parameter int MASTER_ID 					= 0,
    parameter int TIDS_M 				    	= 16,
    parameter int ADDRESS_WIDTH 				= 32,
    parameter int DATA_LANES 					= 4,
    parameter int USER_WIDTH 					= 2,
    parameter int EXT_MASTERS 					= 4,
    parameter int EXT_SLAVES 					= 2,
    parameter logic HAS_WRITE 					= 1'b1,
    parameter logic HAS_READ 					= 1'b1,
    parameter int MAX_LINK_WIDTH_REQ 			= 128,
    parameter int MAX_LINK_WIDTH_RESP 			= 128,
    parameter int MAX_PENDING_SAME_DST 			= 16,
    // Slave Served Address range
    parameter logic [ADDRESS_WIDTH*EXT_SLAVES-1:0] ADDRS_LO = {ADDRESS_WIDTH*EXT_SLAVES{1'b0}},
    parameter logic [ADDRESS_WIDTH*EXT_SLAVES-1:0] ADDRS_HI = {ADDRESS_WIDTH*EXT_SLAVES{1'b1}},
    parameter logic OVERLAPPING_ADDRS 			= 1'b0,
    // FIFO depths
    parameter int AW_FIFO_DEPTH 			= 2,
    parameter int W_FIFO_DEPTH 				= 2,
    parameter int AR_FIFO_DEPTH 			= 2,
    parameter int B_FIFO_DEPTH 				= 2,
    parameter int R_FIFO_DEPTH 				= 2,
    // Flit widths passed here to avoid recaclulation
    parameter int FLIT_WIDTH_REQ_C 			= 128,
    parameter int FLIT_WIDTH_RESP_C 		= 128,
    parameter link_fc_params_snd_type NI_NOC_FC_SND	= RTR_ELASTIC_FC_SND,
    parameter link_fc_params_rcv_type NOC_NI_FC_RCV	= RTR_ELASTIC_FC_RCV,
    parameter logic ASSERT_RV               = 1'b0)
   (input logic clk,
    input logic rst,
    ///   Master Side   ///
    // Write Address
    input logic[log2c_1if1(TIDS_M) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS-1 : 0] aw_chan,
    input logic aw_valid,
    output logic aw_ready,
    // Write Data
    input logic[log2c_1if1(TIDS_M) + 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST-1 : 0] w_chan,
    input logic w_valid,
    output logic w_ready,
    // Read Address
    input logic[log2c_1if1(TIDS_M) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS-1 : 0 ] ar_chan,
    input logic ar_valid,
    output logic ar_ready,
    // Write Response
    output logic[log2c_1if1(TIDS_M) +  USER_WIDTH + AXI_SPECS_WIDTH_RESP-1 : 0] b_chan,
    output logic b_valid,
    input logic b_ready,
    // Read Data
    output logic[log2c_1if1(TIDS_M) + 8*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_RESP + AXI_SPECS_WIDTH_LAST-1 : 0] r_chan,
    output logic r_valid,
    input logic r_ready,
    ///   NoC Side   ///
    // Req flits -> NoC
    output logic[FLIT_WIDTH_REQ_C-1 : 0] req_flit_to_noc,
    output logic req_valid_to_noc,
    input logic req_ready_from_noc,
    // Resp Flits <- NoC
    input logic[FLIT_WIDTH_RESP_C-1 : 0] resp_flit_from_noc,
    input logic resp_valid_from_noc,
    output logic resp_ready_to_noc);

// pragma synthesis_off
// pragma translate_off
initial begin
    $display("FIFOs @ Slave NI %0d (AW, W, B, AR, R: %0d %0d %0d %0d %0d)", MASTER_ID, AW_FIFO_DEPTH, W_FIFO_DEPTH, B_FIFO_DEPTH, AR_FIFO_DEPTH, R_FIFO_DEPTH);
end
// pragma synthesis_on
// pragma translate_on


// Local Parameters
localparam integer AXI_W_AWR_M = log2c_1if1(TIDS_M) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS;
localparam integer AXI_W_W_M   = log2c_1if1(TIDS_M) + 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST;
localparam integer AXI_W_B_M   = log2c_1if1(TIDS_M) + USER_WIDTH + AXI_SPECS_WIDTH_RESP;
localparam integer AXI_W_R_M   = log2c_1if1(TIDS_M) + 8*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_RESP + AXI_SPECS_WIDTH_LAST;

// Ready/Valid monitoring
// AW
rv_handshake_checker
        #(  .DATA_WIDTH (AXI_W_AWR_M-USER_WIDTH),
            .ASSERT_EN  (ASSERT_RV))
    rv_mon_aw
        (   .clk    (clk),
            .rst    (rst),
            .data   (aw_chan[AXI_W_AWR_M-USER_WIDTH-1:0]),
            .valid  (aw_valid),
            .ready  (aw_ready));
// W
rv_handshake_checker
        #(  .DATA_WIDTH (AXI_W_W_M-USER_WIDTH),
            .ASSERT_EN  (ASSERT_RV))
    rv_mon_w
        (   .clk    (clk),
            .rst    (rst),
            .data   (w_chan[AXI_W_W_M-USER_WIDTH-1:0]),
            .valid  (w_valid),
            .ready  (w_ready));
// AR
rv_handshake_checker
        #(  .DATA_WIDTH (AXI_W_AWR_M-USER_WIDTH),
            .ASSERT_EN  (ASSERT_RV))
    rv_mon_ar
        (   .clk    (clk),
            .rst    (rst),
            .data   (ar_chan[AXI_W_AWR_M-USER_WIDTH-1:0]),
            .valid  (ar_valid),
            .ready  (ar_ready));
// B
rv_handshake_checker
        #(  .DATA_WIDTH (AXI_W_B_M-USER_WIDTH),
            .ASSERT_EN  (ASSERT_RV))
    rv_mon_b
        (   .clk    (clk),
            .rst    (rst),
            .data   (b_chan[AXI_W_B_M-USER_WIDTH-1:0]),
            .valid  (b_valid),
            .ready  (b_ready));
// R
rv_handshake_checker
        #(  .DATA_WIDTH (AXI_W_R_M-USER_WIDTH),
            .ASSERT_EN  (ASSERT_RV))
    rv_mon_r
        (   .clk    (clk),
            .rst    (rst),
            .data   (r_chan[AXI_W_R_M-USER_WIDTH-1:0]),
            .valid  (r_valid),
            .ready  (r_ready));

// Serialization & Width params for packetizing AXI
localparam integer W_HEADER_FULL    = log2c(TIDS_M) + log2c(EXT_SLAVES) + log2c(EXT_MASTERS) + 1 + 1 + FLIT_FIELD_WIDTH;
localparam integer W_HEADER_SMALL   = 1 + 1 + FLIT_FIELD_WIDTH;
// ADDR
localparam integer FLIT_WIDTH_ADDR  = get_addr_flit_width_first(MAX_LINK_WIDTH_REQ, AXI_W_AWR_M - log2c_1if1(TIDS_M), AXI_W_W_M - log2c_1if1(TIDS_M), W_HEADER_FULL);
// DATA
localparam integer FLIT_WIDTH_DATA  = get_data_flit_width_first(MAX_LINK_WIDTH_REQ, AXI_W_AWR_M - log2c_1if1(TIDS_M), AXI_W_W_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
// Overall (maximum of ADDR/DATA)
localparam integer FLIT_WIDTH_REQ   = get_max2(FLIT_WIDTH_ADDR, FLIT_WIDTH_DATA);

localparam integer FW_WRITE_RESP    = get_resp_flit_width_first(MAX_LINK_WIDTH_RESP, AXI_W_B_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FW_READ_RESP     = get_resp_flit_width_first(MAX_LINK_WIDTH_RESP, AXI_W_R_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FLIT_WIDTH_RESP  = get_max2(FW_WRITE_RESP, FW_READ_RESP);

// AXI Channel Input Queues
 // AW
logic[AXI_W_AWR_M-1 : 0] aw_fifo_data;
logic aw_fifo_ready, aw_fifo_valid;
 // W
logic[AXI_W_W_M-1 : 0] w_fifo_data;
logic w_fifo_ready, w_fifo_valid;
 // AR
logic[AXI_W_AWR_M-1 : 0] ar_fifo_data;
logic ar_fifo_ready, ar_fifo_valid;
 // Reorder Unit - Qualification
logic reorder_req_valid;
logic[1:0] reorder_req_wr_sel, reorder_req_valid_wr;
logic[log2c_1if1(TIDS_M)-1 : 0] reorder_req_tid; // bin enc
logic[EXT_SLAVES-1 : 0] reorder_req_avail_dsts;
logic[log2c_1if1(EXT_SLAVES)-1 : 0] reorder_req_dst_from_wr[1:0];
logic[log2c_1if1(EXT_SLAVES)-1 : 0] reorder_req_dst_final;
logic[1:0] reorder_qual_wr_sel; // 1: Read, 0: Write
logic reorder_qualifies;
 // NoC Channel Output Queue
logic[FLIT_WIDTH_REQ-1 : 0] noc_req_fifo_data;
logic noc_req_fifo_valid, noc_req_fifo_ready;
 // NoC Channel Input Queues
logic[FLIT_WIDTH_RESP-1 : 0] noc_resp_fifo_data;
logic noc_resp_fifo_ready, noc_resp_fifo_valid;
 // Reorder Unit - Returns
logic reorder_return_valid;
logic[1:0] reorder_return_wr_sel, reorder_return_valid_wr;
logic[log2c_1if1(TIDS_M)-1 : 0] reorder_return_tid; // bin enc
 // Output Queues
 // B
logic[AXI_W_B_M-1 : 0] b_fifo_data;
logic b_fifo_ready, b_fifo_valid;
 // R
logic[AXI_W_R_M-1 : 0] r_fifo_data;
logic r_fifo_ready, r_fifo_valid;

function logic[log2c_1if1(EXT_SLAVES)-1:0] onehot_to_wbin_dst(logic[EXT_SLAVES-1:0] inp);
    logic[log2c_1if1(EXT_SLAVES)-1:0] ret;
    ret = 0;
    for (int i=0; i<EXT_SLAVES; i++)
        if (inp[i])
            ret = ret | i;
    return ret;
endfunction

// Work-around for tool unsupporting on-the-fly enum assignment
localparam link_fc_params_rcv_type AW_FC_RCV_PARAMS = '{FC_TYPE:FLOW_CONTROL_ELASTIC, BUFF_DEPTH:AW_FIFO_DEPTH, POP_CHECK_VALID:1'b1, CR_REG_CR_UPD:1'b0, RV_PUSH_CHECK_READY:1'b1};
localparam link_fc_params_rcv_type W_FC_RCV_PARAMS  = '{FC_TYPE:FLOW_CONTROL_ELASTIC, BUFF_DEPTH:W_FIFO_DEPTH,  POP_CHECK_VALID:1'b1, CR_REG_CR_UPD:1'b0, RV_PUSH_CHECK_READY:1'b1};
localparam link_fc_params_rcv_type AR_FC_RCV_PARAMS = '{FC_TYPE:FLOW_CONTROL_ELASTIC, BUFF_DEPTH:AR_FIFO_DEPTH, POP_CHECK_VALID:1'b1, CR_REG_CR_UPD:1'b0, RV_PUSH_CHECK_READY:1'b1};
localparam link_fc_params_snd_type B_FC_SND_PARAMS  = '{FC_TYPE:FLOW_CONTROL_ELASTIC, PUSH_CHECK_READY:1'b1, CR_MAX_CREDITS:3, CR_REG_DATA:1'b0, CR_REG_CR_UPD:1'b0, CR_USE_INCR:1'b0, RV_BUFF_DEPTH:B_FIFO_DEPTH};
localparam link_fc_params_snd_type R_FC_SND_PARAMS  = '{FC_TYPE:FLOW_CONTROL_ELASTIC, PUSH_CHECK_READY:1'b1, CR_MAX_CREDITS:3, CR_REG_DATA:1'b0, CR_REG_CR_UPD:1'b0, CR_USE_INCR:1'b0, RV_BUFF_DEPTH:R_FIFO_DEPTH};

///   Request Path   ///
genvar wr;
generate
// AXI Input Buffers
  if (HAS_WRITE) begin: w_buf
    if (AW_FIFO_DEPTH > 0) begin: aw_fc
      // AW
	  flow_control_receiver #(.LINK_WIDTH       (AXI_W_AWR_M),
	                          .FC_RCV_PARAMS    (AW_FC_RCV_PARAMS))
	  inp_buf_axi_aw(.clk              (clk),
                     .rst              (rst),
				     .data_in          (aw_chan),
				     .valid_in         (aw_valid),
				     .back_notify      (aw_ready),
				     .data_out         (aw_fifo_data),
				     .valid_out        (aw_fifo_valid),
				     .ready_in         (aw_fifo_ready));
    end else begin: aw_dum
        assign aw_fifo_data = aw_chan;
        assign aw_fifo_valid = aw_valid;
        assign aw_ready = aw_fifo_ready;
    end

    if (W_FIFO_DEPTH > 0) begin: w_fc
      // W
	  flow_control_receiver #(.LINK_WIDTH         (AXI_W_W_M),
                              .FC_RCV_PARAMS		 (W_FC_RCV_PARAMS))
	  inp_buf_axi_w(.clk              (clk),
                    .rst              (rst),
				    .data_in          (w_chan),
				    .valid_in         (w_valid),
				    .back_notify      (w_ready),
				    .data_out         (w_fifo_data),
				    .valid_out        (w_fifo_valid),
				    .ready_in         (w_fifo_ready));
    end else begin: w_dum
        assign w_fifo_data = w_chan;
        assign w_fifo_valid = w_valid;
        assign w_ready = w_fifo_ready;
    end
  end else begin: w_buf_not
    //NOT HAS_WRITE
	
	  assign aw_ready = 0;
      assign w_ready = 0;
      assign aw_fifo_valid = 0;
      assign w_fifo_valid = 0;
  end
	
  if (HAS_READ) begin: r_buf
    // AR
    if (AR_FIFO_DEPTH > 0) begin: ar_fc
        flow_control_receiver #(.LINK_WIDTH         (AXI_W_AWR_M),
                                .FC_RCV_PARAMS		 (AR_FC_RCV_PARAMS))
        inp_buf_axi_ar(.clk              (clk),
                       .rst              (rst),
                       .data_in          (ar_chan),
                       .valid_in         (ar_valid),
                       .back_notify      (ar_ready),
                       .data_out         (ar_fifo_data),
                       .valid_out        (ar_fifo_valid),
                       .ready_in         (ar_fifo_ready));
    end else begin: ar_dum
        assign ar_fifo_data = ar_chan;
        assign ar_fifo_valid = ar_valid;
        assign ar_ready = ar_fifo_ready;
    end
  end else begin: r_buf_not
    // NOT HAS_READ
	  assign ar_ready = 0;
      assign ar_fifo_valid = 0;
  end

endgenerate
  // Request Path (Master -> NoC)
  axi_slave_ni_req_path #(.MASTER_ID      (MASTER_ID),
                          .TIDS_M         (TIDS_M),
                          .ADDRESS_WIDTH  (ADDRESS_WIDTH),
                          .DATA_LANES     (DATA_LANES),
                          .USER_WIDTH     (USER_WIDTH),
                          .EXT_MASTERS    (EXT_MASTERS),
                          .EXT_SLAVES     (EXT_SLAVES),
                          .HAS_WRITE      (HAS_WRITE),
                          .HAS_READ       (HAS_READ),
                          .ADDRS_LO       (ADDRS_LO),
                          .ADDRS_HI       (ADDRS_HI),
                          .MAX_LINK_WIDTH_REQ (MAX_LINK_WIDTH_REQ),
		    			  .FLIT_WIDTH_C   (FLIT_WIDTH_REQ))
  req_path(.clk                   (clk),
           .rst                   (rst),
           .aw_chan               (aw_fifo_data),
           .aw_valid              (aw_fifo_valid),
           .aw_ready              (aw_fifo_ready),
           .w_chan                (w_fifo_data),
           .w_valid               (w_fifo_valid),
           .w_ready               (w_fifo_ready),
           .ar_chan               (ar_fifo_data),
           .ar_valid              (ar_fifo_valid),
           .ar_ready              (ar_fifo_ready),
           .reorder_req           (reorder_req_valid),
           .reorder_req_op        (reorder_req_wr_sel), 
           .reorder_req_tid       (reorder_req_tid),
           .reorder_req_dst_out   (reorder_req_avail_dsts),
           .reorder_req_dst_in    (reorder_req_dst_final),
           .reorder_qualify_now   (reorder_qualifies),
           .outp_chan             (noc_req_fifo_data),
           .outp_valid            (noc_req_fifo_valid),
           .outp_ready            (noc_req_fifo_ready));
		 
 generate
  // Reorder Unit
  // Mask request to the proper reorder unit of the winner transaction type (write/read)
  // and MUX qualification bit
  if ((HAS_WRITE) && (HAS_READ)) begin: reord_sig_w_r
      assign reorder_qualifies = (reorder_qual_wr_sel[0] & reorder_req_wr_sel[0]) | (reorder_qual_wr_sel[1] & reorder_req_wr_sel[1]);
	  for (wr=0; wr < 2; wr++) begin: for_wr
		  assign reorder_return_valid_wr[wr] = reorder_return_wr_sel[wr] & reorder_return_valid;
          assign reorder_req_valid_wr[wr] = reorder_req_valid & reorder_req_wr_sel[wr];
      end
  end else if ((HAS_WRITE) && (!HAS_READ)) begin: reord_sig_w
      assign reorder_qualifies = reorder_qual_wr_sel[0] & reorder_req_wr_sel[0];
      assign reorder_return_valid_wr[0] = reorder_return_valid;
      assign reorder_req_valid_wr[0] = reorder_req_valid;
  end else if ((!HAS_WRITE) && (HAS_READ)) begin: reord_sig_r
	  assign reorder_qualifies = reorder_qual_wr_sel[1] & reorder_req_wr_sel[1];
      assign reorder_return_valid_wr[1] = reorder_return_valid;
      assign reorder_req_valid_wr[1] = reorder_req_valid;
  end
	
  for (wr=0; wr < 2; wr=wr+1) begin: for_wr
    axi_reordering_unit #(.TRANSACTION_IDS      (TIDS_M),
	                      .EXT_SLAVES           (EXT_SLAVES),
						  .OVERLAPPING_ADDRS    (OVERLAPPING_ADDRS),
						  .MAX_PENDING_SAME_DST (MAX_PENDING_SAME_DST),
                          .MASTER_ID            (MASTER_ID))	
	reord (.clk             (clk),
	       .rst             (rst),
		   .req_valid       (reorder_req_valid_wr[wr]),
		   .req_tid         (reorder_req_tid),
		   .req_avail_dsts  (reorder_req_avail_dsts),
		   .req_qualifies   (reorder_qual_wr_sel[wr]),
		   .req_dst_final   (reorder_req_dst_from_wr[wr]),
		   .resp_valid      (reorder_return_valid_wr[wr]),
		   .resp_tid        (reorder_return_tid));
  end
  
  if (OVERLAPPING_ADDRS) begin: addrs_overlap
     // MUX to get the correct DST
     assign reorder_req_dst_final = ( {log2c_1if1(EXT_SLAVES){reorder_req_wr_sel[0]}} & reorder_req_dst_from_wr[0] ) |
                                    ( {log2c_1if1(EXT_SLAVES){reorder_req_wr_sel[1]}} & reorder_req_dst_from_wr[1]);
	end
  else
    // One destination only - decode it
	assign reorder_req_dst_final = onehot_to_wbin_dst(reorder_req_avail_dsts);

		 
  // NoC Output Buffer
  flow_control_sender #(.LINK_WIDTH         (FLIT_WIDTH_REQ),
						.FC_SND_PARAMS    	(NI_NOC_FC_SND))
  out_buf_noc_req(.clk               (clk),
                  .rst               (rst),
                  .data_in           (noc_req_fifo_data),
                  .valid_in          (noc_req_fifo_valid),
                  .ready_out         (noc_req_fifo_ready),
                  .data_out          (req_flit_to_noc),
                  .valid_out         (req_valid_to_noc),
                  .front_notify      (req_ready_from_noc)); 
 
  ///   Response Path   ///
  // NoC Input Buffer
  flow_control_receiver #(.LINK_WIDTH         (FLIT_WIDTH_RESP),
                          .FC_RCV_PARAMS	  (NOC_NI_FC_RCV))
  inp_buf_noc_resp(.clk              (clk),
                   .rst              (rst),
				   .data_in          (resp_flit_from_noc),
				   .valid_in         (resp_valid_from_noc),
				   .back_notify      (resp_ready_to_noc),
				   .data_out         (noc_resp_fifo_data),
				   .valid_out        (noc_resp_fifo_valid),
				   .ready_in         (noc_resp_fifo_ready));
	
	
  axi_slave_ni_resp_path #(.MASTER_ID       (MASTER_ID),
                           .TIDS_M          (TIDS_M),
                           .DATA_LANES      (DATA_LANES),
	  					   .USER_WIDTH      (USER_WIDTH),
						   .EXT_MASTERS     (EXT_MASTERS),
						   .EXT_SLAVES      (EXT_SLAVES),
						   .MAX_LINK_WIDTH  (MAX_LINK_WIDTH_RESP),
						   .FLIT_WIDTH_C    (FLIT_WIDTH_RESP))
  noc_to_m_ni(.clk                  (clk),
              .rst                  (rst),
              .inp_chan             (noc_resp_fifo_data),
              .inp_valid            (noc_resp_fifo_valid),
              .inp_ready            (noc_resp_fifo_ready),
			  .reorder_return       (reorder_return_valid),
			  .reorder_return_op    (reorder_return_wr_sel),
			  .reorder_return_tid   (reorder_return_tid),
			  .b_chan               (b_fifo_data),
			  .b_valid              (b_fifo_valid),
			  .b_ready              (b_fifo_ready),
			  .r_chan               (r_fifo_data),
			  .r_valid              (r_fifo_valid),
			  .r_ready              (r_fifo_ready));
			
  // Output Buffering
  if (HAS_WRITE)
    if (B_FIFO_DEPTH > 0) begin: b_fc
        // B
        flow_control_sender #(.LINK_WIDTH         (AXI_W_B_M),
                              .FC_SND_PARAMS		  (B_FC_SND_PARAMS))
        outp_buf_axi_b(.clk              (clk),
                       .rst              (rst),
                       .data_in          (b_fifo_data),
                       .valid_in         (b_fifo_valid),
                       .ready_out        (b_fifo_ready),
                       .data_out         (b_chan),
                       .valid_out        (b_valid),
                       .front_notify     (b_ready));
    end else begin: b_dum
        assign b_chan = b_fifo_data;
        assign b_valid = b_fifo_valid;
        assign b_fifo_ready = b_ready;
    end
  else begin
  // NOT HAS_WRITE
	  assign b_fifo_ready = 0;
	  assign b_valid = 0;
  end
	
  if (HAS_READ)
    // R
      if (R_FIFO_DEPTH > 0) begin: r_fc
          flow_control_sender #(.LINK_WIDTH         (AXI_W_R_M),
                                .FC_SND_PARAMS		(R_FC_SND_PARAMS))
            outp_buf_axi_r(.clk              (clk),
                           .rst              (rst),
                           .data_in          (r_fifo_data),
                           .valid_in         (r_fifo_valid),
                           .ready_out        (r_fifo_ready),
                           .data_out         (r_chan),
                           .valid_out        (r_valid),
                           .front_notify     (r_ready));
      end else begin: r_dum
        assign r_chan = r_fifo_data;
        assign r_valid = r_fifo_valid;
        assign r_fifo_ready = r_ready;
      end
  else begin
  // NOT HAS_READ
	  assign r_fifo_ready = 0;
	  assign r_valid = 0;
	end
	
endgenerate				 
				 
endmodule
