// `default_nettype none

module dut_passthrough
#(
    parameter int       DW                  = 64,  // Data bus width
    parameter int       AW                  = 32,  // Address width
    parameter int       USERW               = 1, // Width of the AxUSER signal - should be > 
    parameter int       AXI_VER             = 4, // TODO: (No effect now)
    parameter int       MTIDW               = 1, // Master-side xxID width
    parameter int       STIDW               = 1  // Slave-side xxID width
)
(
    // clock/reset
    input logic                                     clk,
    input logic                                     rst_n,
    // -- Slave AXI interface -- //
    // AW (Write Address) channel (NI -> Target)
    input  logic[STIDW-1:0]                         axi_s_aw_id_i,    // AWID
    input  logic[AW-1:0]                            axi_s_aw_addr_i,  // AWADDR
    input  logic[7:0]                               axi_s_aw_len_i,   // AWLEN
    input  logic[2:0]                               axi_s_aw_size_i,  // AWSIZE
    input  logic[1:0]                               axi_s_aw_burst_i, // AWBURST
    input  logic[1:0]                               axi_s_aw_lock_i,  // AWLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support) 
    input  logic[3:0]                               axi_s_aw_cache_i, // AWCACHE
    input  logic[2:0]                               axi_s_aw_prot_i,  // AWPROT
    input  logic[3:0]                               axi_s_aw_qos_i,   // AWQOS
    input  logic[3:0]                               axi_s_aw_region_i,// AWREGION
    input  logic[USERW-1:0]                         axi_s_aw_user_i,  // AWUSER
    input  logic                                    axi_s_aw_valid_i, // AWVALID
    output logic                                    axi_s_aw_ready_o, // AWREADY
    // W (Write Data) channel (NI -> Target)
    input  logic[STIDW-1:0]                         axi_s_w_id_i,     // WID / driven only under AXI_VER==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
    input  logic[DW-1:0]                            axi_s_w_data_i,   // WDATA
    input  logic[DW/8-1:0]                          axi_s_w_strb_i,   // WSTRB
    input  logic                                    axi_s_w_last_i,   // WLAST
    input  logic[USERW-1:0]                         axi_s_w_user_i,   // WUSER / tied to zero
    input  logic                                    axi_s_w_valid_i,  // WVALID
    output logic                                    axi_s_w_ready_o,  // WREADY
    // B (Write Response) channel (Target -> NI)
    output logic[STIDW-1:0]                         axi_s_b_id_o,     // BID
    output logic[1:0]                               axi_s_b_resp_o,   // BRESP
    output logic[USERW-1:0]                         axi_s_b_user_o,   // BUSER
    output logic                                    axi_s_b_valid_o,  // BVALID
    input  logic                                    axi_s_b_ready_i,  // BREADY
    // AR (Read Address) channel (NI -> Target)
    input  logic[STIDW-1:0]                         axi_s_ar_id_i,    // ARID
    input  logic[AW-1:0]                            axi_s_ar_addr_i,  // ARADDR
    input  logic[7:0]                               axi_s_ar_len_i,   // ARLEN
    input  logic[2:0]                               axi_s_ar_size_i,  // ARSIZE
    input  logic[1:0]                               axi_s_ar_burst_i, // ARBURST
    input  logic[1:0]                               axi_s_ar_lock_i,  // ARLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support)
    input  logic[3:0]                               axi_s_ar_cache_i, // ARCACHE
    input  logic[2:0]                               axi_s_ar_prot_i,  // ARPROT
    input  logic[3:0]                               axi_s_ar_qos_i,   // ARQOS
    input  logic[3:0]                               axi_s_ar_region_i,// ARREGION
    input  logic[USERW-1:0]                         axi_s_ar_user_i,  // ARUSER
    input  logic                                    axi_s_ar_valid_i, // ARVALID
    output logic                                    axi_s_ar_ready_o, // ARREADY
    // R (Read Data) channel (Target -> NI)
    output logic[STIDW-1:0]                         axi_s_r_id_o,     // RID
    output logic[DW-1:0]                            axi_s_r_data_o,   // RDATA
    output logic[1:0]                               axi_s_r_resp_o,   // RRESP
    output logic                                    axi_s_r_last_o,   // RLAST
    output logic[USERW-1:0]                         axi_s_r_user_o,   // RUSER
    output logic                                    axi_s_r_valid_o,  // RVALID
    input  logic                                    axi_s_r_ready_i,  // RREADY
    // -- Master AXI interface -- //
    // AW (Write Address) channel (NI -> Target)
    output logic[MTIDW-1:0]                         axi_m_aw_id_o,    // AWID
    output logic[AW-1:0]                            axi_m_aw_addr_o,  // AWADDR
    output logic[7:0]                               axi_m_aw_len_o,   // AWLEN
    output logic[2:0]                               axi_m_aw_size_o,  // AWSIZE
    output logic[1:0]                               axi_m_aw_burst_o, // AWBURST
    output logic[1:0]                               axi_m_aw_lock_o,  // AWLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support) 
    output logic[3:0]                               axi_m_aw_cache_o, // AWCACHE
    output logic[2:0]                               axi_m_aw_prot_o,  // AWPROT
    output logic[3:0]                               axi_m_aw_qos_o,   // AWQOS
    output logic[3:0]                               axi_m_aw_region_o,// AWREGION
    output logic[USERW-1:0]                         axi_m_aw_user_o,  // AWUSER
    output logic                                    axi_m_aw_valid_o, // AWVALID
    input logic                                     axi_m_aw_ready_i, // AWREADY
    // W (Write Data) channel (NI -> Target)
    output logic[MTIDW-1:0]                         axi_m_w_id_o,     // WID / driven only under AXI_VER==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
    output logic[DW-1:0]                            axi_m_w_data_o,   // WDATA
    output logic[DW/8-1:0]                          axi_m_w_strb_o,   // WSTRB
    output logic                                    axi_m_w_last_o,   // WLAST
    output logic[USERW-1:0]                         axi_m_w_user_o,   // WUSER / tied to zero
    output logic                                    axi_m_w_valid_o,  // WVALID
    input  logic                                    axi_m_w_ready_i,  // WREADY
    // B (Write Response) channel (Target -> NI)
    input logic[MTIDW-1:0]                          axi_m_b_id_i,     // BID
    input logic[1:0]                                axi_m_b_resp_i,   // BRESP
    input logic[USERW-1:0]                          axi_m_b_user_i,   // BUSER
    input logic                                     axi_m_b_valid_i,  // BVALID
    output logic                                    axi_m_b_ready_o,  // BREADY
    // AR (Read Address) channel (NI -> Target)
    output logic[MTIDW-1:0]                         axi_m_ar_id_o,    // ARID
    output logic[AW-1:0]                            axi_m_ar_addr_o,  // ARADDR
    output logic[7:0]                               axi_m_ar_len_o,   // ARLEN
    output logic[2:0]                               axi_m_ar_size_o,  // ARSIZE
    output logic[1:0]                               axi_m_ar_burst_o, // ARBURST
    output logic[1:0]                               axi_m_ar_lock_o,  // ARLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support)
    output logic[3:0]                               axi_m_ar_cache_o, // ARCACHE
    output logic[2:0]                               axi_m_ar_prot_o,  // ARPROT
    output logic[3:0]                               axi_m_ar_qos_o,   // ARQOS
    output logic[3:0]                               axi_m_ar_region_o,// ARREGION
    output logic[USERW-1:0]                         axi_m_ar_user_o,  // ARUSER
    output logic                                    axi_m_ar_valid_o, // ARVALID
    input  logic                                    axi_m_ar_ready_i, // ARREADY
    // R (Read Data) channel (Target -> NI)
    input  logic[MTIDW-1:0]                         axi_m_r_id_i,     // RID
    input  logic[DW-1:0]                            axi_m_r_data_i,   // RDATA
    input  logic[1:0]                               axi_m_r_resp_i,   // RRESP
    input  logic                                    axi_m_r_last_i,   // RLAST
    input  logic[USERW-1:0]                         axi_m_r_user_i,   // RUSER
    input  logic                                    axi_m_r_valid_i,  // RVALID
    output logic                                    axi_m_r_ready_o  // RREADY    
);
initial begin
    #0;
    assert (MTIDW == STIDW) else $fatal(1, "Only MTIDW == STIDW config supported");
end
// -- Pass-through -------------------------------------------------------------------------------- //
// AW
assign {axi_m_aw_id_o, axi_m_aw_addr_o, axi_m_aw_len_o, axi_m_aw_size_o, axi_m_aw_burst_o, axi_m_aw_lock_o, axi_m_aw_cache_o, axi_m_aw_prot_o, axi_m_aw_qos_o, axi_m_aw_region_o, axi_m_aw_user_o, axi_m_aw_valid_o} = 
       {axi_s_aw_id_i, axi_s_aw_addr_i, axi_s_aw_len_i, axi_s_aw_size_i, axi_s_aw_burst_i, axi_s_aw_lock_i, axi_s_aw_cache_i, axi_s_aw_prot_i, axi_s_aw_qos_i, axi_s_aw_region_i, axi_s_aw_user_i, axi_s_aw_valid_i};
assign axi_s_aw_ready_o = axi_m_aw_ready_i;

// W
assign {axi_m_w_id_o, axi_m_w_data_o, axi_m_w_strb_o, axi_m_w_last_o, axi_m_w_user_o, axi_m_w_valid_o} =
       {axi_s_w_id_i, axi_s_w_data_i, axi_s_w_strb_i, axi_s_w_last_i, axi_s_w_user_i, axi_s_w_valid_i};
assign axi_s_w_ready_o = axi_m_w_ready_i;

// B
assign {axi_s_b_id_o, axi_s_b_resp_o, axi_s_b_user_o, axi_s_b_valid_o} =
       {axi_m_b_id_i, axi_m_b_resp_i, axi_m_b_user_i, axi_m_b_valid_i};
assign axi_m_b_ready_o = axi_s_b_ready_i;

// AR
assign {axi_m_ar_id_o, axi_m_ar_addr_o, axi_m_ar_len_o, axi_m_ar_size_o, axi_m_ar_burst_o, axi_m_ar_lock_o, axi_m_ar_cache_o, axi_m_ar_prot_o, axi_m_ar_qos_o, axi_m_ar_region_o, axi_m_ar_user_o, axi_m_ar_valid_o} = 
       {axi_s_ar_id_i, axi_s_ar_addr_i, axi_s_ar_len_i, axi_s_ar_size_i, axi_s_ar_burst_i, axi_s_ar_lock_i, axi_s_ar_cache_i, axi_s_ar_prot_i, axi_s_ar_qos_i, axi_s_ar_region_i, axi_s_ar_user_i, axi_s_ar_valid_i};
assign axi_s_ar_ready_o = axi_m_ar_ready_i;

// R
assign {axi_s_r_id_o, axi_s_r_data_o, axi_s_r_resp_o, axi_s_r_last_o, axi_s_r_user_o, axi_s_r_valid_o} =
       {axi_m_r_id_i, axi_m_r_data_i, axi_m_r_resp_i, axi_m_r_last_i, axi_m_r_user_i, axi_m_r_valid_i};
assign axi_m_r_ready_o = axi_s_r_ready_i;


endmodule: dut_passthrough

// `default_nettype wire
