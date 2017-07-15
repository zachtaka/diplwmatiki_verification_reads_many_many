/** 
 * @info Top-level NIs + NoC
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Generates and glues all required modules to build the NoC along with the AXI4 NIs, under the proper parameters.
 *
 * @param TIDS_M specifies the number of AXI Transaction IDs
 * @param ADDRESS_WIDTH specifies the address filed width of the transactions (AxADDR)
 * @param DATA_LANES specifies the number of byte lanes of the Write Data channel (W)
 * @param USER_WIDTH specifies the width of the US field of the AXI channels
 * @param EXT_MASTERS specifies the number of the system's External Masters
 * @param EXT_SLAVES specifies the number of External AXI Slave
 * @param NOC_HOP_COUNT_REQ specifies the number of hops of the NoC request path.
 *        Increasing the number of hops lowers the critical path, and adds some extra buffers.
 * @param NOC_HOP_COUNT_RESP specifies the number of hops of the NoC response path.
 *        Increasing the number of hops lowers the critical path, and adds some extra buffers.
 * @param MAX_LINK_WIDTH_REQ_IN specifies the maximum tolerated link width of the NoC request path.
 *        Set to 0 to automatically get the maximum link that does not force any serialization.
 * @param MAX_LINK_WIDTH_RESP_IN specifies the maximum tolerated link width of the NoC response path.
 *        Set to 0 to automatically get the maximum link that does not force any serialization.
 * @param SHARED_WR_PATH specifies if the Write & Read transactions share the same paths in the NoC.
 *        Using separate read/write paths might offer some performance boost, bad will add extra wiring + twice the NoC,
 *        i.e. twice the buffering and switching logic.
 * @param MAX_PENDING_SAME_DST specifies the maximum number of transactions that are allowed to be in-flight for a single destination.
 * @param ADDR_BASE specifies the lower address bound served by each slave.
 *        The lower address bound of Slave[i] should be found in ADDR_BASE[(i+1)*ADDRESS_WIDTH-1 : i*ADDRESS_WIDTH]
 * @param ADDR_RANGE specifies the address range served by each External Slave.
 *        Eventually, the address range that is served by Slave i starts at the lower address of [@see ADDR_BASE] and
 *        and ranges to base+2^range. See functions below that calculate ADDRS_LO, ADDRS_HI (similar to AXI4_NoC.v)
 * @param OVERLAPPING_ADDRS specifies if the address ranges between different external Slaves. The reordering operation
 *        changes when==true, in which case load-balancing is also activated.
 * @param M_FIFO_DEPTHS specifies the buffer slots of the AW,W,B,AR,R channel inp/outp buffering at the Slave NIs (connected to External Masters).
 *        Slave NI i's buffer slots are found at 5*(i+1)*32-1 : 5*i*32. Within this range, the buffering for the
 *        AW,W,B,AR,R channels is found in positions 5*i*32+5*32,...,5*i*32+1*32,5*i*32 respectively
 * @param S_FIFO_DEPTHS specifies the buffer slots of the AW,W,B,AR,R channel inp/outp buffering at the Master NIs (connected to External Slaves).
 *        Master NI i's buffer slots are found at 5*(i+1)*32-1 : 5*i*32. Within this range, the buffering for the
 *        AW,W,B,AR,R channels is found in positions 5*i*32+5*32,...,5*i*32+1*32,5*i*32 respectively
 * @param ASSERT_READYVALID specifies if AXI channels are checked for consistency with AXI Specifications
 *        (e.g. a Valid is not dropped when the receiver stalls, until a successful reception)
 */
 
import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;

module axi4_duth_noc
#(
    parameter int TIDS_M                                       = 1,
    parameter int ADDRESS_WIDTH                                = 32,
    parameter int DATA_LANES                                   = 4,
    parameter int USER_WIDTH                                   = 1,
    parameter int EXT_MASTERS                                  = 1,
    parameter int EXT_SLAVES                                   = 1,
    // NoC
    parameter int NOC_HOP_COUNT_REQ                            = 1,
    parameter int NOC_HOP_COUNT_RESP                           = 1,
    parameter int MAX_LINK_WIDTH_REQ_IN                        = 0,
    parameter int MAX_LINK_WIDTH_RESP_IN                       = 0,
    parameter logic SHARED_WR_PATH                             = 1'b1,
    // NI
    parameter int MAX_PENDING_SAME_DST                      = 256,
    parameter logic[EXT_SLAVES*ADDRESS_WIDTH-1:0] ADDR_BASE = {EXT_SLAVES*ADDRESS_WIDTH{1'b0}},
    parameter logic[32*EXT_SLAVES-1:0] ADDR_RANGE           = {EXT_SLAVES{32'd32}}, // can't have unpacked array of ints, 32-bit each then
    parameter logic[32*EXT_MASTERS*5-1:0] M_FIFO_DEPTHS     = {EXT_MASTERS*5{32'd2}},
    parameter logic[32*EXT_SLAVES*5-1:0] S_FIFO_DEPTHS      = {EXT_SLAVES*5{32'd2}},
    parameter logic ASSERT_READYVALID                       = 1'b0,
    // NEW
    parameter int STIDW                                     = log2c_1if1(TIDS_M),
    parameter int MTIDW                                     = log2c_1if1(TIDS_M) + log2c_1if1(EXT_MASTERS),
    parameter int AW                                        = ADDRESS_WIDTH,
    parameter int USERW                                     = USER_WIDTH,
    parameter int DW                                        = 8*DATA_LANES
    
 )
(
    input logic clk,
    input logic rst,
    // -- Slave AXI interface -- //
    // AW (Write Address) channel (NI -> Target)
    input  logic[EXT_MASTERS-1:0][STIDW-1:0]        axi_s_aw_id_i,    // AWID
    input  logic[EXT_MASTERS-1:0][AW-1:0]           axi_s_aw_addr_i,  // AWADDR
    input  logic[EXT_MASTERS-1:0][7:0]              axi_s_aw_len_i,   // AWLEN
    input  logic[EXT_MASTERS-1:0][2:0]              axi_s_aw_size_i,  // AWSIZE
    input  logic[EXT_MASTERS-1:0][1:0]              axi_s_aw_burst_i, // AWBURST
    input  logic[EXT_MASTERS-1:0][1:0]              axi_s_aw_lock_i,  // AWLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support) 
    input  logic[EXT_MASTERS-1:0][3:0]              axi_s_aw_cache_i, // AWCACHE
    input  logic[EXT_MASTERS-1:0][2:0]              axi_s_aw_prot_i,  // AWPROT
    input  logic[EXT_MASTERS-1:0][3:0]              axi_s_aw_qos_i,   // AWQOS
    input  logic[EXT_MASTERS-1:0][3:0]              axi_s_aw_region_i,// AWREGION
    input  logic[EXT_MASTERS-1:0][USERW-1:0]        axi_s_aw_user_i,  // AWUSER
    input  logic[EXT_MASTERS-1:0]                   axi_s_aw_valid_i, // AWVALID
    output logic[EXT_MASTERS-1:0]                   axi_s_aw_ready_o, // AWREADY
    // W (Write Data) channel (NI -> Target)
    input  logic[EXT_MASTERS-1:0][STIDW-1:0]        axi_s_w_id_i,     // WID / driven only under AXI_VER==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
    input  logic[EXT_MASTERS-1:0][DW-1:0]           axi_s_w_data_i,   // WDATA
    input  logic[EXT_MASTERS-1:0][DW/8-1:0]         axi_s_w_strb_i,   // WSTRB
    input  logic[EXT_MASTERS-1:0]                   axi_s_w_last_i,   // WLAST
    input  logic[EXT_MASTERS-1:0][USERW-1:0]        axi_s_w_user_i,   // WUSER / tied to zero
    input  logic[EXT_MASTERS-1:0]                   axi_s_w_valid_i,  // WVALID
    output logic[EXT_MASTERS-1:0]                   axi_s_w_ready_o,  // WREADY
    // B (Write Response) channel (Target -> NI)
    output logic[EXT_MASTERS-1:0][STIDW-1:0]        axi_s_b_id_o,     // BID
    output logic[EXT_MASTERS-1:0][1:0]              axi_s_b_resp_o,   // BRESP
    output logic[EXT_MASTERS-1:0][USERW-1:0]        axi_s_b_user_o,   // BUSER
    output logic[EXT_MASTERS-1:0]                   axi_s_b_valid_o,  // BVALID
    input  logic[EXT_MASTERS-1:0]                   axi_s_b_ready_i,  // BREADY
    // AR (Read Address) channel (NI -> Target)
    input  logic[EXT_MASTERS-1:0][STIDW-1:0]        axi_s_ar_id_i,    // ARID
    input  logic[EXT_MASTERS-1:0][AW-1:0]           axi_s_ar_addr_i,  // ARADDR
    input  logic[EXT_MASTERS-1:0][7:0]              axi_s_ar_len_i,   // ARLEN
    input  logic[EXT_MASTERS-1:0][2:0]              axi_s_ar_size_i,  // ARSIZE
    input  logic[EXT_MASTERS-1:0][1:0]              axi_s_ar_burst_i, // ARBURST
    input  logic[EXT_MASTERS-1:0][1:0]              axi_s_ar_lock_i,  // ARLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support)
    input  logic[EXT_MASTERS-1:0][3:0]              axi_s_ar_cache_i, // ARCACHE
    input  logic[EXT_MASTERS-1:0][2:0]              axi_s_ar_prot_i,  // ARPROT
    input  logic[EXT_MASTERS-1:0][3:0]              axi_s_ar_qos_i,   // ARQOS
    input  logic[EXT_MASTERS-1:0][3:0]              axi_s_ar_region_i,// ARREGION
    input  logic[EXT_MASTERS-1:0][USERW-1:0]        axi_s_ar_user_i,  // ARUSER
    input  logic[EXT_MASTERS-1:0]                   axi_s_ar_valid_i, // ARVALID
    output logic[EXT_MASTERS-1:0]                   axi_s_ar_ready_o, // ARREADY
    // R (Read Data) channel (Target -> NI)
    output logic[EXT_MASTERS-1:0][STIDW-1:0]        axi_s_r_id_o,     // RID
    output logic[EXT_MASTERS-1:0][DW-1:0]           axi_s_r_data_o,   // RDATA
    output logic[EXT_MASTERS-1:0][1:0]              axi_s_r_resp_o,   // RRESP
    output logic[EXT_MASTERS-1:0]                   axi_s_r_last_o,   // RLAST
    output logic[EXT_MASTERS-1:0][USERW-1:0]        axi_s_r_user_o,   // RUSER
    output logic[EXT_MASTERS-1:0]                   axi_s_r_valid_o,  // RVALID
    input  logic[EXT_MASTERS-1:0]                   axi_s_r_ready_i,  // RREADY
    // -- Master AXI interface -- //
    // AW (Write Address) channel (NI -> Target)
    output logic[EXT_SLAVES-1:0][MTIDW-1:0]         axi_m_aw_id_o,    // AWID
    output logic[EXT_SLAVES-1:0][AW-1:0]            axi_m_aw_addr_o,  // AWADDR
    output logic[EXT_SLAVES-1:0][7:0]               axi_m_aw_len_o,   // AWLEN
    output logic[EXT_SLAVES-1:0][2:0]               axi_m_aw_size_o,  // AWSIZE
    output logic[EXT_SLAVES-1:0][1:0]               axi_m_aw_burst_o, // AWBURST
    output logic[EXT_SLAVES-1:0][1:0]               axi_m_aw_lock_o,  // AWLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support) 
    output logic[EXT_SLAVES-1:0][3:0]               axi_m_aw_cache_o, // AWCACHE
    output logic[EXT_SLAVES-1:0][2:0]               axi_m_aw_prot_o,  // AWPROT
    output logic[EXT_SLAVES-1:0][3:0]               axi_m_aw_qos_o,   // AWQOS
    output logic[EXT_SLAVES-1:0][3:0]               axi_m_aw_region_o,// AWREGION
    output logic[EXT_SLAVES-1:0][USERW-1:0]         axi_m_aw_user_o,  // AWUSER
    output logic[EXT_SLAVES-1:0]                    axi_m_aw_valid_o, // AWVALID
    input  logic[EXT_SLAVES-1:0]                    axi_m_aw_ready_i, // AWREADY
    // W (Write Data) channel (NI -> Target)
    output logic[EXT_SLAVES-1:0][MTIDW-1:0]         axi_m_w_id_o,     // WID / driven only under AXI_VER==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
    output logic[EXT_SLAVES-1:0][DW-1:0]            axi_m_w_data_o,   // WDATA
    output logic[EXT_SLAVES-1:0][DW/8-1:0]          axi_m_w_strb_o,   // WSTRB
    output logic[EXT_SLAVES-1:0]                    axi_m_w_last_o,   // WLAST
    output logic[EXT_SLAVES-1:0][USERW-1:0]         axi_m_w_user_o,   // WUSER / tied to zero
    output logic[EXT_SLAVES-1:0]                    axi_m_w_valid_o,  // WVALID
    input  logic[EXT_SLAVES-1:0]                    axi_m_w_ready_i,  // WREADY
    // B (Write Response) channel (Target -> NI)
    input  logic[EXT_SLAVES-1:0][MTIDW-1:0]         axi_m_b_id_i,     // BID
    input  logic[EXT_SLAVES-1:0][1:0]               axi_m_b_resp_i,   // BRESP
    input  logic[EXT_SLAVES-1:0][USERW-1:0]         axi_m_b_user_i,   // BUSER
    input  logic[EXT_SLAVES-1:0]                    axi_m_b_valid_i,  // BVALID
    output logic[EXT_SLAVES-1:0]                    axi_m_b_ready_o,  // BREADY
    // AR (Read Address) channel (NI -> Target)
    output logic[EXT_SLAVES-1:0][MTIDW-1:0]         axi_m_ar_id_o,    // ARID
    output logic[EXT_SLAVES-1:0][AW-1:0]            axi_m_ar_addr_o,  // ARADDR
    output logic[EXT_SLAVES-1:0][7:0]               axi_m_ar_len_o,   // ARLEN
    output logic[EXT_SLAVES-1:0][2:0]               axi_m_ar_size_o,  // ARSIZE
    output logic[EXT_SLAVES-1:0][1:0]               axi_m_ar_burst_o, // ARBURST
    output logic[EXT_SLAVES-1:0][1:0]               axi_m_ar_lock_o,  // ARLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support)
    output logic[EXT_SLAVES-1:0][3:0]               axi_m_ar_cache_o, // ARCACHE
    output logic[EXT_SLAVES-1:0][2:0]               axi_m_ar_prot_o,  // ARPROT
    output logic[EXT_SLAVES-1:0][3:0]               axi_m_ar_qos_o,   // ARQOS
    output logic[EXT_SLAVES-1:0][3:0]               axi_m_ar_region_o,// ARREGION
    output logic[EXT_SLAVES-1:0][USERW-1:0]         axi_m_ar_user_o,  // ARUSER
    output logic[EXT_SLAVES-1:0]                    axi_m_ar_valid_o, // ARVALID
    input  logic[EXT_SLAVES-1:0]                    axi_m_ar_ready_i, // ARREADY
    // R (Read Data) channel (Target -> NI)
    input  logic[EXT_SLAVES-1:0][MTIDW-1:0]         axi_m_r_id_i,     // RID
    input  logic[EXT_SLAVES-1:0][DW-1:0]            axi_m_r_data_i,   // RDATA
    input  logic[EXT_SLAVES-1:0][1:0]               axi_m_r_resp_i,   // RRESP
    input  logic[EXT_SLAVES-1:0]                    axi_m_r_last_i,   // RLAST
    input  logic[EXT_SLAVES-1:0][USERW-1:0]         axi_m_r_user_i,   // RUSER
    input  logic[EXT_SLAVES-1:0]                    axi_m_r_valid_i,  // RVALID
    output logic[EXT_SLAVES-1:0]                    axi_m_r_ready_o  // RREADY    
);



initial begin
    #0;
    assert (SHARED_WR_PATH) else $fatal(1, "separate W/R paths not supported [Replace routers]");
end

    // -- Flow Control & Buffering options -------------------------------------------------------- //
    // modify with caution!
    localparam link_fc_params_snd_type NI_NOC_FC_SND    = NI_NOC_ZERO_BUFF_FC_SND;
                                                          //NI_NOC_CREDITS_3_FC_SND;
    localparam link_fc_params_rcv_type NOC_NI_FC_RCV    = NOC_NI_ZERO_BUFF_FC_RCV;
                                                          //NOC_NI_CREDITS_3_FC_RCV;
    localparam link_fc_params_snd_type NOC_FC_SND       = RTR_ELASTIC_FC_SND;
                                                          //RTR_CREDITS_3_FC_SND;
    localparam link_fc_params_rcv_type NOC_FC_RCV       = RTR_ELASTIC_FC_RCV;
                                                          //RTR_CREDITS_3_FC_RCV;
    
    // -------------------------------------------------------------------------------------------- //
    
    // -- AXI Channel Widths ---------------------------------------------------------------------- //
    // (External) Master Side
    localparam int AXI_W_AWR_M = log2c_1if1(TIDS_M) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS;
    localparam int AXI_W_W_M   = log2c_1if1(TIDS_M) + 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST;
    localparam int AXI_W_B_M   = log2c_1if1(TIDS_M) + USER_WIDTH + AXI_SPECS_WIDTH_RESP;
    localparam int AXI_W_R_M   = log2c_1if1(TIDS_M) + 8*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_RESP + AXI_SPECS_WIDTH_LAST;
    // (External) Slave Side
    localparam int AXI_W_AWR_S = log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) + ADDRESS_WIDTH + USER_WIDTH + AXI_W_AWR_STD_FIELDS;
    localparam int AXI_W_W_S   = log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) + 9*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_LAST;
    localparam int AXI_W_B_S   = log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) + USER_WIDTH + AXI_SPECS_WIDTH_RESP;
    localparam int AXI_W_R_S   = log2c_1if1(TIDS_M) + log2c(EXT_MASTERS) + 8*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_RESP + AXI_SPECS_WIDTH_LAST;
    // -------------------------------------------------------------------------------------------- //
    
    
logic[EXT_MASTERS*AXI_W_AWR_M-1:0]  s_aw_chan;
logic[EXT_MASTERS*AXI_W_W_M-1:0]    s_w_chan;
logic[EXT_MASTERS*AXI_W_B_M-1:0]    s_b_chan;
logic[EXT_MASTERS*AXI_W_AWR_M-1:0]  s_ar_chan;
logic[EXT_MASTERS*AXI_W_R_M-1:0]    s_r_chan;
logic[EXT_SLAVES*AXI_W_AWR_S-1:0]   m_aw_chan;
logic[EXT_SLAVES*AXI_W_W_S-1:0]     m_w_chan;
logic[EXT_SLAVES*AXI_W_B_S-1:0]     m_b_chan;
logic[EXT_SLAVES*AXI_W_AWR_S-1:0]   m_ar_chan;
logic[EXT_SLAVES*AXI_W_R_S-1:0]     m_r_chan;

for (genvar m=0; m<EXT_MASTERS; m++) begin: for_m_pass
    assign s_aw_chan[m*AXI_W_AWR_M +: AXI_W_AWR_M]  = {axi_s_aw_user_i[m], axi_s_aw_region_i[m], axi_s_aw_qos_i[m], axi_s_aw_prot_i[m], axi_s_aw_cache_i[m], axi_s_aw_lock_i[m][0], axi_s_aw_burst_i[m], axi_s_aw_size_i[m], axi_s_aw_len_i[m], axi_s_aw_addr_i[m], axi_s_aw_id_i[m]};
    assign s_w_chan[m*AXI_W_W_M +: AXI_W_W_M]       = {axi_s_w_user_i[m], axi_s_w_last_i[m], axi_s_w_strb_i[m], axi_s_w_data_i[m],  axi_s_w_id_i[m]};
    assign {axi_s_b_user_o[m], axi_s_b_resp_o[m], axi_s_b_id_o[m]} = s_b_chan[m*AXI_W_B_M +: AXI_W_B_M];
    assign s_ar_chan[m*AXI_W_AWR_M +: AXI_W_AWR_M]  = {axi_s_ar_user_i[m], axi_s_ar_region_i[m], axi_s_ar_qos_i[m], axi_s_ar_prot_i[m], axi_s_ar_cache_i[m], axi_s_ar_lock_i[m][0], axi_s_ar_burst_i[m], axi_s_ar_size_i[m], axi_s_ar_len_i[m], axi_s_ar_addr_i[m], axi_s_ar_id_i[m]};
    assign {axi_s_r_user_o[m], axi_s_r_last_o[m], axi_s_r_resp_o[m], axi_s_r_data_o[m], axi_s_r_id_o[m]} = s_r_chan[m*AXI_W_R_M +: AXI_W_R_M];
end
for (genvar s=0; s<EXT_SLAVES; s++) begin: for_s_pass
    if (EXT_MASTERS > 1) begin: if_m_gt1
        assign {axi_m_aw_user_o[s], axi_m_aw_region_o[s], axi_m_aw_qos_o[s], axi_m_aw_prot_o[s], axi_m_aw_cache_o[s], axi_m_aw_lock_o[s][0], axi_m_aw_burst_o[s], axi_m_aw_size_o[s], axi_m_aw_len_o[s], axi_m_aw_addr_o[s], axi_m_aw_id_o[s]} = m_aw_chan[s*AXI_W_AWR_S +: AXI_W_AWR_S];
        assign {axi_m_w_user_o[s], axi_m_w_last_o[s], axi_m_w_strb_o[s], axi_m_w_data_o[s],  axi_m_w_id_o[s]} = m_w_chan[s*AXI_W_W_S +: AXI_W_W_S];
        assign m_b_chan[s*AXI_W_B_S +: AXI_W_B_S] = {axi_m_b_user_i[s], axi_m_b_resp_i[s], axi_m_b_id_i[s]};
        assign {axi_m_ar_user_o[s], axi_m_ar_region_o[s], axi_m_ar_qos_o[s], axi_m_ar_prot_o[s], axi_m_ar_cache_o[s], axi_m_ar_lock_o[s][0], axi_m_ar_burst_o[s], axi_m_ar_size_o[s], axi_m_ar_len_o[s], axi_m_ar_addr_o[s], axi_m_ar_id_o[s]} = m_ar_chan[s*AXI_W_AWR_S +: AXI_W_AWR_S];
        assign m_r_chan[s*AXI_W_R_S +: AXI_W_R_S] = {axi_m_r_user_i[s], axi_m_r_last_i[s], axi_m_r_resp_i[s], axi_m_r_data_i[s], axi_m_r_id_i[s]};
    end else begin: if_m_eq1
        assign {axi_m_aw_user_o[s], axi_m_aw_region_o[s], axi_m_aw_qos_o[s], axi_m_aw_prot_o[s], axi_m_aw_cache_o[s], axi_m_aw_lock_o[s][0], axi_m_aw_burst_o[s], axi_m_aw_size_o[s], axi_m_aw_len_o[s], axi_m_aw_addr_o[s], axi_m_aw_id_o[s]} = {m_aw_chan[s*AXI_W_AWR_S +: AXI_W_AWR_S], 1'b0};
        assign {axi_m_w_user_o[s], axi_m_w_last_o[s], axi_m_w_strb_o[s], axi_m_w_data_o[s],  axi_m_w_id_o[s]} = {m_w_chan[s*AXI_W_W_S +: AXI_W_W_S], 1'b0};
        assign m_b_chan[s*AXI_W_B_S +: AXI_W_B_S] = {axi_m_b_user_i[s], axi_m_b_resp_i[s], axi_m_b_id_i[s][1 +: log2c_1if1(TIDS_M)]};
        assign {axi_m_ar_user_o[s], axi_m_ar_region_o[s], axi_m_ar_qos_o[s], axi_m_ar_prot_o[s], axi_m_ar_cache_o[s], axi_m_ar_lock_o[s][0], axi_m_ar_burst_o[s], axi_m_ar_size_o[s], axi_m_ar_len_o[s], axi_m_ar_addr_o[s], axi_m_ar_id_o[s]} = {m_ar_chan[s*AXI_W_AWR_S +: AXI_W_AWR_S], 1'b0};
        assign m_r_chan[s*AXI_W_R_S +: AXI_W_R_S] = {axi_m_r_user_i[s], axi_m_r_last_i[s], axi_m_r_resp_i[s], axi_m_r_data_i[s], axi_m_r_id_i[s][1 +: log2c_1if1(TIDS_M)]};
    end
end
    
    
    
    
    
    
    
    
// -- Serialization & Width params for packetizing -------------------------------------------- //
// Headers
localparam int W_HEADER_FULL  = log2c(TIDS_M) + log2c(EXT_SLAVES) + log2c(EXT_MASTERS) + 1 + 1 + FLIT_FIELD_WIDTH;
localparam int W_HEADER_SMALL = 1 + 1 + FLIT_FIELD_WIDTH;
// If zero max widths -> set to max possible
localparam int MAX_LINK_WIDTH_REQ  = (MAX_LINK_WIDTH_REQ_IN  == 0) ? W_HEADER_FULL + AXI_W_AWR_M + AXI_W_W_M : MAX_LINK_WIDTH_REQ_IN;
localparam int MAX_LINK_WIDTH_RESP = (MAX_LINK_WIDTH_RESP_IN == 0) ? W_HEADER_FULL + AXI_W_AWR_M + AXI_W_W_M : MAX_LINK_WIDTH_RESP_IN;
// ADDR
localparam int ADDR_PENALTY = get_addr_penalty(MAX_LINK_WIDTH_REQ,          AXI_W_AWR_M - log2c_1if1(TIDS_M), AXI_W_W_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam int FW_REQ_ADDR  = get_addr_flit_width_first(MAX_LINK_WIDTH_REQ, AXI_W_AWR_M - log2c_1if1(TIDS_M), AXI_W_W_M - log2c_1if1(TIDS_M), W_HEADER_FULL);
// DATA
localparam int FLITS_PER_DATA = get_flits_per_data(MAX_LINK_WIDTH_REQ,        AXI_W_AWR_M - log2c_1if1(TIDS_M), AXI_W_W_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam int FW_REQ_DATA    = get_data_flit_width_first(MAX_LINK_WIDTH_REQ, AXI_W_AWR_M - log2c_1if1(TIDS_M), AXI_W_W_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
// Overall (maximum of ADDR/DATA)
localparam int FW_REQ = get_max2(FW_REQ_ADDR, FW_REQ_DATA);
// Paddings
localparam int FW_ADDR_PAD_LAST = get_addr_flit_pad_last(FW_REQ, AXI_W_AWR_M - log2c_1if1(TIDS_M), AXI_W_W_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam int FW_DATA_PAD_LAST = get_data_flit_pad_last(FW_REQ, AXI_W_AWR_M - log2c_1if1(TIDS_M), AXI_W_W_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
// to avoid getting flits = 0, trick function
localparam int FLITS_PER_WRITE_RESP = get_flits_per_resp(MAX_LINK_WIDTH_RESP,        AXI_W_B_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam int FW_RESP_WRITE        = get_resp_flit_width_first(MAX_LINK_WIDTH_RESP, AXI_W_B_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);

localparam int FLITS_PER_READ_RESP = get_flits_per_resp(MAX_LINK_WIDTH_RESP,         AXI_W_R_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam int FW_RESP_READ        = get_resp_flit_width_first(MAX_LINK_WIDTH_RESP,  AXI_W_R_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);

localparam int FW_RESP = get_max2(FW_RESP_WRITE, FW_RESP_READ);

localparam int FW_WRITE_RESP_PAD_LAST = get_resp_flit_pad_last(FW_RESP, AXI_W_B_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam int FW_READ_RESP_PAD_LAST  = get_resp_flit_pad_last(FW_RESP, AXI_W_R_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
// -------------------------------------------------------------------------------------------- //

// -- Address Ranges served by (external) Slaves ---------------------------------------------- //
// Calculate lower address bound for each Slave
function logic[EXT_SLAVES*ADDRESS_WIDTH-1:0] get_addr_lo();
    logic[EXT_SLAVES*ADDRESS_WIDTH-1:0] ret;
    for (int i = 0; i < EXT_SLAVES; i++) begin
        ret[i*ADDRESS_WIDTH +: ADDRESS_WIDTH] = ADDR_BASE[i*ADDRESS_WIDTH +: ADDRESS_WIDTH] & ({ADDRESS_WIDTH{1'b1}} << ADDR_RANGE[i*32 +: 32]);
    end
    
    return ret;
endfunction

// Calculate higher address bound for each Slave
function logic[EXT_SLAVES*ADDRESS_WIDTH-1:0] get_addr_hi();
    logic[EXT_SLAVES*ADDRESS_WIDTH-1:0] ret;
    for (int i = 0; i < EXT_SLAVES; i++) begin
        ret[i*ADDRESS_WIDTH +: ADDRESS_WIDTH] = ADDR_BASE[i*ADDRESS_WIDTH +: ADDRESS_WIDTH] | ~({ADDRESS_WIDTH{1'b1}} << ADDR_RANGE[i*32 +: 32]);
    end
    
    return ret;
endfunction

localparam logic[EXT_SLAVES*ADDRESS_WIDTH-1:0] ADDRS_LO = get_addr_lo();
localparam logic[EXT_SLAVES*ADDRESS_WIDTH-1:0] ADDRS_HI = get_addr_hi();

// Check if addresses may be served by multiple slaves
function logic addresses_overlap(logic[EXT_SLAVES*ADDRESS_WIDTH-1:0] a_lo, logic[EXT_SLAVES*ADDRESS_WIDTH-1:0] a_hi);
    logic out_of_range;

    for (int i = 0; i < EXT_SLAVES-1; i++) begin
        for (int j = i+1; j < EXT_SLAVES; j++) begin
            // i'm out of range if at lower or higher addresses than comparer
            out_of_range = (a_hi[j*ADDRESS_WIDTH +: ADDRESS_WIDTH] < a_lo[i*ADDRESS_WIDTH +: ADDRESS_WIDTH]) || // lower
                           (a_lo[j*ADDRESS_WIDTH +: ADDRESS_WIDTH] > a_hi[i*ADDRESS_WIDTH +: ADDRESS_WIDTH]);   // higher
            if (!out_of_range)
                return 1'b1;
        end
    end
    
    return 1'b0;
endfunction

localparam logic OVERLAPPING_ADDRS = addresses_overlap(ADDRS_LO, ADDRS_HI);
// -------------------------------------------------------------------------------------------- //

// pragma synthesis_off
// pragma translate_off
initial begin
    // Legal Flit Widths
    assert (MAX_LINK_WIDTH_REQ >= W_HEADER_FULL) else
        $fatal(1, "Req Flit width too small! Is %0d must be >= %0d", MAX_LINK_WIDTH_REQ, W_HEADER_FULL);
    assert (MAX_LINK_WIDTH_RESP >= W_HEADER_FULL) else
        $fatal(1, "Req Flit width too small! Is %0d must be >= %0d", MAX_LINK_WIDTH_RESP, W_HEADER_FULL);
        
    // Addresses
    $display(" ------ Addresses in NoC ------ ");
    for (int i = 0; i < EXT_SLAVES; i++) begin
        $write("To Slave %0d (HI <- LO):   %h <- %h\n", i, ADDRS_HI[i*ADDRESS_WIDTH +: ADDRESS_WIDTH], ADDRS_LO[i*ADDRESS_WIDTH +: ADDRESS_WIDTH]);
    end
    $display("Overlapping? %s", OVERLAPPING_ADDRS?"yes":"no");
    // Req
    $display("- Req Flits -");
    $write("ADDR: %0d flits, %0d bits (p: %0d)\n", ADDR_PENALTY, FW_REQ_ADDR, FW_ADDR_PAD_LAST);
    $write("DATA: %0d flits, %0d bits (p: %0d)\n", FLITS_PER_DATA, FW_REQ_DATA, FW_DATA_PAD_LAST);
    $write("final: %0d bits\n", FW_REQ);
    // Resp
    $display("- Resp Flits -");
    $write("WRITE: %0d flits, %0d bits(p: %0d)\n", FLITS_PER_WRITE_RESP, FW_RESP_WRITE, FW_WRITE_RESP_PAD_LAST);
    $write("READ: %0d flits, %0d bits (p: %0d)\n", FLITS_PER_READ_RESP, FW_RESP_READ, FW_READ_RESP_PAD_LAST);
    $write("final: %0d bits\n", FW_RESP);
    $write("------------------------------------\n");
end
// pragma translate_on
// pragma synthesis_on

// ----------------------------------------------------------------//
if (SHARED_WR_PATH) begin: shared_wr            
    // shared RW
    logic[FW_REQ-1:0]      req_flit_from_slave_ni[EXT_MASTERS-1:0];
    logic[EXT_MASTERS-1:0] req_valid_from_slave_ni;
    logic[EXT_MASTERS-1:0] req_notify_to_slave_ni;
    logic[EXT_MASTERS*FW_REQ-1:0] req_flit_to_noc;
    logic[EXT_MASTERS*FW_RESP-1:0] resp_flit_from_noc;
    logic[FW_RESP-1:0] resp_flit_to_slave_ni[EXT_MASTERS-1:0];
    logic[EXT_MASTERS-1:0] resp_valid_to_slave_ni;
    logic[EXT_MASTERS-1:0] resp_notify_from_slave_ni;
    logic[EXT_SLAVES*FW_REQ-1:0] req_flit_from_noc;
    logic[FW_REQ-1:0]       req_flit_to_master_ni[EXT_SLAVES-1:0];
    logic[EXT_SLAVES-1:0]   req_valid_to_master_ni;
    logic[EXT_SLAVES-1:0]   req_notify_from_master_ni;
    logic[EXT_SLAVES*FW_RESP-1:0] resp_flit_to_noc;
    logic[FW_RESP-1:0] resp_flit_from_master_ni[EXT_SLAVES-1:0];
    logic[EXT_SLAVES-1:0] resp_valid_from_master_ni;
    logic[EXT_SLAVES-1:0] resp_notify_to_master_ni;
    // ------------------------------- //
    //    Masters <-> NoC interfaces   //
    // ------------------------------- //
    for (genvar m = 0; m < EXT_MASTERS; m++) begin: for_m
        // Slave NI
        axi_slave_ni #( .MASTER_ID              (m),
                        .TIDS_M                 (TIDS_M),
                        .ADDRESS_WIDTH          (ADDRESS_WIDTH),
                        .DATA_LANES             (DATA_LANES),
                        .USER_WIDTH             (USER_WIDTH),
                        .EXT_MASTERS            (EXT_MASTERS),
                        .EXT_SLAVES             (EXT_SLAVES),
                        .HAS_WRITE              (1'b1), // <----------------
                        .HAS_READ               (1'b1), // <----------------
                        .MAX_LINK_WIDTH_REQ     (MAX_LINK_WIDTH_REQ),
                        .MAX_LINK_WIDTH_RESP    (MAX_LINK_WIDTH_RESP),
                        .MAX_PENDING_SAME_DST   (MAX_PENDING_SAME_DST),
                        .ADDRS_LO               (ADDRS_LO),
                        .ADDRS_HI               (ADDRS_HI),
                        .OVERLAPPING_ADDRS      (OVERLAPPING_ADDRS),
                        .AW_FIFO_DEPTH          (int'(M_FIFO_DEPTHS[m*5*32+5*32-1 : m*5*32+4*32])),
                        .W_FIFO_DEPTH           (int'(M_FIFO_DEPTHS[m*5*32+4*32-1 : m*5*32+3*32])),
                        .B_FIFO_DEPTH           (int'(M_FIFO_DEPTHS[m*5*32+3*32-1 : m*5*32+2*32])),
                        .AR_FIFO_DEPTH          (int'(M_FIFO_DEPTHS[m*5*32+2*32-1 : m*5*32+1*32])),
                        .R_FIFO_DEPTH           (int'(M_FIFO_DEPTHS[m*5*32+1*32-1 : m*5*32+0*32])),
                        .FLIT_WIDTH_REQ_C       (FW_REQ),
                        .FLIT_WIDTH_RESP_C      (FW_RESP),
                        .NI_NOC_FC_SND          (NI_NOC_FC_SND),
                        .NOC_NI_FC_RCV          (NOC_NI_FC_RCV),
                        .ASSERT_RV              (ASSERT_READYVALID)
                ) s_ni (
                        .clk                    (clk),
                        .rst                    (rst),
                        
                        .aw_chan                (s_aw_chan[(m+1)*AXI_W_AWR_M-1 : m*AXI_W_AWR_M]),
                        .aw_valid               (axi_s_aw_valid_i[m]),
                        .aw_ready               (axi_s_aw_ready_o[m]),
                        
                        .w_chan                 (s_w_chan[(m+1)*AXI_W_W_M-1 : m*AXI_W_W_M]),
                        .w_valid                (axi_s_w_valid_i[m]),
                        .w_ready                (axi_s_w_ready_o[m]),
                        
                        .ar_chan                (s_ar_chan[(m+1)*AXI_W_AWR_M-1 : m*AXI_W_AWR_M]),
                        .ar_valid               (axi_s_ar_valid_i[m]),
                        .ar_ready               (axi_s_ar_ready_o[m]),
                        
                        .b_chan                 (s_b_chan[(m+1)*AXI_W_B_M-1 : m*AXI_W_B_M]),
                        .b_valid                (axi_s_b_valid_o[m]),
                        .b_ready                (axi_s_b_ready_i[m]),
                        
                        .r_chan                 (s_r_chan[(m+1)*AXI_W_R_M-1 : m*AXI_W_R_M]),
                        .r_valid                (axi_s_r_valid_o[m]),
                        .r_ready                (axi_s_r_ready_i[m]),
                        
                        .req_flit_to_noc        (req_flit_from_slave_ni[m]),
                        .req_valid_to_noc       (req_valid_from_slave_ni[m]),
                        .req_ready_from_noc     (req_notify_to_slave_ni[m]),
                        
                        .resp_flit_from_noc     (resp_flit_to_slave_ni[m]),
                        .resp_valid_from_noc    (resp_valid_to_slave_ni[m]),
                        .resp_ready_to_noc      (resp_notify_from_slave_ni[m]));
        
        assign req_flit_to_noc[(m+1)*FW_REQ-1 : m*FW_REQ] = req_flit_from_slave_ni[m];
        assign resp_flit_to_slave_ni[m]                   = resp_flit_from_noc[(m+1)*FW_RESP-1 : m*FW_RESP];
    end
    
    
    // Request Network
    // noc_topo_hop_tree #( .HOP_COUNT      (NOC_HOP_COUNT_REQ),
                // .FLIT_WIDTH     (FW_REQ),
                // .IN_PORTS       (EXT_MASTERS),
                // .OUT_PORTS      (EXT_SLAVES),
                // .DST_PNT        (FLIT_FIELD_WIDTH+1+log2c(EXT_MASTERS)),
                // .DST_ADDR_WIDTH (log2c(EXT_SLAVES)),
                // .INP_FC_PARAMS  (NOC_FC_RCV),
                // .OUT_FC_PARAMS  (NOC_FC_SND)
          // ) req_noc (
              // .clk          (clk),
              // .rst          (rst),
              // .data_in      (req_flit_to_noc),
              // .valid_in     (req_valid_from_slave_ni),
              // .back_notify  (req_notify_to_slave_ni),
              // .data_out     (req_flit_from_noc),
              // .valid_out    (req_valid_to_master_ni),
              // .front_notify (req_notify_from_master_ni));
    router
    #(
        .FLIT_WIDTH     (FW_REQ),
        .IN_PORTS       (EXT_MASTERS),
        .OUT_PORTS      (EXT_SLAVES),
        .NODE_ID        (0),
        .RC_ALGO        (RC_ALGO_XBAR),
        .DST_PNT        (FLIT_FIELD_WIDTH+1+log2c(EXT_MASTERS)),
        .DST_ADDR_WIDTH (log2c(EXT_SLAVES)),
        .NO_RETURNS     (1'b0),
        .INP_FC_PARAMS  (NOC_FC_RCV),
        .OUT_FC_PARAMS  (NOC_FC_SND)
    )
    req_noc
    (
        .clk          (clk),
        .rst          (rst),
        .data_in      (req_flit_to_noc),
        .valid_in     (req_valid_from_slave_ni),
        .back_notify  (req_notify_to_slave_ni),
        .data_out     (req_flit_from_noc),
        .valid_out    (req_valid_to_master_ni),
        .front_notify (req_notify_from_master_ni)
    );
    
    
    // Response Network
    router
    #(
        .FLIT_WIDTH         (FW_RESP),
        .IN_PORTS           (EXT_SLAVES),
        .OUT_PORTS          (EXT_MASTERS),
        .NODE_ID            (0),
        .RC_ALGO            (RC_ALGO_XBAR),
        .DST_PNT            (FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES)),
        .DST_ADDR_WIDTH     ($clog2(EXT_MASTERS)),  
        .NO_RETURNS         (1'b0),
        .INP_FC_PARAMS      (NOC_FC_RCV),
        .OUT_FC_PARAMS      (NOC_FC_SND)
    )
    resp_noc
    (
        .clk          (clk),
        .rst          (rst),
        .data_in      (resp_flit_to_noc),
        .valid_in     (resp_valid_from_master_ni),
        .back_notify  (resp_notify_to_master_ni),
        .data_out     (resp_flit_from_noc),
        .valid_out    (resp_valid_to_slave_ni),
        .front_notify (resp_notify_from_slave_ni)
    );
        
    // noc_topo_hop_tree #( .HOP_COUNT        (NOC_HOP_COUNT_RESP),
                // .FLIT_WIDTH       (FW_RESP),
                // .IN_PORTS         (EXT_SLAVES),
                // .OUT_PORTS        (EXT_MASTERS),
                // .DST_PNT          (FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES)),
                // .DST_ADDR_WIDTH   (log2c(EXT_MASTERS)),
                // .INP_FC_PARAMS    (NOC_FC_RCV),
                // .OUT_FC_PARAMS    (NOC_FC_SND)
          // ) resp_noc (
              // .clk          (clk),
              // .rst          (rst),
              // .data_in      (resp_flit_to_noc),
              // .valid_in     (resp_valid_from_master_ni),
              // .back_notify  (resp_notify_to_master_ni),
              // .data_out     (resp_flit_from_noc),
              // .valid_out    (resp_valid_to_slave_ni),
              // .front_notify (resp_notify_from_slave_ni));
              
    for (genvar s = 0; s < EXT_SLAVES; s++) begin: for_s
        assign req_flit_to_master_ni[s]                      = req_flit_from_noc[(s+1)*FW_REQ-1 : s*FW_REQ];
        assign resp_flit_to_noc[(s+1)*FW_RESP-1 : s*FW_RESP] = resp_flit_from_master_ni[s];
        // Master NIs
        axi_master_ni #( .SLAVE_ID              (s),
                         .TIDS_M                (TIDS_M),
                         .ADDRESS_WIDTH         (ADDRESS_WIDTH),
                         .DATA_LANES            (DATA_LANES),
                         .USER_WIDTH            (USER_WIDTH),
                         .EXT_MASTERS           (EXT_MASTERS),
                         .EXT_SLAVES            (EXT_SLAVES),
                         .HAS_WRITE             (1'b1), // <----------------
                         .HAS_READ              (1'b1), // <----------------
                         .MAX_LINK_WIDTH_REQ    (MAX_LINK_WIDTH_REQ),
                         .MAX_LINK_WIDTH_RESP   (MAX_LINK_WIDTH_RESP),
                         .AW_FIFO_DEPTH         (int'(S_FIFO_DEPTHS[s*5*32+5*32-1 : s*5*32+4*32])),
                         .W_FIFO_DEPTH          (int'(S_FIFO_DEPTHS[s*5*32+4*32-1 : s*5*32+3*32])),
                         .B_FIFO_DEPTH          (int'(S_FIFO_DEPTHS[s*5*32+3*32-1 : s*5*32+2*32])),
                         .AR_FIFO_DEPTH         (int'(S_FIFO_DEPTHS[s*5*32+2*32-1 : s*5*32+1*32])),
                         .R_FIFO_DEPTH          (int'(S_FIFO_DEPTHS[s*5*32+1*32-1 : s*5*32+0*32])),
                         .FLIT_WIDTH_REQ_C      (FW_REQ),
                         .FLIT_WIDTH_RESP_C     (FW_RESP),
                         .NI_NOC_FC_SND         (NI_NOC_FC_SND),
                         .NOC_NI_FC_RCV         (NOC_NI_FC_RCV),
                         .ASSERT_RV             (ASSERT_READYVALID)
            ) m_ni (
                     .clk                     (clk),
                     .rst                     (rst),
                        
                     .req_flit_from_noc       (req_flit_to_master_ni[s]),
                     .req_valid_from_noc      (req_valid_to_master_ni[s]),
                     .req_ready_to_noc        (req_notify_from_master_ni[s]),
                     
                     .resp_flit_to_noc        (resp_flit_from_master_ni[s]),
                     .resp_valid_to_noc       (resp_valid_from_master_ni[s]),
                     .resp_ready_from_noc     (resp_notify_to_master_ni[s]),
                     
                     .aw_chan                 (m_aw_chan[(s+1)*AXI_W_AWR_S-1 : s*AXI_W_AWR_S]),
                     .aw_valid                (axi_m_aw_valid_o[s]),
                     .aw_ready                (axi_m_aw_ready_i[s]),
                            
                     .w_chan                  (m_w_chan[(s+1)*AXI_W_W_S-1 : s*AXI_W_W_S]),
                     .w_valid                 (axi_m_w_valid_o[s]),
                     .w_ready                 (axi_m_w_ready_i[s]),
                            
                     .ar_chan                 (m_ar_chan[(s+1)*AXI_W_AWR_S-1 : s*AXI_W_AWR_S]),
                     .ar_valid                (axi_m_ar_valid_o[s]),
                     .ar_ready                (axi_m_ar_ready_i[s]),
                            
                     .b_chan                  (m_b_chan[(s+1)*AXI_W_B_S-1 : s*AXI_W_B_S]),
                     .b_valid                 (axi_m_b_valid_i[s]),
                     .b_ready                 (axi_m_b_ready_o[s]),
                            
                     .r_chan                  (m_r_chan[(s+1)*AXI_W_R_S-1 : s*AXI_W_R_S]),
                     .r_valid                 (axi_m_r_valid_i[s]),
                     .r_ready                 (axi_m_r_ready_o[s]));
    end

end else begin: sep_wr
    localparam int FLIT_WIDTH_REQ_READ = get_addr_flit_width_first(MAX_LINK_WIDTH_REQ, AXI_W_AWR_M - log2c_1if1(TIDS_M), MAX_LINK_WIDTH_REQ+1, W_HEADER_FULL);
    // -- Separate -- //
    logic[EXT_MASTERS-1 : 0][FW_REQ-1:0] w_req_flit_from_slave_ni;
    logic[EXT_MASTERS-1 : 0]             w_req_valid_from_slave_ni;
    logic[EXT_MASTERS-1 : 0]             w_req_notify_to_slave_ni;
    logic[EXT_MASTERS*FW_REQ-1 : 0]      w_req_flit_to_noc;
    
    logic[EXT_MASTERS*FW_RESP_WRITE-1 : 0]  w_resp_flit_from_noc;
    logic[EXT_MASTERS-1 : 0][FW_RESP-1 : 0] w_resp_flit_to_slave_ni;
    logic[EXT_MASTERS-1 : 0]                w_resp_valid_to_slave_ni;
    logic[EXT_MASTERS-1 : 0]                w_resp_notify_from_slave_ni;
    
    // Read Slave NI <-> NoC
    logic[EXT_MASTERS-1 : 0][FW_REQ-1:0]       r_req_flit_from_slave_ni;
    logic[EXT_MASTERS-1 : 0]                   r_req_valid_from_slave_ni;
    logic[EXT_MASTERS-1 : 0]                   r_req_notify_to_slave_ni;
    logic[EXT_MASTERS*FLIT_WIDTH_REQ_READ-1:0] r_req_flit_to_noc;
    
    logic[EXT_MASTERS*FW_RESP-1:0]        r_resp_flit_from_noc;
    logic[EXT_MASTERS-1 : 0][FW_RESP-1:0] r_resp_flit_to_slave_ni;
    logic[EXT_MASTERS-1 : 0]              r_resp_valid_to_slave_ni;
    logic[EXT_MASTERS-1 : 0]              r_resp_notify_from_slave_ni;
    
    // Write Master NI <-> NoC
    logic[EXT_SLAVES*FW_REQ-1:0]      w_req_flit_from_noc;
    logic[EXT_SLAVES-1:0][FW_REQ-1:0] w_req_flit_to_master_ni;
    logic[EXT_SLAVES-1:0]             w_req_valid_to_master_ni;
    logic[EXT_SLAVES-1:0]             w_req_notify_from_master_ni;
    
    logic[EXT_SLAVES-1:0][FW_RESP-1:0]  w_resp_flit_from_master_ni;
    logic[EXT_SLAVES-1:0]               w_resp_valid_from_master_ni;
    logic[EXT_SLAVES-1:0]               w_resp_notify_to_master_ni;
    logic[EXT_SLAVES*FW_RESP_WRITE-1:0] w_resp_flit_to_noc;
    
    // Read Master NI <-> NoC
    logic[EXT_SLAVES*FLIT_WIDTH_REQ_READ-1:0] r_req_flit_from_noc;
    logic[EXT_SLAVES-1:0][FW_REQ-1:0]         r_req_flit_to_master_ni;
    logic[EXT_SLAVES-1:0]                     r_req_valid_to_master_ni;
    logic[EXT_SLAVES-1:0]                     r_req_notify_from_master_ni;
    
    logic[EXT_SLAVES-1:0][FW_RESP-1:0] r_resp_flit_from_master_ni;
    logic[EXT_SLAVES-1:0]              r_resp_valid_from_master_ni;
    logic[EXT_SLAVES-1:0]              r_resp_notify_to_master_ni;
    logic[EXT_SLAVES*FW_RESP-1:0]      r_resp_flit_to_noc;
    
    // Write Slave NI
    for (genvar m = 0; m < EXT_MASTERS; m++) begin: for_m
        // Write Slave NI
        axi_slave_ni #( .MASTER_ID              (m),
                        .TIDS_M                 (TIDS_M),
                        .ADDRESS_WIDTH          (ADDRESS_WIDTH),
                        .DATA_LANES             (DATA_LANES),
                        .USER_WIDTH             (USER_WIDTH),
                        .EXT_MASTERS            (EXT_MASTERS),
                        .EXT_SLAVES             (EXT_SLAVES),
                        .HAS_WRITE              (1'b1), // <----------------
                        .HAS_READ               (1'b0), // <----------------
                        .MAX_LINK_WIDTH_REQ     (MAX_LINK_WIDTH_REQ),
                        .MAX_LINK_WIDTH_RESP    (MAX_LINK_WIDTH_RESP),
                        .MAX_PENDING_SAME_DST   (MAX_PENDING_SAME_DST),
                        .ADDRS_LO               (ADDRS_LO),
                        .ADDRS_HI               (ADDRS_HI),
                        .OVERLAPPING_ADDRS      (OVERLAPPING_ADDRS),
                        .AW_FIFO_DEPTH          (int'(M_FIFO_DEPTHS[m*5*32+5*32-1 : m*5*32+4*32])),
                        .W_FIFO_DEPTH           (int'(M_FIFO_DEPTHS[m*5*32+4*32-1 : m*5*32+3*32])),
                        .B_FIFO_DEPTH           (int'(M_FIFO_DEPTHS[m*5*32+3*32-1 : m*5*32+2*32])),
                        .AR_FIFO_DEPTH          (int'(M_FIFO_DEPTHS[m*5*32+2*32-1 : m*5*32+1*32])),
                        .R_FIFO_DEPTH           (int'(M_FIFO_DEPTHS[m*5*32+1*32-1 : m*5*32+0*32])),
                        .FLIT_WIDTH_REQ_C       (FW_REQ),
                        .FLIT_WIDTH_RESP_C      (FW_RESP),
                        .NI_NOC_FC_SND          (NI_NOC_FC_SND),
                        .NOC_NI_FC_RCV          (NOC_NI_FC_RCV),
                        .ASSERT_RV              (ASSERT_READYVALID)
                ) s_ni_w (
                        .clk        (clk),
                        .rst        (rst),
                        
                        .aw_chan    (s_aw_chan[(m+1)*AXI_W_AWR_M-1 : m*AXI_W_AWR_M]),
                        .aw_valid   (axi_s_aw_valid_i[m]),
                        .aw_ready   (axi_s_aw_ready_o[m]),
                 
                        .w_chan     (s_w_chan[(m+1)*AXI_W_W_M-1 : m*AXI_W_W_M]),
                        .w_valid    (axi_s_w_valid_i[m]),
                        .w_ready    (axi_s_w_ready_o[m]),

                        .ar_chan    ( {AXI_W_AWR_M{1'b0}} ), // zero
                        .ar_valid   (1'b0),
                        .ar_ready   (    ),

                        .b_chan     (s_b_chan[(m+1)*AXI_W_B_M-1 : m*AXI_W_B_M]),
                        .b_valid    (axi_s_b_valid_o[m]),
                        .b_ready    (axi_s_b_ready_i[m]),

                        .r_chan     (    ), // zero
                        .r_valid    (    ),
                        .r_ready    (1'b0),

                        .req_flit_to_noc        (w_req_flit_from_slave_ni[m]),
                        .req_valid_to_noc       (w_req_valid_from_slave_ni[m]),
                        .req_ready_from_noc     (w_req_notify_to_slave_ni[m]),

                        .resp_flit_from_noc     (w_resp_flit_to_slave_ni[m]),
                        .resp_valid_from_noc    (w_resp_valid_to_slave_ni[m]),
                        .resp_ready_to_noc      (w_resp_notify_from_slave_ni[m]));
        
        assign w_resp_flit_to_slave_ni[m][FW_RESP_WRITE-1:0] = w_resp_flit_from_noc[(m+1)*FW_RESP_WRITE-1 : m*FW_RESP_WRITE];
        assign w_req_flit_to_noc[(m+1)*FW_REQ-1 : m*FW_REQ]  = w_req_flit_from_slave_ni[m];
        
        
        // Read Slave NI
        axi_slave_ni #( .MASTER_ID              (m),
                        .TIDS_M                 (TIDS_M),
                        .ADDRESS_WIDTH          (ADDRESS_WIDTH),
                        .DATA_LANES             (DATA_LANES),
                        .USER_WIDTH             (USER_WIDTH),
                        .EXT_MASTERS            (EXT_MASTERS),
                        .EXT_SLAVES             (EXT_SLAVES),
                        .HAS_WRITE              (1'b0), // <----------------
                        .HAS_READ               (1'b1), // <----------------
                        .MAX_LINK_WIDTH_REQ     (MAX_LINK_WIDTH_REQ),
                        .MAX_LINK_WIDTH_RESP    (MAX_LINK_WIDTH_RESP),
                        .MAX_PENDING_SAME_DST   (MAX_PENDING_SAME_DST),
                        .ADDRS_LO               (ADDRS_LO),
                        .ADDRS_HI               (ADDRS_HI),
                        .OVERLAPPING_ADDRS      (OVERLAPPING_ADDRS),
                        .AW_FIFO_DEPTH          (int'(M_FIFO_DEPTHS[m*5*32+5*32-1 : m*5*32+4*32])),
                        .W_FIFO_DEPTH           (int'(M_FIFO_DEPTHS[m*5*32+4*32-1 : m*5*32+3*32])),
                        .B_FIFO_DEPTH           (int'(M_FIFO_DEPTHS[m*5*32+3*32-1 : m*5*32+2*32])),
                        .AR_FIFO_DEPTH          (int'(M_FIFO_DEPTHS[m*5*32+2*32-1 : m*5*32+1*32])),
                        .R_FIFO_DEPTH           (int'(M_FIFO_DEPTHS[m*5*32+1*32-1 : m*5*32+0*32])),
                        .FLIT_WIDTH_REQ_C       (FW_REQ),
                        .FLIT_WIDTH_RESP_C      (FW_RESP),
                        .NI_NOC_FC_SND          (NI_NOC_FC_SND),
                        .NOC_NI_FC_RCV          (NOC_NI_FC_RCV),
                        .ASSERT_RV              (ASSERT_READYVALID)
                ) s_ni_r (
                        .clk          (clk),
                        .rst          (rst),
                        
                        .aw_chan                 ( {AXI_W_AWR_M{1'b0}} ), 
                        .aw_valid                (1'b0),
                        .aw_ready                (    ),
                        
                        .w_chan                  ( {AXI_W_W_M{1'b0}} ), 
                        .w_valid                 (1'b0),
                        .w_ready                 (    ),
        
                        .ar_chan                 (s_ar_chan[(m+1)*AXI_W_AWR_M-1 : m*AXI_W_AWR_M]),
                        .ar_valid                (axi_s_ar_valid_i[m]),
                        .ar_ready                (axi_s_ar_ready_o[m]),
        
                        .b_chan                  (    ),
                        .b_valid                 (    ),
                        .b_ready                 (1'b0),

                        .r_chan                  (s_r_chan[(m+1)*AXI_W_R_M-1 : m*AXI_W_R_M]),
                        .r_valid                 (axi_s_r_valid_o[m]),
                        .r_ready                 (axi_s_r_ready_i[m]),

                        .req_flit_to_noc         (r_req_flit_from_slave_ni[m]),
                        .req_valid_to_noc        (r_req_valid_from_slave_ni[m]),
                        .req_ready_from_noc      (r_req_notify_to_slave_ni[m]),
                        
                        .resp_flit_from_noc      (r_resp_flit_to_slave_ni[m]),
                        .resp_valid_from_noc     (r_resp_valid_to_slave_ni[m]),
                        .resp_ready_to_noc       (r_resp_notify_from_slave_ni[m]));
                        
        assign r_resp_flit_to_slave_ni[m][FW_RESP-1 : 0]                              = r_resp_flit_from_noc[(m+1)*FW_RESP-1 : m*FW_RESP];
        assign r_req_flit_to_noc[(m+1)*FLIT_WIDTH_REQ_READ-1 : m*FLIT_WIDTH_REQ_READ] = r_req_flit_from_slave_ni[m][FLIT_WIDTH_REQ_READ-1 : 0];
    end
    
    
    // // Write Request Network
    // noc_topo_hop_tree #( .HOP_COUNT        (NOC_HOP_COUNT_REQ),
                // .FLIT_WIDTH       (FW_REQ),
                // .IN_PORTS         (EXT_MASTERS),
                // .OUT_PORTS        (EXT_SLAVES),
                // .DST_PNT          (FLIT_FIELD_WIDTH+1+log2c(EXT_MASTERS)),
                // .DST_ADDR_WIDTH   (log2c(EXT_SLAVES)),
                // .INP_FC_PARAMS    (NOC_FC_RCV),
                // .OUT_FC_PARAMS    (NOC_FC_SND)
          // ) req_noc_w (
              // .clk          (clk),
              // .rst          (rst),
              // .data_in      (w_req_flit_to_noc),
              // .valid_in     (w_req_valid_from_slave_ni),
              // .back_notify  (w_req_notify_to_slave_ni),
              // .data_out     (w_req_flit_from_noc),
              // .valid_out    (w_req_valid_to_master_ni),
              // .front_notify (w_req_notify_from_master_ni));
    
    // // Read Request Network
    // noc_topo_hop_tree #( .HOP_COUNT        (NOC_HOP_COUNT_REQ),
                // .FLIT_WIDTH       (FLIT_WIDTH_REQ_READ),
                // .IN_PORTS         (EXT_MASTERS),
                // .OUT_PORTS        (EXT_SLAVES),
                // .DST_PNT          (FLIT_FIELD_WIDTH+1+log2c(EXT_MASTERS)),
                // .DST_ADDR_WIDTH   (log2c(EXT_SLAVES)),
                // .INP_FC_PARAMS    (NOC_FC_RCV),
                // .OUT_FC_PARAMS    (NOC_FC_SND)
          // ) req_noc_r (
              // .clk          (clk),
              // .rst          (rst),
              // .data_in      (r_req_flit_to_noc),
              // .valid_in     (r_req_valid_from_slave_ni),
              // .back_notify  (r_req_notify_to_slave_ni),
              // .data_out     (r_req_flit_from_noc),
              // .valid_out    (r_req_valid_to_master_ni),
              // .front_notify (r_req_notify_from_master_ni));
    
    
    // // Write Response Network
    // noc_topo_hop_tree #( .HOP_COUNT        (NOC_HOP_COUNT_RESP),
                // .FLIT_WIDTH       (FW_RESP_WRITE),
                // .IN_PORTS         (EXT_SLAVES),
                // .OUT_PORTS        (EXT_MASTERS),
                // .DST_PNT          (FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES)),
                // .DST_ADDR_WIDTH   (log2c(EXT_MASTERS)),
                // .INP_FC_PARAMS    (NOC_FC_RCV),
                // .OUT_FC_PARAMS    (NOC_FC_SND)
          // ) resp_noc_w (
              // .clk          (clk),
              // .rst          (rst),
              // .data_in      (w_resp_flit_to_noc),
              // .valid_in     (w_resp_valid_from_master_ni),
              // .back_notify  (w_resp_notify_to_master_ni),
              // .data_out     (w_resp_flit_from_noc),
              // .valid_out    (w_resp_valid_to_slave_ni),
              // .front_notify (w_resp_notify_from_slave_ni));
    
    // // Read Response Network
    // noc_topo_hop_tree #( .HOP_COUNT        (NOC_HOP_COUNT_RESP),
                // .FLIT_WIDTH       (FW_RESP),
                // .IN_PORTS         (EXT_SLAVES),
                // .OUT_PORTS        (EXT_MASTERS),
                // .DST_PNT          (FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES)),
                // .DST_ADDR_WIDTH   (log2c(EXT_MASTERS)),
                // .INP_FC_PARAMS    (NOC_FC_RCV),
                // .OUT_FC_PARAMS    (NOC_FC_SND)
          // ) resp_noc_r (
              // .clk          (clk),
              // .rst          (rst),
              // .data_in      (r_resp_flit_to_noc),
              // .valid_in     (r_resp_valid_from_master_ni),
              // .back_notify  (r_resp_notify_to_master_ni),
              // .data_out     (r_resp_flit_from_noc),
              // .valid_out    (r_resp_valid_to_slave_ni),
              // .front_notify (r_resp_notify_from_slave_ni));
    
    
    for (genvar s = 0; s < EXT_SLAVES; s++) begin: for_s
        // Write Master NI
        assign w_req_flit_to_master_ni[s]                                  = w_req_flit_from_noc[(s+1)*FW_REQ-1 : s*FW_REQ];
        assign w_resp_flit_to_noc[(s+1)*FW_RESP_WRITE-1 : s*FW_RESP_WRITE] = w_resp_flit_from_master_ni[s][FW_RESP_WRITE-1 : 0];
        
        axi_master_ni #( .SLAVE_ID              (s),
                         .TIDS_M                (TIDS_M),
                         .ADDRESS_WIDTH         (ADDRESS_WIDTH),
                         .DATA_LANES            (DATA_LANES),
                         .USER_WIDTH            (USER_WIDTH),
                         .EXT_MASTERS           (EXT_MASTERS),
                         .EXT_SLAVES            (EXT_SLAVES),
                         .HAS_WRITE             (1'b1), // <----------------
                         .HAS_READ              (1'b0), // <----------------
                         .MAX_LINK_WIDTH_REQ    (MAX_LINK_WIDTH_REQ),
                         .MAX_LINK_WIDTH_RESP   (MAX_LINK_WIDTH_RESP),
                         .AW_FIFO_DEPTH         (int'(S_FIFO_DEPTHS[s*5*32+5*32-1 : s*5*32+4*32])),
                         .W_FIFO_DEPTH          (int'(S_FIFO_DEPTHS[s*5*32+4*32-1 : s*5*32+3*32])),
                         .B_FIFO_DEPTH          (int'(S_FIFO_DEPTHS[s*5*32+3*32-1 : s*5*32+2*32])),
                         .AR_FIFO_DEPTH         (int'(S_FIFO_DEPTHS[s*5*32+2*32-1 : s*5*32+1*32])),
                         .R_FIFO_DEPTH          (int'(S_FIFO_DEPTHS[s*5*32+1*32-1 : s*5*32+0*32])),
                         .FLIT_WIDTH_REQ_C      (FW_REQ),
                         .FLIT_WIDTH_RESP_C     (FW_RESP),
                         .NI_NOC_FC_SND         (NI_NOC_FC_SND),
                         .NOC_NI_FC_RCV         (NOC_NI_FC_RCV),
                         .ASSERT_RV             (ASSERT_READYVALID)
            ) m_ni_w (
                     .clk (clk),
                     .rst (rst),
                     
                     .req_flit_from_noc     (w_req_flit_to_master_ni[s]),
                     .req_valid_from_noc    (w_req_valid_to_master_ni[s]),
                     .req_ready_to_noc      (w_req_notify_from_master_ni[s]),
                     
                     .resp_flit_to_noc      (w_resp_flit_from_master_ni[s]),
                     .resp_valid_to_noc     (w_resp_valid_from_master_ni[s]),
                     .resp_ready_from_noc   (w_resp_notify_to_master_ni[s]),
                     
                     .aw_chan           (m_aw_chan[(s+1)*AXI_W_AWR_S-1 : s*AXI_W_AWR_S]),
                     .aw_valid          (axi_m_aw_valid_o[s]),
                     .aw_ready          (axi_m_aw_ready_i[s]),
                     
                     .w_chan            (m_w_chan[(s+1)*AXI_W_W_S-1 : s*AXI_W_W_S]),
                     .w_valid           (axi_m_w_valid_o[s]),
                     .w_ready           (axi_m_w_ready_i[s]),
                     
                     .ar_chan           (    ),
                     .ar_valid          (    ),
                     .ar_ready          (1'b0),
                     
                     .b_chan            (m_b_chan[(s+1)*AXI_W_B_S-1 : s*AXI_W_B_S]),
                     .b_valid           (axi_m_b_valid_i[s]),
                     .b_ready           (axi_m_b_ready_o[s]),
                     
                     .r_chan            ( {AXI_W_R_S{1'b0}} ),
                     .r_valid           (1'b0),
                     .r_ready           (    ));
        // Read Master NI
        assign r_req_flit_to_master_ni[s][FLIT_WIDTH_REQ_READ-1 : 0] = r_req_flit_from_noc[(s+1)*FLIT_WIDTH_REQ_READ-1 : s*FLIT_WIDTH_REQ_READ];
        assign r_resp_flit_to_noc[(s+1)*FW_RESP-1 : s*FW_RESP]       = r_resp_flit_from_master_ni[s];
        axi_master_ni #( .SLAVE_ID              (s),
                         .TIDS_M                (TIDS_M),
                         .ADDRESS_WIDTH         (ADDRESS_WIDTH),
                         .DATA_LANES            (DATA_LANES),
                         .USER_WIDTH            (USER_WIDTH),
                         .EXT_MASTERS           (EXT_MASTERS),
                         .EXT_SLAVES            (EXT_SLAVES),
                         .HAS_WRITE             (1'b0), // <----------------
                         .HAS_READ              (1'b1), // <----------------
                         .MAX_LINK_WIDTH_REQ    (MAX_LINK_WIDTH_REQ),
                         .MAX_LINK_WIDTH_RESP   (MAX_LINK_WIDTH_RESP),
                         .AW_FIFO_DEPTH         (int'(S_FIFO_DEPTHS[s*5*32+5*32-1 : s*5*32+4*32])),
                         .W_FIFO_DEPTH          (int'(S_FIFO_DEPTHS[s*5*32+4*32-1 : s*5*32+3*32])),
                         .B_FIFO_DEPTH          (int'(S_FIFO_DEPTHS[s*5*32+3*32-1 : s*5*32+2*32])),
                         .AR_FIFO_DEPTH         (int'(S_FIFO_DEPTHS[s*5*32+2*32-1 : s*5*32+1*32])),
                         .R_FIFO_DEPTH          (int'(S_FIFO_DEPTHS[s*5*32+1*32-1 : s*5*32+0*32])),
                         .FLIT_WIDTH_REQ_C      (FW_REQ),
                         .FLIT_WIDTH_RESP_C     (FW_RESP),
                         .NI_NOC_FC_SND         (NI_NOC_FC_SND),
                         .NOC_NI_FC_RCV         (NOC_NI_FC_RCV),
                         .ASSERT_RV             (ASSERT_READYVALID)
            ) m_ni_r (
                     .clk (clk),
                     .rst (rst),
                     
                     .req_flit_from_noc     (r_req_flit_to_master_ni[s]),
                     .req_valid_from_noc    (r_req_valid_to_master_ni[s]),
                     .req_ready_to_noc      (r_req_notify_from_master_ni[s]),
                     
                     .resp_flit_to_noc      (r_resp_flit_from_master_ni[s]),
                     .resp_valid_to_noc     (r_resp_valid_from_master_ni[s]),
                     .resp_ready_from_noc   (r_resp_notify_to_master_ni[s]),
                     
                     .aw_chan           (    ),
                     .aw_valid          (    ),
                     .aw_ready          (1'b0),
                     
                     .w_chan            (    ),
                     .w_valid           (    ),
                     .w_ready           (1'b0),
                     
                     .ar_chan           (m_ar_chan[(s+1)*AXI_W_AWR_S-1 : s*AXI_W_AWR_S]),
                     .ar_valid          (axi_m_ar_valid_o[s]),
                     .ar_ready          (axi_m_ar_ready_i[s]),
                     
                     .b_chan            ( {AXI_W_B_S{1'b0}} ),
                     .b_valid           (1'b0),
                     .b_ready           (    ),
                     
                     .r_chan            (m_r_chan[(s+1)*AXI_W_R_S-1 : s*AXI_W_R_S]),
                     .r_valid           (axi_m_r_valid_i[s]),
                     .r_ready           (axi_m_r_ready_o[s]));
    end
end
endmodule
