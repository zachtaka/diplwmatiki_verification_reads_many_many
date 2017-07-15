interface axi_rv_if_m_r
        #(  parameter int PORTS         = 1,
            // General
            parameter int ADDR_WIDTH    = 32,
            parameter int LEN_WIDTH     = 8,
            parameter int SIZE_WIDTH    = 3,
            parameter int BURST_WIDTH   = 2,
            parameter int LOCK_WIDTH    = 1,
            parameter int CACHE_WIDTH   = 4,
            parameter int PROT_WIDTH    = 3,
            parameter int QOS_WIDTH     = 4,
            parameter int REGION_WIDTH  = 4,
            // AR
            parameter int AR_TID_WIDTH  = 1,
            parameter int AR_USER_WIDTH = 2,
            // R
            parameter int R_DATA_WIDTH  = 64,
            parameter int R_RESP_WIDTH  = 2,
            parameter int R_USER_WIDTH  = 2)
        (   input logic clk);
    
    logic check_rv_handshake = 0;
    // AR
    logic[PORTS-1:0]                       ar_valid;
    logic[PORTS-1:0]                       ar_ready;
    logic[PORTS-1:0][AR_TID_WIDTH-1:0]     ar_tid;
    logic[PORTS-1:0][ADDR_WIDTH-1:0]       ar_addr;
    logic[PORTS-1:0][LEN_WIDTH-1:0]        ar_len;
    logic[PORTS-1:0][SIZE_WIDTH-1:0]       ar_size;
    logic[PORTS-1:0][BURST_WIDTH-1:0]      ar_burst;
    logic[PORTS-1:0][LOCK_WIDTH-1:0]       ar_lock;
    logic[PORTS-1:0][CACHE_WIDTH-1:0]      ar_cache;
    logic[PORTS-1:0][PROT_WIDTH-1:0]       ar_prot;
    logic[PORTS-1:0][QOS_WIDTH-1:0]        ar_qos;
    logic[PORTS-1:0][REGION_WIDTH-1:0]     ar_region;
    logic[PORTS-1:0][AR_USER_WIDTH-1:0]    ar_user;
    // R
    logic[PORTS-1:0]                    r_valid;
    logic[PORTS-1:0]                    r_ready;
    logic[PORTS-1:0][AR_TID_WIDTH-1:0]  r_tid;
    logic[PORTS-1:0][R_DATA_WIDTH-1:0]  r_data;
    logic[PORTS-1:0][R_RESP_WIDTH-1:0]  r_resp;
    logic[PORTS-1:0]                    r_last;
    logic[PORTS-1:0][R_USER_WIDTH-1:0]  r_user;
    
    
    import axi_rv_if_m_r_abstract_pkg::*;
    
    class axi_rv_if_m_r_concrete
            #(  parameter int PORTS         = 1,
                // General
                parameter int ADDR_WIDTH    = 32,
                parameter int LEN_WIDTH     = 8,
                parameter int SIZE_WIDTH    = 3,
                parameter int BURST_WIDTH   = 2,
                parameter int LOCK_WIDTH    = 1,
                parameter int CACHE_WIDTH   = 4,
                parameter int PROT_WIDTH    = 3,
                parameter int QOS_WIDTH     = 4,
                parameter int REGION_WIDTH  = 4,
                // AR
                parameter int AR_TID_WIDTH  = 1,
                parameter int AR_USER_WIDTH = 2,
                // R
                parameter int R_DATA_WIDTH  = 64,
                parameter int R_RESP_WIDTH  = 2,
                parameter int R_USER_WIDTH  = 2)
            extends axi_rv_if_m_r_abstract
                    #(  .PORTS          (PORTS),
                        .ADDR_WIDTH     (ADDR_WIDTH),
                        .LEN_WIDTH      (LEN_WIDTH),
                        .SIZE_WIDTH     (SIZE_WIDTH),
                        .BURST_WIDTH    (BURST_WIDTH),
                        .LOCK_WIDTH     (LOCK_WIDTH),
                        .CACHE_WIDTH    (CACHE_WIDTH),
                        .PROT_WIDTH     (PROT_WIDTH),
                        .QOS_WIDTH      (QOS_WIDTH),
                        .REGION_WIDTH   (REGION_WIDTH),
                        .AR_TID_WIDTH   (AR_TID_WIDTH),
                        .AR_USER_WIDTH  (AR_USER_WIDTH),
                        .R_DATA_WIDTH   (R_DATA_WIDTH),
                        .R_RESP_WIDTH   (R_RESP_WIDTH),
                        .R_USER_WIDTH   (R_USER_WIDTH));

        task do_reset();
            for(int p=0; p<PORTS; p++) begin
                ar_valid[p] = 1'b0;
                r_ready[p] = 1'b0;
            end
        endtask
        
        task posedge_clk();
            @(posedge clk);
        endtask
        
        task write_ar(int port, logic[AR_TID_WIDTH-1:0] tid, logic[ADDR_WIDTH-1:0] addr, logic[LEN_WIDTH-1:0] len, logic[SIZE_WIDTH-1:0] size, logic[BURST_WIDTH-1:0] burst, logic[LOCK_WIDTH-1:0] lock, logic[CACHE_WIDTH-1:0] cache, logic[PROT_WIDTH-1:0] prot, logic[QOS_WIDTH-1:0] qos, logic[REGION_WIDTH-1:0] region, logic[AR_USER_WIDTH-1:0] user, int IDLE_RATE);
            ar_valid[port]  = 1'b0;
            ar_tid[port]    = tid;
            ar_addr[port]   = addr;
            ar_len[port]    = len;
            ar_size[port]   = size;
            ar_burst[port]  = burst;
            ar_lock[port]   = lock;
            ar_cache[port]  = cache;
            ar_prot[port]   = prot;
            ar_qos[port]    = qos;
            ar_region[port] = region;
            ar_user[port]   = user;
            
            
            while ($urandom_range(99) < IDLE_RATE) begin
                @(posedge clk);
            end
            ar_valid[port]  = 1'b1;
            
            do begin
                @(posedge clk);
            end while(!ar_ready[port]);
            ar_valid[port] = 1'b0;
        endtask
        
        task read_r(int port, output logic[AR_TID_WIDTH-1:0] tid, output logic[R_DATA_WIDTH-1:0] data, output logic[R_RESP_WIDTH-1:0] resp, logic last, output logic[R_USER_WIDTH-1:0] user, input int STALL_RATE);
            // r_ready[port] = 1'b1;
            // do begin
                // @(posedge clk);
            // end while (!r_valid[port]);
            
            // -- //
            r_ready[port] = 1'b0;
            wait(r_valid[port]);
            do begin
                if ($urandom_range(99) < STALL_RATE) begin
                    r_ready[port] = 1'b0;
                end else begin
                    r_ready[port] = 1'b1;
                end
                @(posedge clk);
            end while (!r_valid[port] || !r_ready[port]);
            // -- //
            tid    = r_tid[port];
            data   = r_data[port];
            resp   = r_resp[port];
            last   = r_last[port];
            user   = r_user[port];
            
            r_ready[port] = 1'b0;
        endtask
    endclass
    
    axi_rv_if_m_r_concrete
            #(  .PORTS          (PORTS),
                .ADDR_WIDTH     (ADDR_WIDTH),
                .LEN_WIDTH      (LEN_WIDTH),
                .SIZE_WIDTH     (SIZE_WIDTH),
                .BURST_WIDTH    (BURST_WIDTH),
                .LOCK_WIDTH     (LOCK_WIDTH),
                .CACHE_WIDTH    (CACHE_WIDTH),
                .PROT_WIDTH     (PROT_WIDTH),
                .QOS_WIDTH      (QOS_WIDTH),
                .REGION_WIDTH   (REGION_WIDTH),
                .AR_TID_WIDTH   (AR_TID_WIDTH),
                .AR_USER_WIDTH  (AR_USER_WIDTH),
                .R_DATA_WIDTH   (R_DATA_WIDTH),
                .R_RESP_WIDTH   (R_RESP_WIDTH),
                .R_USER_WIDTH   (R_USER_WIDTH))
        c_if = new();

    // -- Assertions -- //
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(ar_valid)) else $fatal(1, "ar_valid not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(ar_ready)) else $fatal(1, "ar_ready not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(r_valid )) else $fatal(1, "r_valid not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(r_ready )) else $fatal(1, "r_ready not 0/1 (X's, Z's probably?)");
endinterface
