module my_FIFO
		#(
			parameter address_bits = 4, 	// 2^4=16 theseis
			parameter data_bits = 4
		)(
			input logic clk,
			input logic rst_n,
			input logic wr,
			input logic rd,
			input logic [data_bits-1:0] din,
			output logic empty,
			output logic full,
			output logic [data_bits-1:0] dout
		);

logic [data_bits-1:0] out;
logic [data_bits-1:0] regarray[2**address_bits-1:0]; //number of words in fifo = 2^(number of address bits)
logic [address_bits-1:0] wr_reg, wr_next, wr_succ; //points to the register that needs to be written to
logic [address_bits-1:0] rd_reg, rd_next, rd_succ; //points to the register that needs to be read from
logic full_reg, empty_reg, full_next, empty_next;
// write operation
assign wr_en = wr & ~full; // write when wr signal high and fifo not full
always_ff @(posedge clk) begin
	if(wr_en) begin
		regarray[wr_reg] <= din;
	end
end

// read operation 
always_ff @(posedge clk) begin 
	if(rd) begin
		out <= regarray[rd_reg];
	end
end



always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		wr_reg <= 0;
		rd_reg <= 0;
		full_reg <= 1'b0;
		empty_reg <= 1'b1;
	end else begin
		wr_reg <= wr_next; //created the next registers to avoid the error of mixing blocking and non blocking assignment to the same signal
		rd_reg <= rd_next;
		full_reg <= full_next;
		empty_reg <= empty_next;
	end
end



always_comb begin 
	wr_succ = wr_reg + 1;
	rd_succ = rd_reg + 1;
	wr_next = wr_reg;
	rd_next = rd_reg;
	full_next = full_reg;
	empty_next = empty_reg;

	if(~wr_en && rd) begin // read
		if(~empty) begin //if fifo is not empty continue
			rd_next = rd_succ;
			full_next = 1'b0;
			if(rd_succ == wr_reg)begin //all data has been read
				empty_next = 1'b1;//its empty again
			end
		end
	end else if(wr_en && ~rd) begin // write
		if(~full) begin //if fifo is not full continue
			wr_next = wr_succ;
                               empty_next = 1'b0;
			if(wr_succ == (2**address_bits-1))begin //all registers have been written to
				full_next = 1'b1; //its full now
			end
		end
	end else if(wr_en && rd) begin //read and write
		wr_next = wr_succ;
		rd_next = rd_succ;
	end
	
end


assign full = full_reg;
assign empty = empty_reg;
// assign dout = out;
always_comb begin 
	if(empty && rd && wr_en) begin
		dout = din;
	end else if(rd) begin
		dout = regarray[rd_reg];
	end else begin 
		dout = out;
	end
end

endmodule // my_FIFO