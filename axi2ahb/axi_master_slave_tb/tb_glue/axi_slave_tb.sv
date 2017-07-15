import ni_global::*;
import noc_global::*;
import axi_transactions_pkg::*;
import axi_s_w_responder_pkg::*;
import axi_s_r_responder_pkg::*;
import tb_pkg_general::*;

module axi_slave_tb
#(
    parameter int DW            = 64,  // Data bus width
    parameter int AW            = 32,  // Address width
    parameter int TIDW  = 1,
    parameter int SERVE_RATE    = 100, // Rate at which Slave generates responses
    parameter int ERROR_RATE    = 0,   // Rate at which Slave generates errors
    parameter int STALL_RATE_AW = 0,   // Stalling rate for channel AW
    parameter int STALL_RATE_W  = 0,   // Stalling rate for channel W
    parameter int STALL_RATE_AR = 0,   // Stalling rate for channel AR
    parameter int USERW         = 1    // Width of the AxUSER signal - should be > 0
)
(
    // clock/reset
    input  logic                                    clk,
    input  logic                                    rst_n,
    // -- Slave AXI interface -- //
    // AW (Write Address) channel (NI -> Target)
    input  logic[TIDW-1:0]                          axi_aw_id_i,    // AWID
    input  logic[AW-1:0]                            axi_aw_addr_i,  // AWADDR
    input  logic[7:0]                               axi_aw_len_i,   // AWLEN
    input  logic[2:0]                               axi_aw_size_i,  // AWSIZE
    input  logic[1:0]                               axi_aw_burst_i, // AWBURST
    input  logic[1:0]                               axi_aw_lock_i,  // AWLOCK / 2-bit always for AMBA==3 compliance, but MSB is always tied to zero (no locked support) 
    input  logic[3:0]                               axi_aw_cache_i, // AWCACHE
    input  logic[2:0]                               axi_aw_prot_i,  // AWPROT
    input  logic[3:0]                               axi_aw_qos_i,   // AWQOS
    input  logic[3:0]                               axi_aw_region_i,// AWREGION
    input  logic[USERW-1:0]                         axi_aw_user_i,  // AWUSER
    input  logic                                    axi_aw_valid_i, // AWVALID
    output logic                                    axi_aw_ready_o, // AWREADY
    // W (Write Data) channel (NI -> Target)
    input  logic[TIDW-1:0]                          axi_w_id_i,     // WID / driven only under AMBA==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
    input  logic[DW-1:0]                            axi_w_data_i,   // WDATA
    input  logic[DW/8-1:0]                          axi_w_strb_i,   // WSTRB
    input  logic                                    axi_w_last_i,   // WLAST
    input  logic[USERW-1:0]                         axi_w_user_i,   // WUSER / tied to zero
    input  logic                                    axi_w_valid_i,  // WVALID
    output logic                                    axi_w_ready_o,  // WREADY
    // B (Write Response) channel (Target -> NI)
    output logic[TIDW-1:0]                          axi_b_id_o,     // BID
    output logic[1:0]                               axi_b_resp_o,   // BRESP
    output logic[USERW-1:0]                         axi_b_user_o,   // BUSER
    output logic                                    axi_b_valid_o,  // BVALID
    input  logic                                    axi_b_ready_i,  // BREADY
    // AR (Read Address) channel (NI -> Target)
    input  logic[TIDW-1:0]                          axi_ar_id_i,    // ARID
    input  logic[AW-1:0]                            axi_ar_addr_i,  // ARADDR
    input  logic[7:0]                               axi_ar_len_i,   // ARLEN
    input  logic[2:0]                               axi_ar_size_i,  // ARSIZE
    input  logic[1:0]                               axi_ar_burst_i, // ARBURST
    input  logic[1:0]                               axi_ar_lock_i,  // ARLOCK / 2-bit always for AMBA==3 compliance, but MSB is always tied to zero (no locked support)
    input  logic[3:0]                               axi_ar_cache_i, // ARCACHE
    input  logic[2:0]                               axi_ar_prot_i,  // ARPROT
    input  logic[3:0]                               axi_ar_qos_i,   // ARQOS
    input  logic[3:0]                               axi_ar_region_i,// ARREGION
    input  logic[USERW-1:0]                         axi_ar_user_i,  // ARUSER
    input  logic                                    axi_ar_valid_i, // ARVALID
    output logic                                    axi_ar_ready_o, // ARREADY
    // R (Read Data) channel (Target -> NI)
    output logic[TIDW-1:0]                          axi_r_id_o,     // RID
    output logic[DW-1:0]                            axi_r_data_o,   // RDATA
    output logic[1:0]                               axi_r_resp_o,   // RRESP
    output logic                                    axi_r_last_o,   // RLAST
    output logic[USERW-1:0]                         axi_r_user_o,   // RUSER
    output logic                                    axi_r_valid_o,  // RVALID
    input  logic                                    axi_r_ready_i   // RREADY
);
    // -- SNI config ------------------------------------------------------------------------------- //
    localparam int MASTERS                  = 1;
    localparam int SLAVES                   = 1;
    
    localparam int TIDS_MASTER              = 1;
    
    localparam int SIM_CYCLES               = 2000;
    localparam logic CHECK_RV_HANDSHAKE_IFS = 1'b1;
    
    localparam logic SLAVE_RD_INTERLEAVE    = 0;
    localparam int AMBA=4; 
    localparam int ADDRESS_WIDTH            = 32;
    localparam int ADDR_MSTTID_P            = 24; // this is where the master_id and tid will be stored at the address of transaction - big enough so that we don't mess with 1024-bit buses and 4k bound
    
    localparam int MTIDW    = log2c_1if1(TIDS_MASTER);
    
    // Write Slaves
    axi_s_w_responder
    #(
        .SLAVES         (SLAVES),
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
        .B_USER_WIDTH   (USERW),
        .AW_MTID_W      (log2c_1if1(TIDS_MASTER))
    ) slave_w[SLAVES-1:0];
    
    // IF - Write Slaves <--> DUT
    axi_rv_if_s_w
    #(
        .PORTS          (SLAVES),
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
        .R_USER_WIDTH   (USERW),
        .AR_MTID_W      (MTIDW)
    ) slave_r[SLAVES-1:0];
        
    // IF - Read Slaves <--> DUT
    axi_rv_if_s_r
    #(  
        .PORTS          (SLAVES),
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
    s_r_vif
    (
        .clk    (clk)
    );
    
    // MBs
    // W
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_byte_m_w_p[MASTERS][];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_byte_m_w_np[MASTERS][];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_byte_s_w_p[SLAVES];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_byte_s_w_np[SLAVES];
    
    // R
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_s_r_byte_resp[SLAVES][];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_m_r_byte_resp[MASTERS];
    
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_m_r_byte_req_m2m[MASTERS][];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_m_r_byte_resp_m2m[MASTERS];
    
    task build_all();
        automatic logic IS_RANDOM_DATA  = 1'b0;
        
        automatic int serve_rate_w      = SERVE_RATE;
        automatic int serve_rate_r      = SERVE_RATE;
        automatic int stall_rate_aw     = STALL_RATE_AW;
        automatic int stall_rate_w      = STALL_RATE_W;
        automatic int stall_rate_ar     = STALL_RATE_AR;
        
        // Write - Master
        for(int m=0; m<MASTERS; m++) begin
            mb_byte_m_w_p[m]      = new[TIDS_MASTER];
            mb_byte_m_w_np[m]      = new[TIDS_MASTER];
            for(int t=0; t<TIDS_MASTER; t++) begin
                mb_byte_m_w_p[m][t]   = new();
                mb_byte_m_w_np[m][t]   = new();
            end
        end
        
        // Write - Slave
        for(int s=0; s<SLAVES; s++) begin
            mb_byte_s_w_p[s] = new();
            mb_byte_s_w_np[s] = new();
        end
        
        for (int m=0; m<MASTERS; m++) begin
            mb_m_r_byte_resp[m] = new();
        end
        
        for (int m=0; m<MASTERS; m++) begin
            mb_m_r_byte_req_m2m[m] = new[TIDS_MASTER];
            mb_m_r_byte_resp_m2m[m] = new();
            
            for(int t=0; t<TIDS_MASTER; t++) begin
                mb_m_r_byte_req_m2m[m][t] = new();
            end
        end
        
        
        // Read - Slave
        for(int s=0; s<SLAVES; s++) begin
            mb_s_r_byte_resp[s] = new[TIDS_MASTER];
            for(int t=0; t<TIDS_MASTER; t++) begin
                mb_s_r_byte_resp[s][t] = new();
            end
        end
        
        // Slaves
        for(int s=0; s<SLAVES; s++) begin: for_sw
            slave_w[s] = new(s, TIDS_MASTER, DW/8, IS_RANDOM_DATA, serve_rate_w, ERROR_RATE, stall_rate_aw, stall_rate_w,
                             mb_byte_s_w_p[s], mb_byte_s_w_np[s]);
            slave_w[s].vif = s_w_vif.c_if;
        end
        
        // Slaves
        for(int s=0; s<SLAVES; s++) begin: for_sr
            slave_r[s] = new(s, TIDS_MASTER, DW/8,
                             IS_RANDOM_DATA,
                              SLAVE_RD_INTERLEAVE,
                             serve_rate_r, ERROR_RATE, stall_rate_ar,
                             
                             mb_s_r_byte_resp[s]);
            slave_r[s].vif = s_r_vif.c_if;
        end
        
        // Scoreboard
        // sb_r_s2m = new(TIDS_MASTER, mb_s_r_byte_resp, mb_m_r_byte_resp, "R-s2m");
        
        
        // sb_r_m2m = new(TIDS_MASTER, mb_m_r_byte_req_m2m, mb_m_r_byte_resp_m2m, "R-m2m");
    endtask
    
    task reset_all();
        // vIFs
        s_w_vif.c_if.do_reset();
        s_r_vif.c_if.do_reset();
        
        // Slaves
        for(int s=0; s<SLAVES; s++) begin: for_sw
            slave_w[s].do_reset();
        end
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
    
    initial begin: env_core
        build_all();
        $display("%0t: Everything built", $time);
        
        @(negedge rst_n);
        reset_all();
        @(posedge rst_n);
        if (CHECK_RV_HANDSHAKE_IFS) begin
            // inl_init_if.check_rv_handshake = 1;
            s_w_vif.check_rv_handshake = 1;
            s_r_vif.check_rv_handshake = 1;
        end
        
        $display("%0t: Reset ended", $time);

        start_slaves();
        
    end
    
    // DUT <--> S (Write)
    for(genvar s=0; s<SLAVES; s++) begin: for_sw
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
        sw_if
        (
            .clk                (clk),
            .rst                (~rst_n),
            .check_rv_handshake (1'b1),
            .check_unknown      (1'b1)
        );
        
        // AW
        assign for_sw[s].sw_if.aw_ready = s_w_vif.aw_ready[s]       ;
        assign s_w_vif.aw_valid[s]      = for_sw[s].sw_if.aw_valid  ;
        assign s_w_vif.aw_tid[s]        = for_sw[s].sw_if.aw_tid    ;
        assign s_w_vif.aw_addr[s]       = for_sw[s].sw_if.aw_addr   ;
        assign s_w_vif.aw_len[s]        = for_sw[s].sw_if.aw_len    ;
        assign s_w_vif.aw_size[s]       = for_sw[s].sw_if.aw_size   ;
        assign s_w_vif.aw_burst[s]      = for_sw[s].sw_if.aw_burst  ;
        assign s_w_vif.aw_lock[s]       = for_sw[s].sw_if.aw_lock   ;
        assign s_w_vif.aw_cache[s]      = for_sw[s].sw_if.aw_cache  ;
        assign s_w_vif.aw_prot[s]       = for_sw[s].sw_if.aw_prot   ;
        assign s_w_vif.aw_qos[s]        = for_sw[s].sw_if.aw_qos    ;
        assign s_w_vif.aw_region[s]     = for_sw[s].sw_if.aw_region ;
        assign s_w_vif.aw_user[s]       = for_sw[s].sw_if.aw_user   ;
        // W
        assign for_sw[s].sw_if.w_ready  = s_w_vif.w_ready[s]        ;
        assign s_w_vif.w_valid[s]       = for_sw[s].sw_if.w_valid   ;
        assign s_w_vif.w_tid[s]         = for_sw[s].sw_if.w_tid     ;
        assign s_w_vif.w_data[s]        = for_sw[s].sw_if.w_data    ;
        assign s_w_vif.w_strb[s]        = for_sw[s].sw_if.w_strb    ;
        assign s_w_vif.w_user[s]        = for_sw[s].sw_if.w_user    ;
        assign s_w_vif.w_last[s]        = for_sw[s].sw_if.w_last    ;
        // B
        assign s_w_vif.b_ready[s]       = for_sw[s].sw_if.b_ready   ;
        assign for_sw[s].sw_if.b_valid  = s_w_vif.b_valid[s]        ;
        assign for_sw[s].sw_if.b_tid    = s_w_vif.b_tid[s]          ;
        assign for_sw[s].sw_if.b_resp   = s_w_vif.b_resp[s]         ;
        assign for_sw[s].sw_if.b_user   = s_w_vif.b_user[s]         ;
    end
    
    // DUT <--> S (Read)
    for(genvar s=0; s<SLAVES; s++) begin: for_sr
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
        sr_if
        (
            .clk                (clk),
            .rst                (~rst_n),
            .check_rv_handshake (1'b1),
            .check_unknown      (1'b1)
        );
        
        // AR
        assign for_sr[s].sr_if.ar_ready = s_r_vif.ar_ready[s]       ;
        assign s_r_vif.ar_valid[s]      = for_sr[s].sr_if.ar_valid  ;
        assign s_r_vif.ar_tid[s]        = for_sr[s].sr_if.ar_tid    ;
        assign s_r_vif.ar_addr[s]       = for_sr[s].sr_if.ar_addr   ;
        assign s_r_vif.ar_len[s]        = for_sr[s].sr_if.ar_len    ;
        assign s_r_vif.ar_size[s]       = for_sr[s].sr_if.ar_size   ;
        assign s_r_vif.ar_burst[s]      = for_sr[s].sr_if.ar_burst  ;
        assign s_r_vif.ar_lock[s]       = for_sr[s].sr_if.ar_lock   ;
        assign s_r_vif.ar_cache[s]      = for_sr[s].sr_if.ar_cache  ;
        assign s_r_vif.ar_prot[s]       = for_sr[s].sr_if.ar_prot   ;
        assign s_r_vif.ar_qos[s]        = for_sr[s].sr_if.ar_qos    ;
        assign s_r_vif.ar_region[s]     = for_sr[s].sr_if.ar_region ;
        assign s_r_vif.ar_user[s]       = for_sr[s].sr_if.ar_user   ;
        // R
        assign s_r_vif.r_ready[s]       = for_sr[s].sr_if.r_ready   ;
        assign for_sr[s].sr_if.r_valid  = s_r_vif.r_valid[s]        ;
        assign for_sr[s].sr_if.r_tid    = s_r_vif.r_tid[s]          ;
        assign for_sr[s].sr_if.r_data   = s_r_vif.r_data[s]         ;
        assign for_sr[s].sr_if.r_resp   = s_r_vif.r_resp[s]         ;
        assign for_sr[s].sr_if.r_last   = s_r_vif.r_last[s]         ;
        assign for_sr[s].sr_if.r_user   = s_r_vif.r_user[s]         ;
    end
    
    // AW
    assign axi_aw_ready_o               = for_sw[0].sw_if.aw_ready  ;
    assign for_sw[0].sw_if.aw_valid     = axi_aw_valid_i            ;
    assign for_sw[0].sw_if.aw_tid       = axi_aw_id_i               ;
    assign for_sw[0].sw_if.aw_addr      = axi_aw_addr_i             ;
    assign for_sw[0].sw_if.aw_len       = axi_aw_len_i              ;
    assign for_sw[0].sw_if.aw_size      = axi_aw_size_i             ;
    assign for_sw[0].sw_if.aw_burst     = axi_aw_burst_i            ;
    assign for_sw[0].sw_if.aw_lock      = axi_aw_lock_i             ;
    assign for_sw[0].sw_if.aw_cache     = axi_aw_cache_i            ;
    assign for_sw[0].sw_if.aw_prot      = axi_aw_prot_i             ;
    assign for_sw[0].sw_if.aw_qos       = axi_aw_qos_i              ;
    assign for_sw[0].sw_if.aw_region    = axi_aw_region_i           ;
    assign for_sw[0].sw_if.aw_user      = axi_aw_user_i             ;
    // W
    assign axi_w_ready_o                = for_sw[0].sw_if.w_ready   ;
    assign for_sw[0].sw_if.w_valid      = axi_w_valid_i             ;
    assign for_sw[0].sw_if.w_tid        = axi_w_id_i                ;
    assign for_sw[0].sw_if.w_data       = axi_w_data_i              ;
    assign for_sw[0].sw_if.w_strb       = axi_w_strb_i              ;
    assign for_sw[0].sw_if.w_user       = axi_w_user_i              ;
    assign for_sw[0].sw_if.w_last       = axi_w_last_i              ;
    // B
    assign for_sw[0].sw_if.b_ready      = axi_b_ready_i             ;
    assign axi_b_valid_o                = for_sw[0].sw_if.b_valid   ;
    assign axi_b_id_o                   = for_sw[0].sw_if.b_tid     ;
    assign axi_b_resp_o                 = for_sw[0].sw_if.b_resp    ;
    assign axi_b_user_o                 = for_sw[0].sw_if.b_user    ;
    
    // AR
    assign axi_ar_ready_o               = for_sr[0].sr_if.ar_ready  ;
    assign for_sr[0].sr_if.ar_valid     = axi_ar_valid_i            ;
    assign for_sr[0].sr_if.ar_tid       = axi_ar_id_i               ;
    assign for_sr[0].sr_if.ar_addr      = axi_ar_addr_i             ;
    assign for_sr[0].sr_if.ar_len       = axi_ar_len_i              ;
    assign for_sr[0].sr_if.ar_size      = axi_ar_size_i             ;
    assign for_sr[0].sr_if.ar_burst     = axi_ar_burst_i            ;
    assign for_sr[0].sr_if.ar_lock      = axi_ar_lock_i             ;
    assign for_sr[0].sr_if.ar_cache     = axi_ar_cache_i            ;
    assign for_sr[0].sr_if.ar_prot      = axi_ar_prot_i             ;
    assign for_sr[0].sr_if.ar_qos       = axi_ar_qos_i              ;
    assign for_sr[0].sr_if.ar_region    = axi_ar_region_i           ;
    assign for_sr[0].sr_if.ar_user      = axi_ar_user_i             ;
    // R
    assign for_sr[0].sr_if.r_ready      = axi_r_ready_i             ;
    assign axi_r_valid_o                = for_sr[0].sr_if.r_valid   ;
    assign axi_r_id_o                   = for_sr[0].sr_if.r_tid     ;
    assign axi_r_data_o                 = for_sr[0].sr_if.r_data;
    assign axi_r_resp_o                 = for_sr[0].sr_if.r_resp;
    assign axi_r_last_o                 = for_sr[0].sr_if.r_last;
    assign axi_r_user_o                 = for_sr[0].sr_if.r_user;
    
endmodule

