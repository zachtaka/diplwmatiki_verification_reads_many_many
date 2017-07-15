interface axi_rv_if_m_w
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
            // AW / W
            parameter int AW_USER_WIDTH = 2,
            parameter int AW_TID_WIDTH  = 1,
            parameter int W_DATA_WIDTH  = 64,
            parameter int W_USER_WIDTH  = 2,
            // B
            parameter int B_RESP_WIDTH  = 2,
            parameter int B_USER_WIDTH  = 2)
        (   input logic clk);
    
    logic check_rv_handshake = 0;
    // AW
    logic[PORTS-1:0]                       aw_valid;
    logic[PORTS-1:0]                       aw_ready;
    logic[PORTS-1:0][AW_TID_WIDTH-1:0]     aw_tid;
    logic[PORTS-1:0][ADDR_WIDTH-1:0]       aw_addr;
    logic[PORTS-1:0][LEN_WIDTH-1:0]        aw_len;
    logic[PORTS-1:0][SIZE_WIDTH-1:0]       aw_size;
    logic[PORTS-1:0][BURST_WIDTH-1:0]      aw_burst;
    logic[PORTS-1:0][LOCK_WIDTH-1:0]       aw_lock;
    logic[PORTS-1:0][CACHE_WIDTH-1:0]      aw_cache;
    logic[PORTS-1:0][PROT_WIDTH-1:0]       aw_prot;
    logic[PORTS-1:0][QOS_WIDTH-1:0]        aw_qos;
    logic[PORTS-1:0][REGION_WIDTH-1:0]     aw_region;
    logic[PORTS-1:0][AW_USER_WIDTH-1:0]    aw_user;
    // W
    logic[PORTS-1:0]                        w_valid;
    logic[PORTS-1:0]                        w_ready;
    logic[PORTS-1:0][AW_TID_WIDTH-1:0]      w_tid;
    logic[PORTS-1:0][W_DATA_WIDTH-1:0]      w_data;
    logic[PORTS-1:0][W_DATA_WIDTH/8-1:0]    w_strb;
    logic[PORTS-1:0][W_USER_WIDTH-1:0]      w_user;
    logic[PORTS-1:0]                        w_last;
    
    // B
    logic[PORTS-1:0]                    b_valid;
    logic[PORTS-1:0]                    b_ready;
    logic[PORTS-1:0][AW_TID_WIDTH-1:0]  b_tid;
    logic[PORTS-1:0][B_RESP_WIDTH-1:0]  b_resp;
    logic[PORTS-1:0][B_USER_WIDTH-1:0]  b_user;
    
    
    import axi_rv_if_m_w_abstract_pkg::*;
    
    class axi_rv_if_m_w_concrete
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
                // AW / W
                parameter int AW_USER_WIDTH = 2,
                parameter int AW_TID_WIDTH  = 1,
                parameter int W_DATA_WIDTH  = 64,
                parameter int W_USER_WIDTH  = 2,
                // B
                parameter int B_RESP_WIDTH  = 2,
                parameter int B_USER_WIDTH  = 2)
            extends axi_rv_if_m_w_abstract
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
                        .AW_USER_WIDTH  (AW_USER_WIDTH),
                        .AW_TID_WIDTH   (AW_TID_WIDTH),
                        .W_DATA_WIDTH   (W_DATA_WIDTH),
                        .W_USER_WIDTH   (W_USER_WIDTH),
                        .B_RESP_WIDTH   (B_RESP_WIDTH),
                        .B_USER_WIDTH   (B_USER_WIDTH));

        task do_reset();
            for(int p=0; p<PORTS; p++) begin
                aw_valid[p] = 1'b0;
                w_valid[p] = 1'b0;
            end
        endtask
        
        task posedge_clk();
            @(posedge clk);
        endtask
        
        task write_aw(int port, logic[AW_TID_WIDTH-1:0] tid, logic[ADDR_WIDTH-1:0] addr, logic[LEN_WIDTH-1:0] len, logic[SIZE_WIDTH-1:0] size, logic[BURST_WIDTH-1:0] burst, logic[LOCK_WIDTH-1:0] lock, logic[CACHE_WIDTH-1:0] cache, logic[PROT_WIDTH-1:0] prot, logic[QOS_WIDTH-1:0] qos, logic[REGION_WIDTH-1:0] region, logic[AW_USER_WIDTH-1:0] user);
            aw_valid[port]  = 1'b1;
            aw_tid[port]    = tid;
            aw_addr[port]   = addr;
            aw_len[port]    = len;
            aw_size[port]   = size;
            aw_burst[port]  = burst;
            aw_lock[port]   = lock;
            aw_cache[port]  = cache;
            aw_prot[port]   = prot;
            aw_qos[port]    = qos;
            aw_region[port] = region;
            aw_user[port]   = user;
            
            do begin
                @(posedge clk);
            end while(!aw_ready[port]);
            aw_valid[port] = 1'b0;
        endtask
        
        task write_w(int port, logic[AW_TID_WIDTH-1:0] tid, logic[W_DATA_WIDTH-1:0] data, logic[W_DATA_WIDTH/8-1:0] strb, logic last, logic[W_USER_WIDTH-1:0] user);
            w_valid[port]   = 1'b1;
            w_tid[port]     = tid;
            w_data[port]    = data;
            w_strb[port]    = strb;
            w_last[port]    = last;
            w_user[port]    = user;
            
            do begin
                @(posedge clk);
            end while(!w_ready[port]);
            w_valid[port] = 1'b0;
        endtask
        
        task read_b(int port, output logic[AW_TID_WIDTH-1:0] tid, output logic[B_RESP_WIDTH-1:0] resp, output logic[B_USER_WIDTH-1:0] user, input int STALL_RATE);
            // b_ready[port] = 1'b1;
            // do begin
                // @(posedge clk);
            // end while (!b_valid[port]);
            
            // -- //
            b_ready[port] = 1'b0;
            wait(b_valid[port]);
            do begin
                if ($urandom_range(1, 99) < STALL_RATE) begin
                    b_ready[port] = 1'b0;
                end else begin
                    b_ready[port] = 1'b1;
                end
                @(posedge clk);
            end while (!b_valid[port] || !b_ready[port]);
            // -- //
            
            tid    = b_tid[port];
            resp   = b_resp[port];
            user   = b_user[port];
            
            b_ready[port] = 1'b0;
        endtask
    endclass
    
    axi_rv_if_m_w_concrete
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
                .AW_USER_WIDTH  (AW_USER_WIDTH),
                .AW_TID_WIDTH   (AW_TID_WIDTH),
                .W_DATA_WIDTH   (W_DATA_WIDTH),
                .W_USER_WIDTH   (W_USER_WIDTH),
                .B_RESP_WIDTH   (B_RESP_WIDTH),
                .B_USER_WIDTH   (B_USER_WIDTH))
        c_if = new();

    // -- Assertions -- //
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(aw_valid)) else $fatal(1, "aw_valid not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(aw_ready)) else $fatal(1, "aw_ready not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(w_valid )) else $fatal(1, "w_valid not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(w_ready )) else $fatal(1, "w_ready not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(b_valid )) else $fatal(1, "b_valid not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(b_ready )) else $fatal(1, "b_ready not 0/1 (X's, Z's probably?)");
endinterface
