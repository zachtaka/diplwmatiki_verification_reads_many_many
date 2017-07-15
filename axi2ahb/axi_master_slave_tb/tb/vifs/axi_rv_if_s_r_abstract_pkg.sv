package axi_rv_if_s_r_abstract_pkg;

    virtual class axi_rv_if_s_r_abstract
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
        // AR
        parameter int AR_TID_WIDTH  = 1,
        parameter int AR_USER_WIDTH = 2,
        // R
        parameter int R_DATA_WIDTH  = 64,
        parameter int R_RESP_WIDTH  = 2,
        parameter int R_USER_WIDTH  = 2
    );
        
        pure virtual task do_reset();
        pure virtual task posedge_clk();
        
        // blocking read
        pure virtual task read_ar(int port, output logic[AR_TID_WIDTH-1:0] tid, output logic[ADDR_WIDTH-1:0] addr, output logic[LEN_WIDTH-1:0] len, output logic[SIZE_WIDTH-1:0] size, output logic[BURST_WIDTH-1:0] burst, output logic[LOCK_WIDTH-1:0] lock, output logic[CACHE_WIDTH-1:0] cache, output logic[PROT_WIDTH-1:0] prot, output logic[QOS_WIDTH-1:0] qos, output logic[REGION_WIDTH-1:0] region, output logic[AR_USER_WIDTH-1:0] user, input int STALL_RATE);
        // blocking write
        pure virtual task write_r(int port, logic[AR_TID_WIDTH-1:0] tid, logic[R_DATA_WIDTH-1:0] data, logic[R_RESP_WIDTH-1:0] resp, logic last, logic[R_USER_WIDTH-1:0] user);
    endclass
endpackage
