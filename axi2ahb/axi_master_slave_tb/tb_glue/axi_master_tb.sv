import ni_global::*;
import noc_global::*;
import axi_transactions_pkg::*;
import axi_m_w_initiator_pkg::*;
import axi_m_r_initiator_pkg::*;
import tb_pkg_general::*;

// `default_nettype none

module axi_master_tb
#(
    // Design config params
    parameter int DW                = 64,  // Data bus width
    parameter int AW                = 32,  // Address width
    parameter int TIDW              = 1,
    parameter int USERW             = 1, // Width of the AxUSER signal - should be > 0
    // TB params
    parameter tb_gen_mode_t TB_MODE = TBGMT_RANDOM, // TBGMT_RANDOM (rnd) or TBGMT_DIRECTED (using file)
    // DIRECTED-related params
    parameter string INP_FILENAME_WR =  "C:/Users/zacarry/Desktop/Verilog/axi2ahb/writes_list.txt",
    parameter string INP_FILENAME_RD = "C:/Users/zacarry/Desktop/Verilog/axi2ahb/reads_list.txt",
    // RANDOM-related params
    parameter int STALL_RATE_WR     = 0,
    parameter int STALL_RATE_RD     = 0,
    parameter int GEN_RATE_WR       = 25, // Write transactions generation rate
    parameter int TRANS_COUNT_WR    = 8, // number of write transactions to be generated (ignored for DIRECTED test)
    parameter int GEN_RATE_RD       = 25, // Read transactions generation rate 
    parameter int TRANS_COUNT_RD    = 0, // number of write transactions to be generated (ignored for DIRECTED test)
    parameter logic DO_UNALIGNED    = 1'b0, // Size-Unaligned transfers?
    parameter int INCR_DISTR        = 1, // burst distribution (INCR)
    parameter int WRAP_DISTR        = 0, // burst distribution (WRAP)
    parameter int FIXED_DISTR       = 0, // burst distribution (FIXED)
    parameter int MIN_BURST_LEN     = 0, // minimum burst length [0...255]
    parameter int MAX_BURST_LEN     = 5, // minimum burst length [MIN...255]
    parameter int MIN_BURST_SIZE    = 0, // minimum burst size [0...$clog(DW/8)]
    parameter int MAX_BURST_SIZE    = $clog2(DW/8), // minimum burst size [MIN...$clog(DW/8)]
    parameter logic WRITE_TO_FILE   = 1'b1, // write output file
    parameter string FLNAME_WR      = "C:/Users/zacarry/Desktop/Verilog/axi2ahb/writes_output.txt", // output filename (writes)
    parameter string FLNAME_RD      = "C:/Users/zacarry/Desktop/Verilog/axi2ahb/reads_output.txt" // output filename (reads)
)
(
    // clock/reset
    input  logic                                    clk,
    input  logic                                    rst_n,
    // -- Master AXI interface -- //
    // AW (Write Address) channel (NI -> Target)
    output logic[TIDW-1:0]                          axi_aw_id_o,    // AWID
    output logic[AW-1:0]                            axi_aw_addr_o,  // AWADDR
    output logic[7:0]                               axi_aw_len_o,   // AWLEN
    output logic[2:0]                               axi_aw_size_o,  // AWSIZE
    output logic[1:0]                               axi_aw_burst_o, // AWBURST
    output logic[1:0]                               axi_aw_lock_o,  // AWLOCK / 2-bit always for AMBA==3 compliance, but MSB is always tied to zero (no locked support) 
    output logic[3:0]                               axi_aw_cache_o, // AWCACHE
    output logic[2:0]                               axi_aw_prot_o,  // AWPROT
    output logic[3:0]                               axi_aw_qos_o,   // AWQOS
    output logic[3:0]                               axi_aw_region_o,// AWREGION
    output logic[USERW-1:0]                         axi_aw_user_o,  // AWUSER
    output logic                                    axi_aw_valid_o, // AWVALID
    input logic                                     axi_aw_ready_i, // AWREADY
    // W (Write Data) channel (NI -> Target)
    output logic[TIDW-1:0]                          axi_w_id_o,     // WID / driven only under AMBA==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
    output logic[DW-1:0]                            axi_w_data_o,   // WDATA
    output logic[DW/8-1:0]                          axi_w_strb_o,   // WSTRB
    output logic                                    axi_w_last_o,   // WLAST
    output logic[USERW-1:0]                         axi_w_user_o,   // WUSER / tied to zero
    output logic                                    axi_w_valid_o,  // WVALID
    input  logic                                    axi_w_ready_i,  // WREADY
    // B (Write Response) channel (Target -> NI)
    input logic[TIDW-1:0]                           axi_b_id_i,     // BID
    input logic[1:0]                                axi_b_resp_i,   // BRESP
    input logic[USERW-1:0]                          axi_b_user_i,   // BUSER
    input logic                                     axi_b_valid_i,  // BVALID
    output logic                                    axi_b_ready_o,  // BREADY
    // AR (Read Address) channel (NI -> Target)
    output logic[TIDW-1:0]                          axi_ar_id_o,    // ARID
    output logic[AW-1:0]                            axi_ar_addr_o,  // ARADDR
    output logic[7:0]                               axi_ar_len_o,   // ARLEN
    output logic[2:0]                               axi_ar_size_o,  // ARSIZE
    output logic[1:0]                               axi_ar_burst_o, // ARBURST
    output logic[1:0]                               axi_ar_lock_o,  // ARLOCK / 2-bit always for AMBA==3 compliance, but MSB is always tied to zero (no locked support)
    output logic[3:0]                               axi_ar_cache_o, // ARCACHE
    output logic[2:0]                               axi_ar_prot_o,  // ARPROT
    output logic[3:0]                               axi_ar_qos_o,   // ARQOS
    output logic[3:0]                               axi_ar_region_o,// ARREGION
    output logic[USERW-1:0]                         axi_ar_user_o,  // ARUSER
    output logic                                    axi_ar_valid_o, // ARVALID
    input  logic                                    axi_ar_ready_i, // ARREADY
    // R (Read Data) channel (Target -> NI)
    input  logic[TIDW-1:0]                          axi_r_id_i,     // RID
    input  logic[DW-1:0]                            axi_r_data_i,   // RDATA
    input  logic[1:0]                               axi_r_resp_i,   // RRESP
    input  logic                                    axi_r_last_i,   // RLAST
    input  logic[USERW-1:0]                         axi_r_user_i,   // RUSER
    input  logic                                    axi_r_valid_i,  // RVALID
    output logic                                    axi_r_ready_o   // RREADY
);
    // -- SNI config ------------------------------------------------------------------------------- //
    localparam int MASTERS                  = 1;
    localparam int SLAVES                   = 1;
    
    localparam int TIDS_MASTER              = 1;
    
    localparam logic CHECK_RV_HANDSHAKE_IFS = 1'b1;
    
    localparam int AMBA=4; 
    localparam int ADDRESS_WIDTH            = 32;
    localparam int ADDR_MSTTID_P            = 24; // this is where the master_id and tid will be stored at the address of transaction - big enough so that we don't mess with 1024-bit buses and 4k bound
    
    localparam int MTIDW    = log2c_1if1(TIDS_MASTER);
    
    // Write Master
    axi_m_w_initiator
    #(
        .MASTERS        (MASTERS),
        .ADDR_MSTTID_P  (ADDR_MSTTID_P),
        .ADDR_WIDTH     (ADDRESS_WIDTH),
        .LEN_WIDTH      (AXI_SPECS_WIDTH_LEN),
        .SIZE_WIDTH     (AXI_SPECS_WIDTH_SIZE),
        .BURST_WIDTH    (AXI_SPECS_WIDTH_BURST),
        .LOCK_WIDTH     (AXI_SPECS_WIDTH_LOCK),
        .CACHE_WIDTH    (AXI_SPECS_WIDTH_CACHE),
        .PROT_WIDTH     (AXI_SPECS_WIDTH_PROT),
        .QOS_WIDTH      (AXI_SPECS_WIDTH_QOS),
        .REGION_WIDTH   (AXI_SPECS_WIDTH_REGION),
        .AW_USER_WIDTH  (USERW),
        .AW_TID_WIDTH   (TIDW),
        .W_DATA_WIDTH   (int'(DW)),
        .W_USER_WIDTH   (USERW),
        .B_RESP_WIDTH   (AXI_SPECS_WIDTH_RESP),
        .B_USER_WIDTH   (USERW)
    ) master_w[MASTERS-1:0];
    
    // IF - Write Master <--> DUT
    axi_rv_if_m_w
    #(
        .PORTS          (MASTERS),
        .ADDR_WIDTH     (ADDRESS_WIDTH),
        .LEN_WIDTH      (AXI_SPECS_WIDTH_LEN),
        .SIZE_WIDTH     (AXI_SPECS_WIDTH_SIZE),
        .BURST_WIDTH    (AXI_SPECS_WIDTH_BURST),
        .LOCK_WIDTH     (AXI_SPECS_WIDTH_LOCK),
        .CACHE_WIDTH    (AXI_SPECS_WIDTH_CACHE),
        .PROT_WIDTH     (AXI_SPECS_WIDTH_PROT),
        .QOS_WIDTH      (AXI_SPECS_WIDTH_QOS),
        .REGION_WIDTH   (AXI_SPECS_WIDTH_REGION),
        .AW_USER_WIDTH  (USERW),
        .AW_TID_WIDTH   (TIDW),
        .W_DATA_WIDTH   (int'(DW)),
        .W_USER_WIDTH   (USERW),
        .B_RESP_WIDTH   (AXI_SPECS_WIDTH_RESP),
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
        .ADDR_WIDTH     (ADDRESS_WIDTH),
        .LEN_WIDTH      (AXI_SPECS_WIDTH_LEN),
        .SIZE_WIDTH     (AXI_SPECS_WIDTH_SIZE),
        .BURST_WIDTH    (AXI_SPECS_WIDTH_BURST),
        .LOCK_WIDTH     (AXI_SPECS_WIDTH_LOCK),
        .CACHE_WIDTH    (AXI_SPECS_WIDTH_CACHE),
        .PROT_WIDTH     (AXI_SPECS_WIDTH_PROT),
        .QOS_WIDTH      (AXI_SPECS_WIDTH_QOS),
        .REGION_WIDTH   (AXI_SPECS_WIDTH_REGION),
        .AR_TID_WIDTH   (TIDW),
        .AR_USER_WIDTH  (USERW),
        .R_DATA_WIDTH   (DW),
        .R_RESP_WIDTH   (AXI_SPECS_WIDTH_RESP),
        .R_USER_WIDTH   (USERW)
    ) master_r[MASTERS-1:0];
        
    // IF - Read Masters <--> DUT
    axi_rv_if_m_r
    #(  
        .PORTS          (MASTERS),
        .ADDR_WIDTH     (ADDRESS_WIDTH),
        .LEN_WIDTH      (AXI_SPECS_WIDTH_LEN),
        .SIZE_WIDTH     (AXI_SPECS_WIDTH_SIZE),
        .BURST_WIDTH    (AXI_SPECS_WIDTH_BURST),
        .LOCK_WIDTH     (AXI_SPECS_WIDTH_LOCK),
        .CACHE_WIDTH    (AXI_SPECS_WIDTH_CACHE),
        .PROT_WIDTH     (AXI_SPECS_WIDTH_PROT),
        .QOS_WIDTH      (AXI_SPECS_WIDTH_QOS),
        .REGION_WIDTH   (AXI_SPECS_WIDTH_REGION),
        .AR_TID_WIDTH   (TIDW),
        .AR_USER_WIDTH  (USERW),
        .R_DATA_WIDTH   (DW),
        .R_RESP_WIDTH   (AXI_SPECS_WIDTH_RESP),
        .R_USER_WIDTH   (USERW)
    )
    m_r_vif
    (
        .clk    (clk)
    );
    
    // MBs
    // W
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_m_w[MASTERS][];
    // R
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_m_r_exp[MASTERS][];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_m_r_got[MASTERS];
    
    task build_all();
        automatic logic IS_RANDOM_DATA  = 1'b0;
        
        // Write - Master
        for(int m=0; m<MASTERS; m++) begin
            mb_m_w[m]      = new[TIDS_MASTER];
            mb_m_r_exp[m]  = new[TIDS_MASTER];
            for(int t=0; t<TIDS_MASTER; t++) begin
                mb_m_w[m][t]        = new();
                mb_m_r_exp[m][t]    = new();
            end
            mb_m_r_got[m]  = new();
        end
        
        // Masters
        for(int m=0; m<MASTERS; m++) begin
            // Write Master
            master_w[m] = new(m, TIDS_MASTER, DW/8,
                              STALL_RATE_WR,
                              GEN_RATE_WR,
                              TB_MODE, INP_FILENAME_WR,
                              TRANS_COUNT_WR, 
                              FIXED_DISTR, INCR_DISTR, WRAP_DISTR, DO_UNALIGNED,
                              MIN_BURST_LEN, MAX_BURST_LEN, MIN_BURST_SIZE, MAX_BURST_SIZE,
                              IS_RANDOM_DATA,
                              mb_m_w[m],
                              WRITE_TO_FILE, FLNAME_WR);
            master_w[m].vif = m_w_vif.c_if;
            // Read Master
            master_r[m] = new(m, TIDS_MASTER, DW/8,
                              STALL_RATE_RD,
                              GEN_RATE_RD, TB_MODE, INP_FILENAME_RD,
                              TRANS_COUNT_RD,
                              FIXED_DISTR, INCR_DISTR, WRAP_DISTR, DO_UNALIGNED,
                              MIN_BURST_LEN, MAX_BURST_LEN, MIN_BURST_SIZE, MAX_BURST_SIZE,
                              IS_RANDOM_DATA,
                              mb_m_r_exp[m], mb_m_r_got[m],
                              WRITE_TO_FILE, FLNAME_RD);
            master_r[m].vif = m_r_vif.c_if;
        end
    endtask
    
    task reset_all();
        // vIFs
        m_w_vif.c_if.do_reset();
        m_r_vif.c_if.do_reset();
        
        // Masters
        for(int s=0; s<MASTERS; s++) begin: for_mw
            master_w[s].do_reset();
            master_r[s].do_reset();
        end
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
        end join_none
    endtask
    
    initial begin: env_core
        build_all();
        $display("%0t: Everything built", $time);
        
        @(negedge rst_n);
        reset_all();
        @(posedge rst_n);
        if (CHECK_RV_HANDSHAKE_IFS) begin
            // inl_init_if.check_rv_handshake = 1;
            m_w_vif.check_rv_handshake = 1;
            m_r_vif.check_rv_handshake = 1;
        end
        
        $display("%0t: Reset ended", $time);

        start_masters();
        
    end
    
    // M <--> DUT (Write)
    for(genvar m=0; m<MASTERS; m++) begin: for_mw
        axi_duth_if_w
        #(
            .AXI_MODE           (AMBA),
            .ADDRESS_WIDTH      (ADDRESS_WIDTH),
            .LEN_WIDTH          (AXI_SPECS_WIDTH_LEN),
            .SIZE_WIDTH         (AXI_SPECS_WIDTH_SIZE),
            .BURST_WIDTH        (AXI_SPECS_WIDTH_BURST),
            .LOCK_WIDTH         (AXI_SPECS_WIDTH_LOCK),
            .CACHE_WIDTH        (AXI_SPECS_WIDTH_CACHE),
            .PROT_WIDTH         (AXI_SPECS_WIDTH_PROT),
            .QOS_WIDTH          (AXI_SPECS_WIDTH_QOS),
            .REGION_WIDTH       (AXI_SPECS_WIDTH_REGION),
            .AW_TID_WIDTH       (TIDW),
            .AW_USER_WIDTH      (USERW),
            .W_DATA_WIDTH       (DW),
            .W_USER_WIDTH       (USERW),
            .B_RESP_WIDTH       (AXI_SPECS_WIDTH_RESP),
            .B_USER_WIDTH       (USERW)
        )
        mw_if
        (
            .clk                (clk),
            .rst                (~rst_n),
            .check_rv_handshake (1'b1),
            .check_unknown      (1'b1)
        );
        
        // AW
        assign m_w_vif.aw_ready[m]          = for_mw[m].mw_if.aw_ready;
        assign for_mw[m].mw_if.aw_valid     = m_w_vif.aw_valid[m];
        assign for_mw[m].mw_if.aw_tid       = m_w_vif.aw_tid[m];
        assign for_mw[m].mw_if.aw_addr      = m_w_vif.aw_addr[m];
        assign for_mw[m].mw_if.aw_len       = m_w_vif.aw_len[m];
        assign for_mw[m].mw_if.aw_size      = m_w_vif.aw_size[m];
        assign for_mw[m].mw_if.aw_burst     = m_w_vif.aw_burst[m];
        assign for_mw[m].mw_if.aw_lock      = m_w_vif.aw_lock[m];
        assign for_mw[m].mw_if.aw_cache     = m_w_vif.aw_cache[m];
        assign for_mw[m].mw_if.aw_prot      = m_w_vif.aw_prot[m];
        assign for_mw[m].mw_if.aw_qos       = m_w_vif.aw_qos[m];
        assign for_mw[m].mw_if.aw_region    = m_w_vif.aw_region[m];
        assign for_mw[m].mw_if.aw_user      = m_w_vif.aw_user[m];
        // W
        assign m_w_vif.w_ready[m]           = for_mw[m].mw_if.w_ready;
        assign for_mw[m].mw_if.w_valid      = m_w_vif.w_valid[m];
        assign for_mw[m].mw_if.w_data       = m_w_vif.w_data[m];
        assign for_mw[m].mw_if.w_strb       = m_w_vif.w_strb[m];
        assign for_mw[m].mw_if.w_user       = m_w_vif.w_user[m];
        assign for_mw[m].mw_if.w_last       = m_w_vif.w_last[m];
        // B
        assign for_mw[m].mw_if.b_ready      = m_w_vif.b_ready[m];
        assign m_w_vif.b_valid[m]           = for_mw[m].mw_if.b_valid;
        assign m_w_vif.b_tid[m]             = for_mw[m].mw_if.b_tid;
        assign m_w_vif.b_resp[m]            = for_mw[m].mw_if.b_resp;
        assign m_w_vif.b_user[m]            = for_mw[m].mw_if.b_user;
    end
    
    // M <--> DUT (Read)
    for(genvar m=0; m<MASTERS; m++) begin: for_mr
        axi_duth_if_r
        #(
            .AXI_MODE           (AMBA),
            .ADDRESS_WIDTH      (ADDRESS_WIDTH),
            .LEN_WIDTH          (AXI_SPECS_WIDTH_LEN),
            .SIZE_WIDTH         (AXI_SPECS_WIDTH_SIZE),
            .BURST_WIDTH        (AXI_SPECS_WIDTH_BURST),
            .LOCK_WIDTH         (AXI_SPECS_WIDTH_LOCK),
            .CACHE_WIDTH        (AXI_SPECS_WIDTH_CACHE),
            .PROT_WIDTH         (AXI_SPECS_WIDTH_PROT),
            .QOS_WIDTH          (AXI_SPECS_WIDTH_QOS),
            .REGION_WIDTH       (AXI_SPECS_WIDTH_REGION),
            .AR_TID_WIDTH       (TIDW),
            .AR_USER_WIDTH      (USERW),
            .R_DATA_WIDTH       (DW),
            .R_RESP_WIDTH       (AXI_SPECS_WIDTH_RESP),
            .R_USER_WIDTH       (USERW)
        )
        mr_if
        (
            .clk                (clk),
            .rst                (~rst_n),
            .check_rv_handshake (1'b1),
            .check_unknown      (1'b1)
        );
        
        // AR
        assign m_r_vif.ar_ready[m]       = for_mr[m].mr_if.ar_ready;
        assign for_mr[m].mr_if.ar_valid  = m_r_vif.ar_valid[m]     ;
        assign for_mr[m].mr_if.ar_tid    = m_r_vif.ar_tid[m]       ;
        assign for_mr[m].mr_if.ar_addr   = m_r_vif.ar_addr[m]      ;
        assign for_mr[m].mr_if.ar_len    = m_r_vif.ar_len[m]       ;
        assign for_mr[m].mr_if.ar_size   = m_r_vif.ar_size[m]      ;
        assign for_mr[m].mr_if.ar_burst  = m_r_vif.ar_burst[m]     ;
        assign for_mr[m].mr_if.ar_lock   = m_r_vif.ar_lock[m]      ;
        assign for_mr[m].mr_if.ar_cache  = m_r_vif.ar_cache[m]     ;
        assign for_mr[m].mr_if.ar_prot   = m_r_vif.ar_prot[m]      ;
        assign for_mr[m].mr_if.ar_qos    = m_r_vif.ar_qos[m]       ;
        assign for_mr[m].mr_if.ar_region = m_r_vif.ar_region[m]    ;
        assign for_mr[m].mr_if.ar_user   = m_r_vif.ar_user[m]      ;
        // R
        assign for_mr[m].mr_if.r_ready   = m_r_vif.r_ready[m]      ;
        assign m_r_vif.r_valid[m]        = for_mr[m].mr_if.r_valid ;
        assign m_r_vif.r_tid[m]          = for_mr[m].mr_if.r_tid   ;
        assign m_r_vif.r_data[m]         = for_mr[m].mr_if.r_data  ;
        assign m_r_vif.r_resp[m]         = for_mr[m].mr_if.r_resp  ;
        assign m_r_vif.r_last[m]         = for_mr[m].mr_if.r_last  ;
        assign m_r_vif.r_user[m]         = for_mr[m].mr_if.r_user  ;
    end
    
    // AW
    assign for_mw[0].mw_if.aw_ready     = axi_aw_ready_i              ;
    assign axi_aw_valid_o               = for_mw[0].mw_if.aw_valid    ;
    assign axi_aw_id_o                  = for_mw[0].mw_if.aw_tid      ;
    assign axi_aw_addr_o                = for_mw[0].mw_if.aw_addr     ;
    assign axi_aw_len_o                 = for_mw[0].mw_if.aw_len      ;
    assign axi_aw_size_o                = for_mw[0].mw_if.aw_size     ;
    assign axi_aw_burst_o               = for_mw[0].mw_if.aw_burst    ;
    assign axi_aw_lock_o                = for_mw[0].mw_if.aw_lock     ;
    assign axi_aw_cache_o               = for_mw[0].mw_if.aw_cache    ;
    assign axi_aw_prot_o                = for_mw[0].mw_if.aw_prot     ;
    assign axi_aw_qos_o                 = for_mw[0].mw_if.aw_qos      ;
    assign axi_aw_region_o              = for_mw[0].mw_if.aw_region   ;
    assign axi_aw_user_o                = for_mw[0].mw_if.aw_user     ;
    // W
    assign for_mw[0].mw_if.w_ready      = axi_w_ready_i               ;
    assign axi_w_valid_o                = for_mw[0].mw_if.w_valid     ;
    assign axi_w_id_o                   = for_mw[0].mw_if.w_tid       ;
    assign axi_w_data_o                 = for_mw[0].mw_if.w_data      ;
    assign axi_w_strb_o                 = for_mw[0].mw_if.w_strb      ;
    assign axi_w_user_o                 = for_mw[0].mw_if.w_user      ;
    assign axi_w_last_o                 = for_mw[0].mw_if.w_last      ;
    // B
    assign axi_b_ready_o                = for_mw[0].mw_if.b_ready    ;
    assign for_mw[0].mw_if.b_valid      = axi_b_valid_i              ;
    assign for_mw[0].mw_if.b_tid        = axi_b_id_i                 ;
    assign for_mw[0].mw_if.b_resp       = axi_b_resp_i               ;
    assign for_mw[0].mw_if.b_user       = axi_b_user_i               ;
    
    // AR
    assign for_mr[0].mr_if.ar_ready     = axi_ar_ready_i               ;
    assign axi_ar_valid_o               = for_mr[0].mr_if.ar_valid     ;
    assign axi_ar_id_o                  = for_mr[0].mr_if.ar_tid       ;
    assign axi_ar_addr_o                = for_mr[0].mr_if.ar_addr      ;
    assign axi_ar_len_o                 = for_mr[0].mr_if.ar_len       ;
    assign axi_ar_size_o                = for_mr[0].mr_if.ar_size      ;
    assign axi_ar_burst_o               = for_mr[0].mr_if.ar_burst     ;
    assign axi_ar_lock_o                = for_mr[0].mr_if.ar_lock      ;
    assign axi_ar_cache_o               = for_mr[0].mr_if.ar_cache     ;
    assign axi_ar_prot_o                = for_mr[0].mr_if.ar_prot      ;
    assign axi_ar_qos_o                 = for_mr[0].mr_if.ar_qos       ;
    assign axi_ar_region_o              = for_mr[0].mr_if.ar_region    ;
    assign axi_ar_user_o                = for_mr[0].mr_if.ar_user      ;
    // R
    assign axi_r_ready_o                = for_mr[0].mr_if.r_ready      ;
    assign for_mr[0].mr_if.r_valid      = axi_r_valid_i                ;
    assign for_mr[0].mr_if.r_tid        = axi_r_id_i                   ;
    assign for_mr[0].mr_if.r_data       = axi_r_data_i                 ;
    assign for_mr[0].mr_if.r_resp       = axi_r_resp_i                 ;
    assign for_mr[0].mr_if.r_last       = axi_r_last_i                 ;
    assign for_mr[0].mr_if.r_user       = axi_r_user_i                 ;

endmodule

// `default_nettype wire
