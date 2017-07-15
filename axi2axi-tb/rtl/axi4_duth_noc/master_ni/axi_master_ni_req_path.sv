/** 
 * @info Request Path of the Master NI
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief The request path of the Master NI contains only the depacketizer of the response transactions.
 *        Depending on the maximum tolerated link width passed (as a param), the flit width, number of 
 *        flits per transaction etc. is calculated to match the other side's flit parameters and the
 *        the proper deserialization is performed (if required).
 *
 * @param SLAVE_ID specifies the ID of the External Slave, attached to the Master NI
 * @param TIDS_M specifies the number of AXI Transaction IDs at the External Master Side
 * @param ADDRESS_WIDTH specifies the address filed width of the transactions (AxADDR)
 * @param DATA_LANES specifies the number of byte lanes of the Write Data channel (W)
 * @param USER_WIDTH specifies the width of the US field of the AXI channels
 * @param EXT_MASTERS specifies the number of the system's External Masters
 * @param EXT_SLAVES specifies the number of External AXI Slave
 * @param MAX_LINK_WIDTH_REQ specifies the maximum tolerated link width of the NoC request path (@see axi_master_ni_req_path)
 * @param FLIT_WIDTH_REQ_C specifies the width of the request flit.
 */

import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;


module axi_master_ni_req_path
  #(parameter int SLAVE_ID              = 0,
    parameter int TIDS_M                = 16,
    parameter int ADDRESS_WIDTH         = 32,
    parameter int DATA_LANES            = 4,
    parameter int USER_WIDTH            = 2,
    parameter int EXT_MASTERS           = 4,
    parameter int EXT_SLAVES            = 2,
    parameter int MAX_LINK_WIDTH_REQ    = 128,
    parameter int FLIT_WIDTH_REQ_C      = 128)
   (input logic clk,
    input logic rst,
    ///   Input NoC Channel   ///
    input logic[FLIT_WIDTH_REQ_C-1 :0] inp_chan,
    input logic inp_valid,
    output logic inp_ready,
    ///   Output AXI Channels   ///
    // Write Address
    output logic[log2c_1if1(TIDS_M) + $clog2(EXT_MASTERS) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS-1 : 0] aw_chan,
    output logic aw_valid,
    input logic aw_ready,
    // Write Data
    output logic[log2c_1if1(TIDS_M) + $clog2(EXT_MASTERS) + 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST-1 : 0] w_chan,
    output logic w_valid,
    input logic w_ready,
    // Read Address
    output logic[log2c_1if1(TIDS_M) + $clog2(EXT_MASTERS)  + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS-1 : 0] ar_chan,
    output logic ar_valid,
    input logic ar_ready);
    
// Master Side Channel Widths (incoming)
localparam integer AXI_W_M_AWR  = log2c_1if1(TIDS_M) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS;
localparam integer AXI_W_M_W    = log2c_1if1(TIDS_M) + 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST;
// Slave Side Channel Widths (outgoing)
localparam integer AXI_W_S_AWR  = log2c_1if1(TIDS_M) + $clog2(EXT_MASTERS) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS;
localparam integer AXI_W_S_W    = log2c_1if1(TIDS_M) + $clog2(EXT_MASTERS) + 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST;
// Headers
localparam integer W_HEADER_FULL    = log2c(TIDS_M) + $clog2(EXT_SLAVES) + $clog2(EXT_MASTERS) + 1 + 1 + FLIT_FIELD_WIDTH;
localparam integer W_HEADER_SMALL   = 1 + 1 + FLIT_FIELD_WIDTH;
// Serialization & Width params for packetizing AXI
// ADDR
localparam integer ADDR_PENALTY = get_addr_penalty(MAX_LINK_WIDTH_REQ,          AXI_W_M_AWR - log2c_1if1(TIDS_M), AXI_W_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FW_ADDR      = get_addr_flit_width_first(MAX_LINK_WIDTH_REQ, AXI_W_M_AWR - log2c_1if1(TIDS_M), AXI_W_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL);
// DATA
localparam integer FLITS_PER_DATA = get_flits_per_data(MAX_LINK_WIDTH_REQ, AXI_W_M_AWR - log2c_1if1(TIDS_M), AXI_W_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FW_DATA = get_data_flit_width_first(MAX_LINK_WIDTH_REQ, AXI_W_M_AWR - log2c_1if1(TIDS_M), AXI_W_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FW_REQ = get_max2(FW_ADDR, FW_DATA);

// Current transaction info
logic op_from_header, op_current_w, op_current_r;

logic[log2c_1if1(TIDS_M) - 1 : 0] tid_now, tid_stored, tid_for_data;
logic[log2c_1if1(EXT_MASTERS) - 1 : 0] src_now, src_stored, src_for_data;
    
logic[AXI_W_S_AWR-1 : 0] addr_chan;
logic[AXI_W_S_W-1 : 0] data_chan;
logic WLAST;
    
logic aw_valid_TMP, w_valid_TMP, ar_valid_TMP;
    
// logic[AXI_SPECS_WIDTH_LEN-1 : 0] DBG_TMP_LEN, DBG_TMP_LEN_STORED;

assign WLAST = data_chan[log2c_1if1(TIDS_M) + $clog2(EXT_MASTERS) + 9*DATA_LANES];
// Active Operation state
assign op_current_w = ~(op_from_header);
assign op_current_r = op_from_header;

// Channel Outputs
assign aw_chan = addr_chan;
assign w_chan = data_chan;
assign ar_chan = addr_chan;

// Stored info & state
logic address_passed, reset_addr_state, set_addr_state;
always_ff @ (posedge clk, posedge rst)
    if (rst)
        address_passed <= 0;
    else
        if (reset_addr_state)
            address_passed <= 0;
        else if (set_addr_state) begin
            address_passed <= 1;
            src_stored <= src_now;
            tid_stored <= tid_now;
            // DBG_TMP_LEN_STORED <= DBG_TMP_LEN;
        end



// pragma synthesis_off
// pragma translate_off
`ifdef NI_VERBOSE
	initial begin
		forever begin
		    @(posedge clk);
		    if (ar_valid & ar_ready) begin
		        automatic logic[ADDRESS_WIDTH-1:0]      addr_TMP = ar_chan[log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) +: ADDRESS_WIDTH];
		        automatic logic[log2c_1if1(TIDS_M)-1:0] tid_TMP1 = ar_chan[0 +: log2c_1if1(TIDS_M)];
		        automatic logic[log2c_1if1(TIDS_M)-1:0] tid_TMP2 = inp_chan[FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)];
		        automatic logic[log2c_1if1(TIDS_M)-1:0] tid_TMP3 = inp_chan[FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)];
		        automatic logic[log2c_1if1(TIDS_M)-1:0] tid_TMP4 = tid_now;
		        automatic int src_TMP;
		        if (EXT_MASTERS > 1) begin
		            src_TMP = int'(ar_chan[log2c_1if1(TIDS_M) +: log2c_1if1(EXT_MASTERS)]);
		        end else begin
		            src_TMP = 0;
		        end
		        
		        $display("%0t: NoC >>> M_NI[%0d] AR=%0h T=%0d(%0d-%0d-%0d) M=%0d (addr_passed=%0b)", $time, SLAVE_ID, addr_TMP, tid_TMP1, tid_TMP2, tid_TMP3, tid_TMP4, src_TMP, address_passed);
		    end
		    
		    if (aw_valid & aw_ready) begin
		        automatic logic[ADDRESS_WIDTH-1:0]      addr_TMP = aw_chan[log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) +: ADDRESS_WIDTH];
		        automatic logic[log2c_1if1(TIDS_M)-1:0] tid_TMP1 = aw_chan[0 +: log2c_1if1(TIDS_M)];
		        automatic logic[log2c_1if1(TIDS_M)-1:0] tid_TMP2 = inp_chan[FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)];
		        automatic logic[log2c_1if1(TIDS_M)-1:0] tid_TMP3 = inp_chan[FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)];
		        automatic logic[log2c_1if1(TIDS_M)-1:0] tid_TMP4 = tid_now;
		        automatic int src_TMP;
		        if (EXT_MASTERS > 1) begin
		            src_TMP = int'(aw_chan[log2c_1if1(TIDS_M) +: log2c_1if1(EXT_MASTERS)]);
		        end else begin
		            src_TMP = 0;
		        end
		        $display("%0t: NoC >>> M_NI[%0d] AW=%0h T=%0d(%0d-%0d-%0d) M=%0d (addr_passed=%0b)", $time, SLAVE_ID, addr_TMP, tid_TMP1, tid_TMP2, tid_TMP3, tid_TMP4, src_TMP, address_passed);
		    end
		end
	end
`endif
// pragma translate_on
// pragma synthesis_on







        
genvar i;
generate
    if (ADDR_PENALTY == 0) begin
        logic first_data_passed; // reset when transaction is flushed - activated when the first data pack leaves
        logic flushing_transaction_w;
        assign flushing_transaction_w = inp_valid & op_current_w &
                                            ( (~address_passed & ~first_data_passed & aw_ready & w_ready & WLAST) |
                                              (~address_passed &  first_data_passed & aw_ready &           WLAST) |
                                              ( address_passed &                                 w_ready & WLAST));
        // Valid Outputs
        assign aw_valid = inp_valid & op_current_w & ~address_passed;
        assign w_valid  = inp_valid & op_current_w & (address_passed | ~first_data_passed);
        assign ar_valid = inp_valid & op_current_r;

        // input pops:
        //  -> On Write: - both address & data leave at once
        //               - address first, data next
        //               - data first, address next
        //  -> On Read:  - address leaves
        assign inp_ready = (op_current_w & ~address_passed & ~first_data_passed) ? aw_ready & w_ready :
                           (op_current_w & ~address_passed &  first_data_passed) ? aw_ready :
                           (op_current_w &  address_passed                     ) ? w_ready  : 
                                                                                   ar_ready;
        
        assign addr_chan = EXT_MASTERS > 1 ? {inp_chan[W_HEADER_FULL +: AXI_W_M_AWR - log2c_1if1(TIDS_M)], src_now, tid_now} :
                                             {inp_chan[W_HEADER_FULL +: AXI_W_M_AWR - log2c_1if1(TIDS_M)],          tid_now};
        assign data_chan = EXT_MASTERS > 1 ? {inp_chan[W_HEADER_FULL +  AXI_W_M_AWR - log2c_1if1(TIDS_M) +: AXI_W_M_W - log2c_1if1(TIDS_M)], src_for_data, tid_for_data} :
                                             {inp_chan[W_HEADER_FULL +  AXI_W_M_AWR - log2c_1if1(TIDS_M) +: AXI_W_M_W - log2c_1if1(TIDS_M)],               tid_for_data};
        assign src_now   = EXT_MASTERS > 1 ? inp_chan[FLIT_FIELD_WIDTH+1 +: log2c_1if1(EXT_MASTERS)] :
                                             1'b0;
        // Concatenate Address & Data
        // if (EXT_MASTERS > 1) begin
            // assign addr_chan = {inp_chan[W_HEADER_FULL +: AXI_W_M_AWR - log2c_1if1(TIDS_M)], src_now, tid_now};
            // assign data_chan = {inp_chan[W_HEADER_FULL +  AXI_W_M_AWR - log2c_1if1(TIDS_M) +: AXI_W_M_W - log2c_1if1(TIDS_M)], src_for_data, tid_for_data};
            // assign src_now = inp_chan[FLIT_FIELD_WIDTH+1+1 +: log2c_1if1(EXT_MASTERS)];
        // end else begin
            // assign addr_chan = {inp_chan[W_HEADER_FULL +: AXI_W_M_AWR - log2c_1if1(TIDS_M)],          tid_now};
            // assign data_chan = {inp_chan[W_HEADER_FULL +  AXI_W_M_AWR - log2c_1if1(TIDS_M) +: AXI_W_M_W - log2c_1if1(TIDS_M)],               tid_for_data};
        // end
        // assign addr_chan = EXT_MASTERS > 1 ? {inp_chan[W_HEADER_FULL + AXI_W_M_AWR - $clog2(TIDS_M) - 1 : W_HEADER_FULL], src_now, tid_now} :
                                             // {inp_chan[W_HEADER_FULL + AXI_W_M_AWR - $clog2(TIDS_M) - 1 : W_HEADER_FULL],          tid_now};
        // assign data_chan = EXT_MASTERS > 1 ? {inp_chan[W_HEADER_FULL + AXI_W_M_AWR - $clog2(TIDS_M) + AXI_W_M_W - $clog2(TIDS_M) - 1 : W_HEADER_FULL + AXI_W_M_AWR - $clog2(TIDS_M)], src_for_data, tid_for_data} :
                                             // {inp_chan[W_HEADER_FULL + AXI_W_M_AWR - $clog2(TIDS_M) + AXI_W_M_W - $clog2(TIDS_M) - 1 : W_HEADER_FULL + AXI_W_M_AWR - $clog2(TIDS_M)],               tid_for_data};
        assign src_for_data = (!address_passed) ? src_now : src_stored;
        assign tid_for_data = (!address_passed) ? tid_now : tid_stored;
        assign op_from_header = inp_chan[FLIT_FIELD_WIDTH];

        assign reset_addr_state = flushing_transaction_w; // inp_valid & w_ready & op_current_w & WLAST;
        assign set_addr_state = inp_valid & op_current_w & ~address_passed & aw_ready;

        assign tid_now = TIDS_M > 1 ? inp_chan[FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)] :
                                      1'b0;
        // if (TIDS_M > 1) begin
            // assign tid_now = inp_chan[FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) + log2c(TIDS_M)-1 : FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES)];
            // assign tid_now = inp_chan[FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)]; //-1 : FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES)];
        // end else begin
            // assign tid_now = 1'b0;
        // end

        // Used to track if the data on the head flit has been consumed or not (check inp_ready)
        always_ff @ (posedge clk, posedge rst) begin: more_state
            if (rst) begin
                first_data_passed <= 1'b0;
            end else begin
                if (flushing_transaction_w)
                    first_data_passed <= 1'b0;
                else if (!first_data_passed && w_valid && w_ready)
                    first_data_passed <= 1'b1;
            end
        end
    
    end else begin
        // ADDR_PENALTY > 0
        localparam integer SER_MAX_COUNT = get_max2(ADDR_PENALTY, FLITS_PER_DATA);
        localparam integer FW_ADDR_PAD_LAST = get_addr_flit_pad_last(FW_REQ, AXI_W_M_AWR - log2c_1if1(TIDS_M), AXI_W_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
        localparam integer FW_DATA_PAD_LAST = get_data_flit_pad_last(FW_REQ, AXI_W_M_AWR - log2c_1if1(TIDS_M), AXI_W_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);

        logic deser_cnt_sel;
        logic[ADDR_PENALTY*FW_REQ-1 : 0] data_from_ser_addr;
        logic[FLITS_PER_DATA*FW_REQ-1 : 0] data_from_ser_data;
        logic valid_from_ser, ready_to_ser;

        logic[FW_REQ-1 : 0] addr_flits [ADDR_PENALTY-1 : 0];
        logic[FW_REQ-1 : 0] data_flits [FLITS_PER_DATA-1 : 0];

        logic[AXI_W_M_AWR - log2c_1if1(TIDS_M) - 1 : 0] addr_chan_no_tid;
        logic[AXI_W_M_W - log2c_1if1(TIDS_M) - 1  : 0] data_chan_no_tid;

        assign op_from_header = data_from_ser_addr[FLIT_FIELD_WIDTH];
        assign deser_cnt_sel = address_passed;
      
        deser_shared2 #(.SER_WIDTH    (FW_REQ),
                        .COUNT_0      (ADDR_PENALTY),
                        .COUNT_1      (FLITS_PER_DATA)) 
        deser_both(.clk               (clk), 
                   .rst               (rst),
                   .count_sel         (deser_cnt_sel),
                   .serial_in         (inp_chan),
                   .valid_in          (inp_valid),
                   .ready_out         (inp_ready),
                   .parallel_out_0    (data_from_ser_addr),
                   .parallel_out_1    (data_from_ser_data),
                   .valid_out         (valid_from_ser),
                   .ready_in          (ready_to_ser));
                 
        assign ready_to_ser = (!address_passed && op_current_w) ? aw_ready :
                              (address_passed && op_current_w)  ? w_ready  :
                                                                  ar_ready;

        for (i=0; i < ADDR_PENALTY; i++) begin: for_i
            assign addr_flits[i] = data_from_ser_addr[(i+1)*FW_REQ-1 : i*FW_REQ];
		  end
        
        for(i=0; i < FLITS_PER_DATA; i++) begin: for_i2
            assign data_flits[i] = data_from_ser_data[(i+1)*FW_REQ-1 : i*FW_REQ];
		  end
        
        
        // First flit of ADDR
        assign addr_chan_no_tid[FW_ADDR-W_HEADER_FULL-1 : 0] = addr_flits[0][FW_ADDR-1 : W_HEADER_FULL];
        // Rest flits of ADDR
        for(i=1; i < ADDR_PENALTY; i++) begin: for_i3
            if (i == (ADDR_PENALTY-1)) // Last
                assign addr_chan_no_tid[FW_REQ-W_HEADER_FULL + (i-1)*(FW_REQ-W_HEADER_SMALL) + (FW_REQ-W_HEADER_SMALL-FW_ADDR_PAD_LAST)-1 :
                                        FW_REQ-W_HEADER_FULL + (i-1)*(FW_REQ-W_HEADER_SMALL)] = 
                    addr_flits[i][FW_REQ-FW_ADDR_PAD_LAST-1 : W_HEADER_SMALL];
            else   
                assign addr_chan_no_tid[FW_REQ-W_HEADER_FULL + i*(FW_REQ-W_HEADER_SMALL)-1 : FW_REQ-W_HEADER_FULL + (i-1)*(FW_REQ-W_HEADER_SMALL)] = 
                    addr_flits[i][FW_REQ-1 : W_HEADER_SMALL];
        end
        
        if (EXT_MASTERS > 1) begin
            assign addr_chan = {addr_chan_no_tid, src_now, tid_now};
            assign data_chan = {data_chan_no_tid, src_stored, tid_stored};
            assign src_now = data_from_ser_addr[FLIT_FIELD_WIDTH+1 +: $clog2(EXT_MASTERS)];
        end else begin
            assign addr_chan = {addr_chan_no_tid,          tid_now};
            assign data_chan = {data_chan_no_tid,             tid_stored};
        end
        
        // All flits of DATA
        for(i=0; i < FLITS_PER_DATA; i++) begin: for_i4
            if (i == (FLITS_PER_DATA-1)) // Last
                assign data_chan_no_tid[ i*(FW_REQ-W_HEADER_SMALL) + (FW_REQ-W_HEADER_SMALL-FW_DATA_PAD_LAST) - 1 : i*(FW_REQ-W_HEADER_SMALL) ] =
                    data_flits[i][FW_REQ-FW_DATA_PAD_LAST-1 : W_HEADER_SMALL];            
            else
                assign data_chan_no_tid[ (i+1)*(FW_REQ-W_HEADER_SMALL)-1 : i*(FW_REQ-W_HEADER_SMALL) ] = data_flits[i][FW_REQ-1 : W_HEADER_SMALL];
        end
        
        // assign data_chan = EXT_MASTERS > 1 ? {data_chan_no_tid, src_stored, tid_stored} :
                                             // {data_chan_no_tid, tid_stored};
        if (TIDS_M > 1) begin
            // assign tid_now = data_from_ser_addr[FLIT_FIELD_WIDTH+1+1+log2c(EXT_MASTERS)+log2c(EXT_SLAVES)+log2c(TIDS_M)-1 : FLIT_FIELD_WIDTH+1+1+$clog2(EXT_MASTERS)+$clog2(EXT_SLAVES)];
            assign tid_now = data_from_ser_addr[FLIT_FIELD_WIDTH+1+log2c(EXT_MASTERS)+log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)];
        end else begin
            assign tid_now = 1'b0;
        end
        // assign src_now = EXT_MASTERS > 1 ? data_from_ser_addr[FLIT_FIELD_WIDTH+1+1 +: $clog2(EXT_MASTERS)] : 0;
        assign reset_addr_state = valid_from_ser & op_current_w & address_passed & WLAST & w_ready;
        assign set_addr_state = valid_from_ser & op_current_w & ~address_passed & aw_ready;

        // Valid Outputs
        assign aw_valid = valid_from_ser & op_current_w & ~address_passed;
        assign w_valid = valid_from_ser & op_current_w & address_passed;
        assign ar_valid = valid_from_ser & op_current_r;

        assign aw_valid_TMP = valid_from_ser & op_current_w & ~address_passed;
        assign w_valid_TMP = valid_from_ser & op_current_w & address_passed;
        assign ar_valid_TMP = valid_from_ser & op_current_r;
    end
endgenerate

int s_dst;
if (EXT_SLAVES > 1) begin
    assign s_dst = EXT_SLAVES > 1 ? int'(inp_chan[FLIT_FIELD_WIDTH+1+log2c(EXT_MASTERS) +: log2c_1if1(EXT_SLAVES)]) : 0;
    assert property (@(posedge clk) disable iff(rst) (inp_valid && flit_is_head(inp_chan) && EXT_SLAVES > 1) |-> s_dst == SLAVE_ID) else
        $fatal(1, "[Req NI at Slave] Received flit NOT destined for me!");
end

// assert property (@(posedge clk) disable iff(rst) inp_valid |-> inp_chan[FLIT_FIELD_WIDTH+1] == KIND_ID_REQ) else
    // $fatal(1, "[Req NI at Slave] Received a non-REQUEST flit!!!");

endmodule
