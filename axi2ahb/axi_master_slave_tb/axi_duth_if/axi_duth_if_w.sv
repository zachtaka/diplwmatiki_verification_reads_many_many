interface axi_duth_if_w
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
    // AW / W
    parameter int AW_USER_WIDTH = 2,
    parameter int AW_TID_WIDTH  = 1,
    parameter int W_DATA_WIDTH  = 64,
    parameter int W_USER_WIDTH  = 2,
    // B
    parameter int B_RESP_WIDTH  = 2,
    parameter int B_USER_WIDTH  = 2)
(   
    input logic clk,
    input logic rst,
    input logic check_rv_handshake,
    input logic check_unknown
);

// AW
logic                       aw_ready    ;
logic                       aw_valid    ;
logic[AW_TID_WIDTH-1:0]     aw_tid      ;
logic[ADDRESS_WIDTH-1:0]    aw_addr     ;
logic[LEN_WIDTH-1:0]        aw_len      ;
logic[SIZE_WIDTH-1:0]       aw_size     ;
logic[BURST_WIDTH-1:0]      aw_burst    ;
logic[LOCK_WIDTH-1:0]       aw_lock     ;
logic[CACHE_WIDTH-1:0]      aw_cache    ;
logic[PROT_WIDTH-1:0]       aw_prot     ;
logic[QOS_WIDTH-1:0]        aw_qos      ;
logic[REGION_WIDTH-1:0]     aw_region   ;
logic[AW_USER_WIDTH-1:0]    aw_user     ;
// W
logic                       w_ready     ;
logic                       w_valid     ;
logic[AW_TID_WIDTH-1:0]     w_tid       ;
logic[W_DATA_WIDTH-1:0]     w_data      ;
logic[W_DATA_WIDTH/8-1:0]   w_strb      ;
logic[W_USER_WIDTH-1:0]     w_user      ;
logic                       w_last      ;
// B
logic                       b_ready     ;
logic                       b_valid     ;
logic[AW_TID_WIDTH-1:0]     b_tid       ;
logic[B_RESP_WIDTH-1:0]     b_resp      ;
logic[B_USER_WIDTH-1:0]     b_user      ;

modport master(output aw_valid, input aw_ready,
               output aw_tid, aw_addr, aw_len, aw_size, aw_burst, aw_lock, aw_cache, aw_prot, aw_qos, aw_region, aw_user,
               output w_valid, input w_ready,
               output w_tid, w_data, w_strb, w_last, w_user,
               input b_valid, output b_ready,
               input b_tid, b_resp, b_user);

modport slave(input aw_valid, output aw_ready,
              input aw_tid, aw_addr, aw_len, aw_size, aw_burst, aw_lock, aw_cache, aw_prot, aw_qos, aw_region, aw_user,
              input w_valid, output w_ready,
              input w_tid, w_data, w_strb, w_last, w_user,
              output b_valid, input b_ready,
              output b_tid, b_resp, b_user);

// -- Assertions ------------------------------------------------------------------------------ //
// STUPID VCS // default clocking @(posedge clk); endclocking
// STUPID VCS // default disable iff(rst);
// Ready valid handshake
assert property(@(posedge clk) disable iff(rst)
    check_rv_handshake |-> !$isunknown(aw_valid)) else $fatal(1, "aw_valid not 0/1 (X's, Z's probably?)");
assert property(@(posedge clk) disable iff(rst)
    check_rv_handshake |-> !$isunknown(aw_ready)) else $fatal(1, "aw_ready not 0/1 (X's, Z's probably?)");

assert property(@(posedge clk) disable iff(rst)
    check_rv_handshake |-> !$isunknown(w_valid )) else $fatal(1, "w_valid not 0/1 (X's, Z's probably?)");
assert property(@(posedge clk) disable iff(rst)
    check_rv_handshake |-> !$isunknown(w_ready )) else $fatal(1, "w_ready not 0/1 (X's, Z's probably?)");

assert property(@(posedge clk) disable iff(rst)
    check_rv_handshake |-> !$isunknown(b_valid )) else $fatal(1, "b_valid not 0/1 (X's, Z's probably?)");
assert property(@(posedge clk) disable iff(rst)
    check_rv_handshake |-> !$isunknown(b_ready )) else $fatal(1, "b_ready not 0/1 (X's, Z's probably?)");

// Fields with unknown values
assert property(@(posedge clk) disable iff(rst)
    (check_unknown && aw_valid |-> !$isunknown(aw_addr))) else $fatal(1, "X/Z at AW_ADDR!");
assert property(@(posedge clk) disable iff(rst)
    (check_unknown && aw_valid |-> !$isunknown(aw_tid))) else $fatal(1, "X/Z at AW_TID!");
assert property(@(posedge clk) disable iff(rst)
    (check_unknown && aw_valid |-> !$isunknown(aw_len))) else $fatal(1, "X/Z at AW_LEN!");
assert property(@(posedge clk) disable iff(rst)
    (check_unknown && aw_valid |-> !$isunknown(aw_size))) else $fatal(1, "X/Z at AW_SIZE!");
assert property(@(posedge clk) disable iff(rst)
    (check_unknown && aw_valid |-> !$isunknown(aw_burst))) else $fatal(1, "X/Z at AW_BURST!");

if (AXI_MODE == 3) begin: if_axi3
    assert property(@(posedge clk) disable iff(rst)
        (check_unknown && w_valid |-> !$isunknown(w_tid))) else $fatal(1, "X/Z at W_TID!");
    assert property(@(posedge clk) disable iff(rst)
        (aw_valid |-> aw_len[4 +: LEN_WIDTH-4] == 0)) else $fatal(1, "length not AXI3");
end

assert property(@(posedge clk) disable iff(rst)
    (check_unknown && w_valid |-> !$isunknown(w_strb))) else $fatal(1, "X/Z at W_STRB!");
for (genvar b=0; b<W_DATA_WIDTH/8; b++) begin: for_b
    assert property(@(posedge clk) disable iff(rst)
        (check_unknown && w_valid && w_strb[b] |-> !$isunknown(w_data[b*8 +: 8]))) else $fatal(1, "X/Z at W_DATA[%0d*8 +: 8]!", b);
end

assert property(@(posedge clk) disable iff(rst)
    (check_unknown && w_valid |-> !$isunknown(w_last))) else $fatal(1, "X/Z at W_LAST!");
assert property(@(posedge clk) disable iff(rst)
    (check_unknown && b_valid |-> !$isunknown(b_tid))) else $fatal(1, "X/Z at B_TID!");
assert property(@(posedge clk) disable iff(rst)
    (check_unknown && b_valid |-> !$isunknown(b_resp))) else $fatal(1, "X/Z at B_RESP!");

// Higher level
localparam logic[BURST_WIDTH-1:0] FIXED_BURST   = 2'b00;
localparam logic[BURST_WIDTH-1:0] INCR_BURST    = 2'b01;
localparam logic[BURST_WIDTH-1:0] WRAP_BURST    = 2'b10;
localparam logic[BURST_WIDTH-1:0] RES_BURST     = 2'b11;
logic[ADDRESS_WIDTH-1:0] dbg_addr_size_aligned;
assign dbg_addr_size_aligned = aw_addr & ( (1 << aw_size) - 1);

prop_size_limits: assert property (@(posedge clk) disable iff(rst)
    aw_valid |-> ( aw_size <= $clog2(W_DATA_WIDTH/8)) ) else $fatal(1, "Size > Data width?! - size=%0d, log2(data_w/8)=%0d", aw_size, $clog2(W_DATA_WIDTH/8));
prop_wrap_len: assert property (@(posedge clk) disable iff(rst)
    (aw_valid && (aw_burst == WRAP_BURST)) |-> aw_len inside {1, 3, 7, 15}) else $fatal(1, "AXI Rules: WRAP but len=%0d - valid values = 1, 3, 7, 15", aw_len);
prop_wrap_addr: assert property (@(posedge clk) disable iff(rst)
    (aw_valid && (aw_burst == WRAP_BURST)) |-> ~(|dbg_addr_size_aligned) ) else $fatal(1, "AXI Rules: WRAP but address (%0h) not aligned to size (%0d) - aligned addr = %0h", aw_addr, aw_size, dbg_addr_size_aligned);


assert property (@(posedge clk) disable iff(rst)
    aw_valid |-> aw_burst != RES_BURST) else $fatal(1, "invalid aw_burst value");

int dbg_w_len_cur;
int dbg_w_len_cnt;
always_ff @(posedge clk, posedge rst) begin
    if (rst) begin
        dbg_w_len_cnt <= 0;
    end else begin
        if (w_valid && w_ready) begin
            if (w_last) begin
                dbg_w_len_cnt <= 0;
            end else begin
                dbg_w_len_cnt <= dbg_w_len_cnt + 1;
            end
        end
    end
end

endinterface
