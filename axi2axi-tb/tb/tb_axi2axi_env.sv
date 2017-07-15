import axi_global_pkg::*;
import noc_global::*;
import axi_transactions_pkg::*;
import axi_scoreboard_pkg::*;
import axi_m_w_initiator_pkg::*;
import axi_m_r_initiator_pkg::*;
import axi_s_w_responder_pkg::*;
import axi_s_r_responder_pkg::*;
import tb_pkg_general::*;

// `default_nettype none


module tb_axi2axi_env
#(
    // Design config params
    parameter int       DW                  = 64,  // Data bus width
    parameter int       AW                  = 32,  // Address width
    parameter int       USERW               = 1, // Width of the AxUSER signal - should be > 
    parameter int       AXI_VER             = 4, // TODO: (No effect now)
    parameter int       MTID                = 1, // Master-side TIDs
    parameter int       MTIDW               = MTID > 1 ? $clog2(MTID) : 1, // Master-side xxID width
    parameter int       STID                = 1, // Slave-side TIDs
    parameter int       STIDW               = STID > 1 ? $clog2(STID) : 1, // Slave-side xxID width
    parameter logic[AW-1:0] ADDR_MAX        = 0,
    // Master idle/stall
    parameter int       M_IDLE_RATE_AW      = 10,  // Idle cycle injection @ AW
    parameter int       M_IDLE_RATE_W       = 10,  // Idle cycle injection @ W
    parameter int       M_IDLE_RATE_AR      = 10,  // Idle cycle injection @ AR
    parameter int       M_STALL_RATE_B      = 10,  // Idle cycle injection @ B
    parameter int       M_STALL_RATE_R      = 10,  // Idle cycle injection @ R
    parameter int       M_STROBE_MASK_RATE  = 10,  // Strobe masking rate
    // Slave idle/stall
    parameter int       S_ERROR_RATE        = 0,   // Rate at which Slave generates errors
    parameter int       S_STALL_RATE_AW     = 0,   // Stalling rate for channel AW
    parameter int       S_STALL_RATE_W      = 0,   // Stalling rate for channel W
    parameter int       S_STALL_RATE_AR     = 0,   // Stalling rate for channel AR
    parameter int       S_IDLE_RATE_B       = 10,  // Idle cycle injection @ B
    parameter int       S_IDLE_RATE_R       = 10,  // Idle cycle injection @ R
    // TB params
    parameter tb_gen_mode_t M_TB_MODE       = TBGMT_RANDOM, // TBGMT_RANDOM (rnd) or TBGMT_DIRECTED (using file)
    // DIRECTED-related params
    parameter string    M_INP_FILENAME_WR   = "",
    parameter string    M_INP_FILENAME_RD   = "",
    // RANDOM-related params
    parameter int       M_GEN_RATE_WR       = 10, // Write transactions generation rate
    parameter int       M_TRANS_COUNT_WR    = 0, // number of write transactions to be generated (ignored for DIRECTED test)
    parameter int       M_GEN_RATE_RD       = 10, // Read transactions generation rate 
    parameter int       M_TRANS_COUNT_RD    = 10, // number of write transactions to be generated (ignored for DIRECTED test)
    parameter logic     M_DO_UNALIGNED      = 1'b0, // Size-Unaligned transfers?
    parameter int       M_INCR_DISTR        = 1, // burst distribution (INCR)
    parameter int       M_WRAP_DISTR        = 0, // burst distribution (WRAP)
    parameter int       M_FIXED_DISTR       = 0, // burst distribution (FIXED)
    parameter int       M_MIN_BURST_LEN     = 0, // minimum burst length [0...255]
    parameter int       M_MAX_BURST_LEN     = 255, // minimum burst length [MIN...255]
    parameter int       M_MIN_BURST_SIZE    = 0, // minimum burst length [0...$clog(DW/8)]
    parameter int       M_MAX_BURST_SIZE    = 0, // minimum burst length [MIN...$clog(DW/8)]
    parameter logic     M_WRITE_TO_FILE     = 1'b0, // write output file
    parameter string    M_FLNAME_WR         = "", // output filename (writes)
    parameter string    M_FLNAME_RD         = "", // output filename (reads)
    //
    parameter logic     WRITE_REPORT        = 1'b0,
    parameter string    WORK_DIR            = "",
    //
    parameter int       MASTERS             = 1,
    parameter int       SLAVES              = 1
)
(
    // clock/reset
    output logic                                    clk,
    output logic                                    rst_n,
    // -- Master AXI interface -- //
    // AW (Write Address) channel (NI -> Target)
    output logic[MASTERS-1:0][MTIDW-1:0]            axi_m_aw_id_o,    // AWID
    output logic[MASTERS-1:0][AW-1:0]               axi_m_aw_addr_o,  // AWADDR
    output logic[MASTERS-1:0][7:0]                  axi_m_aw_len_o,   // AWLEN
    output logic[MASTERS-1:0][2:0]                  axi_m_aw_size_o,  // AWSIZE
    output logic[MASTERS-1:0][1:0]                  axi_m_aw_burst_o, // AWBURST
    output logic[MASTERS-1:0][1:0]                  axi_m_aw_lock_o,  // AWLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support) 
    output logic[MASTERS-1:0][3:0]                  axi_m_aw_cache_o, // AWCACHE
    output logic[MASTERS-1:0][2:0]                  axi_m_aw_prot_o,  // AWPROT
    output logic[MASTERS-1:0][3:0]                  axi_m_aw_qos_o,   // AWQOS
    output logic[MASTERS-1:0][3:0]                  axi_m_aw_region_o,// AWREGION
    output logic[MASTERS-1:0][USERW-1:0]            axi_m_aw_user_o,  // AWUSER
    output logic[MASTERS-1:0]                       axi_m_aw_valid_o, // AWVALID
    input  logic[MASTERS-1:0]                       axi_m_aw_ready_i, // AWREADY
    // W (Write Data) channel (NI -> Target)
    output logic[MASTERS-1:0][MTIDW-1:0]            axi_m_w_id_o,     // WID / driven only under AXI_VER==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
    output logic[MASTERS-1:0][DW-1:0]               axi_m_w_data_o,   // WDATA
    output logic[MASTERS-1:0][DW/8-1:0]             axi_m_w_strb_o,   // WSTRB
    output logic[MASTERS-1:0]                       axi_m_w_last_o,   // WLAST
    output logic[MASTERS-1:0][USERW-1:0]            axi_m_w_user_o,   // WUSER / tied to zero
    output logic[MASTERS-1:0]                       axi_m_w_valid_o,  // WVALID
    input  logic[MASTERS-1:0]                       axi_m_w_ready_i,  // WREADY
    // B (Write Response) channel (Target -> NI)
    input  logic[MASTERS-1:0][MTIDW-1:0]            axi_m_b_id_i,     // BID
    input  logic[MASTERS-1:0][1:0]                  axi_m_b_resp_i,   // BRESP
    input  logic[MASTERS-1:0][USERW-1:0]            axi_m_b_user_i,   // BUSER
    input  logic[MASTERS-1:0]                       axi_m_b_valid_i,  // BVALID
    output logic[MASTERS-1:0]                       axi_m_b_ready_o,  // BREADY
    // AR (Read Address) channel (NI -> Target)
    output logic[MASTERS-1:0][MTIDW-1:0]            axi_m_ar_id_o,    // ARID
    output logic[MASTERS-1:0][AW-1:0]               axi_m_ar_addr_o,  // ARADDR
    output logic[MASTERS-1:0][7:0]                  axi_m_ar_len_o,   // ARLEN
    output logic[MASTERS-1:0][2:0]                  axi_m_ar_size_o,  // ARSIZE
    output logic[MASTERS-1:0][1:0]                  axi_m_ar_burst_o, // ARBURST
    output logic[MASTERS-1:0][1:0]                  axi_m_ar_lock_o,  // ARLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support)
    output logic[MASTERS-1:0][3:0]                  axi_m_ar_cache_o, // ARCACHE
    output logic[MASTERS-1:0][2:0]                  axi_m_ar_prot_o,  // ARPROT
    output logic[MASTERS-1:0][3:0]                  axi_m_ar_qos_o,   // ARQOS
    output logic[MASTERS-1:0][3:0]                  axi_m_ar_region_o,// ARREGION
    output logic[MASTERS-1:0][USERW-1:0]            axi_m_ar_user_o,  // ARUSER
    output logic[MASTERS-1:0]                       axi_m_ar_valid_o, // ARVALID
    input  logic[MASTERS-1:0]                       axi_m_ar_ready_i, // ARREADY
    // R (Read Data) channel (Target -> NI)
    input  logic[MASTERS-1:0][MTIDW-1:0]            axi_m_r_id_i,     // RID
    input  logic[MASTERS-1:0][DW-1:0]               axi_m_r_data_i,   // RDATA
    input  logic[MASTERS-1:0][1:0]                  axi_m_r_resp_i,   // RRESP
    input  logic[MASTERS-1:0]                       axi_m_r_last_i,   // RLAST
    input  logic[MASTERS-1:0][USERW-1:0]            axi_m_r_user_i,   // RUSER
    input  logic[MASTERS-1:0]                       axi_m_r_valid_i,  // RVALID
    output logic[MASTERS-1:0]                       axi_m_r_ready_o,  // RREADY
    // -- Slave AXI interface -- //
    // AW (Write Address) channel (NI -> Target)
    input  logic[SLAVES-1:0][STIDW-1:0]             axi_s_aw_id_i,    // AWID
    input  logic[SLAVES-1:0][AW-1:0]                axi_s_aw_addr_i,  // AWADDR
    input  logic[SLAVES-1:0][7:0]                   axi_s_aw_len_i,   // AWLEN
    input  logic[SLAVES-1:0][2:0]                   axi_s_aw_size_i,  // AWSIZE
    input  logic[SLAVES-1:0][1:0]                   axi_s_aw_burst_i, // AWBURST
    input  logic[SLAVES-1:0][1:0]                   axi_s_aw_lock_i,  // AWLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support) 
    input  logic[SLAVES-1:0][3:0]                   axi_s_aw_cache_i, // AWCACHE
    input  logic[SLAVES-1:0][2:0]                   axi_s_aw_prot_i,  // AWPROT
    input  logic[SLAVES-1:0][3:0]                   axi_s_aw_qos_i,   // AWQOS
    input  logic[SLAVES-1:0][3:0]                   axi_s_aw_region_i,// AWREGION
    input  logic[SLAVES-1:0][USERW-1:0]             axi_s_aw_user_i,  // AWUSER
    input  logic[SLAVES-1:0]                        axi_s_aw_valid_i, // AWVALID
    output logic[SLAVES-1:0]                        axi_s_aw_ready_o, // AWREADY
    // W (Write Data) channel (NI -> Target)
    input  logic[SLAVES-1:0][STIDW-1:0]             axi_s_w_id_i,     // WID / driven only under AXI_VER==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
    input  logic[SLAVES-1:0][DW-1:0]                axi_s_w_data_i,   // WDATA
    input  logic[SLAVES-1:0][DW/8-1:0]              axi_s_w_strb_i,   // WSTRB
    input  logic[SLAVES-1:0]                        axi_s_w_last_i,   // WLAST
    input  logic[SLAVES-1:0][USERW-1:0]             axi_s_w_user_i,   // WUSER / tied to zero
    input  logic[SLAVES-1:0]                        axi_s_w_valid_i,  // WVALID
    output logic[SLAVES-1:0]                        axi_s_w_ready_o,  // WREADY
    // B (Write Response) channel (Target -> NI)
    output logic[SLAVES-1:0][STIDW-1:0]             axi_s_b_id_o,     // BID
    output logic[SLAVES-1:0][1:0]                   axi_s_b_resp_o,   // BRESP
    output logic[SLAVES-1:0][USERW-1:0]             axi_s_b_user_o,   // BUSER
    output logic[SLAVES-1:0]                        axi_s_b_valid_o,  // BVALID
    input  logic[SLAVES-1:0]                        axi_s_b_ready_i,  // BREADY
    // AR (Read Address) channel (NI -> Target)
    input  logic[SLAVES-1:0][STIDW-1:0]             axi_s_ar_id_i,    // ARID
    input  logic[SLAVES-1:0][AW-1:0]                axi_s_ar_addr_i,  // ARADDR
    input  logic[SLAVES-1:0][7:0]                   axi_s_ar_len_i,   // ARLEN
    input  logic[SLAVES-1:0][2:0]                   axi_s_ar_size_i,  // ARSIZE
    input  logic[SLAVES-1:0][1:0]                   axi_s_ar_burst_i, // ARBURST
    input  logic[SLAVES-1:0][1:0]                   axi_s_ar_lock_i,  // ARLOCK / 2-bit always for AXI_VER==3 compliance, but MSB is always tied to zero (no locked support)
    input  logic[SLAVES-1:0][3:0]                   axi_s_ar_cache_i, // ARCACHE
    input  logic[SLAVES-1:0][2:0]                   axi_s_ar_prot_i,  // ARPROT
    input  logic[SLAVES-1:0][3:0]                   axi_s_ar_qos_i,   // ARQOS
    input  logic[SLAVES-1:0][3:0]                   axi_s_ar_region_i,// ARREGION
    input  logic[SLAVES-1:0][USERW-1:0]             axi_s_ar_user_i,  // ARUSER
    input  logic[SLAVES-1:0]                        axi_s_ar_valid_i, // ARVALID
    output logic[SLAVES-1:0]                        axi_s_ar_ready_o, // ARREADY
    // R (Read Data) channel (Target -> NI)
    output logic[SLAVES-1:0][STIDW-1:0]             axi_s_r_id_o,     // RID
    output logic[SLAVES-1:0][DW-1:0]                axi_s_r_data_o,   // RDATA
    output logic[SLAVES-1:0][1:0]                   axi_s_r_resp_o,   // RRESP
    output logic[SLAVES-1:0]                        axi_s_r_last_o,   // RLAST
    output logic[SLAVES-1:0][USERW-1:0]             axi_s_r_user_o,   // RUSER
    output logic[SLAVES-1:0]                        axi_s_r_valid_o,  // RVALID
    input  logic[SLAVES-1:0]                        axi_s_r_ready_i,   // RREADY
    input logic both_mailbox_empty
);
    // -- AXI Agents Config ----------------------------------------------------------------------- //
    localparam int SIM_CYCLES               = 2000;
    localparam logic CHECK_RV_HANDSHAKE_IFS = 1'b1;
    localparam logic SLAVE_RD_INTERLEAVE = 0;
    
    initial begin
        #0;
        assert (MTID <= 2**MTIDW) else $fatal(1, "Not enough bits to fit Master-side TIDs -- it must hold: MTID <= 2**MTIDW but MTID=%0d, MTIDW=%0d", MTID, MTIDW);
        assert (STID <= 2**STIDW) else $fatal(1, "Not enough bits to fit Slave-side TIDs -- it must hold: STID <= 2**STIDW but STID=%0d, STIDW=%0d", STID, STIDW);
    end
    
    // -- FIFOs ----------------------------------------------------------------------------------- //
    // General - NoC-wide
    localparam int ADDR_MSTTID_P    = 26; // this is where the master_id and tid will be stored at the address of transaction - big enough so that we don't mess with 1024-bit buses and 4k bound
    // -- clk/rst --------------------------------------------------------------------------------- //
    localparam CLK_PERIOD = 100;
    // logic clk;
    logic rst;
    
    initial begin: rst_tsk
        rst = 0;
        #0 rst = 1;
        #(10*CLK_PERIOD+CLK_PERIOD/10) rst = 0;
    end
    assign rst_n = ~rst;
    
    initial begin: clk_tsk
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    
    // Write Master
    axi_m_w_initiator
    #(
        .MASTERS        (MASTERS),
        .ADDR_MSTTID_P  (ADDR_MSTTID_P),
        .ADDR_WIDTH     (AW),
        .LEN_WIDTH      (AXI_LEN_W),
        .SIZE_WIDTH     (AXI_SIZE_W),
        .BURST_WIDTH    (AXI_BURST_W),
        .LOCK_WIDTH     (AXI_LOCK_W),
        .CACHE_WIDTH    (AXI_CACHE_W),
        .PROT_WIDTH     (AXI_PROT_W),
        .QOS_WIDTH      (AXI_QOS_W),
        .REGION_WIDTH   (AXI_REGION_W),
        .AW_USER_WIDTH  (USERW),
        .AW_TID_WIDTH   (MTIDW),
        .W_DATA_WIDTH   (int'(DW)),
        .W_USER_WIDTH   (USERW),
        .B_RESP_WIDTH   (AXI_RESP_W),
        .B_USER_WIDTH   (USERW)
    ) master_w[MASTERS-1:0];
    
    // IF - Write Master <--> DUT
    axi_rv_if_m_w
    #(
        .PORTS          (MASTERS),
        .ADDR_WIDTH     (AW),
        .LEN_WIDTH      (AXI_LEN_W),
        .SIZE_WIDTH     (AXI_SIZE_W),
        .BURST_WIDTH    (AXI_BURST_W),
        .LOCK_WIDTH     (AXI_LOCK_W),
        .CACHE_WIDTH    (AXI_CACHE_W),
        .PROT_WIDTH     (AXI_PROT_W),
        .QOS_WIDTH      (AXI_QOS_W),
        .REGION_WIDTH   (AXI_REGION_W),
        .AW_USER_WIDTH  (USERW),
        .AW_TID_WIDTH   (MTIDW),
        .W_DATA_WIDTH   (int'(DW)),
        .W_USER_WIDTH   (USERW),
        .B_RESP_WIDTH   (AXI_RESP_W),
        .B_USER_WIDTH   (USERW)
    )
    m_w_vif
    (
        .clk    (clk)
    );
    
    // Read Master
    axi_m_r_initiator
    #(
        .MASTERS        (MASTERS),
        .ADDR_MSTTID_P  (ADDR_MSTTID_P),
        .ADDR_WIDTH     (AW),
        .LEN_WIDTH      (AXI_LEN_W),
        .SIZE_WIDTH     (AXI_SIZE_W),
        .BURST_WIDTH    (AXI_BURST_W),
        .LOCK_WIDTH     (AXI_LOCK_W),
        .CACHE_WIDTH    (AXI_CACHE_W),
        .PROT_WIDTH     (AXI_PROT_W),
        .QOS_WIDTH      (AXI_QOS_W),
        .REGION_WIDTH   (AXI_REGION_W),
        .AR_TID_WIDTH   (MTIDW),
        .AR_USER_WIDTH  (USERW),
        .R_DATA_WIDTH   (DW),
        .R_RESP_WIDTH   (AXI_RESP_W),
        .R_USER_WIDTH   (USERW)
    ) master_r[MASTERS-1:0];
    
    // IF - Read Masters <--> DUT
    axi_rv_if_m_r
    #(  
        .PORTS          (MASTERS),
        .ADDR_WIDTH     (AW),
        .LEN_WIDTH      (AXI_LEN_W),
        .SIZE_WIDTH     (AXI_SIZE_W),
        .BURST_WIDTH    (AXI_BURST_W),
        .LOCK_WIDTH     (AXI_LOCK_W),
        .CACHE_WIDTH    (AXI_CACHE_W),
        .PROT_WIDTH     (AXI_PROT_W),
        .QOS_WIDTH      (AXI_QOS_W),
        .REGION_WIDTH   (AXI_REGION_W),
        .AR_TID_WIDTH   (MTIDW),
        .AR_USER_WIDTH  (USERW),
        .R_DATA_WIDTH   (DW),
        .R_RESP_WIDTH   (AXI_RESP_W),
        .R_USER_WIDTH   (USERW)
    )
    m_r_vif
    (
        .clk    (clk)
    );
    
    // Write Slaves
    axi_s_w_responder
    #(
        .SLAVES         (SLAVES),
        .MASTERS        (MASTERS),
        .ADDR_MSTTID_P  (ADDR_MSTTID_P),
        .ADDR_WIDTH     (AW),
        .LEN_WIDTH      (AXI_LEN_W),
        .SIZE_WIDTH     (AXI_SIZE_W),
        .BURST_WIDTH    (AXI_BURST_W),
        .LOCK_WIDTH     (AXI_LOCK_W),
        .CACHE_WIDTH    (AXI_CACHE_W),
        .PROT_WIDTH     (AXI_PROT_W),
        .QOS_WIDTH      (AXI_QOS_W),
        .REGION_WIDTH   (AXI_REGION_W),
        .AW_USER_WIDTH  (USERW),
        .AW_TID_WIDTH   (STIDW),
        .W_DATA_WIDTH   (int'(DW)),
        .W_USER_WIDTH   (USERW),
        .B_RESP_WIDTH   (AXI_RESP_W),
        .B_USER_WIDTH   (USERW),
        .AW_MTID_W      (MTIDW)
    ) slave_w[SLAVES-1:0];
    
    // IF - Write Slaves <--> DUT
    axi_rv_if_s_w
    #(
        .PORTS          (SLAVES),
        .ADDR_WIDTH     (AW),
        .LEN_WIDTH      (AXI_LEN_W),
        .SIZE_WIDTH     (AXI_SIZE_W),
        .BURST_WIDTH    (AXI_BURST_W),
        .LOCK_WIDTH     (AXI_LOCK_W),
        .CACHE_WIDTH    (AXI_CACHE_W),
        .PROT_WIDTH     (AXI_PROT_W),
        .QOS_WIDTH      (AXI_QOS_W),
        .REGION_WIDTH   (AXI_REGION_W),
        .AW_USER_WIDTH  (USERW),
        .AW_TID_WIDTH   (STIDW),
        .W_DATA_WIDTH   (int'(DW)),
        .W_USER_WIDTH   (USERW),
        .B_RESP_WIDTH   (AXI_RESP_W),
        .B_USER_WIDTH   (USERW)
    )
    s_w_vif
    (
        .clk    (clk)
    );
    
    // Read Slaves
    axi_s_r_responder
    #(
        .SLAVES         (SLAVES),
        .MASTERS        (MASTERS),
        .ADDR_MSTTID_P  (ADDR_MSTTID_P),
        .ADDR_WIDTH     (AW),
        .LEN_WIDTH      (AXI_LEN_W),
        .SIZE_WIDTH     (AXI_SIZE_W),
        .BURST_WIDTH    (AXI_BURST_W),
        .LOCK_WIDTH     (AXI_LOCK_W),
        .CACHE_WIDTH    (AXI_CACHE_W),
        .PROT_WIDTH     (AXI_PROT_W),
        .QOS_WIDTH      (AXI_QOS_W),
        .REGION_WIDTH   (AXI_REGION_W),
        .AR_TID_WIDTH   (STIDW),
        .AR_USER_WIDTH  (USERW),
        .R_DATA_WIDTH   (DW),
        .R_RESP_WIDTH   (AXI_RESP_W),
        .R_USER_WIDTH   (USERW),
        .AR_MTID_W      (MTIDW)
    ) slave_r[SLAVES-1:0];
    
    // IF - Read Slaves <--> DUT
    axi_rv_if_s_r
    #(  
        .PORTS          (SLAVES),
        .ADDR_WIDTH     (AW),
        .LEN_WIDTH      (AXI_LEN_W),
        .SIZE_WIDTH     (AXI_SIZE_W),
        .BURST_WIDTH    (AXI_BURST_W),
        .LOCK_WIDTH     (AXI_LOCK_W),
        .CACHE_WIDTH    (AXI_CACHE_W),
        .PROT_WIDTH     (AXI_PROT_W),
        .QOS_WIDTH      (AXI_QOS_W),
        .REGION_WIDTH   (AXI_REGION_W),
        .AR_TID_WIDTH   (STIDW),
        .AR_USER_WIDTH  (USERW),
        .R_DATA_WIDTH   (DW),
        .R_RESP_WIDTH   (AXI_RESP_W),
        .R_USER_WIDTH   (USERW)
    )
    s_r_vif
    (
        .clk    (clk)
    );
    
    // MBs
    // W
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(AW))) mb_byte_m_w[MASTERS][];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(AW))) mb_byte_s_w[SLAVES];
    
    // R
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(AW))) mb_byte_m_r_req_to_slave[];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(AW))) mb_s_r_byte_resp[SLAVES][];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(AW))) mb_m_r_byte_resp[MASTERS];
    
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(AW))) mb_m_r_byte_req_m2m[MASTERS][];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(AW))) mb_m_r_byte_resp_m2m[MASTERS];
    
    // Scoreboards
    axi_data_scoreboard 
    #(
        .ADDRESS_WIDTH  (AW),
        .SOURCES        (MASTERS),
        .DESTINATIONS   (SLAVES)
    ) sb_w;
    
    axi_data_scoreboard 
    #(
        .ADDRESS_WIDTH  (AW),
        .SOURCES        (SLAVES),
        .DESTINATIONS   (MASTERS)
    ) sb_r_s2m;   
    
    axi_data_scoreboard 
    #(
        .ADDRESS_WIDTH  (AW),
        .SOURCES        (MASTERS),
        .DESTINATIONS   (MASTERS)
    ) sb_r_m2m;
    
    task build_all();
        // -- Scoreboards -- //
        build_scoreboards();
        // -- Slaves -- //
        build_slaves();
        // -- Masters -- //
        build_masters();
    endtask
    
    task reset_all();
        reset_scoreboards();
        reset_slaves();
        reset_masters();
    endtask
    
    task start_all();
        start_scoreboards();
        start_slaves();
        start_masters();
    endtask
    
    task build_masters();
        automatic logic IS_RANDOM_DATA  = 1'b0;
        
        // Masters
        for(int m=0; m<MASTERS; m++) begin
            // Write Master
            master_w[m] = new(m, MTID, DW/8, ADDR_MAX,
                              M_STALL_RATE_B, M_IDLE_RATE_AW, M_IDLE_RATE_W, M_STROBE_MASK_RATE,
                              M_GEN_RATE_WR,
                              M_TB_MODE, M_INP_FILENAME_WR,
                              M_TRANS_COUNT_WR, 
                              M_FIXED_DISTR, M_INCR_DISTR, M_WRAP_DISTR, M_DO_UNALIGNED,
                              M_MIN_BURST_LEN, M_MAX_BURST_LEN, M_MIN_BURST_SIZE, M_MAX_BURST_SIZE,
                              IS_RANDOM_DATA,
                              mb_byte_m_w[m],
                              M_WRITE_TO_FILE, M_FLNAME_WR);
            master_w[m].vif = m_w_vif.c_if;
            // Read Master
            master_r[m] = new(m, MTID, DW/8, ADDR_MAX,
                              M_STALL_RATE_R, M_IDLE_RATE_AR,
                              M_GEN_RATE_RD, M_TB_MODE, M_INP_FILENAME_RD,
                              M_TRANS_COUNT_RD,
                              M_FIXED_DISTR, M_INCR_DISTR, M_WRAP_DISTR, M_DO_UNALIGNED,
                              M_MIN_BURST_LEN, M_MAX_BURST_LEN, M_MIN_BURST_SIZE, M_MAX_BURST_SIZE,
                              IS_RANDOM_DATA,
                          mb_byte_m_r_req_to_slave,
                          mb_m_r_byte_resp[0],
                          
                          mb_m_r_byte_req_m2m[0],
                          mb_m_r_byte_resp_m2m[0],
                              M_WRITE_TO_FILE, M_FLNAME_RD);
            master_r[m].vif = m_r_vif.c_if;
        end
    endtask
    
    task build_slaves();
        const logic FIFO_LIKE = 1'b0;
        automatic logic IS_RANDOM_DATA  = 1'b0;
        const int SERVE_RATE = 100;
        // Slaves
        for(int s=0; s<SLAVES; s++) begin: for_sw
            slave_w[s] = new(s, MTID, DW/8, IS_RANDOM_DATA,
                             SERVE_RATE, S_ERROR_RATE, S_STALL_RATE_AW, S_STALL_RATE_W, S_IDLE_RATE_B,
                             mb_byte_s_w[s]);
            slave_w[s].vif = s_w_vif.c_if;
        end
        
        // Slaves
        for(int s=0; s<SLAVES; s++) begin: for_sr
            slave_r[s] = new(s, MTID, DW/8,
                             IS_RANDOM_DATA,
                             FIFO_LIKE, SLAVE_RD_INTERLEAVE,
                             SERVE_RATE, S_ERROR_RATE, S_STALL_RATE_AR, S_IDLE_RATE_R,
                             mb_byte_m_r_req_to_slave,
                             mb_s_r_byte_resp[s]);
            slave_r[s].vif = s_r_vif.c_if;
        end
    endtask
    
    task build_scoreboards();
        // -- Mailboxes --------------------------------------------------------------------------- //
        // Write - Master
        for(int m=0; m<MASTERS; m++) begin
            mb_byte_m_w[m]      = new[MTID];
            for(int t=0; t<MTID; t++) begin
                mb_byte_m_w[m][t]   = new();
            end
        end
        // Write - Slave
        for(int s=0; s<SLAVES; s++) begin
            mb_byte_s_w[s] = new();
        end
        
        // Read - Master
        mb_byte_m_r_req_to_slave = new[MTID];
        for(int t=0; t<MTID; t++) begin
            mb_byte_m_r_req_to_slave[t] = new();
        end
        
        for (int m=0; m<MASTERS; m++) begin
            mb_m_r_byte_resp[m] = new();
        end
        
        for (int m=0; m<MASTERS; m++) begin
            mb_m_r_byte_req_m2m[m] = new[MTID];
            mb_m_r_byte_resp_m2m[m] = new();
            
            for(int t=0; t<MTID; t++) begin
                mb_m_r_byte_req_m2m[m][t] = new();
            end
        end
        
        // Read - Slave
        for(int s=0; s<SLAVES; s++) begin
            mb_s_r_byte_resp[s] = new[MTID];
            for(int t=0; t<MTID; t++) begin
                mb_s_r_byte_resp[s][t] = new();
            end
        end
        
        
        // Scoreboard
        sb_w     = new(MTID, mb_byte_m_w, mb_byte_s_w, "W");
        sb_r_s2m = new(MTID, mb_s_r_byte_resp, mb_m_r_byte_resp, "R-s2m");
        sb_r_m2m = new(MTID, mb_m_r_byte_req_m2m, mb_m_r_byte_resp_m2m, "R-m2m");
    endtask
    
    task reset_masters();
        // vIFs
        m_w_vif.c_if.do_reset();
        m_r_vif.c_if.do_reset();
        
        // Masters
        for(int s=0; s<MASTERS; s++) begin: for_mw
            master_w[s].do_reset();
            master_r[s].do_reset();
        end
    endtask
    
    task reset_slaves();
        // vIFs
        s_w_vif.c_if.do_reset();
        s_r_vif.c_if.do_reset();
        
        // Slaves
        for(int s=0; s<SLAVES; s++) begin: for_sw
            slave_w[s].do_reset();
        end
    endtask
    
    task reset_scoreboards();
        // scoreboards
        sb_w.do_reset();
        sb_r_s2m.do_reset();
        sb_r_m2m.do_reset();
    endtask
    
    task start_masters();
        fork begin: iso_thread
            for(int mm=0; mm<MASTERS; mm++) begin: for_mmw
                fork
                    automatic int m = mm;
                begin
                    master_w[m].start();
                end join_none
            end
            $display("%0t: Spawned %0d W-Masters", $time, MASTERS);
            
            for(int mm=0; mm<MASTERS; mm++) begin: for_mmr
                fork
                    automatic int m = mm;
                begin
                    master_r[m].start();
                end join_none
            end
            $display("%0t: Spawned %0d R-Masters", $time, MASTERS);
            
            wait fork;
        // end join_none
        end join
    endtask
    
    task start_slaves();
        fork begin: iso_thread
            for(int ss=0; ss<SLAVES; ss++) begin: for_ssw
                fork
                    automatic int s = ss;
                begin
                    slave_w[s].start();
                end join_none
            end
            $display("%0t: Spawned %0d W-Slaves", $time, SLAVES);
            
            for(int ss=0; ss<SLAVES; ss++) begin: for_ssr
                fork
                    automatic int s = ss;
                begin
                    slave_r[s].start();
                end join_none
            end
            $display("%0t: Spawned %0d R-Slaves", $time, SLAVES);
            
            wait fork;
        end join_none
    endtask
    
    task start_scoreboards();
        fork
            sb_w.start();
            // sb_r_s2m.start();
            // sb_r_m2m.start();
        join_none
    endtask
    
    
    initial begin: env_core
        build_all();
        $display("%0t: Everything built", $time);
        
        @(negedge rst_n);
        reset_all();
        @(posedge rst_n);
        if (CHECK_RV_HANDSHAKE_IFS) begin
            m_w_vif.check_rv_handshake = 1;
            m_r_vif.check_rv_handshake = 1;
            s_w_vif.check_rv_handshake = 1;
            s_r_vif.check_rv_handshake = 1;
        end
        
        $display("%0t: Waiting for Masters to drain.......................................................", $time);
        start_all();
        // ^^^ blocking @ start_masters() -- unblocked once masters drained
        $display("%0t: Waiting for SBs to drain ..........................................................", $time);
        
        fork
            sb_w.wait_for_drain(CLK_PERIOD);
            // sb_r_s2m.wait_for_drain(CLK_PERIOD);
            // sb_r_m2m.wait_for_drain(CLK_PERIOD);
        join
        $display("%0t: W-SB done", $time);
        $display("%0t: R-SB done", $time);
        #10000ns;
        if(!both_mailbox_empty) begin
            $fatal(1,"Master or Slave Mailbox are not empty and the simulation is ending");
        end
        $display("%0t: All Transactions Completed\n\n", $time,
                 "-----------------------------------------\n",
                 "-----------------------------------------\n",
                 "------                             ------\n",
                 "------    Simulation Successful    ------\n",
                 "------                             ------\n",
                 "-----------------------------------------\n",
                 "-----------------------------------------\n");
        
        $finish;
    end
    
    // -------------------------------------------------------------------------------------------- //
    // -- Master ---------------------------------------------------------------------------------- //
    // -------------------------------------------------------------------------------------------- //
    for (genvar m=0; m<MASTERS; m++) begin
        // AW
        assign m_w_vif.aw_ready[m]      = axi_m_aw_ready_i[m]   ;
        assign axi_m_aw_valid_o[m]      = m_w_vif.aw_valid[m]   ;
        assign axi_m_aw_id_o[m]         = m_w_vif.aw_tid[m]     ;
        assign axi_m_aw_addr_o[m]       = m_w_vif.aw_addr[m]    ;
        assign axi_m_aw_len_o[m]        = m_w_vif.aw_len[m]     ;
        assign axi_m_aw_size_o[m]       = m_w_vif.aw_size[m]    ;
        assign axi_m_aw_burst_o[m]      = m_w_vif.aw_burst[m]   ;
        assign axi_m_aw_lock_o[m]       = m_w_vif.aw_lock[m]    ;
        assign axi_m_aw_cache_o[m]      = m_w_vif.aw_cache[m]   ;
        assign axi_m_aw_prot_o[m]       = m_w_vif.aw_prot[m]    ;
        assign axi_m_aw_qos_o[m]        = m_w_vif.aw_qos[m]     ;
        assign axi_m_aw_region_o[m]     = m_w_vif.aw_region[m]  ;
        assign axi_m_aw_user_o[m]       = m_w_vif.aw_user[m]    ;
        // W
        assign m_w_vif.w_ready[m]       = axi_m_w_ready_i[m]    ;
        assign axi_m_w_valid_o[m]       = m_w_vif.w_valid[m]    ;
        assign axi_m_w_data_o[m]        = m_w_vif.w_data[m]     ;
        assign axi_m_w_strb_o[m]        = m_w_vif.w_strb[m]     ;
        assign axi_m_w_user_o[m]        = m_w_vif.w_user[m]     ;
        assign axi_m_w_last_o[m]        = m_w_vif.w_last[m]     ;
        // B
        assign axi_m_b_ready_o[m]       = m_w_vif.b_ready[m]    ;
        assign m_w_vif.b_valid[m]       = axi_m_b_valid_i[m]    ;
        assign m_w_vif.b_tid[m]         = axi_m_b_id_i[m]       ;
        assign m_w_vif.b_resp[m]        = axi_m_b_resp_i[m]     ;
        assign m_w_vif.b_user[m]        = axi_m_b_user_i[m]     ;
        // AR
        assign m_r_vif.ar_ready[m]      = axi_m_ar_ready_i[m]   ;
        assign axi_m_ar_valid_o[m]      = m_r_vif.ar_valid[m]   ;
        assign axi_m_ar_id_o[m]         = m_r_vif.ar_tid[m]     ;
        assign axi_m_ar_addr_o[m]       = m_r_vif.ar_addr[m]    ;
        assign axi_m_ar_len_o[m]        = m_r_vif.ar_len[m]     ;
        assign axi_m_ar_size_o[m]       = m_r_vif.ar_size[m]    ;
        assign axi_m_ar_burst_o[m]      = m_r_vif.ar_burst[m]   ;
        assign axi_m_ar_lock_o[m]       = m_r_vif.ar_lock[m]    ;
        assign axi_m_ar_cache_o[m]      = m_r_vif.ar_cache[m]   ;
        assign axi_m_ar_prot_o[m]       = m_r_vif.ar_prot[m]    ;
        assign axi_m_ar_qos_o[m]        = m_r_vif.ar_qos[m]     ;
        assign axi_m_ar_region_o[m]     = m_r_vif.ar_region[m]  ;
        assign axi_m_ar_user_o[m]       = m_r_vif.ar_user[m]    ;
        // R
        assign axi_m_r_ready_o[m]       = m_r_vif.r_ready[m]    ;
        assign m_r_vif.r_valid[m]       = axi_m_r_valid_i[m]    ;
        assign m_r_vif.r_tid[m]         = axi_m_r_id_i[m]       ;
        assign m_r_vif.r_data[m]        = axi_m_r_data_i[m]     ;
        assign m_r_vif.r_resp[m]        = axi_m_r_resp_i[m]     ;
        assign m_r_vif.r_last[m]        = axi_m_r_last_i[m]     ;
        assign m_r_vif.r_user[m]        = axi_m_r_user_i[m]     ;
    end
    
    // -------------------------------------------------------------------------------------------- //
    // -- Slave ----------------------------------------------------------------------------------- //
    // -------------------------------------------------------------------------------------------- //
    for (genvar s=0; s<SLAVES; s++) begin
        // AW
        assign axi_s_aw_ready_o[s]      = s_w_vif.aw_ready[s]       ;
        assign s_w_vif.aw_valid[s]      = axi_s_aw_valid_i[s]       ;
        assign s_w_vif.aw_tid[s]        = axi_s_aw_id_i[s]          ;
        assign s_w_vif.aw_addr[s]       = axi_s_aw_addr_i[s]        ;
        assign s_w_vif.aw_len[s]        = axi_s_aw_len_i[s]         ;
        assign s_w_vif.aw_size[s]       = axi_s_aw_size_i[s]        ;
        assign s_w_vif.aw_burst[s]      = axi_s_aw_burst_i[s]       ;
        assign s_w_vif.aw_lock[s]       = axi_s_aw_lock_i[s]        ;
        assign s_w_vif.aw_cache[s]      = axi_s_aw_cache_i[s]       ;
        assign s_w_vif.aw_prot[s]       = axi_s_aw_prot_i[s]        ;
        assign s_w_vif.aw_qos[s]        = axi_s_aw_qos_i[s]         ;
        assign s_w_vif.aw_region[s]     = axi_s_aw_region_i[s]      ;
        assign s_w_vif.aw_user[s]       = axi_s_aw_user_i[s]        ;
        // W
        assign axi_s_w_ready_o[s]       = s_w_vif.w_ready[s]        ;
        assign s_w_vif.w_valid[s]       = axi_s_w_valid_i[s]        ;
        assign s_w_vif.w_tid[s]         = axi_s_w_id_i[s]           ;
        assign s_w_vif.w_data[s]        = axi_s_w_data_i[s]         ;
        assign s_w_vif.w_strb[s]        = axi_s_w_strb_i[s]         ;
        assign s_w_vif.w_user[s]        = axi_s_w_user_i[s]         ;
        assign s_w_vif.w_last[s]        = axi_s_w_last_i[s]         ;
        // B
        assign s_w_vif.b_ready[s]       = axi_s_b_ready_i[s]        ;
        assign axi_s_b_valid_o[s]       = s_w_vif.b_valid[s]        ;
        assign axi_s_b_id_o[s]          = s_w_vif.b_tid[s]          ;
        assign axi_s_b_resp_o[s]        = s_w_vif.b_resp[s]         ;
        assign axi_s_b_user_o[s]        = s_w_vif.b_user[s]         ;
        // AR
        assign axi_s_ar_ready_o[s]      = s_r_vif.ar_ready[s]       ;
        assign s_r_vif.ar_valid[s]      = axi_s_ar_valid_i[s]       ;
        assign s_r_vif.ar_tid[s]        = axi_s_ar_id_i[s]          ;
        assign s_r_vif.ar_addr[s]       = axi_s_ar_addr_i[s]        ;
        assign s_r_vif.ar_len[s]        = axi_s_ar_len_i[s]         ;
        assign s_r_vif.ar_size[s]       = axi_s_ar_size_i[s]        ;
        assign s_r_vif.ar_burst[s]      = axi_s_ar_burst_i[s]       ;
        assign s_r_vif.ar_lock[s]       = axi_s_ar_lock_i[s]        ;
        assign s_r_vif.ar_cache[s]      = axi_s_ar_cache_i[s]       ;
        assign s_r_vif.ar_prot[s]       = axi_s_ar_prot_i[s]        ;
        assign s_r_vif.ar_qos[s]        = axi_s_ar_qos_i[s]         ;
        assign s_r_vif.ar_region[s]     = axi_s_ar_region_i[s]      ;
        assign s_r_vif.ar_user[s]       = axi_s_ar_user_i[s]        ;
        // R
        assign s_r_vif.r_ready[s]       = axi_s_r_ready_i[s]        ;
        assign axi_s_r_valid_o[s]       = s_r_vif.r_valid[s]        ;
        assign axi_s_r_id_o[s]          = s_r_vif.r_tid[s]          ;
        assign axi_s_r_data_o[s]        = s_r_vif.r_data[s]         ;
        assign axi_s_r_resp_o[s]        = s_r_vif.r_resp[s]         ;
        assign axi_s_r_last_o[s]        = s_r_vif.r_last[s]         ;
        assign axi_s_r_user_o[s]        = s_r_vif.r_user[s]         ;
    end
endmodule

// `default_nettype wire

