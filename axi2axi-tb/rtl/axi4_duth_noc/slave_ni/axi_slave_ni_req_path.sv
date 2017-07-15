/** 
 * @info Request Path of the Slave NI
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief The request path of the Slave NI includes the AXI Request Merge Unit (@see axi_merge_reqs), the address LUT
 *        (@see axi_address_lut) and the request packetizer (@see axi_req_packetizer).
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
 * @param ADDRS_LO specifies the lower address bound served by each slave. (@see axi_address_lut)
 *        The lower address bound of Slave[i] should be found in ADDRS_LO[(i+1)*ADDRESS_WIDTH-1 : i*ADDRESS_WIDTH]
 * @param ADDRS_HI specifies the higher address bound served by each slave. (@see axi_address_lut)
 *        The higher address bound of Slave[i] should be found in ADDRS_HI[(i+1)*ADDRESS_WIDTH-1 : i*ADDRESS_WIDTH]
 * @param MAX_LINK_WIDTH_REQ specifies the maximum tolerated link width. This will feed the functions that decide on the packet
 *        length, flit width, number of flits per transaction etc.
 * @param FLIT_WIDTH_C specifies the width of the flit. This is redundantly passed here, since it is also found inside the module.
 *        It is used, however, to avoid doing all those calculations on the module's interface
 */

import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;


module axi_slave_ni_req_path
  #(parameter int MASTER_ID					    =  0,
    parameter int TIDS_M					    =  16,
    parameter int ADDRESS_WIDTH					=  32,
    parameter int DATA_LANES					=  4,
    parameter int USER_WIDTH					=  2,
    parameter int EXT_MASTERS					=  4,
    parameter int EXT_SLAVES					=  2,
    parameter logic HAS_WRITE                   =  1'b1,
    parameter logic HAS_READ					=  1'b1,
    parameter logic [ADDRESS_WIDTH*EXT_SLAVES-1:0] ADDRS_LO	= {ADDRESS_WIDTH*EXT_SLAVES{1'b0}},
    parameter logic [ADDRESS_WIDTH*EXT_SLAVES-1:0] ADDRS_HI	= {ADDRESS_WIDTH*EXT_SLAVES{1'b1}},
    parameter int MAX_LINK_WIDTH_REQ            = 128,
    parameter int FLIT_WIDTH_C					= 128)
   (input logic clk,
    input logic rst,
	///   Input AXI Channels   ///
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
    ///   Reordering info   ///
    output logic reorder_req,
    output logic[1:0] reorder_req_op, // 1: Read, 0: Write
    output logic[log2c_1if1(TIDS_M)-1 : 0] reorder_req_tid, // bin enc
    output logic[EXT_SLAVES-1 : 0]     reorder_req_dst_out,
    input logic[log2c_1if1(EXT_SLAVES)-1 : 0] reorder_req_dst_in,
    input logic reorder_qualify_now,
    ///   Output NoC Channel   ///
    output logic[FLIT_WIDTH_C-1 : 0] outp_chan,
    output logic outp_valid,
    input logic outp_ready);

localparam integer AXI_CW_M_AWR = log2c_1if1(TIDS_M) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS;
localparam integer AXI_CW_M_W   = log2c_1if1(TIDS_M) + 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST;
    
logic[AXI_CW_M_AWR-1 : 0] addr_chan_muxed;
logic addr_ready_to_demux;
logic[1:0] active_channel, update_priority;
logic merge_anygnt;
logic[ADDRESS_WIDTH-1 : 0] addr_to_lut;
    
logic has_qualified_reorder, reorder_qualify;

//--------------------------
//---   AXI Merge Unit   ---
//--------------------------
  
axi_merge_reqs #(.HAS_WRITE  (HAS_WRITE),
                 .HAS_READ   (HAS_READ))
axi_merge(.clk               (clk),
          .rst               (rst),
          .aw_valid          (aw_valid),
          .w_valid           (w_valid),
          .ar_valid          (ar_valid),
          .active_channel    (active_channel),
          .anyactive         (merge_anygnt),
          .update_pri        (update_priority));

generate
  if (HAS_WRITE && HAS_READ)
    //-------------------------------
    //---   MUX Address Channel   ---
    //-------------------------------
    begin
	  logic[2*AXI_CW_M_AWR-1 : 0] addr_to_mux_tmp;
	  // 1: Read, 0: Write
      assign addr_to_mux_tmp = {ar_chan, aw_chan};
	  and_or_multiplexer #(.INPUTS     (2),
	                       .DATA_WIDTH (AXI_CW_M_AWR))
	  mux_addr(.data_in    (addr_to_mux_tmp),
	           .sel        (active_channel),
			   .data_out   (addr_chan_muxed));
	
	  assign aw_ready = addr_ready_to_demux & active_channel[0];
      assign ar_ready = addr_ready_to_demux & active_channel[1];
	end
  else
    if (HAS_WRITE && !(HAS_READ))
	  begin
	    assign addr_chan_muxed = aw_chan;
        assign aw_ready = addr_ready_to_demux;
        assign ar_ready = 0;
	  end
	else
	  if (!(HAS_WRITE) && HAS_READ)
	    begin 
          assign addr_chan_muxed = ar_chan;
          assign aw_ready = 0;
          assign ar_ready = addr_ready_to_demux;
		end
endgenerate
		
// intermediate blocks (alut, reorder)
assign addr_to_lut = addr_chan_muxed[log2c_1if1(TIDS_M) +: ADDRESS_WIDTH]; // - 1 : $clog2(TIDS_M)];
//-----------------------
//---   Address LUT   ---
//-----------------------
axi_address_lut #(.ADDRESS_WIDTH (ADDRESS_WIDTH),
                  .EXT_SLAVES    (EXT_SLAVES),
				  .ADDRS_LO      (ADDRS_LO),
				  .ADDRS_HI      (ADDRS_HI))
addr_lut(.address (addr_to_lut),
         .slaves  (reorder_req_dst_out));

assert property(@(posedge clk) disable iff(rst) (merge_anygnt && !has_qualified_reorder) |-> (^addr_to_lut) !== 1'bx) else
    $fatal(1, "[address check] Invalid address field for request! Check for X's @ addr_to_lut");
    

//---------------------------
//---   To/From Reorder   ---
//---------------------------
assign reorder_req = merge_anygnt & !(has_qualified_reorder);
assign reorder_req_op = active_channel;
assign reorder_req_tid = addr_chan_muxed[0 +: log2c_1if1(TIDS_M)];//-1 : 0];		

always_ff @ (posedge clk, posedge rst)   
  if (rst) 
    has_qualified_reorder <= 0;
  else
    if (update_priority[0] | update_priority[1])
	  has_qualified_reorder <= 0;
  else
	if ((!has_qualified_reorder) & merge_anygnt & reorder_qualify_now)
	  has_qualified_reorder <= 1;
		
assign  reorder_qualify = reorder_qualify_now | has_qualified_reorder;

//----------------------
//---   Packetizer   ---
//----------------------

axi_req_packetizer #(.MASTER_ID         (MASTER_ID),
                     .TIDS_M            (TIDS_M),
                     .ADDRESS_WIDTH     (ADDRESS_WIDTH),
                     .DATA_LANES        (DATA_LANES),
                     .USER_WIDTH        (USER_WIDTH),
                     .EXT_MASTERS       (EXT_MASTERS),
                     .EXT_SLAVES        (EXT_SLAVES),
                     .MAX_LINK_WIDTH    (MAX_LINK_WIDTH_REQ),
                     .FLIT_WIDTH_C      (FLIT_WIDTH_C))
packetizer(.clk               (clk),
           .rst               (rst),
           .addr_chan         (addr_chan_muxed),
           .addr_ready        (addr_ready_to_demux),
           .data_chan         (w_chan),
           .data_valid        (w_valid),
           .data_ready        (w_ready),
           .active_select     (active_channel), 
           .reorder_qualify   (reorder_qualify),
           .release_trans     (update_priority), 
           .addr_lut_dst      (reorder_req_dst_in),
           .flit_out          (outp_chan),
           .valid_out         (outp_valid),
           .ready_in          (outp_ready));

endmodule
