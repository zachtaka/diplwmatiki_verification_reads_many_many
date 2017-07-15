// `include "axi2ahb/axi2ahb.sv"
// `include "bridge_rtl/ahb_to_axi.sv"


module axi2ahb_ahb2axi
	#(
	parameter int TIDW = 1,
	parameter int AW  = 32,
	parameter int DW  = 64,
	parameter int USERW  = 1

	)(
	input HCLK,    // Clock
	input HRESETn,  // Asynchronous reset active low
	// -- AXI Slave interface -- //
		// AW (Write Address) channel (NI -> Target)
		input  logic[TIDW-1:0]                     axi_aw_id_i,    // AWID
		input  logic[AW-1:0]                        axi_aw_addr_i,  // AWADDR
		input  logic[7:0]                               axi_aw_len_i,   // AWLEN
		input  logic[2:0]                               axi_aw_size_i,  // AWSIZE
		input  logic[1:0]                               axi_aw_burst_i, // AWBURST
		input  logic[1:0]                               axi_aw_lock_i,  // AWLOCK / 2-bit always for AMBA==3 compliance, but MSB is always tied to zero (no locked support) 
		input  logic[3:0]                               axi_aw_cache_i, // AWCACHE
		input  logic[2:0]                               axi_aw_prot_i,  // AWPROT
		input  logic[3:0]                               axi_aw_qos_i,   // AWQOS
		input  logic[3:0]                               axi_aw_region_i,// AWREGION
		input  logic[USERW-1:0]                 axi_aw_user_i,  // AWUSER
		input  logic                                     axi_aw_valid_i, // AWVALID
		output logic                                    axi_aw_ready_o, // AWREADY
		// W (Write Data) channel (NI -> Target)
		input  logic[TIDW-1:0]                    axi_w_id_i,     // WID / driven only under AMBA==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
		input  logic[DW-1:0]                       axi_w_data_i,   // WDATA
		input  logic[DW/8-1:0]                    axi_w_strb_i,   // WSTRB
		input  logic                                    axi_w_last_i,   // WLAST
		input  logic[USERW-1:0]                axi_w_user_i,   // WUSER / tied to zero
		input  logic                                    axi_w_valid_i,  // WVALID
		output logic                                   axi_w_ready_o,  // WREADY
		// B (Write Response) channel (Target -> NI)
		output logic[TIDW-1:0]                  axi_b_id_o,     // BID
		output logic[1:0]                            axi_b_resp_o,   // BRESP
		output logic[USERW-1:0]              axi_b_user_o,   // BUSER
		output logic                                  axi_b_valid_o,  // BVALID
		input  logic                                   axi_b_ready_i,  // BREADY
		// AR (Read Address) channel (NI -> Target)
		input  logic[TIDW-1:0]                  axi_ar_id_i,    // ARID
		input  logic[AW-1:0]                     axi_ar_addr_i,  // ARADDR
		input  logic[7:0]                            axi_ar_len_i,   // ARLEN
		input  logic[2:0]                            axi_ar_size_i,  // ARSIZE
		input  logic[1:0]                            axi_ar_burst_i, // ARBURST
		input  logic[1:0]                            axi_ar_lock_i,  // ARLOCK / 2-bit always for AMBA==3 compliance, but MSB is always tied to zero (no locked support)
		input  logic[3:0]                            axi_ar_cache_i, // ARCACHE
		input  logic[2:0]                            axi_ar_prot_i,  // ARPROT
		input  logic[3:0]                            axi_ar_qos_i,   // ARQOS
		input  logic[3:0]                            axi_ar_region_i,// ARREGION
		input  logic[USERW-1:0]              axi_ar_user_i,  // ARUSER
		input  logic                                  axi_ar_valid_i, // ARVALID
		output logic                                 axi_ar_ready_o, // ARREADY
		// R (Read Data) channel (Target -> NI)
		output logic[TIDW-1:0]                  axi_r_id_o,     // RID
		output logic[DW-1:0]                     axi_r_data_o,   // RDATA
		output logic[1:0]                            axi_r_resp_o,   // RRESP
		output logic                                  axi_r_last_o,   // RLAST
		output logic[USERW-1:0]              axi_r_user_o,   // RUSER
		output logic                                  axi_r_valid_o,  // RVALID
		input  logic                                   axi_r_ready_i,   // RREADY
	// AXI master interface
		// AW (Write Address) 
		output logic[TIDW-1:0]           axi_aw_id_o,    // AWID
		output logic[AW-1:0]              axi_aw_addr_o,  // AWADDR
		output logic[7:0]                     axi_aw_len_o,   // AWLEN
		output logic[2:0]                     axi_aw_size_o,  // AWSIZE
		output logic[1:0]                     axi_aw_burst_o, // AWBURST
		output logic[1:0]                     axi_aw_lock_o,  // AWLOCK / 2-bit always for AMBA==3 compliance, but MSB is always tied to zero (no locked support) 
		output logic[3:0]                     axi_aw_cache_o, // AWCACHE
		output logic[2:0]                     axi_aw_prot_o,  // AWPROT
		output logic[3:0]                     axi_aw_qos_o,   // AWQOS
		output logic[3:0]                     axi_aw_region_o,// AWREGION
		output logic[USERW-1:0]        axi_aw_user_o,  // AWUSER
		output logic                            axi_aw_valid_o, // AWVALID
		input logic                              axi_aw_ready_i, // AWREADY
		// W (Write Data) channel
		output  logic[TIDW-1:0]                    axi_w_id_o,     // WID / driven only under AMBA==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
		output  logic[DW-1:0]                       axi_w_data_o,   // WDATA
		output  logic[DW/8-1:0]                    axi_w_strb_o,   // WSTRB
		output  logic                                    axi_w_last_o,   // WLAST
		output  logic[USERW-1:0]                axi_w_user_o,   // WUSER / tied to zero
		output  logic                                    axi_w_valid_o,  // WVALID
		input logic                                       axi_w_ready_i,  // WREADY
		// B (Write Response) channel 
		input logic[TIDW-1:0]                     axi_b_id_i,     // BID
		input logic[1:0]                               axi_b_resp_i,   // BRESP
		input logic[USERW-1:0]                 axi_b_user_i,   // BUSER
		input logic                                     axi_b_valid_i,  // BVALID
		output logic                                   axi_b_ready_o,  // BREADY
		// AR (Read Address) 
		output logic[TIDW-1:0]                     axi_ar_id_o,    // ARID
		output logic[AW-1:0]                        axi_ar_addr_o,  // ARADDR
		output logic[7:0]                               axi_ar_len_o,   // ARLEN
		output logic[2:0]                               axi_ar_size_o,  // ARSIZE
		output logic[1:0]                               axi_ar_burst_o, // ARBURST
		output logic[1:0]                               axi_ar_lock_o,  // ARLOCK / 2-bit always for AMBA==3 compliance, but MSB is always tied to zero (no locked support)
		output logic[3:0]                               axi_ar_cache_o, // ARCACHE
		output logic[2:0]                               axi_ar_prot_o,  // ARPROT
		output logic[3:0]                               axi_ar_qos_o,   // ARQOS
		output logic[3:0]                               axi_ar_region_o,// ARREGION
		output logic[USERW-1:0]                 axi_ar_user_o,  // ARUSER
		output logic                                     axi_ar_valid_o, // ARVALID
		input logic                                       axi_ar_ready_i, // ARREADY
		// R (Read Data) 
		input logic[TIDW-1:0]                      axi_r_id_i,     // RID
		input logic[DW-1:0]                         axi_r_data_i,   // RDATA
		input logic[1:0]                                axi_r_resp_i,   // RRESP
		input logic                                      axi_r_last_i,   // RLAST
		input logic[USERW-1:0]                  axi_r_user_i,   // RUSER
		input logic                                      axi_r_valid_i,  // RVALID
		output  logic                                   axi_r_ready_o   // RREADY
	
	
);
parameter AHB_DATA_WIDTH=64;
parameter AHB_ADDRESS_WIDTH=32;

parameter MAX_PENDING_WRITES = 2; // 2^FIFO_ADDRESS_BITS mou dinei ton arithmo thesewn kathe FIFO
parameter MAX_PENDING_READ_BEATS = 2;
parameter TID_QUEUE_SLOTS = MAX_PENDING_WRITES+1; // 2^4=16 theseis gia tin TID fifo
parameter TID_QUEUE_DATA_BITS = TIDW;
parameter B_QUEUE_SLOTS = MAX_PENDING_WRITES+1;
parameter B_QUEUE_DATA_BITS = 2+TIDW; // osa kai to bresp+id
parameter R_QUEUE_SLOTS = MAX_PENDING_READ_BEATS;
parameter R_QUEUE_DATA_BITS = DW+2+1+TIDW; // = r_data + r_resp + r_last + id
parameter INTERFACE_FIFO_DEPTH = 4;
// -- AHB interface -- //
// Inputs
logic HREADY;
logic HRESP;
logic [AHB_DATA_WIDTH-1:0] HRDATA;
// Outputs
logic [AHB_ADDRESS_WIDTH-1:0] HADDR;
logic [AHB_DATA_WIDTH-1:0] HWDATA;
logic HWRITE;
logic [2:0] HSIZE;
logic [2:0] HBURST;
logic [1:0] HTRANS;



	axi2ahb_wrapper #(
			.INTERFACE_FIFO_DEPTH(INTERFACE_FIFO_DEPTH),
			.AHB_DATA_WIDTH(AHB_DATA_WIDTH),
			.AHB_ADDRESS_WIDTH(AHB_ADDRESS_WIDTH),
			.TIDW(TIDW),
			.AW(AW),
			.DW(DW),
			.USERW(USERW),
			.MAX_PENDING_WRITES(MAX_PENDING_WRITES),
			.MAX_PENDING_READ_BEATS(MAX_PENDING_READ_BEATS),
			.TID_QUEUE_SLOTS(TID_QUEUE_SLOTS),
			.TID_QUEUE_DATA_BITS(TID_QUEUE_DATA_BITS),
			.B_QUEUE_SLOTS(B_QUEUE_SLOTS),
			.B_QUEUE_DATA_BITS(B_QUEUE_DATA_BITS),
			.R_QUEUE_SLOTS(R_QUEUE_SLOTS),
			.R_QUEUE_DATA_BITS(R_QUEUE_DATA_BITS)
		) axi2ahb (
			.axi_aw_id_i     (axi_aw_id_i),
			.axi_aw_addr_i   (axi_aw_addr_i),
			.axi_aw_len_i    (axi_aw_len_i),
			.axi_aw_size_i   (axi_aw_size_i),
			.axi_aw_burst_i  (axi_aw_burst_i),
			.axi_aw_lock_i   (axi_aw_lock_i),
			.axi_aw_cache_i  (axi_aw_cache_i),
			.axi_aw_prot_i   (axi_aw_prot_i),
			.axi_aw_qos_i    (axi_aw_qos_i),
			.axi_aw_region_i (axi_aw_region_i),
			.axi_aw_user_i   (axi_aw_user_i),
			.axi_aw_valid_i  (axi_aw_valid_i),
			.axi_aw_ready_o  (axi_aw_ready_o),
			.axi_w_id_i      (axi_w_id_i),
			.axi_w_data_i    (axi_w_data_i),
			.axi_w_strb_i    (axi_w_strb_i),
			.axi_w_last_i    (axi_w_last_i),
			.axi_w_user_i    (axi_w_user_i),
			.axi_w_valid_i   (axi_w_valid_i),
			.axi_w_ready_o   (axi_w_ready_o),
			.axi_b_id_o      (axi_b_id_o),
			.axi_b_resp_o    (axi_b_resp_o),
			.axi_b_user_o    (axi_b_user_o),
			.axi_b_valid_o   (axi_b_valid_o),
			.axi_b_ready_i   (axi_b_ready_i),
			.axi_ar_id_i     (axi_ar_id_i),
			.axi_ar_addr_i   (axi_ar_addr_i),
			.axi_ar_len_i    (axi_ar_len_i),
			.axi_ar_size_i   (axi_ar_size_i),
			.axi_ar_burst_i  (axi_ar_burst_i),
			.axi_ar_lock_i   (axi_ar_lock_i),
			.axi_ar_cache_i  (axi_ar_cache_i),
			.axi_ar_prot_i   (axi_ar_prot_i),
			.axi_ar_qos_i    (axi_ar_qos_i),
			.axi_ar_region_i (axi_ar_region_i),
			.axi_ar_user_i   (axi_ar_user_i),
			.axi_ar_valid_i  (axi_ar_valid_i),
			.axi_ar_ready_o  (axi_ar_ready_o),
			.axi_r_id_o      (axi_r_id_o),
			.axi_r_data_o    (axi_r_data_o),
			.axi_r_resp_o    (axi_r_resp_o),
			.axi_r_last_o    (axi_r_last_o),
			.axi_r_user_o    (axi_r_user_o),
			.axi_r_valid_o   (axi_r_valid_o),
			.axi_r_ready_i   (axi_r_ready_i),
			.HREADY          (HREADY),
			.HRESP           (HRESP),
			.HRDATA          (HRDATA),
			.HADDR           (HADDR),
			.HWDATA          (HWDATA),
			.HWRITE          (HWRITE),
			.HSIZE           (HSIZE),
			.HBURST          (HBURST),
			.HTRANS          (HTRANS),
			.HCLK            (HCLK),
			.HRESETn         (HRESETn)
		);

	ahb2axi_wrapper #(
			.INTERFACE_FIFO_DEPTH(INTERFACE_FIFO_DEPTH),
			.AHB_DATA_WIDTH(AHB_DATA_WIDTH),
			.AHB_ADDRESS_WIDTH(AHB_ADDRESS_WIDTH),
			.TIDW(TIDW),
			.AW(AW),
			.DW(DW),
			.USERW(USERW)
		) ahb2axi (
			.HCLK            (HCLK),
			.HADDR           (HADDR),
			.HWDATA          (HWDATA),
			.HWRITE          (HWRITE),
			.HSIZE           (HSIZE),
			.HBURST          (HBURST),
			.HTRANS          (HTRANS),
			.HRESETn         (HRESETn),
			.HREADY          (HREADY),
			.HRDATA          (HRDATA),
			.HRESP           (HRESP),
			.HEXOKAY         (HEXOKAY),
			.axi_aw_id_o     (axi_aw_id_o),
			.axi_aw_addr_o   (axi_aw_addr_o),
			.axi_aw_len_o    (axi_aw_len_o),
			.axi_aw_size_o   (axi_aw_size_o),
			.axi_aw_burst_o  (axi_aw_burst_o),
			.axi_aw_lock_o   (axi_aw_lock_o),
			.axi_aw_cache_o  (axi_aw_cache_o),
			.axi_aw_prot_o   (axi_aw_prot_o),
			.axi_aw_qos_o    (axi_aw_qos_o),
			.axi_aw_region_o (axi_aw_region_o),
			.axi_aw_user_o   (axi_aw_user_o),
			.axi_aw_valid_o  (axi_aw_valid_o),
			.axi_aw_ready_i  (axi_aw_ready_i),
			.axi_w_id_o      (axi_w_id_o),
			.axi_w_data_o    (axi_w_data_o),
			.axi_w_strb_o    (axi_w_strb_o),
			.axi_w_last_o    (axi_w_last_o),
			.axi_w_user_o    (axi_w_user_o),
			.axi_w_valid_o   (axi_w_valid_o),
			.axi_w_ready_i   (axi_w_ready_i),
			.axi_b_id_i      (axi_b_id_i),
			.axi_b_resp_i    (axi_b_resp_i),
			.axi_b_user_i    (axi_b_user_i),
			.axi_b_valid_i   (axi_b_valid_i),
			.axi_b_ready_o   (axi_b_ready_o),
			.axi_ar_id_o     (axi_ar_id_o),
			.axi_ar_addr_o   (axi_ar_addr_o),
			.axi_ar_len_o    (axi_ar_len_o),
			.axi_ar_size_o   (axi_ar_size_o),
			.axi_ar_burst_o  (axi_ar_burst_o),
			.axi_ar_lock_o   (axi_ar_lock_o),
			.axi_ar_cache_o  (axi_ar_cache_o),
			.axi_ar_prot_o   (axi_ar_prot_o),
			.axi_ar_qos_o    (axi_ar_qos_o),
			.axi_ar_region_o (axi_ar_region_o),
			.axi_ar_user_o   (axi_ar_user_o),
			.axi_ar_valid_o  (axi_ar_valid_o),
			.axi_ar_ready_i  (axi_ar_ready_i),
			.axi_r_id_i      (axi_r_id_i),
			.axi_r_data_i    (axi_r_data_i),
			.axi_r_resp_i    (axi_r_resp_i),
			.axi_r_last_i    (axi_r_last_i),
			.axi_r_user_i    (axi_r_user_i),
			.axi_r_valid_i   (axi_r_valid_i),
			.axi_r_ready_o   (axi_r_ready_o)
		);






// /*------------------------------------------------------------------------------
// --  TESTBENCH LOGGER ~ REMOVE WHEN SYNTHESIS
// ------------------------------------------------------------------------------*/
	// axi2axi_logger #(
	// 		.AHB_DATA_WIDTH(AHB_DATA_WIDTH),
	// 		.AHB_ADDRESS_WIDTH(AHB_ADDRESS_WIDTH),
	// 		.TIDW(TIDW),
	// 		.AW(AW),
	// 		.DW(DW),
	// 		.USERW(USERW)
	// 	) inst_axi2axi_logger (
	// 		.clk             (HCLK),
	// 		.rst_n           (HRESETn),
	// 		.axi_ar_id_m     (axi_ar_id_i),
	// 		.axi_ar_addr_m   (axi_ar_addr_i),
	// 		.axi_ar_len_m    (axi_ar_len_i),
	// 		.axi_ar_size_m   (axi_ar_size_i),
	// 		.axi_ar_burst_m  (axi_ar_burst_i),
	// 		.axi_ar_lock_m   (axi_ar_lock_i),
	// 		.axi_ar_cache_m  (axi_ar_cache_i),
	// 		.axi_ar_prot_m   (axi_ar_prot_i),
	// 		.axi_ar_qos_m    (axi_ar_qos_i),
	// 		.axi_ar_region_m (axi_ar_region_i),
	// 		.axi_ar_user_m   (axi_ar_user_i),
	// 		.axi_ar_valid_m  (axi_ar_valid_i),
	// 		.axi_ar_ready_m  (axi_ar_ready_o),
	// 		.axi_r_id_m      (axi_r_id_o),
	// 		.axi_r_data_m    (axi_r_data_o),
	// 		.axi_r_resp_m    (axi_r_resp_o),
	// 		.axi_r_last_m    (axi_r_last_o),
	// 		.axi_r_user_m    (axi_r_user_o),
	// 		.axi_r_valid_m   (axi_r_valid_o),
	// 		.axi_r_ready_m   (axi_r_ready_i),
	// 		.axi_ar_id_s     (axi_ar_id_o),
	// 		.axi_ar_addr_s   (axi_ar_addr_o),
	// 		.axi_ar_len_s    (axi_ar_len_o),
	// 		.axi_ar_size_s   (axi_ar_size_o),
	// 		.axi_ar_burst_s  (axi_ar_burst_o),
	// 		.axi_ar_lock_s   (axi_ar_lock_o),
	// 		.axi_ar_cache_s  (axi_ar_cache_o),
	// 		.axi_ar_prot_s   (axi_ar_prot_o),
	// 		.axi_ar_qos_s    (axi_ar_qos_o),
	// 		.axi_ar_region_s (axi_ar_region_o),
	// 		.axi_ar_user_s   (axi_ar_user_o),
	// 		.axi_ar_valid_s  (axi_ar_valid_o),
	// 		.axi_ar_ready_s  (axi_ar_ready_i),
	// 		.axi_r_id_s      (axi_r_id_i),
	// 		.axi_r_data_s    (axi_r_data_i),
	// 		.axi_r_resp_s    (axi_r_resp_i),
	// 		.axi_r_last_s    (axi_r_last_i),
	// 		.axi_r_user_s    (axi_r_user_i),
	// 		.axi_r_valid_s   (axi_r_valid_i),
	// 		.axi_r_ready_s   (axi_r_ready_o)
	// 	);




endmodule