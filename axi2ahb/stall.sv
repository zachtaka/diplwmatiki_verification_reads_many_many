module stall
	#(
	parameter stall_rate = 0
	)(
	input logic clk,
	input logic rst_n,
	input logic valid_in,
	input logic ready_in,
	output logic valid_out,
	output logic ready_out
);

logic stall;
always @(posedge clk or negedge rst_n) begin : proc_
	if(~rst_n) begin
		stall<=0;
	end else begin
		if(~(valid_in && ~ready_in) ||stall) begin
			if($urandom_range(99,0)<stall_rate) begin
				stall<=1'b1;
			end else begin 
				stall<=0;
			end
		end  else begin 
			stall<=0;
		end
	end
end

always_comb begin 
	valid_out=valid_in && ~stall;
	ready_out=ready_in && ~stall;

end


endmodule