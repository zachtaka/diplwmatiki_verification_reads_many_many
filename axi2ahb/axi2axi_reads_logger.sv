
module axi2axi_reads_logger  #(
	parameter AHB_DATA_WIDTH=64,
	parameter AHB_ADDRESS_WIDTH=32,
	parameter int TIDW = 1,
	parameter int AW  = 32,
	parameter int DW  = 64,
	parameter int USERW  = 1,
	parameter int TB_SLAVES = 1
	)(
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low

	// Master side axi2axi
		// AR (Read Address) channel (NI -> Target)
		input  logic[TIDW-1:0]                  axi_ar_id_m,    // ARID
		input  logic[AW-1:0]                     axi_ar_addr_m,  // ARADDR
		input  logic[7:0]                            axi_ar_len_m,   // ARLEN
		input  logic[2:0]                            axi_ar_size_m,  // ARSIZE
		input  logic[1:0]                            axi_ar_burst_m, // ARBURST
		input  logic[1:0]                            axi_ar_lock_m,  // ARLOCK / 2-bit always for AMBA==3 compliance, but MSB is always tied to zero (no locked support)
		input  logic[3:0]                            axi_ar_cache_m, // ARCACHE
		input  logic[2:0]                            axi_ar_prot_m,  // ARPROT
		input  logic[3:0]                            axi_ar_qos_m,   // ARQOS
		input  logic[3:0]                            axi_ar_region_m,// ARREGION
		input  logic[USERW-1:0]              axi_ar_user_m,  // ARUSER
		input  logic                                  axi_ar_valid_m, // ARVALID
		input logic                                 axi_ar_ready_m, // ARREADY
		// R (Read Data) channel (Target -> NI)
		input logic[TIDW-1:0]                  axi_r_id_m,     // RID
		input logic[DW-1:0]                     axi_r_data_m,   // RDATA
		input logic[1:0]                            axi_r_resp_m,   // RRESP
		input logic                                  axi_r_last_m,   // RLAST
		input logic[USERW-1:0]              axi_r_user_m,   // RUSER
		input logic                                  axi_r_valid_m,  // RVALID
		input  logic                                   axi_r_ready_m,   // RREADY

	// Slave side axi2axi
		// AR (Read Address) 
		input logic [TB_SLAVES-1:0] [TIDW-1:0]                     axi_ar_id_s,    // ARID
		input logic [TB_SLAVES-1:0] [AW-1:0]                        axi_ar_addr_s,  // ARADDR
		input logic [TB_SLAVES-1:0] [7:0]                               axi_ar_len_s,   // ARLEN
		input logic [TB_SLAVES-1:0] [2:0]                               axi_ar_size_s,  // ARSIZE
		input logic [TB_SLAVES-1:0] [1:0]                               axi_ar_burst_s, // ARBURST
		input logic [TB_SLAVES-1:0] [1:0]                               axi_ar_lock_s,  // ARLOCK / 2-bit always for AMBA==3 compliance, but MSB is always tied to zero (no locked support)
		input logic [TB_SLAVES-1:0] [3:0]                               axi_ar_cache_s, // ARCACHE
		input logic [TB_SLAVES-1:0] [2:0]                               axi_ar_prot_s,  // ARPROT
		input logic [TB_SLAVES-1:0] [3:0]                               axi_ar_qos_s,   // ARQOS
		input logic [TB_SLAVES-1:0] [3:0]                               axi_ar_region_s,// ARREGION
		input logic [TB_SLAVES-1:0] [USERW-1:0]                 axi_ar_user_s,  // ARUSER
		input logic [TB_SLAVES-1:0]                                      axi_ar_valid_s, // ARVALID
		input logic [TB_SLAVES-1:0]                                        axi_ar_ready_s, // ARREADY
		// R (Read Data) 
		input logic [TB_SLAVES-1:0] [TIDW-1:0]                      axi_r_id_s,     // RID
		input logic [TB_SLAVES-1:0] [DW-1:0]                         axi_r_data_s,   // RDATA
		input logic [TB_SLAVES-1:0] [1:0]                                axi_r_resp_s,   // RRESP
		input logic [TB_SLAVES-1:0]                                       axi_r_last_s,   // RLAST
		input logic [TB_SLAVES-1:0] [USERW-1:0]                  axi_r_user_s,   // RUSER
		input logic [TB_SLAVES-1:0]                                       axi_r_valid_s,  // RVALID
		input logic [TB_SLAVES-1:0]                                     axi_r_ready_s   // RREADY
);





endmodule