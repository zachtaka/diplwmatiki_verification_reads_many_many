/** 
 * @info Response Path of Master NI
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief The Response path of the Master NI contains only an AXI response Merge Unit (@see axi_merge_resps)
 *        and the response packetizer (@see axi_resp_packetizer).
 *
 * @param SLAVE_ID specifies the ID of the External Slave, attached to the Master NI
 * @param TIDS_M specifies the number of AXI Transaction IDs at the External Master Side
 * @param ADDRESS_WIDTH specifies the address filed width of the transactions (AxADDR)
 * @param DATA_LANES specifies the number of byte lanes of the Write Data channel (W)
 * @param USER_WIDTH specifies the width of the US field of the AXI channels
 * @param EXT_MASTERS specifies the number of the system's External Masters
 * @param EXT_SLAVES specifies the number of External AXI Slave
 * @param HAS_WRITE specifies if the NI serves Write Requests (simplifies unit if it doesn't)
 * @param HAS_READ specifies if the NI serves Read Requests (simplifies unit if it doesn't)
 * @param MAX_LINK_WIDTH_RESP specifies the maximum tolerated link width of the NoC response path (@see axi_resp_packetizer)
 * @param FLIT_WIDTH_C specifies the width of the response flits.
 */

import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;


module axi_master_ni_resp_path
  #( parameter int SLAVE_ID             = 0,
     parameter int TIDS_M               = 16,
     parameter int ADDRESS_WIDTH        = 32,
     parameter int DATA_LANES           = 4,
     parameter int USER_WIDTH           = 2,
     parameter int EXT_MASTERS          = 4,
     parameter int EXT_SLAVES           = 2, 
     parameter logic HAS_WRITE          = 1'b1,
     parameter logic HAS_READ           = 1'b1,
     parameter int MAX_LINK_WIDTH_RESP  = 128, 
     parameter int FLIT_WIDTH_C         = 128)
   ( input  logic clk, 
     input  logic rst,
     // --- Input AXI Channels ---
     // Write Response
     input  logic[log2c_1if1(TIDS_M) + $clog2(EXT_MASTERS) + USER_WIDTH + AXI_SPECS_WIDTH_RESP-1 : 0] b_chan,
     input  logic b_valid,
     output logic b_ready,
     
     // Read Data
     input  logic[log2c_1if1(TIDS_M) + $clog2(EXT_MASTERS) + 8*DATA_LANES + USER_WIDTH + AXI_SPECS_WIDTH_RESP + AXI_SPECS_WIDTH_LAST-1 : 0] r_chan,
     input  logic r_valid,
     output logic r_ready,
         
     //  ---   Output NoC Channel   ---
     output logic[FLIT_WIDTH_C-1:0] outp_chan,
     output logic outp_valid,
     input  logic outp_ready);
     

logic[1:0] active_channel, update_priority;

//--------------------------
//---   AXI Merge Unit   ---
//--------------------------
axi_merge_resps #( .HAS_WRITE(HAS_WRITE),
                   .HAS_READ(HAS_READ))
  axi_merge( .clk               (clk),
             .rst               (rst),
             .b_valid           (b_valid),
             .r_valid           (r_valid),
             .active_channel    (active_channel),
             .update_pri        (update_priority));
 
//----------------------
//---   Packetizer   ---
//----------------------
axi_resp_packetizer #( .SLAVE_ID        (SLAVE_ID),
                       .TIDS_M          (TIDS_M),
                       .ADDRESS_WIDTH   (ADDRESS_WIDTH),
                       .DATA_LANES      (DATA_LANES),
                       .USER_WIDTH      (USER_WIDTH),
                       .EXT_MASTERS     (EXT_MASTERS),
                       .EXT_SLAVES      (EXT_SLAVES),
                       .MAX_LINK_WIDTH  (MAX_LINK_WIDTH_RESP),
                       .FLIT_WIDTH_C    (FLIT_WIDTH_C))
  packetizer(clk, rst,
             b_chan, b_ready,
             r_chan, r_ready,
             active_channel, update_priority,
             outp_chan, outp_valid, outp_ready);


endmodule     
