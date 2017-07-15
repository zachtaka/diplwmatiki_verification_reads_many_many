/** 
 * @info AXI Response Packetizer (Master NI)
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Packetizes response transactions according to the provided max tolerated link width.
 *
 * @param SLAVE_ID specifies the ID of the External Slave, attached to the Master NI
 * @param TIDS_M specifies the number of AXI Transaction IDs at the External Master Side
 * @param ADDRESS_WIDTH specifies the address filed width of the transactions (AxADDR)
 * @param DATA_LANES specifies the number of byte lanes of the Write Data channel (W)
 * @param USER_WIDTH specifies the width of the US field of the AXI channels
 * @param EXT_MASTERS specifies the number of the system's External Masters
 * @param EXT_SLAVES specifies the number of External AXI Slave
 * @param MAX_LINK_WIDTH specifies the maximum tolerated link width of the NoC response path (@see axi_resp_packetizer)
 * @param FLIT_WIDTH_C specifies the width of the response flits.
 */

import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;

module axi_resp_packetizer
  #(parameter int SLAVE_ID          = 0,
    parameter int TIDS_M            = 16,
    parameter int ADDRESS_WIDTH     = 32,
    parameter int DATA_LANES        = 4,
    parameter int USER_WIDTH        = 2,
    parameter int EXT_MASTERS       = 4,
    parameter int EXT_SLAVES        = 2,
    parameter int MAX_LINK_WIDTH    = 128,
    parameter int FLIT_WIDTH_C      = 128)
   (input  logic clk,
    input  logic rst,
    
    // Write Response
    input  logic[log2c_1if1(TIDS_M) + $clog2(EXT_MASTERS) + USER_WIDTH + AXI_SPECS_WIDTH_RESP-1 : 0] b_chan,
    output logic b_ready,
    
    // Read Data
    input  logic[log2c_1if1(TIDS_M) + $clog2(EXT_MASTERS) + 8*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_RESP + AXI_SPECS_WIDTH_LAST-1 : 0] r_chan,
    output logic r_ready,
    
    // Merge comm
    input  logic[1:0] active_channel, // 0:write, 1:read
    output logic[1:0] release_trans,  // 0:write, 1:read

    // Output Flit
    output logic[FLIT_WIDTH_C-1:0] flit_out,
    output logic valid_out,
    input  logic ready_in);

// Slave-Side widths
localparam AXI_W_B_S = log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) + USER_WIDTH + AXI_SPECS_WIDTH_RESP;
localparam AXI_W_R_S = log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) + 8*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_RESP + AXI_SPECS_WIDTH_LAST;
    
localparam W_HEADER_FULL  = log2c(TIDS_M) + log2c(EXT_SLAVES) + log2c(EXT_MASTERS) + 1 + 1 + FLIT_FIELD_WIDTH;
localparam W_HEADER_SMALL = 1 + 1 + FLIT_FIELD_WIDTH;
    
// Master-Side widths
localparam AXI_W_B_M = log2c_1if1(TIDS_M) + USER_WIDTH + AXI_SPECS_WIDTH_RESP;
localparam AXI_W_R_M = log2c_1if1(TIDS_M) + 8*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_RESP + AXI_SPECS_WIDTH_LAST;

// Serialization & Width params for packetizing (Check if automatic needed)
localparam FLITS_PER_WRITE = get_flits_per_resp(MAX_LINK_WIDTH, AXI_W_B_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam FW_WRITE = get_resp_flit_width_first(MAX_LINK_WIDTH, AXI_W_B_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
    
localparam FLITS_PER_READ = get_flits_per_resp(MAX_LINK_WIDTH, AXI_W_R_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam FW_READ = get_resp_flit_width_first(MAX_LINK_WIDTH, AXI_W_R_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
    
localparam FW_RESP = get_max2(FW_WRITE, FW_READ);
    
localparam FW_WRITE_PAD_LAST = get_resp_flit_pad_last(FW_RESP, AXI_W_B_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam FW_READ_PAD_LAST  = get_resp_flit_pad_last(FW_RESP, AXI_W_R_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);


const logic[log2c_1if1(EXT_SLAVES)-1:0] SLAVE_ID_VEC = SLAVE_ID;


logic write_select, read_select;
logic[1:0] release_trans_s;
logic r_LAST;
    
logic[W_HEADER_FULL-FLIT_FIELD_WIDTH-1:0]  header_full_write, header_full_read;
logic[W_HEADER_SMALL-FLIT_FIELD_WIDTH-1:0] header_small_write, header_small_read;

logic[AXI_W_B_M-log2c_1if1(TIDS_M)-1:0] b_chan_no_tid;
logic[AXI_W_R_M-log2c_1if1(TIDS_M)-1:0] r_chan_no_tid;
    
localparam SER_MAX_COUNT = get_max2(FLITS_PER_WRITE, FLITS_PER_READ);

logic[FW_RESP-1:0] write_flits [FLITS_PER_WRITE-1:0];
logic[FW_RESP-1:0] read_flits  [FLITS_PER_READ-1:0];
logic[SER_MAX_COUNT*FW_RESP-1:0] data_to_ser_filled_write;
logic[SER_MAX_COUNT*FW_RESP-1:0] data_to_ser_filled_read;

logic ser_cnt_sel;
logic[SER_MAX_COUNT*FW_RESP-1:0] data_to_ser;
logic valid_to_ser, ready_from_ser, valid_from_ser, ready_to_ser;
logic[SER_MAX_COUNT-1:0] cnt_from_ser;
logic[FW_RESP-1:0] data_from_ser;


// readies
assign b_ready = release_trans_s[0];
assign r_ready = release_trans_s[1];

// update pri of AXI Merge
assign release_trans = release_trans_s;
// Alias, for readibility
assign write_select = active_channel[0];
assign read_select  = active_channel[1];

// [Giorgos Check]    
assign release_trans_s = active_channel & ( { 2{ready_from_ser} } );
assign r_LAST = r_chan[ log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) + 8*DATA_LANES + AXI_SPECS_WIDTH_RESP ];

assign b_chan_no_tid = b_chan[ AXI_W_B_S-1 : log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) ];
assign r_chan_no_tid = r_chan[ AXI_W_R_S-1 : log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) ];

logic[log2c_1if1(TIDS_M)-1 : 0]         tid_wr, tid_rd;
assign tid_wr = TIDS_M > 1 ? b_chan[0 +: log2c_1if1(TIDS_M)] : 1'b0;
assign tid_rd = TIDS_M > 1 ? r_chan[0 +: log2c_1if1(TIDS_M)] : 1'b0;

logic[log2c_1if1(EXT_MASTERS)-1 : 0]    src_wr, src_rd;
assign src_wr = EXT_MASTERS > 1 ? b_chan[ log2c_1if1(TIDS_M) +: log2c_1if1(EXT_MASTERS)] : 1'b0;
assign src_rd = EXT_MASTERS > 1 ? r_chan[ log2c_1if1(TIDS_M) +: log2c_1if1(EXT_MASTERS)] : 1'b0;

if ( EXT_SLAVES > 1 && EXT_MASTERS > 1) begin
    if (TIDS_M > 1) begin
        assign header_full_write = { tid_wr, src_wr, SLAVE_ID_VEC, OP_ID_WRITE};
        assign header_full_read  = { tid_rd, src_rd, SLAVE_ID_VEC, OP_ID_READ };
    end else begin
        assign header_full_write = {         src_wr, SLAVE_ID_VEC, OP_ID_WRITE};
        assign header_full_read  = {         src_rd, SLAVE_ID_VEC, OP_ID_READ };
    end
end else if (EXT_SLAVES > 1) begin
    if (TIDS_M > 1) begin
        assign header_full_write = { tid_wr,         SLAVE_ID_VEC, OP_ID_WRITE};
        assign header_full_read  = { tid_rd,         SLAVE_ID_VEC, OP_ID_READ };
    end else begin
        assign header_full_write = {                 SLAVE_ID_VEC, OP_ID_WRITE};
        assign header_full_read  = {                 SLAVE_ID_VEC, OP_ID_READ };
    end
end else if (EXT_MASTERS > 1) begin
    if (TIDS_M > 1) begin
        assign header_full_write = { tid_wr, src_wr,               OP_ID_WRITE};
        assign header_full_read  = { tid_rd, src_rd,               OP_ID_READ };
    end else begin
        assign header_full_write = {         src_wr,               OP_ID_WRITE};
        assign header_full_read  = {         src_rd,               OP_ID_READ };
    end
end else begin
    if (TIDS_M > 1) begin
        assign header_full_write = { tid_wr,                       OP_ID_WRITE};
        assign header_full_read  = { tid_rd,                       OP_ID_READ };
    end else begin
        assign header_full_write = {                               OP_ID_WRITE};
        assign header_full_read  = {                               OP_ID_READ };
    end
end

assign header_small_write = OP_ID_WRITE;

// [Giorgos] Check bit expansion size
logic[FW_WRITE_PAD_LAST-1:0] zeropadwrite;
assign zeropadwrite = 0;

logic[FW_READ_PAD_LAST-1:0] zeropadread;
assign zeropadread = 0;


genvar i;
generate
    if (FLITS_PER_WRITE == 1) begin: fpw_eq1
        if (FW_WRITE_PAD_LAST == 0)
            assign write_flits[0] = { b_chan_no_tid , header_full_write , FLIT_SINGLE};
        else
            assign write_flits[0] = { zeropadwrite, b_chan_no_tid , header_full_write , FLIT_SINGLE};

    end else if (FLITS_PER_WRITE > 1) begin: fpw_gt1
        for( i = 0; i < FLITS_PER_WRITE; i++) begin: for_i
            if (i == 0)
                assign write_flits[i] = { b_chan_no_tid[FW_RESP-W_HEADER_FULL-1:0], header_full_write, FLIT_HEAD };
            if ( (i > 0) && (i < FLITS_PER_WRITE-1) )
                assign write_flits[i] = { b_chan_no_tid[ (FW_RESP-W_HEADER_FULL) + i*(FW_RESP-W_HEADER_SMALL) - 1 : (FW_RESP-W_HEADER_FULL) + (i-1)*(FW_RESP-W_HEADER_SMALL) ],
                                          header_small_write, FLIT_BODY};
           
            if ( i == FLITS_PER_WRITE-1 ) begin
                if ( FW_WRITE_PAD_LAST == 0 )
                    assign write_flits[i] = { b_chan_no_tid[ (FW_RESP-W_HEADER_FULL) + i*(FW_RESP-W_HEADER_SMALL) - 1 : (FW_RESP-W_HEADER_FULL) + (i-1)*(FW_RESP-W_HEADER_SMALL) ],
                                              header_small_write, FLIT_TAIL};

                if ( FW_WRITE_PAD_LAST > 0 )
                    assign write_flits[i] = { zeropadwrite, 
                                              b_chan_no_tid[ (FW_RESP-W_HEADER_FULL) + (i-1)*(FW_RESP-W_HEADER_SMALL) + (FW_RESP-W_HEADER_SMALL-FW_WRITE_PAD_LAST) - 1 : (FW_RESP-W_HEADER_FULL) + (i-1)*(FW_RESP-W_HEADER_SMALL) ],
                                              header_small_write, FLIT_TAIL};
            end
        end
    end
endgenerate

assign header_small_read = OP_ID_READ;


generate

if ( FLITS_PER_READ == 1) begin: fpr_eq1
    if ( FW_READ_PAD_LAST == 0 )
        assign read_flits[0] = { r_chan_no_tid , header_full_read , FLIT_SINGLE };
    if ( FW_READ_PAD_LAST > 0 )
        assign read_flits[0] = { zeropadread, r_chan_no_tid, header_full_read, FLIT_SINGLE };
end else if ( FLITS_PER_READ > 1 ) begin: fpr_gt1
    for ( i=0; i < FLITS_PER_READ; i++) begin: for_i
        if (i == 0)
            assign read_flits[i] = { r_chan_no_tid[FW_RESP-W_HEADER_FULL-1 : 0], header_full_read, FLIT_HEAD};
           
        if ( ( i > 0 ) && ( i < FLITS_PER_READ-1 ) )
            assign read_flits[i] = { r_chan_no_tid[ (FW_RESP-W_HEADER_FULL) + i*(FW_RESP-W_HEADER_SMALL) - 1 : (FW_RESP-W_HEADER_FULL) + (i-1)*(FW_RESP-W_HEADER_SMALL) ],
                                     header_small_read, FLIT_BODY };
            
        if ( i == FLITS_PER_READ-1 ) begin
            if ( FW_READ_PAD_LAST == 0 )
                assign read_flits[i] = { r_chan_no_tid[ (FW_RESP-W_HEADER_FULL) + i*(FW_RESP-W_HEADER_SMALL) - 1 : (FW_RESP-W_HEADER_FULL) + (i-1)*(FW_RESP-W_HEADER_SMALL) ],
                                         header_small_read, FLIT_TAIL};
            if ( FW_READ_PAD_LAST > 0 )
                assign read_flits[i] = { zeropadread, 
                                         r_chan_no_tid[ (FW_RESP-W_HEADER_FULL) + (i-1)*(FW_RESP-W_HEADER_SMALL) + (FW_RESP-W_HEADER_SMALL-FW_READ_PAD_LAST) - 1 : (FW_RESP-W_HEADER_FULL) + (i-1)*(FW_RESP-W_HEADER_SMALL) ],
                                         header_small_read, FLIT_TAIL };
        end 
    end
end
endgenerate

generate
    for (i=0; i < SER_MAX_COUNT; i++) begin: for_i
        if (i < FLITS_PER_WRITE)
            assign data_to_ser_filled_write[(i+1)*FW_RESP-1 : i*FW_RESP] = write_flits[i];
        if (i >= FLITS_PER_WRITE)
            assign data_to_ser_filled_write[(i+1)*FW_RESP-1 : i*FW_RESP] = 0; //{FW_RESP{1'b0}}
        
        if (i < FLITS_PER_READ)
            assign data_to_ser_filled_read[(i+1)*FW_RESP-1 : i*FW_RESP] = read_flits[i];
        if (i >= FLITS_PER_READ)
            assign data_to_ser_filled_read[(i+1)*FW_RESP-1 : i*FW_RESP] = 0; // (others => '0');
    end
endgenerate

assign data_to_ser = (write_select) ? data_to_ser_filled_write : data_to_ser_filled_read;
assign valid_to_ser = write_select | read_select;
    
// no need to check valid (one AXI channel per packet)
// valid_write_flit <= write_select;-- and b_valid;
// valid_read_flit <= read_select;-- and r_valid;
// Serializer shared by B & R flits (null if no serialization)
assign ser_cnt_sel = read_select;
assign ready_to_ser = ready_in;
assign valid_out = valid_from_ser;
assign flit_out = data_from_ser;

ser_shared2 #(.SER_WIDTH    (FW_RESP),
              .COUNT_0      (FLITS_PER_WRITE),
              .COUNT_1      (FLITS_PER_READ))
  ser_both (.clk            (clk),
            .rst            (rst),
            .count_sel      (ser_cnt_sel),
            .parallel_in    (data_to_ser),
            .valid_in       (valid_to_ser),
            .ready_out      (ready_from_ser),
            .cnt_out        (cnt_from_ser),
            .serial_out     (data_from_ser),
            .valid_out      (valid_from_ser),
            .ready_in       (ready_to_ser));




// pragma synthesis_off
// pragma translate_off
`ifdef NI_VERBOSE
	initial begin
		forever begin
		    @(posedge clk);
		    if (valid_out && ready_in) begin
		        // automatic logic[ADDRESS_WIDTH-1:0] addr_TMP = flit_out[FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES)+log2c(EXT_MASTERS)+log2c(TIDS_M) +: ADDRESS_WIDTH];
		        automatic int dst_TMP;
			automatic logic[log2c_1if1(TIDS_M)-1:0] tid_TMP1_logic = active_channel[0] ? b_chan[log2c_1if1(TIDS_M)-1:0] : r_chan[log2c_1if1(TIDS_M)-1:0];
		        automatic int tid_TMP1 = int'(tid_TMP1_logic);
		        automatic int tid_TMP2;
		        
		        if (EXT_MASTERS > 1)
		            dst_TMP = flit_out[FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES) +: log2c_1if1(EXT_MASTERS)];
		        else
		            dst_TMP = 0;
		        
		        if (TIDS_M > 1)
		            tid_TMP2 = flit_out[FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES)+log2c(EXT_MASTERS) +: log2c_1if1(TIDS_M)];
		        else
		            tid_TMP2 = 0;
		        
		        $display("%0t: M_NI[%0d] >>> NoC %s flit to dest=%0d T= 1:%0d(%0b) 2:%0d", $time, SLAVE_ID, flittype_to_str(flit_out), dst_TMP, tid_TMP1, tid_TMP1_logic, tid_TMP2);
		    end
		end
	end
`endif
// pragma translate_on
// pragma synthesis_on
endmodule
