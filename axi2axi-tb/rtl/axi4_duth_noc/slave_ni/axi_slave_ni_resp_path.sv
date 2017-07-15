/** 
 * @info Response Path of the Slave NI
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief The Response path of the Slave NI includes only the depacketizing unit and a deMUX to feed the proper AXI response channel
 *        with the incoming transaction. Given the maximum tolerated link, the module calculates the proper flit width and the expected
 *        amount of serialization performed at the Master NI in the other side.
 *
 * @param MASTER_ID specifies the ID of the External Master, attached to the Slave NI
 * @param TIDS_M specifies the number of AXI Transaction IDs
 * @param DATA_LANES specifies the number of byte lanes of the Write Data channel (W)
 * @param USER_WIDTH specifies the width of the US field of the AXI channels
 * @param EXT_MASTERS specifies the number of the system's External Masters
 * @param EXT_SLAVES specifies the number of External AXI Slave
 * @param MAX_LINK_WIDTH specifies the maximum tolerated link width. This will feed the functions that decide on the packet
 *        length, flit width, number of flits per transaction etc.
 * @param FLIT_WIDTH_C specifies the width of the flit. This is redundantly passed here, since it is also found inside the module.
 *        It is used, however, to avoid doing all those calculations on the module's interface
 */

import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;


module axi_slave_ni_resp_path
  #(parameter int MASTER_ID 		= 0,
    parameter int TIDS_M            = 16,
    parameter int DATA_LANES		= 32,
    parameter int USER_WIDTH		= 4,
    parameter int EXT_MASTERS		= 2,
    parameter int EXT_SLAVES		= 4,
    parameter int MAX_LINK_WIDTH	= 128,
    parameter int FLIT_WIDTH_C		= 128)
  (input logic clk,
   input logic rst,
   //  Input NoC Channel  //
   input logic[FLIT_WIDTH_C-1 : 0] inp_chan,
   input logic inp_valid,
   output logic inp_ready,
   // Reorder Unit
   output logic reorder_return,
   output logic[1:0] reorder_return_op,
   output logic[log2c_1if1(TIDS_M)-1 : 0] reorder_return_tid, // bin enc
   //  Output AXI Channels  //
   // Write Response (B)
   output logic[log2c_1if1(TIDS_M) + USER_WIDTH + AXI_SPECS_WIDTH_RESP-1 : 0] b_chan,
   output logic b_valid,
   input logic b_ready,
   // Read Data (R)
   output logic[log2c_1if1(TIDS_M) + 8*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_RESP + AXI_SPECS_WIDTH_LAST-1 : 0] r_chan,
   output logic r_valid,
   input logic r_ready);
   
localparam integer AXI_W_B_M    = log2c_1if1(TIDS_M) + USER_WIDTH + AXI_SPECS_WIDTH_RESP;
localparam integer AXI_W_R_M    = log2c_1if1(TIDS_M) + 8*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_RESP + AXI_SPECS_WIDTH_LAST;
    
localparam integer W_HEADER_FULL    = log2c(TIDS_M) + log2c(EXT_SLAVES) + log2c(EXT_MASTERS) + 1 + 1 + FLIT_FIELD_WIDTH;
localparam integer W_HEADER_SMALL   = 1 + 1 + FLIT_FIELD_WIDTH;
    
// to avoid getting flits = 0, trick function
localparam integer FLITS_PER_WRITE  = get_flits_per_resp(MAX_LINK_WIDTH,        AXI_W_B_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FW_WRITE         = get_resp_flit_width_first(MAX_LINK_WIDTH, AXI_W_B_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
    
localparam integer FLITS_PER_READ   = get_flits_per_resp(MAX_LINK_WIDTH,        AXI_W_R_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FW_READ          = get_resp_flit_width_first(MAX_LINK_WIDTH, AXI_W_R_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
    
localparam integer FW_RESP          = get_max2(FW_WRITE, FW_READ);
    
localparam integer FW_WRITE_PAD_LAST    = get_resp_flit_pad_last(FW_RESP, AXI_W_B_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);
localparam integer FW_READ_PAD_LAST     = get_resp_flit_pad_last(FW_RESP, AXI_W_R_M - log2c_1if1(TIDS_M), W_HEADER_FULL, W_HEADER_SMALL);

logic write_select, read_select;
logic deser_cnt_sel;
logic[FLITS_PER_WRITE*FW_RESP-1 : 0] data_from_deser_write;
logic[FLITS_PER_READ*FW_RESP-1 : 0] data_from_deser_read;
logic ready_from_deser, valid_from_deser, ready_to_deser;
    
logic[FW_RESP-1 : 0] write_flits [FLITS_PER_WRITE-1 : 0];
logic[FW_RESP-1 : 0] read_flits [FLITS_PER_READ-1 : 0];
    
logic full_header_passed;
logic[log2c_1if1(TIDS_M)-1 : 0] tid_wr, tid_rd;
logic[AXI_W_B_M - log2c_1if1(TIDS_M)-1 : 0] b_chan_no_tid;
logic[AXI_W_R_M - log2c_1if1(TIDS_M)-1 : 0] r_chan_no_tid;
  
logic r_LAST;
  
assign inp_ready = ready_from_deser;
// TEMPORARILY READ FROM INP!!!! --
assign write_select = (inp_chan[FLIT_FIELD_WIDTH] ==  OP_ID_WRITE) ? 1'b1 : 1'b0;
assign read_select = (inp_chan[FLIT_FIELD_WIDTH] ==  OP_ID_READ) ? 1'b1 : 1'b0;

// Depacketize --------------------------------------------------------------------------------
assign deser_cnt_sel = read_select;

deser_shared2 #(.SER_WIDTH    (FW_RESP),
                .COUNT_0      (FLITS_PER_WRITE),
				.COUNT_1      (FLITS_PER_READ))
deser_both(.clk               (clk),
           .rst			      (rst),
		   .count_sel         (deser_cnt_sel),
		   .serial_in         (inp_chan),
		   .valid_in          (inp_valid),
		   .ready_out         (ready_from_deser),
		   .parallel_out_0    (data_from_deser_write),
		   .parallel_out_1    (data_from_deser_read),
		   .valid_out         (valid_from_deser),
		   .ready_in          (ready_to_deser));
		   
assign ready_to_deser = write_select ? b_ready : r_ready;

assign tid_wr   = TIDS_M > 1 ? write_flits[0][FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)] :
                               1'b0;
assign tid_rd   = TIDS_M > 1 ? read_flits[0][FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)] :
                               1'b0;
// if (TIDS_M > 1) begin
    // // store tid
    // assign tid_wr   = write_flits[0][FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)]; //-1 : FLIT_FIELD_WIDTH+1+1+$clog2(EXT_MASTERS)+$clog2(EXT_SLAVES)];
    // assign tid_rd   = read_flits[0][FLIT_FIELD_WIDTH + 1 + log2c(EXT_MASTERS) + log2c(EXT_SLAVES) +: log2c_1if1(TIDS_M)];//-1 : FLIT_FIELD_WIDTH+1+1+$clog2(EXT_MASTERS)+$clog2(EXT_SLAVES)];
// end else begin
    // assign tid_wr = 1'b0;
    // assign tid_rd = 1'b0;
// end

genvar i;
generate
  // Intermediate
  for(i=0; i < FLITS_PER_WRITE; i=i+1) begin: for_i
    assign write_flits[i] = data_from_deser_write[(i+1)*FW_RESP-1 : i*FW_RESP];
  end
  
  for(i=0; i < FLITS_PER_READ; i=i+1) begin: for_i2
    assign read_flits[i] = data_from_deser_read[(i+1)*FW_RESP-1 : i*FW_RESP];
  end
  
endgenerate
  
// Take useful data from Deser
// write  
assign b_chan_no_tid[FW_WRITE-W_HEADER_FULL-1 : 0] = write_flits[0][FW_WRITE-1 : W_HEADER_FULL];
generate  
  for(i=1; i < FLITS_PER_WRITE; i=i+1) begin: for_i3
    if (i == (FLITS_PER_WRITE-1)) // last
      assign b_chan_no_tid[ FW_RESP-W_HEADER_FULL + (i-1)*(FW_RESP-W_HEADER_SMALL) + (FW_RESP-W_HEADER_SMALL-FW_WRITE_PAD_LAST)-1 :
                           FW_RESP-W_HEADER_FULL + (i-1)*(FW_RESP-W_HEADER_SMALL) ] = 
                write_flits[i][FW_RESP-FW_WRITE_PAD_LAST-1 : W_HEADER_SMALL];
    else
      assign b_chan_no_tid[FW_RESP-W_HEADER_FULL + i*(FW_RESP-W_HEADER_SMALL)-1 : FW_RESP-W_HEADER_FULL + (i-1)*(FW_RESP-W_HEADER_SMALL)] =
                write_flits[i][(i+1)*FW_RESP-1 : i*FW_RESP + W_HEADER_SMALL];
  end
endgenerate

assign b_chan = {b_chan_no_tid, tid_wr};
assign b_valid = valid_from_deser & write_select;

// read
assign r_chan_no_tid[FW_READ-W_HEADER_FULL-1 : 0] = read_flits[0][FW_READ-1 : W_HEADER_FULL];
generate
  for(i=1; i < FLITS_PER_READ; i=i+1) begin: for_i4
    if (i == (FLITS_PER_READ-1)) // last
      assign r_chan_no_tid[ FW_RESP-W_HEADER_FULL + (i-1)*(FW_RESP-W_HEADER_SMALL) + (FW_RESP-W_HEADER_SMALL-FW_READ_PAD_LAST)-1 :
                           FW_RESP-W_HEADER_FULL + (i-1)*(FW_RESP-W_HEADER_SMALL) ] = 
                read_flits[i][FW_RESP-FW_READ_PAD_LAST-1 : W_HEADER_SMALL];
    else
      assign r_chan_no_tid[FW_RESP-W_HEADER_FULL + i*(FW_RESP-W_HEADER_SMALL)-1 : FW_RESP-W_HEADER_FULL + (i-1)*(FW_RESP-W_HEADER_SMALL)] =
                read_flits[i][FW_RESP-1 : W_HEADER_SMALL];
	end
endgenerate
				
assign r_chan = {r_chan_no_tid, tid_rd};
assign r_valid = valid_from_deser & read_select;
    
assign r_LAST = r_chan_no_tid[8*DATA_LANES + AXI_SPECS_WIDTH_RESP];

// Reorder ------------------------------------------------------------------------------------
assign reorder_return = valid_from_deser & ( (read_select & r_LAST & r_ready) | (write_select & b_ready) );
assign reorder_return_op = {read_select, write_select};
assign reorder_return_tid = read_select ? tid_rd : tid_wr;


assert property (@(posedge clk) disable iff(rst || EXT_MASTERS == 1) (inp_valid && flit_is_head(inp_chan)) |-> int'(inp_chan[FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES) +: log2c_1if1(EXT_MASTERS)]) == MASTER_ID) else
    $fatal(1, "[NI at Master] Received flit NOT destined for me!");
   

// pragma synthesis_off
// pragma translate_off
`ifdef NI_VERBOSE
	initial begin
		forever begin
		    @(posedge clk);
		    if (r_valid && r_ready) begin
		        // automatic logic[ADDRESS_WIDTH-1:0] addr_TMP = flit_out[FLIT_FIELD_WIDTH+1+1+log2c(EXT_SLAVES)+log2c(EXT_MASTERS)+log2c(TIDS_M) +: ADDRESS_WIDTH];
		        automatic int dst_TMP;
		        automatic int src_TMP;
		        automatic int tid_TMP1 = tid_rd;
		        automatic int tid_TMP2;
		        automatic int tid_TMP3;

			assert (!write_select) else $fatal(1, "ERRRRRRRR REEEEEEEAD");
		        if (EXT_SLAVES > 1)
		            src_TMP = inp_chan[FLIT_FIELD_WIDTH+1 +: log2c_1if1(EXT_SLAVES)];
		        else
		            src_TMP = 0;
		        
		        if (EXT_MASTERS > 1)
		            dst_TMP = inp_chan[FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES) +: log2c_1if1(EXT_MASTERS)];
		        else
		            dst_TMP = 0;
		        
		        if (TIDS_M > 1) begin
		            tid_TMP2 = inp_chan[FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES)+log2c(EXT_MASTERS) +: log2c_1if1(TIDS_M)];
		            tid_TMP3 = int'(r_chan[log2c_1if1(TIDS_M)-1:0]);
		        end else begin
		            tid_TMP2 = 0;
		            tid_TMP3 = 0;
		        end

		        $display("%0t: S_NI[%0d] <<< NoC %s flit from src=%0d to dest=%0d (%0d-%0d)", $time, MASTER_ID, flittype_to_str(inp_chan), src_TMP, dst_TMP, tid_TMP1, tid_TMP2, tid_TMP3);
		    end


		    if (b_valid && b_ready) begin
		        // automatic logic[ADDRESS_WIDTH-1:0] addr_TMP = flit_out[FLIT_FIELD_WIDTH+1+1+log2c(EXT_SLAVES)+log2c(EXT_MASTERS)+log2c(TIDS_M) +: ADDRESS_WIDTH];
		        automatic int dst_TMP;
		        automatic int src_TMP;
		        automatic int tid_TMP1 = tid_wr;
		        automatic int tid_TMP2;
		        automatic int tid_TMP3;
			assert (write_select) else $fatal(1, "ERRRRRRRR WRITEEEEEEE");

		        if (EXT_SLAVES > 1)
		            src_TMP = inp_chan[FLIT_FIELD_WIDTH+1 +: log2c_1if1(EXT_SLAVES)];
		        else
		            src_TMP = 0;
		        
		        if (EXT_MASTERS > 1)
		            dst_TMP = inp_chan[FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES) +: log2c_1if1(EXT_MASTERS)];
		        else
		            dst_TMP = 0;
		        
		        if (TIDS_M > 1) begin
		            tid_TMP2 = inp_chan[FLIT_FIELD_WIDTH+1+log2c(EXT_SLAVES)+log2c(EXT_MASTERS) +: log2c_1if1(TIDS_M)];
		            tid_TMP3 = int'(b_chan[log2c_1if1(TIDS_M)-1:0]);
		        end else begin
		            tid_TMP2 = 0;
		            tid_TMP3 = 0;
		        end
		        
		        $display("%0t: S_NI[%0d] <<< NoC %s flit from src=%0d to dest=%0d (%0d-%0d-%0d)", $time, MASTER_ID, flittype_to_str(inp_chan), src_TMP, dst_TMP, tid_TMP1, tid_TMP2, tid_TMP3);
		    end
		end
	end
`endif
// pragma translate_on
// pragma synthesis_on

endmodule
