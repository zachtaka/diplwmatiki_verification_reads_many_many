/** 
 * @info Address Lookup Table (Slave NI)
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Returns the Slave(s) that serve the given 'address'. The address range served by each slave is
 *        determined by ADDRS_LO and ADDRS_HI vector parameters.
 *
 * @param ADDRESS_WIDTH specifies the address filed width of the transactions (AxADDR)
 * @param EXT_SLAVES specifies the number of the system's AXI Slaves
 * @param ADDRS_LO specifies the lower address bound served by each slave.
 *        The lower address bound of Slave[i] should be found in ADDRS_LO[(i+1)*ADDRESS_WIDTH-1 : i*ADDRESS_WIDTH]
 * @param ADDRS_HI specifies the higher address bound served by each slave.
 *        The higher address bound of Slave[i] should be found in ADDRS_HI[(i+1)*ADDRESS_WIDTH-1 : i*ADDRESS_WIDTH]
 */
import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;

module axi_address_lut
  #(parameter int ADDRESS_WIDTH 						= 32,
    parameter int EXT_SLAVES							= 4,
    parameter [EXT_SLAVES*ADDRESS_WIDTH-1:0] ADDRS_LO	= {EXT_SLAVES*ADDRESS_WIDTH{1'b0}},
    parameter [EXT_SLAVES*ADDRESS_WIDTH-1:0] ADDRS_HI	= {EXT_SLAVES*ADDRESS_WIDTH{1'b1}})
   (input logic[ADDRESS_WIDTH-1:0]  address,
    output logic[EXT_SLAVES-1:0]    slaves);
	
logic[EXT_SLAVES-1 : 0] gt_min, lt_max;

// genvar s;
// generate
//   for(s=0; s < EXT_SLAVES; s++) begin: for_s
//     // Slave asserted when its address is in range (multiple may be asserted, if Ranges overlap)
// 	assign slaves[s] = gt_min[s] & lt_max[s]; // (gt_min[s] & lt_max[s]) ? 1'b1 : 1'b0;
// 	assign gt_min[s] = (address >= ADDRS_LO[s*ADDRESS_WIDTH +: ADDRESS_WIDTH]) ? 1'b1 : 1'b0;
// 	assign lt_max[s] = (address <= ADDRS_HI[s*ADDRESS_WIDTH +: ADDRESS_WIDTH]) ? 1'b1 : 1'b0;
//   end
// endgenerate


logic [ADDRESS_WIDTH-1:0] temp_address;
assign temp_address = address[0 +: 24];
genvar s;
generate
  for(s=0; s < EXT_SLAVES; s++) begin: for_s
    // Slave asserted when its address is in range (multiple may be asserted, if Ranges overlap)
  assign slaves[s] = gt_min[s] & lt_max[s]; // (gt_min[s] & lt_max[s]) ? 1'b1 : 1'b0;
  assign gt_min[s] = (temp_address >= ADDRS_LO[s*ADDRESS_WIDTH +: ADDRESS_WIDTH]) ? 1'b1 : 1'b0;
  assign lt_max[s] = (temp_address <= ADDRS_HI[s*ADDRESS_WIDTH +: ADDRESS_WIDTH]) ? 1'b1 : 1'b0;
  end
endgenerate
	
endmodule
