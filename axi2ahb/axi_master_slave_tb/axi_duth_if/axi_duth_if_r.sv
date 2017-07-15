interface axi_duth_if_r
#(  parameter int AXI_MODE      = 4,
    // General
    parameter int ADDRESS_WIDTH = 32,
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
(   
    input logic clk,
    input logic rst,
    input logic check_rv_handshake,
    input logic check_unknown
);
    // AR
    logic                       ar_valid;
    logic                       ar_ready;
    logic[AR_TID_WIDTH-1:0]     ar_tid;
    logic[ADDRESS_WIDTH-1:0]    ar_addr;
    logic[LEN_WIDTH-1:0]        ar_len;
    logic[SIZE_WIDTH-1:0]       ar_size;
    logic[BURST_WIDTH-1:0]      ar_burst;
    logic[LOCK_WIDTH-1:0]       ar_lock;
    logic[CACHE_WIDTH-1:0]      ar_cache;
    logic[PROT_WIDTH-1:0]       ar_prot;
    logic[QOS_WIDTH-1:0]        ar_qos;
    logic[REGION_WIDTH-1:0]     ar_region;
    logic[AR_USER_WIDTH-1:0]    ar_user;
    // R
    logic                       r_valid;
    logic                       r_ready;
    logic[AR_TID_WIDTH-1:0]     r_tid;
    logic[R_DATA_WIDTH-1:0]     r_data;
    logic[R_RESP_WIDTH-1:0]     r_resp;
    logic                       r_last;
    logic[R_USER_WIDTH-1:0]     r_user;
    
    
    modport master(output ar_valid, input ar_ready,
                   output ar_tid, ar_addr, ar_len, ar_size, ar_burst, ar_lock, ar_cache, ar_prot, ar_qos, ar_region, ar_user,
                   input r_valid, output r_ready,
                   input r_tid, r_data, r_resp, r_last, r_user);
    
    modport slave(input ar_valid, output ar_ready,
                  input ar_tid, ar_addr, ar_len, ar_size, ar_burst, ar_lock, ar_cache, ar_prot, ar_qos, ar_region, ar_user,
                  output r_valid, input r_ready,
                  output r_tid, r_data, r_resp, r_last, r_user);
    
    // -- Assertions ------------------------------------------------------------------------------ //
    // STUPID VCS // default clocking @(posedge clk); endclocking
    // STUPID VCS // default disable iff(rst);
    
    // Ready valid handshake
    assert property(@(posedge clk) disable iff(rst)
        check_rv_handshake |-> !$isunknown(ar_valid)) else $fatal(1, "ar_valid not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(rst)
        check_rv_handshake |-> !$isunknown(ar_ready)) else $fatal(1, "ar_ready not 0/1 (X's, Z's probably?)");
    
    assert property(@(posedge clk) disable iff(rst)
        check_rv_handshake |-> !$isunknown(r_valid )) else $fatal(1, "r_valid not 0/1 (X's, Z's probably?)");
    assert property(@(posedge clk) disable iff(rst)
        check_rv_handshake |-> !$isunknown(r_ready )) else $fatal(1, "r_ready not 0/1 (X's, Z's probably?)");
    
    // Fields with unknown values
    assert property(@(posedge clk) disable iff(rst)
        (check_unknown && ar_valid |-> !$isunknown(ar_addr))) else $fatal(1, "X/Z at AR_ADDR!");
    assert property(@(posedge clk) disable iff(rst)
        (check_unknown && ar_valid |-> !$isunknown(ar_tid))) else $fatal(1, "X/Z at AR_TID!");
    assert property(@(posedge clk) disable iff(rst)
        (check_unknown && ar_valid |-> !$isunknown(ar_len))) else $fatal(1, "X/Z at AR_LEN!");
    assert property(@(posedge clk) disable iff(rst)
        (check_unknown && ar_valid |-> !$isunknown(ar_size))) else $fatal(1, "X/Z at AR_SIZE!");
    assert property(@(posedge clk) disable iff(rst)
        (check_unknown && ar_valid |-> !$isunknown(ar_burst))) else $fatal(1, "X/Z at AR_BURST!");
    
    assert property(@(posedge clk) disable iff(rst)
        (check_unknown && r_valid |-> !$isunknown(r_tid))) else $fatal(1, "X/Z at R_TID!");
    assert property(@(posedge clk) disable iff(rst)
        (check_unknown && r_valid |-> !$isunknown(r_resp))) else $fatal(1, "X/Z at R_RESP!");
    assert property(@(posedge clk) disable iff(rst)
        (check_unknown && r_valid |-> !$isunknown(r_last))) else $fatal(1, "X/Z at R_LAST!");

if (AXI_MODE == 3) begin: if_axi3
    assert property(@(posedge clk) disable iff(rst)
        (ar_valid |-> ar_len[4 +: LEN_WIDTH-4] == 0)) else $fatal(1, "length not AXI3");
end
    
    // Higher level
    localparam logic[BURST_WIDTH-1:0] FIXED_BURST   = 2'b00;
    localparam logic[BURST_WIDTH-1:0] INCR_BURST    = 2'b01;
    localparam logic[BURST_WIDTH-1:0] WRAP_BURST    = 2'b10;
    localparam logic[BURST_WIDTH-1:0] RES_BURST     = 2'b11;
    logic[ADDRESS_WIDTH-1:0] dbg_addr_size_aligned;
    assign dbg_addr_size_aligned = ar_addr & ( (1 << ar_size) - 1);
    
    prop_size_limits: assert property(@(posedge clk) disable iff(rst)
        ar_valid |-> ( ar_size <= $clog2(R_DATA_WIDTH/8)) ) else $fatal(1, "Size > Data width?! - size=%0d, log2(data_w/8)=%0d", ar_size, $clog2(R_DATA_WIDTH/8));
    prop_wrap_len: assert property (@(posedge clk) disable iff(rst)
        (ar_valid && (ar_burst == WRAP_BURST)) |-> ar_len inside {1, 3, 7, 15}) else $fatal(1, "AXI Rules: WRAP but len=%0d - valid values = 1, 3, 7, 15", ar_len);
    prop_wrap_addr: assert property (@(posedge clk) disable iff(rst)
        (ar_valid && (ar_burst == WRAP_BURST)) |-> ~(|dbg_addr_size_aligned) ) else $fatal(1, "AXI Rules: WRAP but address (%0h) not aligned to size (%0d)", ar_addr, ar_size);
    
    assert property (@(posedge clk) disable iff(rst)
        ar_valid |-> ar_burst != RES_BURST) else $fatal(1, "invalid ar_burst value");
endinterface
