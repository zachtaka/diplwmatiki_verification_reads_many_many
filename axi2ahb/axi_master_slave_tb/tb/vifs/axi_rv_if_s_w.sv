interface axi_rv_if_s_w
#(
    parameter int PORTS         = 1,
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
    parameter int B_USER_WIDTH  = 2
)
(
    input logic clk
);
    
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
    
    
    import axi_rv_if_s_w_abstract_pkg::*;
    
    class axi_rv_if_s_w_concrete
    #(
        parameter int PORTS         = 1,
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
        parameter int B_USER_WIDTH  = 2
    )
    extends axi_rv_if_s_w_abstract
    #(
        .PORTS          (PORTS),
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
        .B_USER_WIDTH   (B_USER_WIDTH)
    );

        task do_reset();
            for(int p=0; p<PORTS; p++) begin
                aw_ready[p] = 1'b0;
                w_ready[p] = 1'b0;
                b_valid[p] = 1'b0;
            end
        endtask
        
        task posedge_clk();
            @(posedge clk);
        endtask
        
        task read_aw(int port, output logic[AW_TID_WIDTH-1:0] tid, output logic[ADDR_WIDTH-1:0] addr, output logic[LEN_WIDTH-1:0] len, output logic[SIZE_WIDTH-1:0] size, output logic[BURST_WIDTH-1:0] burst, output logic[LOCK_WIDTH-1:0] lock, output logic[CACHE_WIDTH-1:0] cache, output logic[PROT_WIDTH-1:0] prot, output logic[QOS_WIDTH-1:0] qos, output logic[REGION_WIDTH-1:0] region, output logic[AW_USER_WIDTH-1:0] user, input int STALL_RATE);
            aw_ready[port] = 1'b0;
            
            // wait for valid (otherwise stalling it doesn't make a difference)
            wait(aw_valid[port]);
            
            do begin
                if ($urandom_range(1, 99) < STALL_RATE) begin
                    aw_ready[port] = 1'b0;
                end else begin
                    aw_ready[port] = 1'b1;
                end
                @(posedge clk);
            end while (!aw_valid[port] || !aw_ready[port]);
            
            tid    = aw_tid[port];
            addr   = aw_addr[port];
            len    = aw_len[port];
            size   = aw_size[port];
            burst  = aw_burst[port];
            lock   = aw_lock[port];
            cache  = aw_cache[port];
            prot   = aw_prot[port];
            qos    = aw_qos[port];
            region = aw_region[port];
            user   = aw_user[port];
            
            aw_ready[port] = 1'b0;
        endtask
        
        task read_w(int port, output logic[AW_TID_WIDTH-1:0] tid, output logic[W_DATA_WIDTH-1:0] data, output logic[W_DATA_WIDTH/8-1:0] strb, output logic last, output logic[W_USER_WIDTH-1:0] user, input int STALL_RATE);
            w_ready[port] = 1'b0;
            
            // wait for valid (otherwise stalling it doesn't make a difference)
            wait(w_valid[port]);
            
            
            do begin
                if ($urandom_range(1, 99) < STALL_RATE) begin
                    w_ready[port] = 1'b0;
                end else begin
                    w_ready[port] = 1'b1;
                end
                @(posedge clk);
            end while (!w_valid[port] || !w_ready[port]);
            
            tid    = w_tid[port];
            data   = w_data[port];
            strb   = w_strb[port];
            last   = w_last[port];
            user   = w_user[port];
            user   = w_user[port];
            
            w_ready[port] = 1'b0;
        endtask
        
        task write_b(int port, logic[AW_TID_WIDTH-1:0] tid, logic[B_RESP_WIDTH-1:0] resp, logic[B_USER_WIDTH-1:0] user);
            b_valid[port]   = 1'b1;
            b_tid[port] = tid;
            b_resp[port]    = resp;
            b_user[port]    = user;
            
            do begin
                @(posedge clk);
            end while(!b_ready[port]);
            b_valid[port] = 1'b0;
        endtask
    endclass
    
    axi_rv_if_s_w_concrete
    #(
        .PORTS          (PORTS),
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
        .B_USER_WIDTH   (B_USER_WIDTH)
    )
    c_if = new();

    // -- Assertions -- //
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(aw_valid)) else $fatal(1, "aw_valid not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(aw_ready)) else $fatal(1, "aw_ready not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(w_valid )) else $fatal(1, "w_valid not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(w_ready )) else $fatal(1, "w_ready not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(b_valid )) else $fatal(1, "b_valid not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(!check_rv_handshake) !$isunknown(b_ready )) else $fatal(1, "b_ready not 0/1 (X's, Z's probably?)");
endinterface
