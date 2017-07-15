import ahb_pkg::*;
module ahb_s #(
	parameter AHB_DATA_WIDTH=64,
	parameter AHB_ADDRESS_WIDTH=32,
	parameter AHB_SLAVE_STALL_RATE=0,
	parameter ERROR_RATE=0
	)(
	// Inputs
	input logic HCLK,
	input logic [AHB_ADDRESS_WIDTH-1:0] HADDR,
	input logic [AHB_DATA_WIDTH-1:0] HWDATA,
	input logic HWRITE,
	input logic [2:0] HSIZE,HBURST,
	input logic [1:0] HTRANS,
	input logic HRESETn,
	// Outputs
	output logic HREADY,
	output logic [AHB_DATA_WIDTH-1:0] HRDATA,
	output logic HRESP,
	output logic HEXOKAY
	);




//////////////////////////////////////////
////// Encoding stuff
//////////////////////////////////////////

// state encoding
state_t state;
assign state = state_t'(HTRANS);
// burst encoding
burst_t burst_type;
assign burst_type = burst_t'(HBURST);
// size encoding
size_t size;
assign size = size_t'(HSIZE);
// HRESP encoding
response_t response;
assign response = response_t'(HRESP);

///////++++++++++++++++++++++
////// END OF - Encoding stuff
///////++++++++++++++++++++++
logic pending,first_cycle_error,second_cycle_error;
always_ff @(posedge HCLK or negedge HRESETn) begin 
	if(~HRESETn) begin
		pending <= 0;
		second_cycle_error<=0;
	end else begin
		if(state==NONSEQ || state==SEQ && HREADY) begin
			pending<=1'b1;
		end else if(HREADY) begin
			pending <= 0;
		end

		if(first_cycle_error) begin
			second_cycle_error<=1'b1;
		end else begin 
			second_cycle_error<=0;
		end

	end
end
always_comb begin 
	if(pending && $urandom_range(99,0)<ERROR_RATE && ~second_cycle_error) begin
		first_cycle_error=1'b1;
	end else begin 
		first_cycle_error=0;
	end
end





// response to write
logic resp_to_write;
always_ff @(posedge HCLK or negedge HRESETn) begin : proc_
	if(~HRESETn) begin
		 resp_to_write<=0;
	end else begin
		if(HREADY && state==NONSEQ || state==SEQ) begin
			resp_to_write<=1'b1;
		end else begin 
			resp_to_write<=0;
		end
	end
end

// #HREADY
logic will_i_stall;
always_ff @(posedge HCLK or negedge HRESETn) begin 
	if(~HRESETn) begin
		will_i_stall <= 0;
		pending<=0;
	end else begin
		if($urandom_range(0,99)<AHB_SLAVE_STALL_RATE) begin 
			will_i_stall <= 1'b1;
		end else begin 
			will_i_stall <= 0;
		end


	end
end
always_comb begin 
	if(first_cycle_error) begin
		HREADY = 0;
	end else if(second_cycle_error) begin
		HREADY = 1'b1;
	end else if(resp_to_write && ~will_i_stall && state!==BUSY) begin
		HREADY = 1'b1;
	end else if(will_i_stall) begin
		HREADY=0;
	end else begin 
		HREADY = 1'b1;
	end
	
end

logic [AHB_ADDRESS_WIDTH-1:0] start_address;
logic [AHB_ADDRESS_WIDTH-1:0] aligned_address;
logic [63:0] number_bytes,upper_byte_lane,lower_byte_lane,data_bus_bytes;
logic [AHB_DATA_WIDTH-1:0] data;
logic [7:0] tmp0;

assign data_bus_bytes = AHB_DATA_WIDTH/8 ;




// @HRDATA
always_comb begin 
	number_bytes = 2**HSIZE;
	aligned_address =(HADDR/number_bytes)*number_bytes ;
	if(state==NONSEQ) begin
		lower_byte_lane = (HADDR-(HADDR/data_bus_bytes)*data_bus_bytes);
		upper_byte_lane = ( aligned_address+(number_bytes-1)-(HADDR/data_bus_bytes)*data_bus_bytes);
	end else begin 
		lower_byte_lane=HADDR-(HADDR/data_bus_bytes)*data_bus_bytes;
		upper_byte_lane=lower_byte_lane+number_bytes-1;
	end
end
logic [AHB_DATA_WIDTH-1:0] read_data;
always_ff @(posedge HCLK or negedge HRESETn) begin
	if(~HRESETn) begin
		HRDATA<= {AHB_DATA_WIDTH{4'hf}};
		tmp0=0;
	end else begin
		if(HREADY==1'b1 && (state==NONSEQ || state==SEQ)  && HWRITE==1'b0 ) begin
			if (state==NONSEQ) tmp0=0;
			for (int i=0;i<=AHB_DATA_WIDTH;i=i+8)begin
				if ((i>=lower_byte_lane*8) && (i<=upper_byte_lane*8)) begin 
					HRDATA[i+:8]<=tmp0;
					tmp0=tmp0+1;
				end else begin
					HRDATA[i+:8]<='hff;
				end
			end
		end 

	end
end


always_comb begin 
	if(first_cycle_error || second_cycle_error) begin
		HRESP=1'b1;
	end else begin 
		HRESP=0;
	end
	
end



endmodule