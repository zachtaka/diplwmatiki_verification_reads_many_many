import ahb_pkg::*;
parameter int TIDW = 1;
parameter int AW  = 32;
parameter int DW  = 64;
parameter int USERW  = 1;

module ahb_bytes_to_send_logger (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	logic HREADY,
	logic [AHB_ADDRESS_WIDTH-1:0] HADDR,
	logic [AHB_DATA_WIDTH-1:0] HWDATA,
	logic HWRITE,
	logic [2:0] HSIZE,
	logic [1:0] HTRANS
);


// state encoding
state_t state;
assign state=state_t'(HTRANS);

int log_file2;
initial begin 
	log_file2 = $fopen("C:/Users/zacarry/Desktop/Verilog/axi2ahb/ahb_bytes.txt", "w") ;
end



logic write_data_phase;
logic [AHB_ADDRESS_WIDTH-1:0] address;
logic [63:0] size;
assign waiting_for_HREADY= write_data_phase && ~HREADY ;
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		write_data_phase<=0;
		address<=0;
		size<=0;
	end else begin
		if((state==NONSEQ || state==SEQ) && HREADY && HWRITE) begin
			write_data_phase<=1'b1;
			address<=HADDR;
			size<=HSIZE;
		end else if(HREADY && state!==BUSY) begin 
			write_data_phase<=0;
			address<=0;
			size<=0;
		end
	end
end
int lower_byte_lane,upper_byte_lane;
assign lower_byte_lane=address%(DW/8);
assign upper_byte_lane=address%(DW/8)+2**size;
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
	end else begin
		

		if(write_data_phase && HREADY && state!==BUSY) begin
			automatic int j=0;
			for (int i = 0; i < DW/8; i++) begin
				
				if(i>=lower_byte_lane && i<upper_byte_lane ) begin
					$fwrite(log_file2,"address=%h byte=%h\n",address+j, HWDATA[i*8+:8] );
					j++;
				end
			end
		end


		if(state==NONSEQ && HWRITE) begin
			// $fwrite(log_file2,"\naddress=%h :\n", HADDR );
		end
	end
end




endmodule