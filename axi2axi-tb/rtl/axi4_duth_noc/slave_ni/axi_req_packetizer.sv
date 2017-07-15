/** 
 * @info Request Transactions Packetizer (Slave NI)
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Packetizes request transactions (both read and write), according to a given maximum tolerated link width.
 *
 * @param MASTER_ID specifies the ID of the External Master, attached to the Slave NI
 * @param TIDS_M specifies the number of AXI Transaction IDs
 * @param ADDRESS_WIDTH specifies the address filed width of the transactions (AxADDR)
 * @param DATA_LANES specifies the number of byte lanes of the Write Data channel (W)
 * @param USER_WIDTH specifies the width of the US field of the AXI channels
 * @param EXT_MASTERS specifies the number of the system's External Masters
 * @param EXT_SLAVES specifies the number of External AXI Slave
 * @param MAX_LINK_WIDTH specifies the maximum tolerated link width. This will feed the functions that decide on the packet
 *        length, flit width, number of flits per transaction etc.
 * @param FLIT_WIDTH_C specifies the width of the flit. This is redundantly passed here, since it is also found inside the module.
 *        It is used, however, to avoid doing all those calculations on the module's interface
 */
import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;


module axi_req_packetizer
  #(parameter int MASTER_ID			= 0,
    parameter int TIDS_M			= 16,
    parameter int ADDRESS_WIDTH		= 32,
    parameter int DATA_LANES		= 4,
    parameter int USER_WIDTH		= 2,
    parameter int EXT_MASTERS		= 4,
    parameter int EXT_SLAVES		= 2,
    parameter int MAX_LINK_WIDTH	= 128,
    parameter int FLIT_WIDTH_C		= 128)
   (input logic clk,
    input logic rst,
	// AXI Input Channels
	// Address
	input logic[log2c_1if1(TIDS_M) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS-1 : 0] addr_chan,
	output logic addr_ready,
	// Write Data
	input logic[log2c_1if1(TIDS_M) + 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST-1 : 0] data_chan,
	input logic data_valid,
	output logic data_ready,
	// Active transaction, reorder qualification, and Merge update priority
	input logic[1:0] active_select, // 0: Write, 1: Read
	input logic reorder_qualify,
	output logic[1:0] release_trans, // 0: Write, 1: Read
	// From Address LUT
	input logic[log2c_1if1(EXT_SLAVES)-1 : 0] addr_lut_dst,
	// Output Flit
	output logic[FLIT_WIDTH_C-1 : 0] flit_out,
	output logic                     valid_out,
	input logic                      ready_in);
	
// Master's ID, for packet's header
localparam logic[ log2c_1if1(EXT_MASTERS)-1 : 0] MASTER_ID_VEC = MASTER_ID; 

localparam integer AXI_CW_M_AWR = log2c_1if1(TIDS_M) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS;
localparam integer AXI_CW_M_W   = log2c_1if1(TIDS_M) + 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST;
    
localparam integer W_HEADER_FULL = log2c(TIDS_M) + log2c(EXT_SLAVES) + log2c(EXT_MASTERS) + 1 + 1 + FLIT_FIELD_WIDTH;
localparam integer W_HEADER_SMALL = 1 + 1 + FLIT_FIELD_WIDTH;
    
// Serialization & Width params for packetizing
// ADDR
localparam integer ADDR_PENALTY = get_addr_penalty(MAX_LINK_WIDTH,     AXI_CW_M_AWR - log2c_1if1(TIDS_M), AXI_CW_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FW_ADDR = get_addr_flit_width_first(MAX_LINK_WIDTH, AXI_CW_M_AWR - log2c_1if1(TIDS_M), AXI_CW_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL);
// DATA
localparam integer FLITS_PER_DATA = get_flits_per_data(MAX_LINK_WIDTH, AXI_CW_M_AWR - log2c_1if1(TIDS_M), AXI_CW_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FW_DATA = get_data_flit_width_first(MAX_LINK_WIDTH, AXI_CW_M_AWR - log2c_1if1(TIDS_M), AXI_CW_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FW_REQ = get_max2(FW_ADDR, FW_DATA);
	
// Write or Read is active
logic write_select, read_select;
// flit header params
logic d_LAST;
    
logic[1:0] release_trans_s;
    
logic op_id;
logic[log2c_1if1(TIDS_M)-1 : 0] tid;
    
logic[W_HEADER_FULL-1 : 0] header_full;
logic[W_HEADER_SMALL-1 : 0] header_small;
    
logic[ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS - 1 : 0] addr_chan_no_tid;
logic[9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST - 1 : 0] data_chan_no_tid;
    
logic[FLIT_FIELD_WIDTH-1 : 0] flittype_full, flittype_small;
    
logic addr_passed, processing_addr, processing_data, processing_last_data;


assign release_trans = release_trans_s;
assign write_select = active_select[0];
assign read_select = active_select[1];
    
assign addr_ready = processing_addr;
assign data_ready = processing_data;
    
// Release transaction (reset states & let merge update its priority)
assign release_trans_s[1] = processing_addr & read_select;
assign release_trans_s[0] = processing_last_data; // contains write_select

// State only required for keeping track whether header (address) has left
always_ff @ (posedge clk, posedge rst) begin: state_addr
    if (rst)
        addr_passed <= 0;
    else
        if (release_trans_s[1] | release_trans_s[0])
            // releasing any of Write or Read
            addr_passed <= 0;
        else if (processing_addr)
            // reading address from Write
            addr_passed <= 1;
end
assign d_LAST = data_chan[log2c_1if1(TIDS_M) + 9*DATA_LANES];

// basic header fields (flittype depends on serialization, check if-generates)
assign op_id = read_select ? OP_ID_READ : OP_ID_WRITE;
assign tid = addr_chan[log2c_1if1(TIDS_M)-1 : 0];

// pragma synthesis_off
// pragma translate_off
`ifdef NI_VERBOSE
	initial begin
		forever begin
		    @(posedge clk);
		    if (valid_out && ready_in) begin
		        automatic int tid_TMP = TIDS_M > 1 ? flit_out[FLIT_FIELD_WIDTH+1+log2c(EXT_MASTERS)+log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)] : 0;
		        automatic int dst_TMP;
		        if (EXT_SLAVES > 1)
		            dst_TMP = flit_out[FLIT_FIELD_WIDTH+1+log2c(EXT_MASTERS) +: log2c_1if1(EXT_SLAVES)];
		        else
		            dst_TMP = 0;
		        $display("%0t: S_NI[%0d] >>> NoC %s flit to dest=%0d T=%0d", $time, MASTER_ID, flittype_to_str(flit_out), dst_TMP, tid_TMP);
		        // end
		    end
		end
		// if (TIDS_M == 1) begin
		    // assert (tid !== 1'b1) else $fatal(1, "TID == 1??");
		// end
	end
`endif
// pragma translate_on
// pragma synthesis_on

// Headers
// [TID][DST][SRC][KIND][OP][FLIT]
// assign header_full = {tid,addr_lut_dst,MASTER_ID_VEC,kind_id,op_id,flittype_full};
// assign header_full = (EXT_SLAVES > 1 && EXT_MASTERS > 1) ? ( (TIDS_M > 1) ? {tid, addr_lut_dst, MASTER_ID_VEC, kind_id, op_id, flittype_full} :
                                                                            // {     addr_lut_dst, MASTER_ID_VEC, kind_id, op_id, flittype_full})
if (EXT_SLAVES > 1 && EXT_MASTERS > 1) begin
    if (TIDS_M > 1) begin
        assign header_full = {tid, addr_lut_dst, MASTER_ID_VEC, op_id, flittype_full};
    end else begin
        assign header_full = {     addr_lut_dst, MASTER_ID_VEC, op_id, flittype_full};
    end
end else if (EXT_SLAVES > 1) begin
    if (TIDS_M > 1) begin
        assign header_full = {tid, addr_lut_dst,                op_id, flittype_full};
    end else begin
        assign header_full = {     addr_lut_dst,                op_id, flittype_full};
    end
end else if (EXT_MASTERS > 1) begin
    if (TIDS_M > 1) begin
        assign header_full = {tid,               MASTER_ID_VEC, op_id, flittype_full};
    end else begin
        assign header_full = {                   MASTER_ID_VEC, op_id, flittype_full};
    end
end else begin
    if (TIDS_M > 1) begin
        assign header_full = {tid,                              op_id, flittype_full};
    end else begin
        assign header_full = {                                  op_id, flittype_full};
    end
end

// assign header_full = EXT_SLAVES > 1 ? (EXT_MASTERS > 1 ? {tid,addr_lut_dst,MASTER_ID_VEC,kind_id,op_id,flittype_full} :
                                                         // {tid,addr_lut_dst,kind_id,op_id,flittype_full}) :
                                      // (EXT_MASTERS > 1 ? {tid,MASTER_ID_VEC,kind_id,op_id,flittype_full} :
                                                         // {tid,kind_id,op_id,flittype_full}); // Ignore DST if only 1
assign header_small = {op_id,flittype_small};
    
// aliases
assign addr_chan_no_tid = addr_chan[log2c_1if1(TIDS_M) +: ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS];// - 1 : log2c_1if1(TIDS_M)];
assign data_chan_no_tid = data_chan[log2c_1if1(TIDS_M) +: 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST];// - 1 : log2c_1if1(TIDS_M)];

genvar i;
generate
if (ADDR_PENALTY == 0) begin: a_pen_eq0
    localparam logic[FW_DATA-(9*DATA_LANES+USER_WIDTH+AXI_SPECS_WIDTH_LAST)-W_HEADER_SMALL-1 : 0] ZERO_PAD_DATA = 0;
    logic[FW_ADDR-1 : 0] address_flit;
    logic valid_address_flit;
    logic[FW_DATA-1 : 0] data_flit;
    logic valid_data_flit;
    
    // case also for single-Length data (both address and data will fit in a single-flit)
    assign flittype_full = (read_select | (write_select & d_LAST)) ? FLIT_SINGLE : FLIT_HEAD;
    assign flittype_small = d_LAST ? FLIT_TAIL : FLIT_BODY;
    
    // Replace (or) with anygnt from merge
    assign valid_address_flit = reorder_qualify & !(addr_passed) & (read_select | write_select);
    assign valid_data_flit = addr_passed & data_valid & write_select;
    //
    assign processing_addr = valid_address_flit & ready_in;
    assign processing_data = ((reorder_qualify & !(addr_passed) & write_select) | valid_data_flit) & ready_in;
    assign processing_last_data = processing_data & d_LAST;
    
    // For zero-penalty, address_flit == First flit that has both ADDR & DATA
    assign address_flit = {data_chan_no_tid, addr_chan_no_tid, header_full};
    // Fill address part and remaining header with zeros
    assign data_flit = {data_chan_no_tid, ZERO_PAD_DATA, header_small};
    
    assign flit_out = (!addr_passed) ? address_flit : data_flit;
    assign valid_out = valid_address_flit | valid_data_flit;
end else begin: a_pen_gt0
    localparam integer SER_MAX_COUNT = get_max2(ADDR_PENALTY, FLITS_PER_DATA);

    logic[FW_REQ-1 : 0] address_flits [ADDR_PENALTY-1 : 0];
    logic[SER_MAX_COUNT*FW_REQ-1 : 0] data_to_ser_filled_addr;
    logic[FW_REQ-1 : 0] data_flits [FLITS_PER_DATA-1 : 0];
    logic[SER_MAX_COUNT*FW_REQ-1 : 0] data_to_ser_filled_data;
    
    //DON'T Call those using MAX_LINK_WIDTH! Now the flit width has been determined!
    localparam integer FW_ADDR_PAD_LAST = get_addr_flit_pad_last(FW_REQ, AXI_CW_M_AWR - log2c_1if1(TIDS_M), AXI_CW_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
    localparam integer FW_DATA_PAD_LAST = get_data_flit_pad_last(FW_REQ, AXI_CW_M_AWR - log2c_1if1(TIDS_M), AXI_CW_M_W - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
    
    logic valid_address_flit, valid_data_flit;
    
    // counter from serializer
    logic ser_cnt_sel;
    logic[SER_MAX_COUNT*FW_REQ-1 : 0] data_to_ser;
    logic valid_to_ser, ready_from_ser;
    logic[SER_MAX_COUNT-1 : 0] cnt_from_ser;

    assign flittype_full = (read_select && (ADDR_PENALTY==1)) ? FLIT_SINGLE : FLIT_HEAD;
    // Tail only when final read (if serialized) OR final data
    assign flittype_small = ( (read_select & cnt_from_ser[ADDR_PENALTY-1]) | 
                              (write_select & addr_passed & d_LAST & cnt_from_ser[FLITS_PER_DATA-1]) ) ?  FLIT_TAIL : FLIT_BODY;
    
    // Replace (or) with anygnt from merge
    assign valid_address_flit = reorder_qualify & ~(addr_passed) & (read_select | write_select);
    assign valid_data_flit = addr_passed & data_valid & write_select;
    // For state update etc
    assign processing_addr = valid_address_flit & ready_from_ser;
    assign processing_data = valid_data_flit & ready_from_ser;
    assign processing_last_data = processing_data & d_LAST;
        
    //Address Flits Bounds Manipulation ------------------------------------------------------
    // Fill Address flits
    if (ADDR_PENALTY == 1) begin: a_pen_eq1
        // Separate condition if PENALTY = 1, because of a different Header for flits (can't fit in one iter)
        if (FW_ADDR_PAD_LAST == 0)
            assign address_flits[0] = {addr_chan_no_tid, header_full};
        else
            assign address_flits[0] = { {FW_ADDR_PAD_LAST{1'b0}}, addr_chan_no_tid, header_full};            
    end else begin: a_pen_gt1
        // Manual FULL header to first flit
        assign address_flits[0] = {addr_chan_no_tid[FW_REQ-W_HEADER_FULL-1 : 0], header_full};
        for (i=1; i < ADDR_PENALTY; i=i+1) begin: for_i
            // Padding to the last one, if necessary
            if ( (i == (ADDR_PENALTY-1)) && (FW_ADDR_PAD_LAST > 0))
                assign address_flits[i] = {{FW_ADDR_PAD_LAST{1'b0}}, addr_chan_no_tid[(FW_REQ-W_HEADER_FULL) + (i-1)*(FW_REQ-W_HEADER_SMALL) + (FW_REQ-W_HEADER_SMALL-FW_ADDR_PAD_LAST) - 1 : (FW_REQ-W_HEADER_FULL) + (i-1)*(FW_REQ-W_HEADER_SMALL)], header_small};
            else // if ((i < (ADDR_PENALTY-1)) | (FW_ADDR_PAD_LAST == 0))
                assign address_flits[i] = {addr_chan_no_tid[ (FW_REQ-W_HEADER_FULL) + i*(FW_REQ-W_HEADER_SMALL) - 1 : (FW_REQ-W_HEADER_FULL) + (i-1)*(FW_REQ-W_HEADER_SMALL) ], header_small};
        end
    end

    // Data Flits Bounds Manipulation ---------------------------------------------------------
    // No need for the same work-around here, all data flits will get the SMALL header
    for (i=0; i < FLITS_PER_DATA; i++) begin: for_i
        // similar to previous (pad, if needed)
        if ( (i == (FLITS_PER_DATA-1)) && (FW_DATA_PAD_LAST > 0 ))
            assign data_flits[i] = {{FW_DATA_PAD_LAST{1'b0}}, data_chan_no_tid[ i*(FW_REQ-W_HEADER_SMALL) + (FW_REQ-W_HEADER_SMALL-FW_DATA_PAD_LAST) - 1 : i*(FW_REQ-W_HEADER_SMALL)], header_small};
        else // if ((i < (FLITS_PER_DATA-1)) & (FW_DATA_PAD_LAST == 0))
            assign data_flits[i] = {data_chan_no_tid[(i+1)*(FW_REQ-W_HEADER_SMALL) - 1 : i*(FW_REQ-W_HEADER_SMALL)], header_small};
    end
    // Fill a full input vector that matches ser's input (dummy inputs if necessary)
    for (i=0; i < SER_MAX_COUNT; i++) begin: for_i2
        if (i < ADDR_PENALTY)
            assign data_to_ser_filled_addr[(i+1)*FW_REQ-1 : i*FW_REQ] = address_flits[i];
        else
            assign data_to_ser_filled_addr[(i+1)*FW_REQ-1 : i*FW_REQ] = {FW_REQ{1'b0}};
     end

    for (i=0; i < SER_MAX_COUNT; i++) begin: for_i3
        if (i < FLITS_PER_DATA)
            assign data_to_ser_filled_data[(i+1)*FW_REQ-1 : i*FW_REQ] = data_flits[i];
        else
            assign data_to_ser_filled_data[(i+1)*FW_REQ-1 : i*FW_REQ] = {FW_REQ{1'b0}};
    end
    // MUX them
    assign data_to_ser = (!addr_passed) ? data_to_ser_filled_addr : data_to_ser_filled_data;
    assign valid_to_ser = valid_address_flit | valid_data_flit;

    // Serializer
    //ser_cnt_sel selects current max count (for address or data flits)
    //(serializer supports any of the max counts to be 1)
    assign ser_cnt_sel = addr_passed;

    ser_shared2 
        #(.SER_WIDTH (FW_REQ),
          .COUNT_0   (ADDR_PENALTY),
          .COUNT_1   (FLITS_PER_DATA))
      ser_both(.clk          (clk),
               .rst          (rst),
               .count_sel    (ser_cnt_sel),
               .parallel_in  (data_to_ser),
               .valid_in     (valid_to_ser),
               .ready_out    (ready_from_ser),
               .cnt_out      (cnt_from_ser),
               .serial_out   (flit_out),
               .valid_out    (valid_out),
               .ready_in     (ready_in));
	
end
endgenerate

// pragma synthesis_off
// pragma translate_off
//always @(posedge clk, posedge rst)
//    if (!rst)
//        if ( valid_out && (flit_is_head(flit_out) || flit_is_single(flit_out)) )
//            $display("%0d: d=%0d - d@h=%0d", $time, int'(flit_out[FLIT_FIELD_WIDTH+1+1+log2c(EXT_MASTERS) +: log2c(EXT_SLAVES)]), int'(addr_lut_dst));
// pragma translate_on
// pragma synthesis_on
endmodule
