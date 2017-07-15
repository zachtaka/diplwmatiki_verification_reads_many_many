import ahb_pkg::*;
module response_path
	#(
		parameter AHB_DATA_WIDTH=64,
		parameter AHB_ADDRESS_WIDTH=32,
		parameter int TIDW = 1,
		parameter int AW  = 32,
		parameter int DW  = 64,
		parameter int USERW  = 1,
		parameter MAX_PENDING_WRITES = 4, // 2^FIFO_ADDRESS_BITS mou dinei ton arithmo thesewn kathe FIFO
		parameter MAX_PENDING_READ_BEATS = 4,
		parameter B_QUEUE_SLOTS = MAX_PENDING_WRITES,
		parameter B_QUEUE_DATA_BITS = 2+TIDW, // osa kai to bresp+id
		parameter R_QUEUE_SLOTS = MAX_PENDING_READ_BEATS,
		parameter R_QUEUE_DATA_BITS = DW+2+1+TIDW // = r_data + r_resp + r_last + id
	)(
	
	
	// -- AXI Slave interface -- //
		// B (Write Response) channel (Target -> NI)
		output logic[TIDW-1:0]                  axi_b_id_o,     // BID
		output logic[1:0]                            axi_b_resp_o,   // BRESP
		output logic[USERW-1:0]              axi_b_user_o,   // BUSER
		output logic                                  axi_b_valid_o,  // BVALID
		input  logic                                   axi_b_ready_i,  // BREADY
		// R (Read Data) channel (Target -> NI)
		output logic[TIDW-1:0]                  axi_r_id_o,     // RID
		output logic[DW-1:0]                     axi_r_data_o,   // RDATA
		output logic[1:0]                            axi_r_resp_o,   // RRESP
		output logic                                  axi_r_last_o,   // RLAST
		output logic[USERW-1:0]              axi_r_user_o,   // RUSER
		output logic                                  axi_r_valid_o,  // RVALID
		input  logic                                   axi_r_ready_i,   // RREADY
	// -- common signals -- //
		input logic pending_read,
		input logic waiting_for_ahb_slave_response,
		input logic r_last_beat,
		input logic [TIDW-1:0]  TID_queue_data,

		output logic TID_queue_pop,
		output logic reset_pending_read,
		output logic reset_waiting_ahb_slave_response,
		output logic write_b_ack,
		output logic read_queue_ready,
	// -- AHB Master interface -- //
		// Inputs
		input logic HREADY,
		input logic [1:0] HTRANS,
		input logic HRESP,
		input logic [AHB_DATA_WIDTH-1:0] HRDATA,
		input logic HCLK,
		input logic HRESETn
	
	
);


// state encoding
state_t state;
assign state = state_t'(HTRANS);


// b channel queue
logic wr_b,rd_b,ready_b,valid_b;
logic [B_QUEUE_DATA_BITS-1:0] din_b,dout_b;
// r channel queue
logic r_wr,r_rd,r_ready,r_valid;
logic [R_QUEUE_DATA_BITS-1:0] r_din,r_dout;
//
logic error_reg;

logic r_last_pushed,r_ack;
assign reset_pending_read = r_wr && r_din[TIDW];
assign r_last_pushed = pending_read && r_wr && r_din[TIDW];
assign reset_waiting_ahb_slave_response = HREADY && state!==BUSY;
assign read_queue_ready = r_ready;


always_ff @(posedge HCLK or negedge HRESETn) begin 
	if(~HRESETn) begin
		error_reg<=0;
	end else begin

		if(wr_b || r_last_pushed) begin
			error_reg<=0;
		end else if(~HREADY && HRESP) begin // an exw error
			error_reg<=1'b1;
		end

	end
end


/////////////////////////
//// B queue
/////////////////////////
fifo_duth #(
		.DATA_WIDTH(B_QUEUE_DATA_BITS),
		.RAM_DEPTH(B_QUEUE_SLOTS)
	) B_queue (
		.clk          (HCLK),
		.rst         (~HRESETn),
		.push_data (din_b),
		.push      (wr_b),
		.ready        (ready_b),
		.pop_data (dout_b),
		.valid        (valid_b),
		.pop       (rd_b)
	);

assign write_b_ack = axi_b_valid_o && axi_b_ready_i;
always_comb begin
	// vazw ta bresp stin B queue otan exw tin apantisi 
	if(waiting_for_ahb_slave_response&&HREADY) begin
		wr_b=1'b1;
		din_b={{error_reg,1'b0},TID_queue_data}; // din_b = {ERROR,ID}
	end else begin 
		wr_b=0;
		din_b=0;
	end

	// diavazw apo tin B queue otan stelnw ena write response sto b
	if(write_b_ack) begin 
		rd_b=1'b1; 
	end else begin 
		rd_b=0;
	end

end

/////////////////////////
//// B channel
/////////////////////////
// @axi_b_resp_o kai @axi_b_valid_o
always_comb begin 
	if(valid_b) begin // oso exw data stin bqueue 
		axi_b_valid_o=1'b1;
		{axi_b_resp_o,axi_b_id_o}=dout_b;
	end else begin 
		axi_b_valid_o=0;
		axi_b_resp_o=0;
		axi_b_id_o=0; 
	end
end



/////////////////////////
//// R queue
/////////////////////////
fifo_duth #(
		.DATA_WIDTH(R_QUEUE_DATA_BITS),
		.RAM_DEPTH(R_QUEUE_SLOTS)
	) R_queue (
		.clk          (HCLK),
		.rst         (~HRESETn),
		.push_data (r_din),
		.push      (r_wr),
		.ready        (r_ready),
		.pop_data (r_dout),
		.valid        (r_valid),
		.pop       (r_rd)
	);

assign r_ack = axi_r_valid_o && axi_r_ready_i;
always_comb begin
	// kanw push otan mou erxontai read data apo ton ahb
	if(pending_read && HREADY && r_ready) begin
		r_wr=1'b1;
		r_din={HRDATA,{error_reg,1'b0},r_last_beat,TID_queue_data}; // r_din={HRDATA,ERROR,R_LAST,ID}
	end else begin 
		r_wr=0;
		r_din=0;
	end
	// kanw pop otan feugoun ston r kanali 
	if(r_ack) begin
		r_rd=1'b1;
	end else begin 
		r_rd=0;
	end
end

/////////////////////////
//// R channel
/////////////////////////
always_comb begin
	if(r_valid) begin 
		axi_r_valid_o=1'b1;
		{axi_r_data_o,axi_r_resp_o,axi_r_last_o,axi_r_id_o}=r_dout;
	end else begin 
		axi_r_valid_o=0;
		axi_r_data_o=0;
		axi_r_last_o=0;
		axi_r_resp_o=0;
		axi_r_id_o=0; 
	end

end

assign TID_queue_pop = wr_b || (r_wr && r_din[TIDW]);


// set region,protection etc signals to 0
always_comb begin 
	// B channel
	axi_b_user_o = 0;
	// R channel
	axi_r_user_o = 0;

end




`ifndef SYNTHESIS
int dbg_write_resp_counter,dbg_read_resp_counter;
logic r_last;
assign r_last = axi_r_valid_o && axi_r_ready_i && axi_r_last_o; 
always_ff @(posedge HCLK or negedge HRESETn) begin
	if(~HRESETn) begin
		dbg_write_resp_counter<=0;
		dbg_read_resp_counter<=0;
	end else begin
		if(write_b_ack) begin
			dbg_write_resp_counter++;
			$display("write_resp_counter=%0d",dbg_write_resp_counter);
		end
		if(r_last) begin
			dbg_read_resp_counter++;
			$display("read_resp_counter=%0d",dbg_read_resp_counter);
		end
	end
end
`endif



endmodule