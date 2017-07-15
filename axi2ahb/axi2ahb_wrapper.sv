module axi2ahb_wrapper#(
	parameter INTERFACE_FIFO_DEPTH = 2,
	parameter AHB_DATA_WIDTH=64,
	parameter AHB_ADDRESS_WIDTH=32,
	parameter int TIDW = 1,
	parameter int AW  = AHB_ADDRESS_WIDTH,
	parameter int DW  = AHB_DATA_WIDTH,
	parameter int USERW  = 1,
	parameter MAX_PENDING_WRITES = 2, // 2^FIFO_ADDRESS_BITS mou dinei ton arithmo thesewn kathe FIFO
	parameter MAX_PENDING_READ_BEATS = 2,
	parameter TID_QUEUE_SLOTS = MAX_PENDING_WRITES, // 2^4=16 theseis gia tin TID fifo
	parameter TID_QUEUE_DATA_BITS = TIDW,
	parameter B_QUEUE_SLOTS = MAX_PENDING_WRITES,
	parameter B_QUEUE_DATA_BITS = 2+TIDW, // osa kai to bresp+id
	parameter R_QUEUE_SLOTS = MAX_PENDING_READ_BEATS,
	parameter R_QUEUE_DATA_BITS = DW+2+1+TIDW // = r_data + r_resp + r_last + id
	) (
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

	// -- AHB Master interface -- //
		// Inputs
		input logic HREADY,
		input logic HRESP,
		input logic [AHB_DATA_WIDTH-1:0] HRDATA,
		// Outputs
		output logic [AHB_ADDRESS_WIDTH-1:0] HADDR,
		output logic [AHB_DATA_WIDTH-1:0] HWDATA,
		output logic HWRITE,
		output logic [2:0] HSIZE,
		output logic [2:0] HBURST,
		output logic [1:0] HTRANS,
		input logic HCLK,
		input logic HRESETn

		);

logic              [TIDW-1:0] axi_aw_id;
logic                [AW-1:0] axi_aw_addr;
logic                   [7:0] axi_aw_len;
logic                   [2:0] axi_aw_size;
logic                   [1:0] axi_aw_burst;
logic                   [1:0] axi_aw_lock;
logic                   [3:0] axi_aw_cache;
logic                   [2:0] axi_aw_prot;
logic                   [3:0] axi_aw_qos;
logic                   [3:0] axi_aw_region;
logic             [USERW-1:0] axi_aw_user;
logic                         axi_aw_valid;
logic                         axi_aw_ready;
logic              [TIDW-1:0] axi_w_id;
logic                [DW-1:0] axi_w_data;
logic              [DW/8-1:0] axi_w_strb;
logic                         axi_w_last;
logic             [USERW-1:0] axi_w_user;
logic                         axi_w_valid;
logic                         axi_w_ready;
logic              [TIDW-1:0] axi_b_id;
logic                   [1:0] axi_b_resp;
logic             [USERW-1:0] axi_b_user;
logic                         axi_b_valid;
logic                         axi_b_ready;
logic              [TIDW-1:0] axi_ar_id;
logic                [AW-1:0] axi_ar_addr;
logic                   [7:0] axi_ar_len;
logic                   [2:0] axi_ar_size;
logic                   [1:0] axi_ar_burst;
logic                   [1:0] axi_ar_lock;
logic                   [3:0] axi_ar_cache;
logic                   [2:0] axi_ar_prot;
logic                   [3:0] axi_ar_qos;
logic                   [3:0] axi_ar_region;
logic             [USERW-1:0] axi_ar_user;
logic                         axi_ar_valid;
logic                         axi_ar_ready;
logic              [TIDW-1:0] axi_r_id;
logic                [DW-1:0] axi_r_data;
logic                   [1:0] axi_r_resp;
logic                         axi_r_last;
logic             [USERW-1:0] axi_r_user;
logic                         axi_r_valid;
logic                         axi_r_ready;

/////////////////////////////////////
///// AW channel FIFO
/////////////////////////////////////
logic [TIDW+AW+30+USERW-1:0] aw_push_data;
logic                  aw_push;
logic                  aw_ready;
logic [TIDW+AW+30+USERW-1:0] aw_pop_data;
logic                  aw_valid;
logic                  aw_pop;

assign axi_aw_ready_o = aw_ready;
assign aw_push = axi_aw_valid_i && axi_aw_ready_o;
assign aw_push_data = {axi_aw_user_i,axi_aw_region_i,axi_aw_qos_i,axi_aw_prot_i,axi_aw_cache_i,axi_aw_lock_i,axi_aw_burst_i,axi_aw_size_i,axi_aw_len_i,axi_aw_addr_i,axi_aw_id_i};
assign axi_aw_valid = aw_valid;
assign aw_pop = axi_aw_ready && axi_aw_valid;
assign {axi_aw_user,axi_aw_region,axi_aw_qos,axi_aw_prot,axi_aw_cache,axi_aw_lock,axi_aw_burst,axi_aw_size,axi_aw_len,axi_aw_addr,axi_aw_id} = aw_pop_data;

fifo_duth #(
		.DATA_WIDTH(TIDW+AW+30+USERW),
		.RAM_DEPTH(INTERFACE_FIFO_DEPTH)
	) aw_channel_fifo (
		.clk       (HCLK),
		.rst       (~HRESETn),
		.push_data (aw_push_data),
		.push      (aw_push),
		.ready     (aw_ready),
		.pop_data  (aw_pop_data),
		.valid     (aw_valid),
		.pop       (aw_pop)
	);



/////////////////////////////////////
///// W channel FIFO
/////////////////////////////////////
logic [TIDW+DW+DW/8+1+USERW-1:0] w_push_data;
logic                  w_push;
logic                  w_ready;
logic [TIDW+DW+DW/8+1+USERW-1:0] w_pop_data;
logic                  w_valid;
logic                  w_pop;

assign axi_w_ready_o = w_ready;
assign w_push = axi_w_valid_i && axi_w_ready_o;
assign w_push_data = {axi_w_user_i,axi_w_last_i,axi_w_strb_i,axi_w_data_i,axi_w_id_i};
assign axi_w_valid = w_valid;
assign w_pop = axi_w_ready && axi_w_valid;
assign {axi_w_user,axi_w_last,axi_w_strb,axi_w_data,axi_w_id} = w_pop_data;

fifo_duth #(
		.DATA_WIDTH(TIDW+DW+DW/8+1+USERW),
		.RAM_DEPTH(INTERFACE_FIFO_DEPTH)
	) w_channel_fifo (
		.clk       (HCLK),
		.rst       (~HRESETn),
		.push_data (w_push_data),
		.push      (w_push),
		.ready     (w_ready),
		.pop_data  (w_pop_data),
		.valid     (w_valid),
		.pop       (w_pop)
	);


/////////////////////////////////////
///// AR channel FIFO
/////////////////////////////////////
logic [TIDW+AW+30+USERW-1:0] ar_push_data;
logic                  ar_push;
logic                  ar_ready;
logic [TIDW+AW+30+USERW-1:0] ar_pop_data;
logic                  ar_valid;
logic                  ar_pop;

assign axi_ar_ready_o = ar_ready;
assign ar_push = axi_ar_valid_i && axi_ar_ready_o;
assign ar_push_data = {axi_ar_user_i,axi_ar_region_i,axi_ar_qos_i,axi_ar_prot_i,axi_ar_cache_i,axi_ar_lock_i,axi_ar_burst_i,axi_ar_size_i,axi_ar_len_i,axi_ar_addr_i,axi_ar_id_i};
assign axi_ar_valid = ar_valid;
assign ar_pop = axi_ar_ready && axi_ar_valid;
assign {axi_ar_user,axi_ar_region,axi_ar_qos,axi_ar_prot,axi_ar_cache,axi_ar_lock,axi_ar_burst,axi_ar_size,axi_ar_len,axi_ar_addr,axi_ar_id} = ar_pop_data;

fifo_duth #(
		.DATA_WIDTH(TIDW+AW+30+USERW),
		.RAM_DEPTH(INTERFACE_FIFO_DEPTH)
	) ar_channel_fifo (
		.clk       (HCLK),
		.rst       (~HRESETn),
		.push_data (ar_push_data),
		.push      (ar_push),
		.ready     (ar_ready),
		.pop_data  (ar_pop_data),
		.valid     (ar_valid),
		.pop       (ar_pop)
	);


/////////////////////////////////////
///// B channel FIFO
/////////////////////////////////////
logic [TIDW+1+USERW:0] b_push_data;
logic                  b_push;
logic                  b_ready;
logic [TIDW+1+USERW-1:0] b_pop_data;
logic                  b_valid;
logic                  b_pop;

assign axi_b_ready = b_ready;
assign b_push = axi_b_ready && axi_b_valid;	
assign b_push_data = {axi_b_user,axi_b_resp,axi_b_id};
assign axi_b_valid_o = b_valid;
assign b_pop = axi_b_ready_i && axi_b_valid_o;
assign {axi_b_user_o,axi_b_resp_o,axi_b_id_o} = b_pop_data;

fifo_duth #(
		.DATA_WIDTH(TIDW+1+USERW),
		.RAM_DEPTH(INTERFACE_FIFO_DEPTH)
	) b_channel_fifo (
		.clk       (HCLK),
		.rst       (~HRESETn),
		.push_data (b_push_data),
		.push      (b_push),
		.ready     (b_ready),
		.pop_data  (b_pop_data),
		.valid     (b_valid),
		.pop       (b_pop)
	);

/////////////////////////////////////
///// R channel FIFO
/////////////////////////////////////
logic [TIDW+DW+3+USERW-1:0] r_push_data;
logic                  r_push;
logic                  r_ready;
logic [TIDW+DW+3+USERW-1:0] r_pop_data;
logic                  r_valid;
logic                  r_pop;

assign axi_r_ready = r_ready;
assign r_push = axi_r_ready && axi_r_valid;	
assign r_push_data = {axi_r_user,axi_r_last,axi_r_resp,axi_r_data,axi_r_id};
assign axi_r_valid_o = r_valid;
assign r_pop = axi_r_ready_i && axi_r_valid_o;
assign {axi_r_user_o,axi_r_last_o,axi_r_resp_o,axi_r_data_o,axi_r_id_o} = r_pop_data;

fifo_duth #(
		.DATA_WIDTH(TIDW+DW+3+USERW),
		.RAM_DEPTH(INTERFACE_FIFO_DEPTH)
	) r_channel_fifo (
		.clk       (HCLK),
		.rst       (~HRESETn),
		.push_data (r_push_data),
		.push      (r_push),
		.ready     (r_ready),
		.pop_data  (r_pop_data),
		.valid     (r_valid),
		.pop       (r_pop)
	);




	axi2ahb #(
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
		) inst_axi2ahb (
			.axi_aw_id_i     (axi_aw_id),
			.axi_aw_addr_i   (axi_aw_addr),
			.axi_aw_len_i    (axi_aw_len),
			.axi_aw_size_i   (axi_aw_size),
			.axi_aw_burst_i  (axi_aw_burst),
			.axi_aw_lock_i   (axi_aw_lock),
			.axi_aw_cache_i  (axi_aw_cache),
			.axi_aw_prot_i   (axi_aw_prot),
			.axi_aw_qos_i    (axi_aw_qos),
			.axi_aw_region_i (axi_aw_region),
			.axi_aw_user_i   (axi_aw_user),
			.axi_aw_valid_i  (axi_aw_valid),
			.axi_aw_ready_o  (axi_aw_ready),
			.axi_w_id_i      (axi_w_id),
			.axi_w_data_i    (axi_w_data),
			.axi_w_strb_i    (axi_w_strb),
			.axi_w_last_i    (axi_w_last),
			.axi_w_user_i    (axi_w_user),
			.axi_w_valid_i   (axi_w_valid),
			.axi_w_ready_o   (axi_w_ready),
			.axi_b_id_o      (axi_b_id),
			.axi_b_resp_o    (axi_b_resp),
			.axi_b_user_o    (axi_b_user),
			.axi_b_valid_o   (axi_b_valid),
			.axi_b_ready_i   (axi_b_ready),
			.axi_ar_id_i     (axi_ar_id),
			.axi_ar_addr_i   (axi_ar_addr),
			.axi_ar_len_i    (axi_ar_len),
			.axi_ar_size_i   (axi_ar_size),
			.axi_ar_burst_i  (axi_ar_burst),
			.axi_ar_lock_i   (axi_ar_lock),
			.axi_ar_cache_i  (axi_ar_cache),
			.axi_ar_prot_i   (axi_ar_prot),
			.axi_ar_qos_i    (axi_ar_qos),
			.axi_ar_region_i (axi_ar_region),
			.axi_ar_user_i   (axi_ar_user),
			.axi_ar_valid_i  (axi_ar_valid),
			.axi_ar_ready_o  (axi_ar_ready),
			.axi_r_id_o      (axi_r_id),
			.axi_r_data_o    (axi_r_data),
			.axi_r_resp_o    (axi_r_resp),
			.axi_r_last_o    (axi_r_last),
			.axi_r_user_o    (axi_r_user),
			.axi_r_valid_o   (axi_r_valid),
			.axi_r_ready_i   (axi_r_ready),
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


endmodule