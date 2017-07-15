import ahb_pkg::*;
module axi2ahb
		#(
			parameter AHB_DATA_WIDTH=64,
			parameter AHB_ADDRESS_WIDTH=32,
			parameter int TIDW = 1,
			parameter int AW  = 32,
			parameter int DW  = 64,
			parameter int USERW  = 1,
			parameter MAX_PENDING_WRITES = 4, // 2^FIFO_ADDRESS_BITS mou dinei ton arithmo thesewn kathe FIFO
			parameter MAX_PENDING_READ_BEATS = 4,
			parameter TID_QUEUE_SLOTS = MAX_PENDING_WRITES, // 2^4=16 theseis gia tin TID fifo
			parameter TID_QUEUE_DATA_BITS = TIDW,
			parameter B_QUEUE_SLOTS = MAX_PENDING_WRITES,
			parameter B_QUEUE_DATA_BITS = 2+TIDW, // osa kai to bresp+id
			parameter R_QUEUE_SLOTS = MAX_PENDING_READ_BEATS,
			parameter R_QUEUE_DATA_BITS = DW+2+1+TIDW // = r_data + r_resp + r_last + id
		)
		(
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





// state encoding
state_t state;
assign state = state_t'(HTRANS);







// id queue
logic id_queue_wr,pop_TID_queue,id_queue_ready,id_queue_valid;
logic [TID_QUEUE_DATA_BITS-1:0] id_queue_din,id_queue_dout;

////////////////
logic pending_write,set_pening_write,reset_pending_write;
logic pending_read,set_pending_read,reset_pending_read;
logic waiting_for_ahb_slave_response,set_waiting_ahb_slave_response,reset_waiting_ahb_slave_response;
logic [7:0]ar_len_buffer;
logic [63:0] cycle_counter;
logic read_beats_count_less_than_ar_len_buffer;
logic write_b_ack,read_queue_ready,set_pending_write,set_ar_len_buffer,push_TID_queue,is_write_first_single_beat,r_last_beat;


		request_path #(
			.AHB_DATA_WIDTH(AHB_DATA_WIDTH),
			.AHB_ADDRESS_WIDTH(AHB_ADDRESS_WIDTH),
			.TIDW(TIDW),
			.AW(AW),
			.DW(DW),
			.USERW(USERW),
			.MAX_PENDING_WRITES(MAX_PENDING_WRITES),
			.MAX_PENDING_READ_BEATS(MAX_PENDING_READ_BEATS),
			.B_QUEUE_SLOTS(B_QUEUE_SLOTS),
			.B_QUEUE_DATA_BITS(B_QUEUE_DATA_BITS),
			.R_QUEUE_SLOTS(R_QUEUE_SLOTS),
			.R_QUEUE_DATA_BITS(R_QUEUE_DATA_BITS)
		) inst_request_path (
			.axi_aw_id_i                              (axi_aw_id_i),
			.axi_aw_addr_i                            (axi_aw_addr_i),
			.axi_aw_len_i                             (axi_aw_len_i),
			.axi_aw_size_i                            (axi_aw_size_i),
			.axi_aw_burst_i                           (axi_aw_burst_i),
			.axi_aw_lock_i                            (axi_aw_lock_i),
			.axi_aw_cache_i                           (axi_aw_cache_i),
			.axi_aw_prot_i                            (axi_aw_prot_i),
			.axi_aw_qos_i                             (axi_aw_qos_i),
			.axi_aw_region_i                          (axi_aw_region_i),
			.axi_aw_user_i                            (axi_aw_user_i),
			.axi_aw_valid_i                           (axi_aw_valid_i),
			.axi_aw_ready_o                           (axi_aw_ready_o),
			.axi_w_id_i                               (axi_w_id_i),
			.axi_w_data_i                             (axi_w_data_i),
			.axi_w_strb_i                             (axi_w_strb_i),
			.axi_w_last_i                             (axi_w_last_i),
			.axi_w_user_i                             (axi_w_user_i),
			.axi_w_valid_i                            (axi_w_valid_i),
			.axi_w_ready_o                            (axi_w_ready_o),
			.axi_ar_id_i                              (axi_ar_id_i),
			.axi_ar_addr_i                            (axi_ar_addr_i),
			.axi_ar_len_i                             (axi_ar_len_i),
			.axi_ar_size_i                            (axi_ar_size_i),
			.axi_ar_burst_i                           (axi_ar_burst_i),
			.axi_ar_lock_i                            (axi_ar_lock_i),
			.axi_ar_cache_i                           (axi_ar_cache_i),
			.axi_ar_prot_i                            (axi_ar_prot_i),
			.axi_ar_qos_i                             (axi_ar_qos_i),
			.axi_ar_region_i                          (axi_ar_region_i),
			.axi_ar_user_i                            (axi_ar_user_i),
			.axi_ar_valid_i                           (axi_ar_valid_i),
			.axi_ar_ready_o                           (axi_ar_ready_o),
			.pending_write                            (pending_write),
			.pending_read                             (pending_read),
			.write_b_ack                              (write_b_ack),
			.read_queue_ready                         (read_queue_ready),
			.read_beats_count_less_than_ar_len_buffer (read_beats_count_less_than_ar_len_buffer),
			.set_pending_write                        (set_pending_write),
			.reset_pending_write                      (reset_pending_write),
			.set_pending_read                         (set_pending_read),
			.set_ar_len_buffer                        (set_ar_len_buffer),
			.push_TID_queue                           (push_TID_queue),
			.is_write_first_single_beat               (is_write_first_single_beat),
			.set_waiting_ahb_slave_response           (set_waiting_ahb_slave_response),
			.HREADY                                   (HREADY),
			.HRESP                                    (HRESP),
			.HRDATA                                   (HRDATA),
			.HADDR                                    (HADDR),
			.HWDATA                                   (HWDATA),
			.HWRITE                                   (HWRITE),
			.HSIZE                                    (HSIZE),
			.HBURST                                   (HBURST),
			.HTRANS                                   (HTRANS),
			.HCLK                                     (HCLK),
			.HRESETn                                  (HRESETn)
		);












always_ff @(posedge HCLK or negedge HRESETn) begin 
	if(~HRESETn) begin
		pending_write <= 0;
		pending_read <= 0;
		cycle_counter <= 0;
		waiting_for_ahb_slave_response<=0;
	end else begin

		// pending write
		if(reset_pending_write) begin 
			pending_write <= 0;
		end else if(set_pending_write) begin
			pending_write <= 1'b1;
		end

		
		// pending read
		if(set_pending_read) begin
			pending_read <= 1'b1;
		end else if(reset_pending_read) begin // otan kanoume push to teleutaio read data
			pending_read <= 0;
		end


		// beat counter for read beats
		if(pending_read && HREADY && state!==BUSY) begin
			cycle_counter<=cycle_counter+1;
		end else if(state==NONSEQ) begin
			cycle_counter<=0;
		end


		// @waiting_for_ahb_slave_response
		if(set_waiting_ahb_slave_response) begin
			waiting_for_ahb_slave_response<=1'b1;
		end else if(reset_waiting_ahb_slave_response) begin
			waiting_for_ahb_slave_response<=0;
		end
	end
end



assign read_beats_count_less_than_ar_len_buffer = cycle_counter < ar_len_buffer;



///////////////////////////////////////
//// AW & AR Buffers
///////////////////////////////////////
always_ff @(posedge HCLK or negedge HRESETn) begin 
	if(~HRESETn) begin
		ar_len_buffer<=0;
	end else begin
		// AR Buffers
		if(set_ar_len_buffer) begin
			ar_len_buffer<=axi_ar_len_i;
		end

	end
end







/////////////////////////
//// ID queue
/////////////////////////
fifo_duth #(
		.DATA_WIDTH(TID_QUEUE_DATA_BITS),
		.RAM_DEPTH(TID_QUEUE_SLOTS)
	) ID_queue (
		.clk          (HCLK),
		.rst        (~HRESETn),
		.push_data (id_queue_din),
		.push      (id_queue_wr),
		.ready        (id_queue_ready),
		.pop_data (id_queue_dout),
		.valid        (id_queue_valid),
		.pop       (pop_TID_queue)
	);
always_comb begin
	// pote kanw push stin ID queue
	// vazw ta ID stin TID queue otan exw aw i ar ack 
	if(push_TID_queue) begin
		id_queue_wr=1'b1;
		if(is_write_first_single_beat) begin
			id_queue_din=axi_aw_id_i;
		end else begin 
			id_queue_din=axi_ar_id_i;
		end
	end else begin 
		id_queue_wr=0;
		id_queue_din=0;
	end

	
end




assign r_last_beat = cycle_counter == ar_len_buffer;
	response_path #(
			.AHB_DATA_WIDTH(AHB_DATA_WIDTH),
			.AHB_ADDRESS_WIDTH(AHB_ADDRESS_WIDTH),
			.TIDW(TIDW),
			.AW(AW),
			.DW(DW),
			.USERW(USERW),
			.B_QUEUE_SLOTS(B_QUEUE_SLOTS),
			.R_QUEUE_SLOTS(R_QUEUE_SLOTS)
		) inst_response_path
		(
			.axi_b_id_o                     (axi_b_id_o),
			.axi_b_resp_o                   (axi_b_resp_o),
			.axi_b_user_o                   (axi_b_user_o),
			.axi_b_valid_o                  (axi_b_valid_o),
			.axi_b_ready_i                  (axi_b_ready_i),
			.axi_r_id_o                     (axi_r_id_o),
			.axi_r_data_o                   (axi_r_data_o),
			.axi_r_resp_o                   (axi_r_resp_o),
			.axi_r_last_o                   (axi_r_last_o),
			.axi_r_user_o                   (axi_r_user_o),
			.axi_r_valid_o                  (axi_r_valid_o),
			.axi_r_ready_i                 (axi_r_ready_i),
			// -- common signals  -- //
			.pending_read                   (pending_read),
			.waiting_for_ahb_slave_response (waiting_for_ahb_slave_response),
			.TID_queue_pop                  (pop_TID_queue),
			.r_last_beat                         (r_last_beat),
			.TID_queue_data                 (id_queue_dout),
			.reset_pending_read            (reset_pending_read),
			.reset_waiting_ahb_slave_response	(reset_waiting_ahb_slave_response),
			.write_b_ack                     (write_b_ack),
			.read_queue_ready 		(read_queue_ready),
			// -- common signals  -- //
			.HREADY                         (HREADY),
			.HTRANS                          (HTRANS),
			.HRESP                          (HRESP),
			.HRDATA                         (HRDATA),
			.HCLK                           (HCLK),
			.HRESETn                        (HRESETn)
		);


	




endmodule // axi2ahb