import ahb_pkg::*;
module request_path 
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

		// -- common signals -- //
		input logic pending_write,
		input logic pending_read,
		input logic write_b_ack,
		input logic read_queue_ready,
		input logic read_beats_count_less_than_ar_len_buffer,
		input logic reset_pending_read,
		input logic r_last_beat,

		output logic set_pending_write,
		output logic reset_pending_write,
		output logic set_pending_read,
		output logic set_ar_len_buffer,
		output logic push_TID_queue,
		output logic is_write_first_single_beat,
		output logic set_waiting_ahb_slave_response,
		

		// -- common signals -- //



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











////////
// Registers
logic waiting_split_to_end,first_single_beat;
logic [AHB_DATA_WIDTH-1:0]w_data_buffer;
logic [63:0] max_pending_writes;
logic [2:0]aw_size_buffer,ar_size_buffer;
logic [AHB_ADDRESS_WIDTH-1:0]aw_address_buffer,ar_address_buffer;

// Comb signals 
logic can_accept_AW,aw_ack,ar_ack;

// strobe signals
logic [$clog2(DW/8)-1:0] lower_byte_lane,upper_byte_lane;
logic [AHB_ADDRESS_WIDTH-1:0] start_address,aligned_address;
logic [$clog2(DW/8):0] number_bytes;
logic all_strobes_ace;
logic [DW/8-1:0] w_strobes,local_strb,strobe_buffer;
logic start_splitting,keep_splitting,split;

// unaligned signals
logic [AHB_ADDRESS_WIDTH-1:0] aw_aligned_addr,ar_aligned_addr;
logic address_is_unaligned;


// state encoding
state_t state;
assign HTRANS=state_t'(state);
// burst encoding
burst_t burst_type;
assign HBURST = burst_t'(burst_type);

// DEBUG FILE - REMOVE THIS
// int dbg_file;
// initial begin 
// 	dbg_file = $fopen("fsm_begug.txt","w");
// end




// outputs
assign set_pending_write = aw_ack;
assign reset_pending_write = (axi_w_last_i && axi_w_valid_i && axi_w_ready_o&& (~split || (split && |local_strb==0)))||(waiting_split_to_end && HREADY && |local_strb==0);

assign set_pending_read = ar_ack;

assign set_ar_len_buffer = ar_ack;

assign set_waiting_ahb_slave_response = (axi_w_last_i && axi_w_valid_i && axi_w_ready_o&&(~split || (split && |local_strb==0)))||(waiting_split_to_end && HREADY && |local_strb==0);

assign push_TID_queue = is_write_first_single_beat || ar_ack;

// internal signals
logic w_ack;
assign w_ack = axi_w_valid_i && axi_w_ready_o;
assign aw_ack = axi_aw_valid_i && axi_aw_ready_o;
assign ar_ack = axi_ar_valid_i && axi_ar_ready_o;


logic write_request, read_request;
logic write_grant, read_grant;
rr_arbiter #(
		.N(2),
		.PRI_RST(0)
	) inst_rr_arbiter (
		.clk        (HCLK),
		.rst        (~HRESETn),
		.request    ({write_request,read_request}),
		.grant      ({write_grant,read_grant}),
		.update_pri (1'b1)
	);

always_comb begin 
	write_request = axi_aw_valid_i && axi_w_valid_i && ~(pending_write || pending_read) && can_accept_AW && HREADY;
	read_request = axi_ar_valid_i && ~(pending_write || pending_read) && HREADY ;
end



always_ff @(posedge HCLK or negedge HRESETn) begin 
	if(~HRESETn) begin
		waiting_split_to_end<=0;
		w_data_buffer<=0;
		max_pending_writes <= MAX_PENDING_WRITES;
	end else begin


		if(axi_w_last_i && w_ack && split && |local_strb!==0) begin
			waiting_split_to_end<=1'b1;
		end else if(|local_strb==0 && HREADY) begin
			waiting_split_to_end<=0;
		end

		


		// HWDATA = w_data_buffer
		if(w_ack) begin
			w_data_buffer<=axi_w_data_i;
		end


		// ena aw meiwnei ton counter max_pending_writes, enw ena write_b_ack (kai dn ginetai aw ack) auksanei to max_pending_writes 
		if(write_b_ack && ~aw_ack) begin
			max_pending_writes <= max_pending_writes + 1;
		end else if(~write_b_ack && aw_ack ) begin
			max_pending_writes <= max_pending_writes - 1;
		end 

	end
end


// ena aw meiwnei ton counter max_pending_writes, enw ena write_b_ack (kai dn ginetai aw ack) auksanei to max_pending_writes 
always_comb begin 
	if(max_pending_writes!==0) begin
		can_accept_AW = 1'b1;
	end else begin 
		can_accept_AW = 0;
	end
end


///////////////////////////////////////
//// AW & AR Buffers
///////////////////////////////////////
always_ff @(posedge HCLK or negedge HRESETn) begin
	if(~HRESETn) begin
		aw_size_buffer<=0;
		aw_address_buffer<=0;
		ar_size_buffer<=0;
		ar_address_buffer<=0;
	end else begin
		// AW Buffers
		if (is_write_first_single_beat)begin 
			aw_size_buffer<=axi_aw_size_i;
			if(start_splitting && |local_strb!==0) begin
				aw_address_buffer<=aw_aligned_addr;
			end else begin
				aw_address_buffer<=aligned_address+2**axi_aw_size_i;
			end
		end else if (pending_write) begin 
			if( ((split && |local_strb==0)||(~split)) && axi_w_valid_i && HREADY) begin
				aw_address_buffer<=aw_address_buffer+2**aw_size_buffer;
			end 
		end

		// AR Buffers
		if(ar_ack) begin
			ar_size_buffer<=axi_ar_size_i;
			ar_address_buffer<=ar_aligned_addr+2**axi_ar_size_i;
		end else begin 
			if(HREADY && read_queue_ready) begin
				ar_address_buffer<=ar_address_buffer+2**ar_size_buffer;
			end
		end
	end
end




////////////////////////////////////////
////// AHB master interface
////////////////////////////////////////
//// @HTRANS or @state
// always_comb begin 
// 	if(write_grant || read_grant) begin
// 		state=NONSEQ;
// 	end else begin
// 		if(pending_write) begin
// 			if((split || axi_w_valid_i) && HREADY ) begin
// 				state=NONSEQ;
// 			end else begin 
// 				state=IDLE;
// 			end			
// 		end else if(pending_read) begin
// 			if(~read_queue_ready) begin 
// 				state=BUSY;
// 			end else if(read_beats_count_less_than_ar_len_buffer) begin
// 				state=SEQ;
// 			end else begin 
// 				state=IDLE;
// 			end
// 		end else begin 
// 			state=IDLE;
// 		end
// 	end
// end
// state FSM
state_t state_fsm, next_state_fsm,dbg_state,dbg_state2;
always_ff @(posedge HCLK or negedge HRESETn) begin
	if(~HRESETn) begin
		state_fsm <= IDLE;
		// dbg_state2 <= IDLE;
	end else begin
		state_fsm <= next_state_fsm;
		// dbg_state2 <= state;
		// if(dbg_state2 !== state_fsm) begin
		// 	$fwrite(dbg_file,"\n @%0t dbg_state2=%s state_fsm=%s",$time,dbg_state2,state_fsm);
		// end
	end
	
end
always_comb begin
	case (state_fsm)
		IDLE : 
		begin 
			// writes
			// -> NONSEQ otan exw eite write_grant eite eimai se write kai exw ta epomena data i sunexizw to split kai exw HREADY apo ton slave
			if((write_grant)||(pending_write && (axi_w_valid_i || split) && HREADY)) begin
				next_state_fsm = NONSEQ;
			end else if(read_grant) begin
				next_state_fsm = NONSEQ;
			end else begin 
				next_state_fsm = IDLE;
			end
		end
		NONSEQ :
		begin 
			// writes
			// an eimai se NONSEQ se ena write tote an kanw split kai exw kai HREADY synexizw me to split
			if(pending_write && split && HREADY) begin	
				next_state_fsm = NONSEQ;
			end else if(reset_pending_read) begin
				next_state_fsm = IDLE;
			end else if(read_queue_ready && read_beats_count_less_than_ar_len_buffer && pending_read) begin
				next_state_fsm = SEQ;
			end else if(~read_queue_ready && pending_read) begin
				next_state_fsm = BUSY;
			end  else begin 
				next_state_fsm = IDLE;
			end
		end

		SEQ: 
		begin 
			if(~read_queue_ready) begin
				next_state_fsm = BUSY;
			end else if(read_queue_ready && read_beats_count_less_than_ar_len_buffer) begin
				next_state_fsm = SEQ;
			end else if(reset_pending_read) begin 
				next_state_fsm = IDLE;
			end else begin 
				next_state_fsm = IDLE;
			end
		end

		BUSY:
		begin 
			if(read_queue_ready && read_beats_count_less_than_ar_len_buffer) begin
				next_state_fsm = SEQ;
			end else if(read_queue_ready && r_last_beat) begin
				next_state_fsm = IDLE;
			end else begin 
				next_state_fsm = BUSY;
			end
		end

		default : next_state_fsm = IDLE;
	endcase
	// dbg_state = next_state_fsm;
	state = next_state_fsm;

end



// @HADDR
// edw dn ginetai na antikatastisw to aw_ack me state==NONSEQ && HWRITE, gt spaw se singles stin ahb meria opote kathe fora pou exw NONSEQ dn simainei pws vgazw to axi_aw_addr_i
// alla auto se periptwsi pou dexomaste ar otan den uparxei aw_valid stin eisodo, an allaksei auto xalaei nomizw to is_write_first_single_beat
assign is_write_first_single_beat = first_single_beat && axi_aw_valid_i && axi_w_valid_i && HREADY && write_grant;
always_comb begin
	if(is_write_first_single_beat && split) begin
		HADDR = axi_aw_addr_i + first_ace_pos(w_strobes,lower_byte_lane) - lower_byte_lane;
	end else if(is_write_first_single_beat && ~split) begin
		HADDR = axi_aw_addr_i;
	end else if(ar_ack) begin
		HADDR = ar_aligned_addr;
	end else if(pending_write && split) begin
		HADDR = aw_address_buffer + first_ace_pos(w_strobes,lower_byte_lane) - lower_byte_lane;
	end else if(pending_write && ~split) begin
		HADDR = aw_address_buffer;
	end else if(pending_read) begin
		HADDR = ar_address_buffer;
	end else begin 
        		HADDR = 0;
    	end
end


// @HSIZE
always_comb begin 
	if(is_write_first_single_beat && split) begin
		HSIZE = 0;
	end else if(is_write_first_single_beat && ~split) begin
		HSIZE = axi_aw_size_i;
	end else if(ar_ack ) begin
        		HSIZE = axi_ar_size_i;
    	end else if(pending_write && split) begin
    		HSIZE = 0;
    	end else if(pending_write && ~split) begin
		HSIZE = aw_size_buffer;
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
	HWDATA = w_data_buffer;
end

// @HWRITE
always_comb begin 
	if(is_write_first_single_beat) begin
		HWRITE = 1'b1;
	end else if(ar_ack) begin
       		 HWRITE = 0;
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

/////////////////////////
//// AW channel
/////////////////////////
// @axi_aw_ready_o
always_comb begin 
	// otan dn exoume read, i exoume read kai kanoume push to teleutaio beat tou 
	if(HREADY && axi_aw_valid_i && axi_w_valid_i && write_grant) begin  
		axi_aw_ready_o=1'b1;
	end else begin 
		axi_aw_ready_o=0;
	end
end

/////////////////////////
//// W channel
/////////////////////////
// @w_ready_o
always_comb begin
	if(split && |strobe_buffer==1) begin
		axi_w_ready_o=0;
	end else begin 
		if((HREADY && (is_write_first_single_beat || pending_write) && HWRITE && axi_w_valid_i )&&~keep_splitting)  begin
			axi_w_ready_o=1'b1;
		end else begin 
			axi_w_ready_o=0;
		end
	end
	

end


/////////////////////////
//// AR channel
/////////////////////////
// @axi_ar_ready_o
always_comb begin
	if(HREADY && axi_ar_valid_i && read_grant) begin
		axi_ar_ready_o=1'b1 ;
	end else begin 
		axi_ar_ready_o=0;
	end
end



//////////////////////////
//// Write strobes 
//////////////////////////
always_ff @(posedge HCLK or negedge HRESETn) begin 
	if(~HRESETn) begin
		strobe_buffer <= 0;
		first_single_beat<=1'b1;
	end else begin
		if(split && HREADY && state==NONSEQ) begin
			strobe_buffer<=local_strb;
		end


		if( (waiting_split_to_end && |local_strb==0 && HREADY) || (~waiting_split_to_end  && w_ack && axi_w_last_i)	) begin
			first_single_beat<=1'b1;
		end else if(aw_ack && (axi_aw_len_i!==0 || (start_splitting && |local_strb!==0) )  ) begin
			first_single_beat<=0;
		end
	end
end

always_comb begin 
	// upper & lower bytelane calculation
	if(is_write_first_single_beat) begin    //first_single_beat
		start_address = axi_aw_addr_i;
		number_bytes = 2**axi_aw_size_i;
		aligned_address = axi_aw_addr_i & ~((1<<axi_aw_size_i)-1);//(start_address/number_bytes)*number_bytes;
		/////////////
		lower_byte_lane = start_address & ((1<<$clog2(DW/8))-1);  //(start_address-(start_address/(AHB_DATA_WIDTH/8))*(AHB_DATA_WIDTH/8));
		upper_byte_lane = aligned_address + number_bytes -1;  //( aligned_address+(number_bytes-1)-(start_address/(AHB_DATA_WIDTH/8))*(AHB_DATA_WIDTH/8));
	end else begin 
		start_address = 0;
		number_bytes = 2**aw_size_buffer;
		aligned_address = 0;
		//////////////////
		lower_byte_lane= aw_address_buffer & ((1<<$clog2(DW/8))-1);   //aw_address_buffer-(aw_address_buffer/(AHB_DATA_WIDTH/8))*(AHB_DATA_WIDTH/8);
		upper_byte_lane=lower_byte_lane+number_bytes-1;
	end

	
	if(|strobe_buffer) begin
		w_strobes = strobe_buffer;
	end else begin 
		w_strobes = axi_w_strb_i;
	end

	// check if strobes between upper and lower bytelane are all 1
	all_strobes_ace = AND_STROBES(axi_w_strb_i, upper_byte_lane, lower_byte_lane);
	

	// (~all_strobes_ace && w_ack && state!==BUSY)
	// ~all_strobes_ace && axi_w_valid_i && ~keep_splitting && state!==BUSY
	if(|strobe_buffer) begin
		keep_splitting=1'b1;
	end else begin 
		keep_splitting=0;
	end


	if(((~all_strobes_ace && axi_w_valid_i)||address_is_unaligned)&&((write_grant && ~pending_write)||(pending_write))) begin // eite exw w_ack kai exw holes in strobes eite enw unaligned address se write  || (state==NONSEQ && address_is_unaligned)
		start_splitting=1'b1;
	end else begin 
		start_splitting=0;
	end



	split=start_splitting||keep_splitting;

	if(~|strobe_buffer) begin
		local_strb=((axi_w_strb_i>>(first_ace_pos(axi_w_strb_i,lower_byte_lane) +1))<<first_ace_pos(axi_w_strb_i,lower_byte_lane) +1);
	end else begin 
		local_strb=((strobe_buffer>>(first_ace_pos(strobe_buffer,lower_byte_lane) +1))<<first_ace_pos(strobe_buffer,lower_byte_lane) +1);
	end
	

end



///////////////////////////////////
//// Unaligned Address 
///////////////////////////////////
always_comb begin
	aw_aligned_addr = axi_aw_addr_i & ~((1<<axi_aw_size_i)-1);
	ar_aligned_addr = axi_ar_addr_i & ~((1<<axi_ar_size_i)-1);

	if( is_write_first_single_beat && ((HWRITE &&  axi_aw_addr_i!==aw_aligned_addr) || (~HWRITE && axi_ar_addr_i!==ar_aligned_addr))) begin
		address_is_unaligned=1'b1;
	end else begin 
		address_is_unaligned=0;
	end

end










endmodule