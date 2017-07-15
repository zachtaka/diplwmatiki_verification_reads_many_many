parameter int TIDW = 1;
parameter int AW  = 32;
parameter int DW  = 64;
parameter int USERW  = 1;

module axi_bytes_to_send_logger (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input logic [AW-1:0]                      axi_aw_addr,  // AWADDR
	input logic[2:0]                               axi_aw_size,  // AWSIZE
	input logic                                    axi_aw_valid, // AWVALID
	input logic                                    axi_aw_ready, // AWREADY
	input logic[TIDW-1:0]                    axi_w_id,     // WID / driven only under AMBA==3 mode (AXI4 does not support write interleaving, so there's no WID signal)
	input logic[DW-1:0]                      axi_w_data,   // WDATA
	input logic[DW/8-1:0]                   axi_w_strb,   // WSTRB
	input logic                                    axi_w_last,   // WLAST
	input logic[USERW-1:0]                axi_w_user,   // WUSER / tied to zero
	input logic                                    axi_w_valid,  // WVALID
	input logic                                    axi_w_ready  // WREADY
);

int log_file,old_log_file;
initial begin 
	log_file = $fopen("C:/Users/zacarry/Desktop/Verilog/axi2ahb/axi_bytes_log.txt", "w") ;
	old_log_file =  $fopen("C:/Users/zacarry/Desktop/Verilog/axi2ahb/axi_bytes_log_old.txt", "w") ;
end



assign w_ack = axi_w_valid && axi_w_ready;
assign aw_ack = axi_aw_valid && axi_aw_ready;
logic[2:0] axi_aw_size_buffer,size,aw_size_buffer;
logic [AW-1:0] addr,aw_address_buffer,address;
always @(posedge clk ) begin

	if(aw_ack) begin
		$fwrite(old_log_file,"\naddress=%h :\n", axi_aw_addr );

	end

	if (aw_ack)begin 
		aw_address_buffer<=(axi_aw_addr&~((1<<axi_aw_size)-1))+2**axi_aw_size;	
		aw_size_buffer<=axi_aw_size;
	end else if (w_ack) begin
		aw_address_buffer<=aw_address_buffer+2**aw_size_buffer;
	end



	if(w_ack) begin
		automatic int j=0;
		for (int i = addr%(DW/8); i < DW/8; i++) begin
			address =addr + j; // (addr&~((1<<size)-1))
			if(axi_w_strb[i]==1'b1) begin
				$fwrite(log_file,"address=%h byte=%h\n", address,axi_w_data[i*8+:8] );
			end
			j++;
		end
	end


	if(w_ack) begin
		for (int i = 0; i < DW/8; i++) begin
			if(axi_w_strb[i]==1'b1) begin
				$fwrite(old_log_file," %h ", axi_w_data[i*8+:8] );
			end
		end
	end

		
end
always_comb begin
	if(aw_ack) begin
		size=axi_aw_size;
		addr=axi_aw_addr;
	end else begin 
		size=aw_size_buffer;
		addr=aw_address_buffer;
	end

end

endmodule