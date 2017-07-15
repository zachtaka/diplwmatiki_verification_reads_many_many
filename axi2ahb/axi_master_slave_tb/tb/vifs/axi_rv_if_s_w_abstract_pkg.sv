package axi_rv_if_s_w_abstract_pkg;

    virtual class axi_rv_if_s_w_abstract
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
    );
        
        pure virtual task do_reset();
        pure virtual task posedge_clk();
        // blocking read
        pure virtual task read_aw(int port, output logic[AW_TID_WIDTH-1:0] tid, output logic[ADDR_WIDTH-1:0] addr, output logic[LEN_WIDTH-1:0] len, output logic[SIZE_WIDTH-1:0] size, output logic[BURST_WIDTH-1:0] burst, output logic[LOCK_WIDTH-1:0] lock, output logic[CACHE_WIDTH-1:0] cache, output logic[PROT_WIDTH-1:0] prot, output logic[QOS_WIDTH-1:0] qos, output logic[REGION_WIDTH-1:0] region, output logic[AW_USER_WIDTH-1:0] user, input int STALL_RATE);
        pure virtual task read_w(int port, output logic[AW_TID_WIDTH-1:0] tid, output logic[W_DATA_WIDTH-1:0] data, output logic[W_DATA_WIDTH/8-1:0] strb, output logic last, output logic[W_USER_WIDTH-1:0] user, input int STALL_RATE);
        // blocking write
        pure virtual task write_b(int port, logic[AW_TID_WIDTH-1:0] tid, logic[B_RESP_WIDTH-1:0] resp, logic[B_USER_WIDTH-1:0] user);
    endclass
endpackage
