module random_strobe_gen
			#(
				parameter DW =64,
				parameter STROBE_RANDOM_RATE = 0
			)(	
				input logic clk,
				input logic rst_n,
				input logic  axi_w_valid_o,
				input logic axi_w_ready,
				input logic [DW/8-1:0] axi_w_strb,
				input logic [DW-1:0] axi_w_data,
				output logic [DW/8-1:0] random_axi_w_strb_out
			);

logic [DW/8-1:0] random_strobe,random_strobe_b;
logic valid_wait_for_w_ready;
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		// random_strobe<=$urandom_range(2**(DW/8-1),0);
	end else begin
		if(axi_w_valid_o && ~axi_w_ready) begin
			valid_wait_for_w_ready<=1'b1;
			random_strobe_b<=random_strobe;
		end else begin 
			valid_wait_for_w_ready<=0;
		end

		
	end
end
always_comb begin 
	if(valid_wait_for_w_ready) begin
		random_strobe = random_strobe_b;
	end else if(axi_w_data) begin
		for (int i = 0; i <= DW/8-1; i++) begin
			// an axi_w_strb[i]==1'b1 kai yparxei toulaxiston allos enas assos (wste na min yparxei periptwsi na steilw pote ola ta strobe midenika)
			if(axi_w_strb[i]==1'b1) begin 
				if(STROBE_RANDOM_RATE>$urandom_range(99,0) && |(axi_w_strb>>(i+1))==1'b1) begin
					random_strobe[i]=0;
				end else begin 
					random_strobe[i]=1'b1;
				end
				
			end else begin 
				random_strobe[i]=0;
			end
		end
	end else begin 
		random_strobe= axi_w_strb;
	end
	random_axi_w_strb_out = random_strobe;
end





endmodule // random_strobe_gen