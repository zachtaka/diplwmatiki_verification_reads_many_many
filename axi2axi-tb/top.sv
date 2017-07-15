import axi_global_pkg::*;
import axi_transactions_pkg::*;
import axi_scoreboard_pkg::*;
import axi_m_w_initiator_pkg::*;
import axi_m_r_initiator_pkg::*;
import axi_s_w_responder_pkg::*;
import axi_s_r_responder_pkg::*;
import tb_pkg_general::*;

`default_nettype none

// ADDR_RANGE
// ADDR_RANGE
// ADDR_RANGE
// ADDR_RANGE
// ADDR_RANGE
// ADDR_RANGE
// ADDR_RANGE
// ADDR_RANGE
// ADDR_RANGE
// ADDR_RANGE

module top
#(
    parameter int       TB_MASTERS          = 1,
    parameter int       TB_SLAVES           = 4,
    // Design config params
    parameter int       DW                  = 64,  // Data bus width
    parameter int       AW                  = 32,  // Address width
    parameter int       USERW               = 1, // Width of the AxUSER signal - should be > 
    parameter int       MTID                = 5, // Master-side TIDs
    parameter int       MTIDW               = MTID > 1 ? $clog2(MTID) : 1, // Master-side xxID width
    // Master idle/stall
    parameter int       M_IDLE_RATE_AW      = 70,  // Idle cycle injection @ AW
    parameter int       M_IDLE_RATE_W       = 70,  // Idle cycle injection @ W
    parameter int       M_IDLE_RATE_AR      = 70,  // Idle cycle injection @ AR
    parameter int       M_STALL_RATE_B      = 70,  // Idle cycle injection @ B
    parameter int       M_STALL_RATE_R      = 70,  // Idle cycle injection @ R
    parameter int       M_STROBE_MASK_RATE  = 70,  // Strobe masking rate
    // Slave idle/stall
    parameter int       S_ERROR_RATE        = 70,   // Rate at which Slave generates errors
    parameter int       S_STALL_RATE_AW     = 70,   // Stalling rate for channel AW
    parameter int       S_STALL_RATE_W      = 70,   // Stalling rate for channel W
    parameter int       S_STALL_RATE_AR     = 70,   // Stalling rate for channel AR
    parameter int       S_IDLE_RATE_B       = 70,  // Idle cycle injection @ B
    parameter int       S_IDLE_RATE_R       = 70,  // Idle cycle injection @ R
    // TB params
    parameter tb_gen_mode_t M_TB_MODE       = TBGMT_RANDOM, // TBGMT_RANDOM (rnd) or TBGMT_DIRECTED (using file)
    // DIRECTED-related params
    parameter string    M_INP_FILENAME_WR   = "",
    parameter string    M_INP_FILENAME_RD   = "",
    // RANDOM-related params
    parameter int       M_GEN_RATE_WR       = 100, // Write transactions generation rate
    parameter int       M_TRANS_COUNT_WR    = 0, // number of write transactions to be generated (ignored for DIRECTED test)
    parameter int       M_GEN_RATE_RD       = 100, // Read transactions generation rate 
    parameter int       M_TRANS_COUNT_RD    = 10, // number of read transactions to be generated (ignored for DIRECTED test)
    parameter logic     M_DO_UNALIGNED      = 1'b1, // Size-Unaligned transfers?
    parameter int       M_INCR_DISTR        = 1, // burst distribution (INCR)
    parameter int       M_WRAP_DISTR        = 0, // burst distribution (WRAP)
    parameter int       M_FIXED_DISTR       = 0, // burst distribution (FIXED)
    parameter int       M_MIN_BURST_LEN     = 0, // minimum burst length [0...255]
    parameter int       M_MAX_BURST_LEN     = 16, // minimum burst length [MIN...255]
    parameter int       M_MIN_BURST_SIZE    = 0, // minimum burst length [0...$clog(DW/8)]
    parameter int       M_MAX_BURST_SIZE    = $clog2(DW/8), // minimum burst length [MIN...$clog(DW/8)]
    parameter logic     M_WRITE_TO_FILE     = 1'b1, // write output file
    parameter string    M_FLNAME_WR         = "C:/Users/zacarry/Desktop/Verilog/diplwmatiki/write_report.txt", // output filename (writes)
    parameter string    M_FLNAME_RD         = "C:/Users/zacarry/Desktop/Verilog/diplwmatiki/read_report.txt", // output filename (reads)
    //
    parameter logic     WRITE_REPORT        = 1'b0,
    parameter string    WORK_DIR            = ""
)
(
    // Empty
);
// ------------------------------------------------------------------------------------------------ //
localparam logic SHARED_WR_PATH     = 1'b1;
// ------------------------------------------------------------------------------------------------ //
localparam int  STIDW               = MTIDW + (TB_MASTERS > 1 ? $clog2(TB_MASTERS) : 1);
localparam int  STID                = 2**STIDW;
    
localparam int MAX_PENDING_SAME_DST = 4;
localparam int ADDR_RANGE_EACH      = 12;

// ------------------------------------------------------------------------------------------------ //
function logic[TB_SLAVES*AW-1:0] get_addr_base();
    for (int s=0; s<TB_SLAVES; s++) begin
        get_addr_base[s*AW +: AW] = (s << ADDR_RANGE_EACH);
    end
endfunction
// ------------------------------------------------------------------------------------------------ //
localparam logic[TB_SLAVES*AW-1:0] ADDR_BASE        = get_addr_base();
localparam logic[TB_SLAVES*32-1:0] ADDR_RANGE       = {TB_SLAVES{ADDR_RANGE_EACH}};
localparam logic[AW-1:0]            ADDR_MAX        = (TB_SLAVES << ADDR_RANGE_EACH) - 1;
initial begin
    #0;
    $display("\nADDR_MAX = %0h\n", ADDR_MAX);
end

localparam logic[32*TB_MASTERS*5-1:0] M_FIFO_DEPTHS = {TB_MASTERS*5{32'd2}};
localparam logic[32*TB_SLAVES*5-1:0] S_FIFO_DEPTHS  = {TB_SLAVES*5{32'd2}};
// version fixed to AXI4
localparam int      AXI_VER = 4;
// ARM AXI4 protocol checker
`include "Axi4PC.sv"
`include "Axi4PC_defs.v"
localparam int      AXIPC_MAXRBURSTS   = 128;
localparam int      AXIPC_MAXWBURSTS   = 128;
localparam int      AXIPC_MAXWAITS     = 16;
localparam logic    AXIPC_RecommendOn  = 1'b1;
localparam logic    AXIPC_RecMaxWaitOn = 1'b0;
localparam int      AXIPC_PROTOCOL     = `AXI4PC_AMBA_AXI4;
localparam int      AXIPC_EXMON_WIDTH  = 4;
logic both_mailbox_empty;
// ------------------------------------------------------------------------------------------------ //
logic                                       clk;
logic                                       rst_n;
// DUT Slave -- AW
logic[TB_MASTERS-1:0][MTIDW-1:0]            tb_m_axi_aw_id    ;
logic[TB_MASTERS-1:0][AW-1:0]               tb_m_axi_aw_addr  ;
logic[TB_MASTERS-1:0][7:0]                  tb_m_axi_aw_len   ;
logic[TB_MASTERS-1:0][2:0]                  tb_m_axi_aw_size  ;
logic[TB_MASTERS-1:0][1:0]                  tb_m_axi_aw_burst ;
logic[TB_MASTERS-1:0][1:0]                  tb_m_axi_aw_lock  ;
logic[TB_MASTERS-1:0][3:0]                  tb_m_axi_aw_cache ;
logic[TB_MASTERS-1:0][2:0]                  tb_m_axi_aw_prot  ;
logic[TB_MASTERS-1:0][3:0]                  tb_m_axi_aw_qos   ;
logic[TB_MASTERS-1:0][3:0]                  tb_m_axi_aw_region;
logic[TB_MASTERS-1:0][USERW-1:0]            tb_m_axi_aw_user  ;
logic[TB_MASTERS-1:0]                       tb_m_axi_aw_valid ;
logic[TB_MASTERS-1:0]                       tb_m_axi_aw_ready ;
// DUT Slave -- W
logic[TB_MASTERS-1:0][MTIDW-1:0]            tb_m_axi_w_id     ;
logic[TB_MASTERS-1:0][DW-1:0]               tb_m_axi_w_data   ;
logic[TB_MASTERS-1:0][DW/8-1:0]             tb_m_axi_w_strb   ;
logic[TB_MASTERS-1:0]                       tb_m_axi_w_last   ;
logic[TB_MASTERS-1:0][USERW-1:0]            tb_m_axi_w_user   ;
logic[TB_MASTERS-1:0]                       tb_m_axi_w_valid  ;
logic[TB_MASTERS-1:0]                       tb_m_axi_w_ready  ;
// DUT Slave -- B
logic[TB_MASTERS-1:0][MTIDW-1:0]            tb_m_axi_b_id     ;
logic[TB_MASTERS-1:0][1:0]                  tb_m_axi_b_resp   ;
logic[TB_MASTERS-1:0][USERW-1:0]            tb_m_axi_b_user   ;
logic[TB_MASTERS-1:0]                       tb_m_axi_b_valid  ;
logic[TB_MASTERS-1:0]                       tb_m_axi_b_ready  ;
// DUT Slave -- AR
logic[TB_MASTERS-1:0][MTIDW-1:0]            tb_m_axi_ar_id    ;
logic[TB_MASTERS-1:0][AW-1:0]               tb_m_axi_ar_addr  ;
logic[TB_MASTERS-1:0][7:0]                  tb_m_axi_ar_len   ;
logic[TB_MASTERS-1:0][2:0]                  tb_m_axi_ar_size  ;
logic[TB_MASTERS-1:0][1:0]                  tb_m_axi_ar_burst ;
logic[TB_MASTERS-1:0][1:0]                  tb_m_axi_ar_lock  ;
logic[TB_MASTERS-1:0][3:0]                  tb_m_axi_ar_cache ;
logic[TB_MASTERS-1:0][2:0]                  tb_m_axi_ar_prot  ;
logic[TB_MASTERS-1:0][3:0]                  tb_m_axi_ar_qos   ;
logic[TB_MASTERS-1:0][3:0]                  tb_m_axi_ar_region;
logic[TB_MASTERS-1:0][USERW-1:0]            tb_m_axi_ar_user  ;
logic[TB_MASTERS-1:0]                       tb_m_axi_ar_valid ;
logic[TB_MASTERS-1:0]                       tb_m_axi_ar_ready ;
// DUT Slave -- R
logic[TB_MASTERS-1:0][MTIDW-1:0]            tb_m_axi_r_id     ;
logic[TB_MASTERS-1:0][DW-1:0]               tb_m_axi_r_data   ;
logic[TB_MASTERS-1:0][1:0]                  tb_m_axi_r_resp   ;
logic[TB_MASTERS-1:0]                       tb_m_axi_r_last   ;
logic[TB_MASTERS-1:0][USERW-1:0]            tb_m_axi_r_user   ;
logic[TB_MASTERS-1:0]                       tb_m_axi_r_valid  ;
logic[TB_MASTERS-1:0]                       tb_m_axi_r_ready  ;
// DUT Master -- AW
logic[TB_SLAVES-1:0][STIDW-1:0]             tb_s_axi_aw_id    ;
logic[TB_SLAVES-1:0][AW-1:0]                tb_s_axi_aw_addr  ;
logic[TB_SLAVES-1:0][7:0]                   tb_s_axi_aw_len   ;
logic[TB_SLAVES-1:0][2:0]                   tb_s_axi_aw_size  ;
logic[TB_SLAVES-1:0][1:0]                   tb_s_axi_aw_burst ;
logic[TB_SLAVES-1:0][1:0]                   tb_s_axi_aw_lock  ;
logic[TB_SLAVES-1:0][3:0]                   tb_s_axi_aw_cache ;
logic[TB_SLAVES-1:0][2:0]                   tb_s_axi_aw_prot  ;
logic[TB_SLAVES-1:0][3:0]                   tb_s_axi_aw_qos   ;
logic[TB_SLAVES-1:0][3:0]                   tb_s_axi_aw_region;
logic[TB_SLAVES-1:0][USERW-1:0]             tb_s_axi_aw_user  ;
logic[TB_SLAVES-1:0]                        tb_s_axi_aw_valid ;
logic[TB_SLAVES-1:0]                        tb_s_axi_aw_ready ;
// DUT Master -- W
logic[TB_SLAVES-1:0][STIDW-1:0]             tb_s_axi_w_id     ;
logic[TB_SLAVES-1:0][DW-1:0]                tb_s_axi_w_data   ;
logic[TB_SLAVES-1:0][DW/8-1:0]              tb_s_axi_w_strb   ;
logic[TB_SLAVES-1:0]                        tb_s_axi_w_last   ;
logic[TB_SLAVES-1:0][USERW-1:0]             tb_s_axi_w_user   ;
logic[TB_SLAVES-1:0]                        tb_s_axi_w_valid  ;
logic[TB_SLAVES-1:0]                        tb_s_axi_w_ready  ;
// DUT Master -- B
logic[TB_SLAVES-1:0][STIDW-1:0]             tb_s_axi_b_id     ;
logic[TB_SLAVES-1:0][1:0]                   tb_s_axi_b_resp   ;
logic[TB_SLAVES-1:0][USERW-1:0]             tb_s_axi_b_user   ;
logic[TB_SLAVES-1:0]                        tb_s_axi_b_valid  ;
logic[TB_SLAVES-1:0]                        tb_s_axi_b_ready  ;
// DUT Master -- AR
logic[TB_SLAVES-1:0][STIDW-1:0]             tb_s_axi_ar_id    ;
logic[TB_SLAVES-1:0][AW-1:0]                tb_s_axi_ar_addr  ;
logic[TB_SLAVES-1:0][7:0]                   tb_s_axi_ar_len   ;
logic[TB_SLAVES-1:0][2:0]                   tb_s_axi_ar_size  ;
logic[TB_SLAVES-1:0][1:0]                   tb_s_axi_ar_burst ;
logic[TB_SLAVES-1:0][1:0]                   tb_s_axi_ar_lock  ;
logic[TB_SLAVES-1:0][3:0]                   tb_s_axi_ar_cache ;
logic[TB_SLAVES-1:0][2:0]                   tb_s_axi_ar_prot  ;
logic[TB_SLAVES-1:0][3:0]                   tb_s_axi_ar_qos   ;
logic[TB_SLAVES-1:0][3:0]                   tb_s_axi_ar_region;
logic[TB_SLAVES-1:0][USERW-1:0]             tb_s_axi_ar_user  ;
logic[TB_SLAVES-1:0]                        tb_s_axi_ar_valid ;
logic[TB_SLAVES-1:0]                        tb_s_axi_ar_ready ;
// DUT Master -- R
logic[TB_SLAVES-1:0][STIDW-1:0]             tb_s_axi_r_id     ;
logic[TB_SLAVES-1:0][DW-1:0]                tb_s_axi_r_data   ;
logic[TB_SLAVES-1:0][1:0]                   tb_s_axi_r_resp   ;
logic[TB_SLAVES-1:0]                        tb_s_axi_r_last   ;
logic[TB_SLAVES-1:0][USERW-1:0]             tb_s_axi_r_user   ;
logic[TB_SLAVES-1:0]                        tb_s_axi_r_valid  ;
logic[TB_SLAVES-1:0]                        tb_s_axi_r_ready  ;


///////////////////////////////
///////////////////////////////
///////////////////////////////
// DUT Slave -- AW
logic[TB_MASTERS-1:0][MTIDW-1:0]            axi2ahb2axi_m_axi_aw_id    ;
logic[TB_MASTERS-1:0][AW-1:0]               axi2ahb2axi_m_axi_aw_addr  ;
logic[TB_MASTERS-1:0][7:0]                  axi2ahb2axi_m_axi_aw_len   ;
logic[TB_MASTERS-1:0][2:0]                  axi2ahb2axi_m_axi_aw_size  ;
logic[TB_MASTERS-1:0][1:0]                  axi2ahb2axi_m_axi_aw_burst ;
logic[TB_MASTERS-1:0][1:0]                  axi2ahb2axi_m_axi_aw_lock  ;
logic[TB_MASTERS-1:0][3:0]                  axi2ahb2axi_m_axi_aw_cache ;
logic[TB_MASTERS-1:0][2:0]                  axi2ahb2axi_m_axi_aw_prot  ;
logic[TB_MASTERS-1:0][3:0]                  axi2ahb2axi_m_axi_aw_qos   ;
logic[TB_MASTERS-1:0][3:0]                  axi2ahb2axi_m_axi_aw_region;
logic[TB_MASTERS-1:0][USERW-1:0]            axi2ahb2axi_m_axi_aw_user  ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_aw_valid ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_aw_ready ;
// DUT Slave -- W
logic[TB_MASTERS-1:0][MTIDW-1:0]            axi2ahb2axi_m_axi_w_id     ;
logic[TB_MASTERS-1:0][DW-1:0]               axi2ahb2axi_m_axi_w_data   ;
logic[TB_MASTERS-1:0][DW/8-1:0]             axi2ahb2axi_m_axi_w_strb   ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_w_last   ;
logic[TB_MASTERS-1:0][USERW-1:0]            axi2ahb2axi_m_axi_w_user   ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_w_valid  ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_w_ready  ;
// DUT Slave -- B
logic[TB_MASTERS-1:0][MTIDW-1:0]            axi2ahb2axi_m_axi_b_id     ;
logic[TB_MASTERS-1:0][1:0]                  axi2ahb2axi_m_axi_b_resp   ;
logic[TB_MASTERS-1:0][USERW-1:0]            axi2ahb2axi_m_axi_b_user   ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_b_valid  ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_b_ready  ;
// DUT Slave -- AR
logic[TB_MASTERS-1:0][MTIDW-1:0]            axi2ahb2axi_m_axi_ar_id    ;
logic[TB_MASTERS-1:0][AW-1:0]               axi2ahb2axi_m_axi_ar_addr  ;
logic[TB_MASTERS-1:0][7:0]                  axi2ahb2axi_m_axi_ar_len   ;
logic[TB_MASTERS-1:0][2:0]                  axi2ahb2axi_m_axi_ar_size  ;
logic[TB_MASTERS-1:0][1:0]                  axi2ahb2axi_m_axi_ar_burst ;
logic[TB_MASTERS-1:0][1:0]                  axi2ahb2axi_m_axi_ar_lock  ;
logic[TB_MASTERS-1:0][3:0]                  axi2ahb2axi_m_axi_ar_cache ;
logic[TB_MASTERS-1:0][2:0]                  axi2ahb2axi_m_axi_ar_prot  ;
logic[TB_MASTERS-1:0][3:0]                  axi2ahb2axi_m_axi_ar_qos   ;
logic[TB_MASTERS-1:0][3:0]                  axi2ahb2axi_m_axi_ar_region;
logic[TB_MASTERS-1:0][USERW-1:0]            axi2ahb2axi_m_axi_ar_user  ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_ar_valid ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_ar_ready ;
// DUT Slave -- R
logic[TB_MASTERS-1:0][MTIDW-1:0]            axi2ahb2axi_m_axi_r_id     ;
logic[TB_MASTERS-1:0][DW-1:0]               axi2ahb2axi_m_axi_r_data   ;
logic[TB_MASTERS-1:0][1:0]                  axi2ahb2axi_m_axi_r_resp   ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_r_last   ;
logic[TB_MASTERS-1:0][USERW-1:0]            axi2ahb2axi_m_axi_r_user   ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_r_valid  ;
logic[TB_MASTERS-1:0]                       axi2ahb2axi_m_axi_r_ready  ;

//////////////////////////////
// DUT Master -- AW
logic[TB_SLAVES-1:0][STIDW-1:0]             axi2ahb2axi_s_axi_aw_id    ;
logic[TB_SLAVES-1:0][AW-1:0]                axi2ahb2axi_s_axi_aw_addr  ;
logic[TB_SLAVES-1:0][7:0]                   axi2ahb2axi_s_axi_aw_len   ;
logic[TB_SLAVES-1:0][2:0]                   axi2ahb2axi_s_axi_aw_size  ;
logic[TB_SLAVES-1:0][1:0]                   axi2ahb2axi_s_axi_aw_burst ;
logic[TB_SLAVES-1:0][1:0]                   axi2ahb2axi_s_axi_aw_lock  ;
logic[TB_SLAVES-1:0][3:0]                   axi2ahb2axi_s_axi_aw_cache ;
logic[TB_SLAVES-1:0][2:0]                   axi2ahb2axi_s_axi_aw_prot  ;
logic[TB_SLAVES-1:0][3:0]                   axi2ahb2axi_s_axi_aw_qos   ;
logic[TB_SLAVES-1:0][3:0]                   axi2ahb2axi_s_axi_aw_region;
logic[TB_SLAVES-1:0][USERW-1:0]             axi2ahb2axi_s_axi_aw_user  ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_aw_valid ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_aw_ready ;
// DUT Master -- W
logic[TB_SLAVES-1:0][STIDW-1:0]             axi2ahb2axi_s_axi_w_id     ;
logic[TB_SLAVES-1:0][DW-1:0]                axi2ahb2axi_s_axi_w_data   ;
logic[TB_SLAVES-1:0][DW/8-1:0]              axi2ahb2axi_s_axi_w_strb   ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_w_last   ;
logic[TB_SLAVES-1:0][USERW-1:0]             axi2ahb2axi_s_axi_w_user   ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_w_valid  ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_w_ready  ;
// DUT Master -- B
logic[TB_SLAVES-1:0][STIDW-1:0]             axi2ahb2axi_s_axi_b_id     ;
logic[TB_SLAVES-1:0][1:0]                   axi2ahb2axi_s_axi_b_resp   ;
logic[TB_SLAVES-1:0][USERW-1:0]             axi2ahb2axi_s_axi_b_user   ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_b_valid  ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_b_ready  ;
// DUT Master -- AR
logic[TB_SLAVES-1:0][STIDW-1:0]             axi2ahb2axi_s_axi_ar_id    ;
logic[TB_SLAVES-1:0][AW-1:0]                axi2ahb2axi_s_axi_ar_addr  ;
logic[TB_SLAVES-1:0][7:0]                   axi2ahb2axi_s_axi_ar_len   ;
logic[TB_SLAVES-1:0][2:0]                   axi2ahb2axi_s_axi_ar_size  ;
logic[TB_SLAVES-1:0][1:0]                   axi2ahb2axi_s_axi_ar_burst ;
logic[TB_SLAVES-1:0][1:0]                   axi2ahb2axi_s_axi_ar_lock  ;
logic[TB_SLAVES-1:0][3:0]                   axi2ahb2axi_s_axi_ar_cache ;
logic[TB_SLAVES-1:0][2:0]                   axi2ahb2axi_s_axi_ar_prot  ;
logic[TB_SLAVES-1:0][3:0]                   axi2ahb2axi_s_axi_ar_qos   ;
logic[TB_SLAVES-1:0][3:0]                   axi2ahb2axi_s_axi_ar_region;
logic[TB_SLAVES-1:0][USERW-1:0]             axi2ahb2axi_s_axi_ar_user  ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_ar_valid ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_ar_ready ;
// DUT Master -- R
logic[TB_SLAVES-1:0][STIDW-1:0]             axi2ahb2axi_s_axi_r_id     ;
logic[TB_SLAVES-1:0][DW-1:0]                axi2ahb2axi_s_axi_r_data   ;
logic[TB_SLAVES-1:0][1:0]                   axi2ahb2axi_s_axi_r_resp   ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_r_last   ;
logic[TB_SLAVES-1:0][USERW-1:0]             axi2ahb2axi_s_axi_r_user   ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_r_valid  ;
logic[TB_SLAVES-1:0]                        axi2ahb2axi_s_axi_r_ready  ;

// ------------------------------------------------------------------------------------------------ //
// -- TB ------------------------------------------------------------------------------------------ //
// ------------------------------------------------------------------------------------------------ //
tb_axi2axi_env
#(
    .DW                     (DW                 ),
    .AW                     (AW                 ),
    .USERW                  (USERW              ),
    .AXI_VER                (AXI_VER            ),
    .MTID                   (MTID               ),
    .MTIDW                  (MTIDW              ),
    .STID                   (STID               ),
    .STIDW                  (STIDW              ),
    .ADDR_MAX               (ADDR_MAX           ),

    .M_TB_MODE              (M_TB_MODE          ),
    
    .M_IDLE_RATE_AW         (M_IDLE_RATE_AW     ),
    .M_IDLE_RATE_W          (M_IDLE_RATE_W      ),
    .M_IDLE_RATE_AR         (M_IDLE_RATE_AR     ),
    .M_STALL_RATE_B         (M_STALL_RATE_B     ),
    .M_STALL_RATE_R         (M_STALL_RATE_R     ),
    .M_STROBE_MASK_RATE     (M_STROBE_MASK_RATE ),
    
    .M_INP_FILENAME_WR      (M_INP_FILENAME_WR  ),
    .M_INP_FILENAME_RD      (M_INP_FILENAME_RD  ),
    
    .M_GEN_RATE_WR          (M_GEN_RATE_WR      ),
    .M_TRANS_COUNT_WR       (M_TRANS_COUNT_WR   ),
    .M_GEN_RATE_RD          (M_GEN_RATE_RD      ),
    .M_TRANS_COUNT_RD       (M_TRANS_COUNT_RD   ),
    .M_DO_UNALIGNED         (M_DO_UNALIGNED     ),
    .M_INCR_DISTR           (M_INCR_DISTR       ),
    .M_WRAP_DISTR           (M_WRAP_DISTR       ),
    .M_FIXED_DISTR          (M_FIXED_DISTR      ),
    .M_MIN_BURST_LEN        (M_MIN_BURST_LEN    ),
    .M_MAX_BURST_LEN        (M_MAX_BURST_LEN    ),
    .M_MIN_BURST_SIZE       (M_MIN_BURST_SIZE   ),
    .M_MAX_BURST_SIZE       (M_MAX_BURST_SIZE   ),
    .M_WRITE_TO_FILE        (M_WRITE_TO_FILE    ),
    .M_FLNAME_WR            (M_FLNAME_WR        ),
    .M_FLNAME_RD            (M_FLNAME_RD        ),
    
    .S_ERROR_RATE           (S_ERROR_RATE       ),
    .S_STALL_RATE_AW        (S_STALL_RATE_AW    ),
    .S_STALL_RATE_W         (S_STALL_RATE_W     ),
    .S_STALL_RATE_AR        (S_STALL_RATE_AR    ),
    .S_IDLE_RATE_B          (S_IDLE_RATE_B      ),
    .S_IDLE_RATE_R          (S_IDLE_RATE_R      ),
    
    .WRITE_REPORT           (WRITE_REPORT       ),
    .WORK_DIR               (WORK_DIR           ),
    
    .MASTERS                (TB_MASTERS),
    .SLAVES                 (TB_SLAVES)
)
tb_env
(
    .clk                    (clk),
    .rst_n                  (rst_n),
    
    // TB Master
    .axi_m_aw_id_o          (tb_m_axi_aw_id    ),
    .axi_m_aw_addr_o        (tb_m_axi_aw_addr  ),
    .axi_m_aw_len_o         (tb_m_axi_aw_len   ),
    .axi_m_aw_size_o        (tb_m_axi_aw_size  ),
    .axi_m_aw_burst_o       (tb_m_axi_aw_burst ),
    .axi_m_aw_lock_o        (tb_m_axi_aw_lock  ),
    .axi_m_aw_cache_o       (tb_m_axi_aw_cache ),
    .axi_m_aw_prot_o        (tb_m_axi_aw_prot  ),
    .axi_m_aw_qos_o         (tb_m_axi_aw_qos   ),
    .axi_m_aw_region_o      (tb_m_axi_aw_region),
    .axi_m_aw_user_o        (tb_m_axi_aw_user  ),
    .axi_m_aw_valid_o       (tb_m_axi_aw_valid ),
    .axi_m_aw_ready_i       (tb_m_axi_aw_ready ),
    
    .axi_m_w_id_o           (tb_m_axi_w_id     ),
    .axi_m_w_data_o         (tb_m_axi_w_data   ),
    .axi_m_w_strb_o         (tb_m_axi_w_strb   ),
    .axi_m_w_last_o         (tb_m_axi_w_last   ),
    .axi_m_w_user_o         (tb_m_axi_w_user   ),
    .axi_m_w_valid_o        (tb_m_axi_w_valid  ),
    .axi_m_w_ready_i        (tb_m_axi_w_ready  ),
    
    .axi_m_b_id_i           (tb_m_axi_b_id     ),
    .axi_m_b_resp_i         (tb_m_axi_b_resp   ),
    .axi_m_b_user_i         (tb_m_axi_b_user   ),
    .axi_m_b_valid_i        (tb_m_axi_b_valid  ),
    .axi_m_b_ready_o        (tb_m_axi_b_ready  ),
    
    .axi_m_ar_id_o          (tb_m_axi_ar_id    ),
    .axi_m_ar_addr_o        (tb_m_axi_ar_addr  ),
    .axi_m_ar_len_o         (tb_m_axi_ar_len   ),
    .axi_m_ar_size_o        (tb_m_axi_ar_size  ),
    .axi_m_ar_burst_o       (tb_m_axi_ar_burst ),
    .axi_m_ar_lock_o        (tb_m_axi_ar_lock  ), 
    .axi_m_ar_cache_o       (tb_m_axi_ar_cache ),
    .axi_m_ar_prot_o        (tb_m_axi_ar_prot  ),
    .axi_m_ar_qos_o         (tb_m_axi_ar_qos   ),
    .axi_m_ar_region_o      (tb_m_axi_ar_region),
    .axi_m_ar_user_o        (tb_m_axi_ar_user  ),
    .axi_m_ar_valid_o       (tb_m_axi_ar_valid ),
    .axi_m_ar_ready_i       (tb_m_axi_ar_ready ),
    
    .axi_m_r_id_i           (tb_m_axi_r_id     ),
    .axi_m_r_data_i         (tb_m_axi_r_data   ),
    .axi_m_r_resp_i         (tb_m_axi_r_resp   ),
    .axi_m_r_last_i         (tb_m_axi_r_last   ),
    .axi_m_r_user_i         (tb_m_axi_r_user   ),
    .axi_m_r_valid_i        (tb_m_axi_r_valid  ),
    .axi_m_r_ready_o        (tb_m_axi_r_ready  ),
    
    // TB Slave
    .axi_s_aw_id_i          (axi2ahb2axi_s_axi_aw_id    ),
    .axi_s_aw_addr_i        (axi2ahb2axi_s_axi_aw_addr  ),
    .axi_s_aw_len_i         (axi2ahb2axi_s_axi_aw_len   ),
    .axi_s_aw_size_i        (axi2ahb2axi_s_axi_aw_size  ),
    .axi_s_aw_burst_i       (axi2ahb2axi_s_axi_aw_burst ),
    .axi_s_aw_lock_i        (axi2ahb2axi_s_axi_aw_lock  ),
    .axi_s_aw_cache_i       (axi2ahb2axi_s_axi_aw_cache ),
    .axi_s_aw_prot_i        (axi2ahb2axi_s_axi_aw_prot  ),
    .axi_s_aw_qos_i         (axi2ahb2axi_s_axi_aw_qos   ),
    .axi_s_aw_region_i      (axi2ahb2axi_s_axi_aw_region),
    .axi_s_aw_user_i        (axi2ahb2axi_s_axi_aw_user  ),
    .axi_s_aw_valid_i       (axi2ahb2axi_s_axi_aw_valid ),
    .axi_s_aw_ready_o       (axi2ahb2axi_s_axi_aw_ready ),
    
    .axi_s_w_id_i           (axi2ahb2axi_s_axi_w_id     ),
    .axi_s_w_data_i         (axi2ahb2axi_s_axi_w_data   ),
    .axi_s_w_strb_i         (axi2ahb2axi_s_axi_w_strb   ),
    .axi_s_w_last_i         (axi2ahb2axi_s_axi_w_last   ),
    .axi_s_w_user_i         (axi2ahb2axi_s_axi_w_user   ),
    .axi_s_w_valid_i        (axi2ahb2axi_s_axi_w_valid  ),
    .axi_s_w_ready_o        (axi2ahb2axi_s_axi_w_ready  ),
    
    .axi_s_b_id_o           (axi2ahb2axi_s_axi_b_id     ),
    .axi_s_b_resp_o         (axi2ahb2axi_s_axi_b_resp   ),
    .axi_s_b_user_o         (axi2ahb2axi_s_axi_b_user   ),
    .axi_s_b_valid_o        (axi2ahb2axi_s_axi_b_valid  ),
    .axi_s_b_ready_i        (axi2ahb2axi_s_axi_b_ready  ),
    
    .axi_s_ar_id_i          (axi2ahb2axi_s_axi_ar_id    ),
    .axi_s_ar_addr_i        (axi2ahb2axi_s_axi_ar_addr  ),
    .axi_s_ar_len_i         (axi2ahb2axi_s_axi_ar_len   ),
    .axi_s_ar_size_i        (axi2ahb2axi_s_axi_ar_size  ),
    .axi_s_ar_burst_i       (axi2ahb2axi_s_axi_ar_burst ),
    .axi_s_ar_lock_i        (axi2ahb2axi_s_axi_ar_lock  ),
    .axi_s_ar_cache_i       (axi2ahb2axi_s_axi_ar_cache ),
    .axi_s_ar_prot_i        (axi2ahb2axi_s_axi_ar_prot  ),
    .axi_s_ar_qos_i         (axi2ahb2axi_s_axi_ar_qos   ),
    .axi_s_ar_region_i      (axi2ahb2axi_s_axi_ar_region),
    .axi_s_ar_user_i        (axi2ahb2axi_s_axi_ar_user  ),
    .axi_s_ar_valid_i       (axi2ahb2axi_s_axi_ar_valid ),
    .axi_s_ar_ready_o       (axi2ahb2axi_s_axi_ar_ready ),
    
    .axi_s_r_id_o           (axi2ahb2axi_s_axi_r_id     ),
    .axi_s_r_data_o         (axi2ahb2axi_s_axi_r_data   ),
    .axi_s_r_resp_o         (axi2ahb2axi_s_axi_r_resp   ),
    .axi_s_r_last_o         (axi2ahb2axi_s_axi_r_last   ),
    .axi_s_r_user_o         (axi2ahb2axi_s_axi_r_user   ),
    .axi_s_r_valid_o        (axi2ahb2axi_s_axi_r_valid  ),
    .axi_s_r_ready_i        (axi2ahb2axi_s_axi_r_ready  ),

    
    .both_mailbox_empty (both_mailbox_empty)
);

// ------------------------------------------------------------------------------------------------ //
// -- DUT ----------------------------------------------------------------------------------------- //
// ------------------------------------------------------------------------------------------------ //
axi4_duth_noc
#(
    .TIDS_M                 (MTID),
    .ADDRESS_WIDTH          (AW),
    .DATA_LANES             (DW/8),
    .USER_WIDTH             (USERW),
    .EXT_MASTERS            (TB_MASTERS),
    .EXT_SLAVES             (TB_SLAVES),
    .NOC_HOP_COUNT_REQ      (0),
    .NOC_HOP_COUNT_RESP     (0),
    .MAX_LINK_WIDTH_REQ_IN  (0),
    .MAX_LINK_WIDTH_RESP_IN (0),
    .SHARED_WR_PATH         (SHARED_WR_PATH),
    .MAX_PENDING_SAME_DST   (MAX_PENDING_SAME_DST),
    .ADDR_BASE              (ADDR_BASE),
    .ADDR_RANGE             (ADDR_RANGE),
    .M_FIFO_DEPTHS          (M_FIFO_DEPTHS),
    .S_FIFO_DEPTHS          (S_FIFO_DEPTHS),
    .ASSERT_READYVALID      (1'b0)
)
dut
(
    .clk                    (clk),
    .rst                    (~rst_n),
    
    // DUT Slave
    .axi_s_aw_id_i          (axi2ahb2axi_m_axi_aw_id    ),
    .axi_s_aw_addr_i        (axi2ahb2axi_m_axi_aw_addr  ),
    .axi_s_aw_len_i         (axi2ahb2axi_m_axi_aw_len   ),
    .axi_s_aw_size_i        (axi2ahb2axi_m_axi_aw_size  ),
    .axi_s_aw_burst_i       (axi2ahb2axi_m_axi_aw_burst ),
    .axi_s_aw_lock_i        (axi2ahb2axi_m_axi_aw_lock  ),
    .axi_s_aw_cache_i       (axi2ahb2axi_m_axi_aw_cache ),
    .axi_s_aw_prot_i        (axi2ahb2axi_m_axi_aw_prot  ),
    .axi_s_aw_qos_i         (axi2ahb2axi_m_axi_aw_qos   ),
    .axi_s_aw_region_i      (axi2ahb2axi_m_axi_aw_region),
    .axi_s_aw_user_i        (axi2ahb2axi_m_axi_aw_user  ),
    .axi_s_aw_valid_i       (axi2ahb2axi_m_axi_aw_valid ),
    .axi_s_aw_ready_o       (axi2ahb2axi_m_axi_aw_ready ),
    
    .axi_s_w_id_i           (axi2ahb2axi_m_axi_w_id     ),
    .axi_s_w_data_i         (axi2ahb2axi_m_axi_w_data   ),
    .axi_s_w_strb_i         (axi2ahb2axi_m_axi_w_strb   ),
    .axi_s_w_last_i         (axi2ahb2axi_m_axi_w_last   ),
    .axi_s_w_user_i         (axi2ahb2axi_m_axi_w_user   ),
    .axi_s_w_valid_i        (axi2ahb2axi_m_axi_w_valid  ),
    .axi_s_w_ready_o        (axi2ahb2axi_m_axi_w_ready  ),
    
    .axi_s_b_id_o           (axi2ahb2axi_m_axi_b_id     ),
    .axi_s_b_resp_o         (axi2ahb2axi_m_axi_b_resp   ),
    .axi_s_b_user_o         (axi2ahb2axi_m_axi_b_user   ),
    .axi_s_b_valid_o        (axi2ahb2axi_m_axi_b_valid  ),
    .axi_s_b_ready_i        (axi2ahb2axi_m_axi_b_ready  ),
    
    .axi_s_ar_id_i          (axi2ahb2axi_m_axi_ar_id    ),
    .axi_s_ar_addr_i        (axi2ahb2axi_m_axi_ar_addr  ),
    .axi_s_ar_len_i         (axi2ahb2axi_m_axi_ar_len   ),
    .axi_s_ar_size_i        (axi2ahb2axi_m_axi_ar_size  ),
    .axi_s_ar_burst_i       (axi2ahb2axi_m_axi_ar_burst ),
    .axi_s_ar_lock_i        (axi2ahb2axi_m_axi_ar_lock  ),
    .axi_s_ar_cache_i       (axi2ahb2axi_m_axi_ar_cache ),
    .axi_s_ar_prot_i        (axi2ahb2axi_m_axi_ar_prot  ),
    .axi_s_ar_qos_i         (axi2ahb2axi_m_axi_ar_qos   ),
    .axi_s_ar_region_i      (axi2ahb2axi_m_axi_ar_region),
    .axi_s_ar_user_i        (axi2ahb2axi_m_axi_ar_user  ),
    .axi_s_ar_valid_i       (axi2ahb2axi_m_axi_ar_valid ),
    .axi_s_ar_ready_o       (axi2ahb2axi_m_axi_ar_ready ),
    
    .axi_s_r_id_o           (axi2ahb2axi_m_axi_r_id     ),
    .axi_s_r_data_o         (axi2ahb2axi_m_axi_r_data   ),
    .axi_s_r_resp_o         (axi2ahb2axi_m_axi_r_resp   ),
    .axi_s_r_last_o         (axi2ahb2axi_m_axi_r_last   ),
    .axi_s_r_user_o         (axi2ahb2axi_m_axi_r_user   ),
    .axi_s_r_valid_o        (axi2ahb2axi_m_axi_r_valid  ),
    .axi_s_r_ready_i        (axi2ahb2axi_m_axi_r_ready  ),
    
    // DUT Master
    .axi_m_aw_id_o          (tb_s_axi_aw_id    ),
    .axi_m_aw_addr_o        (tb_s_axi_aw_addr  ),
    .axi_m_aw_len_o         (tb_s_axi_aw_len   ),
    .axi_m_aw_size_o        (tb_s_axi_aw_size  ),
    .axi_m_aw_burst_o       (tb_s_axi_aw_burst ),
    .axi_m_aw_lock_o        (tb_s_axi_aw_lock  ),
    .axi_m_aw_cache_o       (tb_s_axi_aw_cache ),
    .axi_m_aw_prot_o        (tb_s_axi_aw_prot  ),
    .axi_m_aw_qos_o         (tb_s_axi_aw_qos   ),
    .axi_m_aw_region_o      (tb_s_axi_aw_region),
    .axi_m_aw_user_o        (tb_s_axi_aw_user  ),
    .axi_m_aw_valid_o       (tb_s_axi_aw_valid ),
    .axi_m_aw_ready_i       (tb_s_axi_aw_ready ),
    
    .axi_m_w_id_o           (tb_s_axi_w_id     ),
    .axi_m_w_data_o         (tb_s_axi_w_data   ),
    .axi_m_w_strb_o         (tb_s_axi_w_strb   ),
    .axi_m_w_last_o         (tb_s_axi_w_last   ),
    .axi_m_w_user_o         (tb_s_axi_w_user   ),
    .axi_m_w_valid_o        (tb_s_axi_w_valid  ),
    .axi_m_w_ready_i        (tb_s_axi_w_ready  ),
    
    .axi_m_b_id_i           (tb_s_axi_b_id     ),
    .axi_m_b_resp_i         (tb_s_axi_b_resp   ),
    .axi_m_b_user_i         (tb_s_axi_b_user   ),
    .axi_m_b_valid_i        (tb_s_axi_b_valid  ),
    .axi_m_b_ready_o        (tb_s_axi_b_ready  ),
    
    .axi_m_ar_id_o          (tb_s_axi_ar_id    ),
    .axi_m_ar_addr_o        (tb_s_axi_ar_addr  ),
    .axi_m_ar_len_o         (tb_s_axi_ar_len   ),
    .axi_m_ar_size_o        (tb_s_axi_ar_size  ),
    .axi_m_ar_burst_o       (tb_s_axi_ar_burst ),
    .axi_m_ar_lock_o        (tb_s_axi_ar_lock  ), 
    .axi_m_ar_cache_o       (tb_s_axi_ar_cache ),
    .axi_m_ar_prot_o        (tb_s_axi_ar_prot  ),
    .axi_m_ar_qos_o         (tb_s_axi_ar_qos   ),
    .axi_m_ar_region_o      (tb_s_axi_ar_region),
    .axi_m_ar_user_o        (tb_s_axi_ar_user  ),
    .axi_m_ar_valid_o       (tb_s_axi_ar_valid ),
    .axi_m_ar_ready_i       (tb_s_axi_ar_ready ),
    
    .axi_m_r_id_i           (tb_s_axi_r_id     ),
    .axi_m_r_data_i         (tb_s_axi_r_data   ),
    .axi_m_r_resp_i         (tb_s_axi_r_resp   ),
    .axi_m_r_last_i         (tb_s_axi_r_last   ),
    .axi_m_r_user_i         (tb_s_axi_r_user   ),
    .axi_m_r_valid_i        (tb_s_axi_r_valid  ),
    .axi_m_r_ready_o        (tb_s_axi_r_ready  )
);

////////////////////////////////////////////////////
/////    axi2ahb --> ahb2axi
//////////////////////////////////////////////////// 
// for axi2axi_env masters
for (genvar m = 0; m < TB_MASTERS; m++) begin
        axi2ahb_ahb2axi #(
            .TIDW(MTIDW),
            .AW(AW),
            .DW(DW),
            .USERW(USERW)
        ) axi2ahb2axi_m (
            .HCLK            (clk),
            .HRESETn         (rst_n),

            // DUT Slave
            .axi_aw_id_i     (tb_m_axi_aw_id[m]),
            .axi_aw_addr_i   (tb_m_axi_aw_addr[m]),
            .axi_aw_len_i    (tb_m_axi_aw_len[m]),
            .axi_aw_size_i   (tb_m_axi_aw_size[m]),
            .axi_aw_burst_i  (tb_m_axi_aw_burst[m]),
            .axi_aw_lock_i   (tb_m_axi_aw_lock[m]),
            .axi_aw_cache_i  (tb_m_axi_aw_cache[m]),
            .axi_aw_prot_i   (tb_m_axi_aw_prot[m]),
            .axi_aw_qos_i    (tb_m_axi_aw_qos[m]),
            .axi_aw_region_i (tb_m_axi_aw_region[m]),
            .axi_aw_user_i   (tb_m_axi_aw_user[m]),
            .axi_aw_valid_i  (tb_m_axi_aw_valid[m]),
            .axi_aw_ready_o  (tb_m_axi_aw_ready[m]),

            .axi_w_id_i      (tb_m_axi_w_id[m]),
            .axi_w_data_i    (tb_m_axi_w_data[m]),
            .axi_w_strb_i    (tb_m_axi_w_strb[m]),
            .axi_w_last_i    (tb_m_axi_w_last[m]),
            .axi_w_user_i    (tb_m_axi_w_user[m]),
            .axi_w_valid_i   (tb_m_axi_w_valid[m]),
            .axi_w_ready_o   (tb_m_axi_w_ready[m]),

            .axi_b_id_o      (tb_m_axi_b_id[m]),
            .axi_b_resp_o    (tb_m_axi_b_resp[m]),
            .axi_b_user_o    (tb_m_axi_b_user[m]),
            .axi_b_valid_o   (tb_m_axi_b_valid[m]),
            .axi_b_ready_i   (tb_m_axi_b_ready[m]),

            .axi_ar_id_i     (tb_m_axi_ar_id[m]),
            .axi_ar_addr_i   (tb_m_axi_ar_addr[m]),
            .axi_ar_len_i    (tb_m_axi_ar_len[m]),
            .axi_ar_size_i   (tb_m_axi_ar_size[m]),
            .axi_ar_burst_i  (tb_m_axi_ar_burst[m]),
            .axi_ar_lock_i   (tb_m_axi_ar_lock[m]),
            .axi_ar_cache_i  (tb_m_axi_ar_cache[m]),
            .axi_ar_prot_i   (tb_m_axi_ar_prot[m]),
            .axi_ar_qos_i    (tb_m_axi_ar_qos[m]),
            .axi_ar_region_i (tb_m_axi_ar_region[m]),
            .axi_ar_user_i   (tb_m_axi_ar_user[m]),
            .axi_ar_valid_i  (tb_m_axi_ar_valid[m]),
            .axi_ar_ready_o  (tb_m_axi_ar_ready[m]),

            .axi_r_id_o      (tb_m_axi_r_id[m]),
            .axi_r_data_o    (tb_m_axi_r_data[m]),
            .axi_r_resp_o    (tb_m_axi_r_resp[m]),
            .axi_r_last_o    (tb_m_axi_r_last[m]),
            .axi_r_user_o    (tb_m_axi_r_user[m]),
            .axi_r_valid_o   (tb_m_axi_r_valid[m]),
            .axi_r_ready_i   (tb_m_axi_r_ready[m]),

            // DUT Master
            .axi_aw_id_o     (axi2ahb2axi_m_axi_aw_id[m]),
            .axi_aw_addr_o   (axi2ahb2axi_m_axi_aw_addr[m]),
            .axi_aw_len_o    (axi2ahb2axi_m_axi_aw_len[m]),
            .axi_aw_size_o   (axi2ahb2axi_m_axi_aw_size[m]),
            .axi_aw_burst_o  (axi2ahb2axi_m_axi_aw_burst[m]),
            .axi_aw_lock_o   (axi2ahb2axi_m_axi_aw_lock[m]),
            .axi_aw_cache_o  (axi2ahb2axi_m_axi_aw_cache[m]),
            .axi_aw_prot_o   (axi2ahb2axi_m_axi_aw_prot[m]),
            .axi_aw_qos_o    (axi2ahb2axi_m_axi_aw_qos[m]),
            .axi_aw_region_o (axi2ahb2axi_m_axi_aw_region[m]),
            .axi_aw_user_o   (axi2ahb2axi_m_axi_aw_user[m]),
            .axi_aw_valid_o  (axi2ahb2axi_m_axi_aw_valid[m]),
            .axi_aw_ready_i  (axi2ahb2axi_m_axi_aw_ready[m]),

            .axi_w_id_o      (axi2ahb2axi_m_axi_w_id[m]),
            .axi_w_data_o    (axi2ahb2axi_m_axi_w_data[m]),
            .axi_w_strb_o    (axi2ahb2axi_m_axi_w_strb[m]),
            .axi_w_last_o    (axi2ahb2axi_m_axi_w_last[m]),
            .axi_w_user_o    (axi2ahb2axi_m_axi_w_user[m]),
            .axi_w_valid_o   (axi2ahb2axi_m_axi_w_valid[m]),
            .axi_w_ready_i   (axi2ahb2axi_m_axi_w_ready[m]),

            .axi_b_id_i      (axi2ahb2axi_m_axi_b_id[m]),
            .axi_b_resp_i    (axi2ahb2axi_m_axi_b_resp[m]),
            .axi_b_user_i    (axi2ahb2axi_m_axi_b_user[m]),
            .axi_b_valid_i   (axi2ahb2axi_m_axi_b_valid[m]),
            .axi_b_ready_o   (axi2ahb2axi_m_axi_b_ready[m]),

            .axi_ar_id_o     (axi2ahb2axi_m_axi_ar_id[m]),
            .axi_ar_addr_o   (axi2ahb2axi_m_axi_ar_addr[m]),
            .axi_ar_len_o    (axi2ahb2axi_m_axi_ar_len[m]),
            .axi_ar_size_o   (axi2ahb2axi_m_axi_ar_size[m]),
            .axi_ar_burst_o  (axi2ahb2axi_m_axi_ar_burst[m]),
            .axi_ar_lock_o   (axi2ahb2axi_m_axi_ar_lock[m]),
            .axi_ar_cache_o  (axi2ahb2axi_m_axi_ar_cache[m]),
            .axi_ar_prot_o   (axi2ahb2axi_m_axi_ar_prot[m]),
            .axi_ar_qos_o    (axi2ahb2axi_m_axi_ar_qos[m]),
            .axi_ar_region_o (axi2ahb2axi_m_axi_ar_region[m]),
            .axi_ar_user_o   (axi2ahb2axi_m_axi_ar_user[m]),
            .axi_ar_valid_o  (axi2ahb2axi_m_axi_ar_valid[m]),
            .axi_ar_ready_i  (axi2ahb2axi_m_axi_ar_ready[m]),

            .axi_r_id_i      (axi2ahb2axi_m_axi_r_id[m]),
            .axi_r_data_i    (axi2ahb2axi_m_axi_r_data[m]),
            .axi_r_resp_i    (axi2ahb2axi_m_axi_r_resp[m]),
            .axi_r_last_i    (axi2ahb2axi_m_axi_r_last[m]),
            .axi_r_user_i    (axi2ahb2axi_m_axi_r_user[m]),
            .axi_r_valid_i   (axi2ahb2axi_m_axi_r_valid[m]),
            .axi_r_ready_o   (axi2ahb2axi_m_axi_r_ready[m])
        );






    
// /*------------------------------------------------------------------------------
// --  TESTBENCH LOGGER 
// ------------------------------------------------------------------------------*/
    // axi2axi_logger #(
    //         .AHB_DATA_WIDTH(AW),
    //         .AHB_ADDRESS_WIDTH(DW),
    //         .TIDW(MTIDW),
    //         .AW(AW),
    //         .DW(DW),
    //         .USERW(USERW)
    //     ) inst_axi2axi_logger (
    //         .clk             (clk),
    //         .rst_n           (rst_n),
    //         .axi_ar_id_m     (tb_m_axi_ar_id[m]),
    //         .axi_ar_addr_m   (tb_m_axi_ar_addr[m]),
    //         .axi_ar_len_m    (tb_m_axi_ar_len[m]),
    //         .axi_ar_size_m   (tb_m_axi_ar_size[m]),
    //         .axi_ar_burst_m  (tb_m_axi_ar_burst[m]),
    //         .axi_ar_lock_m   (tb_m_axi_ar_lock[m]),
    //         .axi_ar_cache_m  (tb_m_axi_ar_cache[m]),
    //         .axi_ar_prot_m   (tb_m_axi_ar_prot[m]),
    //         .axi_ar_qos_m    (tb_m_axi_ar_qos[m]),
    //         .axi_ar_region_m (tb_m_axi_ar_region[m]),
    //         .axi_ar_user_m   (tb_m_axi_ar_user[m]),
    //         .axi_ar_valid_m  (tb_m_axi_ar_valid[m]),
    //         .axi_ar_ready_m  (tb_m_axi_ar_ready[m]),
    //         .axi_r_id_m      (tb_m_axi_r_id[m]),
    //         .axi_r_data_m    (tb_m_axi_r_data[m]),
    //         .axi_r_resp_m    (tb_m_axi_r_resp[m]),
    //         .axi_r_last_m    (tb_m_axi_r_last[m]),
    //         .axi_r_user_m    (tb_m_axi_r_user[m]),
    //         .axi_r_valid_m   (tb_m_axi_r_valid[m]),
    //         .axi_r_ready_m   (tb_m_axi_r_ready[m]),
    //         .axi_ar_id_s     (axi2ahb2axi_m_axi_ar_id[m]),
    //         .axi_ar_addr_s   (axi2ahb2axi_m_axi_ar_addr[m]),
    //         .axi_ar_len_s    (axi2ahb2axi_m_axi_ar_len[m]),
    //         .axi_ar_size_s   (axi2ahb2axi_m_axi_ar_size[m]),
    //         .axi_ar_burst_s  (axi2ahb2axi_m_axi_ar_burst[m]),
    //         .axi_ar_lock_s   (axi2ahb2axi_m_axi_ar_lock[m]),
    //         .axi_ar_cache_s  (axi2ahb2axi_m_axi_ar_cache[m]),
    //         .axi_ar_prot_s   (axi2ahb2axi_m_axi_ar_prot[m]),
    //         .axi_ar_qos_s    (axi2ahb2axi_m_axi_ar_qos[m]),
    //         .axi_ar_region_s (axi2ahb2axi_m_axi_ar_region[m]),
    //         .axi_ar_user_s   (axi2ahb2axi_m_axi_ar_user[m]),
    //         .axi_ar_valid_s  (axi2ahb2axi_m_axi_ar_valid[m]),
    //         .axi_ar_ready_s  (axi2ahb2axi_m_axi_ar_ready[m]),
    //         .axi_r_id_s      (axi2ahb2axi_m_axi_r_id[m]),
    //         .axi_r_data_s    (axi2ahb2axi_m_axi_r_data[m]),
    //         .axi_r_resp_s    (axi2ahb2axi_m_axi_r_resp[m]),
    //         .axi_r_last_s    (axi2ahb2axi_m_axi_r_last[m]),
    //         .axi_r_user_s    (axi2ahb2axi_m_axi_r_user[m]),
    //         .axi_r_valid_s   (axi2ahb2axi_m_axi_r_valid[m]),
    //         .axi_r_ready_s   (axi2ahb2axi_m_axi_r_ready[m])
    //     );
end

// for axi2axi_env slaves
for (genvar s = 0; s < TB_SLAVES; s++) begin
        axi2ahb_ahb2axi #(
            .TIDW(STIDW),
            .AW(AW),
            .DW(DW),
            .USERW(USERW)
        ) axi2ahb2axi_s (
            .HCLK            (clk),
            .HRESETn         (rst_n),

            // DUT Slave
            .axi_aw_id_i     (tb_s_axi_aw_id[s]),
            .axi_aw_addr_i   (tb_s_axi_aw_addr[s]),
            .axi_aw_len_i    (tb_s_axi_aw_len[s]),
            .axi_aw_size_i   (tb_s_axi_aw_size[s]),
            .axi_aw_burst_i  (tb_s_axi_aw_burst[s]),
            .axi_aw_lock_i   (tb_s_axi_aw_lock[s]),
            .axi_aw_cache_i  (tb_s_axi_aw_cache[s]),
            .axi_aw_prot_i   (tb_s_axi_aw_prot[s]),
            .axi_aw_qos_i    (tb_s_axi_aw_qos[s]),
            .axi_aw_region_i (tb_s_axi_aw_region[s]),
            .axi_aw_user_i   (tb_s_axi_aw_user[s]),
            .axi_aw_valid_i  (tb_s_axi_aw_valid[s]),
            .axi_aw_ready_o  (tb_s_axi_aw_ready[s]),

            .axi_w_id_i      (tb_s_axi_w_id[s]),
            .axi_w_data_i    (tb_s_axi_w_data[s]),
            .axi_w_strb_i    (tb_s_axi_w_strb[s]),
            .axi_w_last_i    (tb_s_axi_w_last[s]),
            .axi_w_user_i    (tb_s_axi_w_user[s]),
            .axi_w_valid_i   (tb_s_axi_w_valid[s]),
            .axi_w_ready_o   (tb_s_axi_w_ready[s]),

            .axi_b_id_o      (tb_s_axi_b_id[s]),
            .axi_b_resp_o    (tb_s_axi_b_resp[s]),
            .axi_b_user_o    (tb_s_axi_b_user[s]),
            .axi_b_valid_o   (tb_s_axi_b_valid[s]),
            .axi_b_ready_i   (tb_s_axi_b_ready[s]),

            .axi_ar_id_i     (tb_s_axi_ar_id[s]),
            .axi_ar_addr_i   (tb_s_axi_ar_addr[s]),
            .axi_ar_len_i    (tb_s_axi_ar_len[s]),
            .axi_ar_size_i   (tb_s_axi_ar_size[s]),
            .axi_ar_burst_i  (tb_s_axi_ar_burst[s]),
            .axi_ar_lock_i   (tb_s_axi_ar_lock[s]),
            .axi_ar_cache_i  (tb_s_axi_ar_cache[s]),
            .axi_ar_prot_i   (tb_s_axi_ar_prot[s]),
            .axi_ar_qos_i    (tb_s_axi_ar_qos[s]),
            .axi_ar_region_i (tb_s_axi_ar_region[s]),
            .axi_ar_user_i   (tb_s_axi_ar_user[s]),
            .axi_ar_valid_i  (tb_s_axi_ar_valid[s]),
            .axi_ar_ready_o  (tb_s_axi_ar_ready[s]),

            .axi_r_id_o      (tb_s_axi_r_id[s]),
            .axi_r_data_o    (tb_s_axi_r_data[s]),
            .axi_r_resp_o    (tb_s_axi_r_resp[s]),
            .axi_r_last_o    (tb_s_axi_r_last[s]),
            .axi_r_user_o    (tb_s_axi_r_user[s]),
            .axi_r_valid_o   (tb_s_axi_r_valid[s]),
            .axi_r_ready_i   (tb_s_axi_r_ready[s]),

            // DUT Master
            .axi_aw_id_o     (axi2ahb2axi_s_axi_aw_id[s]),
            .axi_aw_addr_o   (axi2ahb2axi_s_axi_aw_addr[s]),
            .axi_aw_len_o    (axi2ahb2axi_s_axi_aw_len[s]),
            .axi_aw_size_o   (axi2ahb2axi_s_axi_aw_size[s]),
            .axi_aw_burst_o  (axi2ahb2axi_s_axi_aw_burst[s]),
            .axi_aw_lock_o   (axi2ahb2axi_s_axi_aw_lock[s]),
            .axi_aw_cache_o  (axi2ahb2axi_s_axi_aw_cache[s]),
            .axi_aw_prot_o   (axi2ahb2axi_s_axi_aw_prot[s]),
            .axi_aw_qos_o    (axi2ahb2axi_s_axi_aw_qos[s]),
            .axi_aw_region_o (axi2ahb2axi_s_axi_aw_region[s]),
            .axi_aw_user_o   (axi2ahb2axi_s_axi_aw_user[s]),
            .axi_aw_valid_o  (axi2ahb2axi_s_axi_aw_valid[s]),
            .axi_aw_ready_i  (axi2ahb2axi_s_axi_aw_ready[s]),

            .axi_w_id_o      (axi2ahb2axi_s_axi_w_id[s]),
            .axi_w_data_o    (axi2ahb2axi_s_axi_w_data[s]),
            .axi_w_strb_o    (axi2ahb2axi_s_axi_w_strb[s]),
            .axi_w_last_o    (axi2ahb2axi_s_axi_w_last[s]),
            .axi_w_user_o    (axi2ahb2axi_s_axi_w_user[s]),
            .axi_w_valid_o   (axi2ahb2axi_s_axi_w_valid[s]),
            .axi_w_ready_i   (axi2ahb2axi_s_axi_w_ready[s]),

            .axi_b_id_i      (axi2ahb2axi_s_axi_b_id[s]),
            .axi_b_resp_i    (axi2ahb2axi_s_axi_b_resp[s]),
            .axi_b_user_i    (axi2ahb2axi_s_axi_b_user[s]),
            .axi_b_valid_i   (axi2ahb2axi_s_axi_b_valid[s]),
            .axi_b_ready_o   (axi2ahb2axi_s_axi_b_ready[s]),

            .axi_ar_id_o     (axi2ahb2axi_s_axi_ar_id[s]),
            .axi_ar_addr_o   (axi2ahb2axi_s_axi_ar_addr[s]),
            .axi_ar_len_o    (axi2ahb2axi_s_axi_ar_len[s]),
            .axi_ar_size_o   (axi2ahb2axi_s_axi_ar_size[s]),
            .axi_ar_burst_o  (axi2ahb2axi_s_axi_ar_burst[s]),
            .axi_ar_lock_o   (axi2ahb2axi_s_axi_ar_lock[s]),
            .axi_ar_cache_o  (axi2ahb2axi_s_axi_ar_cache[s]),
            .axi_ar_prot_o   (axi2ahb2axi_s_axi_ar_prot[s]),
            .axi_ar_qos_o    (axi2ahb2axi_s_axi_ar_qos[s]),
            .axi_ar_region_o (axi2ahb2axi_s_axi_ar_region[s]),
            .axi_ar_user_o   (axi2ahb2axi_s_axi_ar_user[s]),
            .axi_ar_valid_o  (axi2ahb2axi_s_axi_ar_valid[s]),
            .axi_ar_ready_i  (axi2ahb2axi_s_axi_ar_ready[s]),

            .axi_r_id_i      (axi2ahb2axi_s_axi_r_id[s]),
            .axi_r_data_i    (axi2ahb2axi_s_axi_r_data[s]),
            .axi_r_resp_i    (axi2ahb2axi_s_axi_r_resp[s]),
            .axi_r_last_i    (axi2ahb2axi_s_axi_r_last[s]),
            .axi_r_user_i    (axi2ahb2axi_s_axi_r_user[s]),
            .axi_r_valid_i   (axi2ahb2axi_s_axi_r_valid[s]),
            .axi_r_ready_o   (axi2ahb2axi_s_axi_r_ready[s])
        );
end

// ------------------------------------------------------------------------------------------------ //
// -- AXI Protocol Checkers ----------------------------------------------------------------------- //
// ------------------------------------------------------------------------------------------------ //
`ifndef AXI4PC_OFF
// DUT Master
for (genvar s=0; s<TB_SLAVES; s++) begin: for_s_pc
    Axi4PC
    #(
        .ADDR_WIDTH             (AW),
        .DATA_WIDTH             (DW),
        .WID_WIDTH              (STIDW),
        .RID_WIDTH              (STIDW),
        .AWUSER_WIDTH           (USERW),
        .WUSER_WIDTH            (USERW),
        .BUSER_WIDTH            (USERW),
        .ARUSER_WIDTH           (USERW),
        .RUSER_WIDTH            (USERW),
        .MAXRBURSTS             (AXIPC_MAXRBURSTS),
        .MAXWBURSTS             (AXIPC_MAXWBURSTS),
        .MAXWAITS               (AXIPC_MAXWAITS),
        .RecommendOn            (AXIPC_RecommendOn),
        .RecMaxWaitOn           (AXIPC_RecMaxWaitOn),
        .PROTOCOL               (AXIPC_PROTOCOL),
        .EXMON_WIDTH            (AXIPC_EXMON_WIDTH)
    )
    axi_pc_s
    (
        .ACLK                   (clk                ),
        .ARESETn                (rst_n              ),
        
        .AWID                   (tb_s_axi_aw_id[s]),
        .AWADDR                 (tb_s_axi_aw_addr[s]),
        .AWLEN                  (tb_s_axi_aw_len[s]),
        .AWSIZE                 (tb_s_axi_aw_size[s]),
        .AWBURST                (tb_s_axi_aw_burst[s]),
        .AWLOCK                 (tb_s_axi_aw_lock[s][0]),
        .AWCACHE                (tb_s_axi_aw_cache[s]),
        .AWPROT                 (tb_s_axi_aw_prot[s]),
        .AWQOS                  (tb_s_axi_aw_qos[s]),
        .AWREGION               (tb_s_axi_aw_region[s]),
        .AWUSER                 (tb_s_axi_aw_user[s]),
        .AWVALID                (tb_s_axi_aw_valid[s]),
        .AWREADY                (tb_s_axi_aw_ready[s]),
        
        .WLAST                  (tb_s_axi_w_last[s]),
        .WDATA                  (tb_s_axi_w_data[s]),
        .WSTRB                  (tb_s_axi_w_strb[s]),
        .WUSER                  (tb_s_axi_w_user[s]),
        .WVALID                 (tb_s_axi_w_valid[s]),
        .WREADY                 (tb_s_axi_w_ready[s]),
        
        .BID                    (tb_s_axi_b_id[s]),
        .BRESP                  (tb_s_axi_b_resp[s]),
        .BUSER                  (tb_s_axi_b_user[s]),
        .BVALID                 (tb_s_axi_b_valid[s]),
        .BREADY                 (tb_s_axi_b_ready[s]),
        
        .ARID                   (tb_s_axi_ar_id[s]),
        .ARADDR                 (tb_s_axi_ar_addr[s]),
        .ARLEN                  (tb_s_axi_ar_len[s]),
        .ARSIZE                 (tb_s_axi_ar_size[s]),
        .ARBURST                (tb_s_axi_ar_burst[s]),
        .ARLOCK                 (tb_s_axi_ar_lock[s][0]),
        .ARCACHE                (tb_s_axi_ar_cache[s]),
        .ARPROT                 (tb_s_axi_ar_prot[s]),
        .ARQOS                  (tb_s_axi_ar_qos[s]),
        .ARREGION               (tb_s_axi_ar_region[s]),
        .ARUSER                 (tb_s_axi_ar_user[s]),
        .ARVALID                (tb_s_axi_ar_valid[s]),
        .ARREADY                (tb_s_axi_ar_ready[s]),
        
        .RID                    (tb_s_axi_r_id[s]),
        .RLAST                  (tb_s_axi_r_last[s]),
        .RDATA                  (tb_s_axi_r_data[s]),
        .RRESP                  (tb_s_axi_r_resp[s]),
        .RUSER                  (tb_s_axi_r_user[s]),
        .RVALID                 (tb_s_axi_r_valid[s]),
        .RREADY                 (tb_s_axi_r_ready[s]),
        
        
        .CACTIVE                (1'b1               ),
        .CSYSREQ                (1'b0               ),
        .CSYSACK                (1'b0               )
    );
end

// DUT Slave
for (genvar m=0; m<TB_MASTERS; m++) begin: for_m_pc
    Axi4PC
    #(
        .ADDR_WIDTH             (AW),
        .DATA_WIDTH             (DW),
        .WID_WIDTH              (MTIDW),
        .RID_WIDTH              (MTIDW),
        .AWUSER_WIDTH           (USERW),
        .WUSER_WIDTH            (USERW),
        .BUSER_WIDTH            (USERW),
        .ARUSER_WIDTH           (USERW),
        .RUSER_WIDTH            (USERW),
        .MAXRBURSTS             (AXIPC_MAXRBURSTS),
        .MAXWBURSTS             (AXIPC_MAXWBURSTS),
        .MAXWAITS               (AXIPC_MAXWAITS),
        .RecommendOn            (AXIPC_RecommendOn),
        .RecMaxWaitOn           (AXIPC_RecMaxWaitOn),
        .PROTOCOL               (AXIPC_PROTOCOL),
        .EXMON_WIDTH            (AXIPC_EXMON_WIDTH)
    )
    axi_pc_m
    (
        .ACLK                   (clk                ),
        .ARESETn                (rst_n              ),
        
        .AWID                   (tb_m_axi_aw_id[m]),
        .AWADDR                 (tb_m_axi_aw_addr[m]),
        .AWLEN                  (tb_m_axi_aw_len[m]),
        .AWSIZE                 (tb_m_axi_aw_size[m]),
        .AWBURST                (tb_m_axi_aw_burst[m]),
        .AWLOCK                 (tb_m_axi_aw_lock[m][0]),
        .AWCACHE                (tb_m_axi_aw_cache[m]),
        .AWPROT                 (tb_m_axi_aw_prot[m]),
        .AWQOS                  (tb_m_axi_aw_qos[m]),
        .AWREGION               (tb_m_axi_aw_region[m]),
        .AWUSER                 (tb_m_axi_aw_user[m]),
        .AWVALID                (tb_m_axi_aw_valid[m]),
        .AWREADY                (tb_m_axi_aw_ready[m]),
        
        .WLAST                  (tb_m_axi_w_last[m]),
        .WDATA                  (tb_m_axi_w_data[m]),
        .WSTRB                  (tb_m_axi_w_strb[m]),
        .WUSER                  (tb_m_axi_w_user[m]),
        .WVALID                 (tb_m_axi_w_valid[m]),
        .WREADY                 (tb_m_axi_w_ready[m]),
        
        .BID                    (tb_m_axi_b_id[m]),
        .BRESP                  (tb_m_axi_b_resp[m]),
        .BUSER                  (tb_m_axi_b_user[m]),
        .BVALID                 (tb_m_axi_b_valid[m]),
        .BREADY                 (tb_m_axi_b_ready[m]),
        
        .ARID                   (tb_m_axi_ar_id[m]),
        .ARADDR                 (tb_m_axi_ar_addr[m]),
        .ARLEN                  (tb_m_axi_ar_len[m]),
        .ARSIZE                 (tb_m_axi_ar_size[m]),
        .ARBURST                (tb_m_axi_ar_burst[m]),
        .ARLOCK                 (tb_m_axi_ar_lock[m][0]),
        .ARCACHE                (tb_m_axi_ar_cache[m]),
        .ARPROT                 (tb_m_axi_ar_prot[m]),
        .ARQOS                  (tb_m_axi_ar_qos[m]),
        .ARREGION               (tb_m_axi_ar_region[m]),
        .ARUSER                 (tb_m_axi_ar_user[m]),
        .ARVALID                (tb_m_axi_ar_valid[m]),
        .ARREADY                (tb_m_axi_ar_ready[m]),
        
        .RID                    (tb_m_axi_r_id[m]),
        .RLAST                  (tb_m_axi_r_last[m]),
        .RDATA                  (tb_m_axi_r_data[m]),
        .RRESP                  (tb_m_axi_r_resp[m]),
        .RUSER                  (tb_m_axi_r_user[m]),
        .RVALID                 (tb_m_axi_r_valid[m]),
        .RREADY                 (tb_m_axi_r_ready[m]),
        
        
        .CACTIVE                (1'b1               ),
        .CSYSREQ                (1'b0               ),
        .CSYSACK                (1'b0               )
    );
end
`endif // AXI4PC_OFF


/*------------------------------------------------------------------------------
--  AXI2AXI READS LOGGER
------------------------------------------------------------------------------*/

    axi2axi_reads_logger #(
            .MTIDW(MTIDW),
            .STIDW(STIDW),
            .AW(AW),
            .DW(DW),
            .USERW(USERW),
            .TB_SLAVES(TB_SLAVES),
            .ADDR_BASE     (ADDR_BASE),
            .ADDR_MAX (ADDR_MAX)
        ) inst_axi2axi_reads_logger (
            .clk             (clk),
            .rst_n           (rst_n),
            // Master Side
            .axi_ar_id_m     (tb_m_axi_ar_id),
            .axi_ar_addr_m   (tb_m_axi_ar_addr),
            .axi_ar_len_m    (tb_m_axi_ar_len),
            .axi_ar_size_m   (tb_m_axi_ar_size),
            .axi_ar_burst_m  (tb_m_axi_ar_burst),
            .axi_ar_lock_m   (tb_m_axi_ar_lock),
            .axi_ar_cache_m  (tb_m_axi_ar_cache),
            .axi_ar_prot_m   (tb_m_axi_ar_prot),
            .axi_ar_qos_m    (tb_m_axi_ar_qos),
            .axi_ar_region_m (tb_m_axi_ar_region),
            .axi_ar_user_m   (tb_m_axi_ar_user),
            .axi_ar_valid_m  (tb_m_axi_ar_valid),
            .axi_ar_ready_m  (tb_m_axi_ar_ready),
            .axi_r_id_m      (tb_m_axi_r_id),
            .axi_r_data_m    (tb_m_axi_r_data),
            .axi_r_resp_m    (tb_m_axi_r_resp),
            .axi_r_last_m    (tb_m_axi_r_last),
            .axi_r_user_m    (tb_m_axi_r_user),
            .axi_r_valid_m   (tb_m_axi_r_valid),
            .axi_r_ready_m   (tb_m_axi_r_ready),
            // Slave Side
            .axi_ar_id_s     (axi2ahb2axi_s_axi_ar_id),
            .axi_ar_addr_s   (axi2ahb2axi_s_axi_ar_addr),
            .axi_ar_len_s    (axi2ahb2axi_s_axi_ar_len),
            .axi_ar_size_s   (axi2ahb2axi_s_axi_ar_size),
            .axi_ar_burst_s  (axi2ahb2axi_s_axi_ar_burst),
            .axi_ar_lock_s   (axi2ahb2axi_s_axi_ar_lock),
            .axi_ar_cache_s  (axi2ahb2axi_s_axi_ar_cache),
            .axi_ar_prot_s   (axi2ahb2axi_s_axi_ar_prot),
            .axi_ar_qos_s    (axi2ahb2axi_s_axi_ar_qos),
            .axi_ar_region_s (axi2ahb2axi_s_axi_ar_region),
            .axi_ar_user_s   (axi2ahb2axi_s_axi_ar_user),
            .axi_ar_valid_s  (axi2ahb2axi_s_axi_ar_valid),
            .axi_ar_ready_s  (axi2ahb2axi_s_axi_ar_ready),
            .axi_r_id_s      (axi2ahb2axi_s_axi_r_id),
            .axi_r_data_s    (axi2ahb2axi_s_axi_r_data),
            .axi_r_resp_s    (axi2ahb2axi_s_axi_r_resp),
            .axi_r_last_s    (axi2ahb2axi_s_axi_r_last),
            .axi_r_user_s    (axi2ahb2axi_s_axi_r_user),
            .axi_r_valid_s   (axi2ahb2axi_s_axi_r_valid),
            .axi_r_ready_s   (axi2ahb2axi_s_axi_r_ready),
            .both_mailbox_empty  (both_mailbox_empty)
        );
















endmodule

`default_nettype wire
