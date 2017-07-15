// axi2ahb backup with only one idle cycle between write and read, no idle between writes and reads 
import ahb_pkg::*;
module axi2ahb
		#(
			parameter AHB_DATA_WIDTH=64,
			parameter AHB_ADDRESS_WIDTH=32,
			parameter int TIDW = 1,
			parameter int AW  = 32,
			parameter int DW  = 64,
			parameter int USERW  = 1
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




always_comb begin
	// axi_aw_ready_o=1'b1;
	// axi_w_ready_o=1'b1;
	// axi_ar_ready_o=1'b1;
	// axi_r_valid_o=1'b0;
	axi_b_id_o=0;
	axi_r_id_o=0;
	// axi_b_valid_o=1'b0;

end

// state encoding
state_t state;
// assign state = state_t'(HTRANS);
assign HTRANS=state_t'(state);
// assign HTRANS
// burst encoding
burst_t burst_type;
assign HBURST = burst_t'(burst_type);
// size encoding
size_t size;
// assign size = size_t'(HSIZE);
// HRESP encoding
response_t response;
// assign response = response_t'(HRESP);

axi_state_t axi_burst;
// assign axi_burst = axi_state_t'(axi_aw_burst_i);




///////++++++++++++++++++++++
////// Write Transfers 
///////++++++++++++++++++++++
assign aw_ack = axi_aw_valid_i && axi_aw_ready_o;
assign w_ack = axi_w_valid_i && axi_w_ready_o;
assign ar_ack = axi_ar_valid_i && axi_ar_ready_o;
assign r_ack = axi_r_valid_o && axi_r_ready_i;
assign r_last = axi_r_valid_o && axi_r_ready_i && axi_r_last_o; 

// beat counter
int cycle_counter;
always_ff @(posedge HCLK or negedge HRESETn) begin
	if(~HRESETn) begin
		cycle_counter <= 1;
	end else begin
		if(HREADY && state==NONSEQ) begin
			cycle_counter<=1;
		end else if(HREADY && state==SEQ) begin
			cycle_counter <= cycle_counter +1;
		end 
	end
end
logic pending_write,pending_read,waiting_for_slave_response;
assign write_last_beat_ack = axi_w_valid_i && axi_w_last_i && axi_w_ready_o;  // Sta error?? yparxei periptwsi na teleiwsei ena transaction prowra prin erthei last?
assign write_b_ack = axi_b_valid_o && axi_b_ready_i;
always_ff @(posedge HCLK or negedge HRESETn) begin 
	if(~HRESETn) begin
		pending_write <= 0;
		pending_read <= 0;
		waiting_for_slave_response<=0;
	end else begin
		// waiting for response
		if(write_last_beat_ack) begin
			waiting_for_slave_response<=1'b1;
		end else if(write_b_ack) begin
			waiting_for_slave_response<=0;
		end


		// pending write
		if(aw_ack) begin
			pending_write <= 1'b1;
		end else if(write_b_ack) begin
			pending_write <= 0;
		end

		// pending read
		if(ar_ack) begin
			pending_read <= 1'b1;
		end else if(r_last) begin
			pending_read <= 0;
		end
	end
end
// @write_data_phase;
logic write_data_phase;
always_ff @(posedge HCLK or negedge HRESETn) begin
	if(~HRESETn) begin
		write_data_phase<=0;
	end else begin
		 if(HREADY==1'b1 && (state!==IDLE && state!==BUSY)  && HWRITE==1'b1) begin
			write_data_phase<=1'b1;
		end else begin
			write_data_phase<=0;
		end
	end
end

////////////////////////////////////////
////// AHB master interface
////////////////////////////////////////


// @HTRANS or @state
// @aw_len_buffer kai 
logic [7:0]aw_len_buffer,ar_len_buffer;
logic [2:0]aw_size_buffer,ar_size_buffer;
logic [AHB_ADDRESS_WIDTH-1:0]aw_address_buffer,ar_address_buffer;
// logic [AHB_ADDRESS_WIDTH-1:0]aw_address_incr;
always_ff @(posedge HCLK or negedge HRESETn) begin
	if(~HRESETn) begin
		aw_len_buffer <= 0;
		aw_size_buffer<=0;
		aw_address_buffer<=0;
		ar_len_buffer<=0;
		ar_size_buffer<=0;
		ar_address_buffer<=0;
		
	end else begin
		if (aw_ack)begin 
			aw_len_buffer<=axi_aw_len_i;
			aw_size_buffer<=axi_aw_size_i;
			aw_address_buffer<=axi_aw_addr_i;
		end
		if(ar_ack) begin
			ar_len_buffer<=axi_ar_len_i;
			ar_size_buffer<=axi_ar_size_i;
			ar_address_buffer<=axi_ar_addr_i;
		end

	end
end
always_comb begin 
	if(aw_ack || ar_ack) begin
		state=NONSEQ;
	end else if ((cycle_counter<aw_len_buffer+1) || (cycle_counter<ar_len_buffer+1)  && (pending_write||pending_read)) begin
		state=SEQ;
	end else begin 
		state=IDLE;
	end
end

// @HADDR
always_comb begin
	if(aw_ack) begin
		HADDR = axi_aw_addr_i;
	end else if(pending_write) begin 
		HADDR = aw_address_buffer+cycle_counter*aw_size_buffer;
	end else if(ar_ack) begin
		HADDR = axi_ar_addr_i;
	end else if(pending_read) begin
		HADDR = ar_address_buffer+cycle_counter*ar_size_buffer;
	end else begin 
		HADDR = 0;
	end
end

// @HSIZE
always_comb begin 
	if(aw_ack) begin
		HSIZE = axi_aw_size_i;
	end else if (pending_write) begin 
		HSIZE = aw_size_buffer;
	end else if(ar_ack) begin
		HSIZE = axi_ar_size_i;
	end else if(pending_read) begin
		HSIZE = ar_size_buffer;
	end else begin 
		HSIZE = 0;
	end
end

// @HBURST
always_comb begin 
	burst_type = INCR;
end

// @HWDATA
always_comb begin 
	HWDATA = axi_w_data_i;
end

// @HWRITE
always_comb begin 
	if(ar_ack) begin
		HWRITE = 0;
	end else if(aw_ack) begin
		HWRITE = 1'b1;
	end else if(pending_write) begin
		HWRITE = 1'b1;
	end else if(pending_read) begin
		HWRITE = 0;
	end else begin 
		HWRITE = 1'b1;
	end
end




////////////////////////////////////////
////// AXI slave interface
////////////////////////////////////////

// @aw_ready_o
always_comb begin
	if(write_data_phase) begin
		axi_w_ready_o = 1'b1;
	end else begin
		axi_w_ready_o = 0;
	end

end

// @axi_b_resp_o kai @axi_b_valid_o
always_comb begin 
	axi_b_resp_o=2'b00;
	if(pending_write) begin
		if(cycle_counter==aw_len_buffer+1 && HREADY) begin
			axi_b_valid_o=1'b1;
		end else begin
			axi_b_valid_o=0;
		end
	end else begin 
		axi_b_valid_o=0;
	end
end

// @axi_aw_ready_o
always_comb begin 
	// if(pending_write || pending_read) begin
	// 	axi_aw_ready_o=0;
	// end else begin 
	// 	axi_aw_ready_o=1'b1;
	// end
	if(pending_write && cycle_counter==aw_len_buffer+1 && HREADY) begin // to vazw wste na min exw idle cycle metaksu diadoxikwn write
		axi_aw_ready_o=1'b1;
	end else if(pending_write) begin
		axi_aw_ready_o=0;
	end else begin 
		axi_aw_ready_o=1'b1;
	end

end

// @read_data_phase
logic read_data_phase;
always_ff @(posedge HCLK or negedge HRESETn) begin 
	if(~HRESETn) begin
		read_data_phase <= 0;
	end else begin
		if((state==NONSEQ || state==SEQ) && HREADY && HWRITE==1'b0) begin
			read_data_phase<=1'b1;
		end else begin 
			read_data_phase<=1'b0;
		end
	end
end
// @axi_r_data_o kai @axi_r_valid_o
always_comb begin 
	if(read_data_phase && HREADY) begin
		axi_r_data_o = HRDATA;
		axi_r_valid_o = 1'b1;
		axi_r_resp_o = 2'b0;
		if(cycle_counter==ar_len_buffer+1) begin
			axi_r_last_o=1'b1;
		end else begin 
			axi_r_last_o=0;
		end
	end else begin 
		axi_r_data_o = HRDATA;
		axi_r_valid_o = 0;
		axi_r_resp_o = 2'b0;
		axi_r_last_o=0;
	end

end

// assign test = pending_write && cycle_counter==aw_len_buffer+1 && HREADY && ~axi_aw_valid_i;
// @axi_ar_ready_o
always_comb begin 
	if(pending_read && cycle_counter==ar_len_buffer+1 && r_last && HREADY) begin // auto einai ligo shaky kai to vazw wste na min exw idle cycle metaksu diadoxikwn read
		axi_ar_ready_o=1'b1;
	end else if(pending_read || pending_write || aw_ack) begin // an exw aw_ack tautoxrona me to ar_ack
		axi_ar_ready_o=0;
	end else begin 
		axi_ar_ready_o=1'b1;
	end

end


endmodule // axi2ahb