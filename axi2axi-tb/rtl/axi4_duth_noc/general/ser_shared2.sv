/** 
 * @info serializer supporting 2 different serialization values
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Serializer that supports 2 ser values (COUNT_0, COUNT_1), with the currently active one is selected by 'count_sel'.
 *        Either count value can be 1, even both of them, in which case a dummy module is generated.
 *        Caution: Once 'valid_in' is asserted, 'count_sel' signal should remain unchanged until all data are fed.
 *        Back notification ('ready_out') can only be asserted when the last data pack is processed.
 *        
 * @param SER_WIDTH Width of output data.
 * @param COUNT_0 1st seriliazation value
 * @param COUNT_2 2nd seriliazation value
 */

import axi4_duth_noc_pkg::*;

module ser_shared2
  #(parameter int SER_WIDTH	= 15,
    parameter int COUNT_0	= 2,
    parameter int COUNT_1	= 1)
   (input logic clk, 
    input logic rst,
    input logic count_sel,

    // Input Channel (ready/valid assumed)
    input logic[SER_WIDTH*get_max2(COUNT_0, COUNT_1)-1:0] parallel_in,
    input logic valid_in,
    output logic ready_out,
    // --
    output logic[get_max2(COUNT_0, COUNT_1)-1:0] cnt_out,
    // --
    // Output Channel (ready/valid assumed)
    output logic[SER_WIDTH-1:0] serial_out,
    output logic valid_out,
    input  logic ready_in);

// we need to load package to see get_max2
localparam COUNT_MAX = get_max2(COUNT_0, COUNT_1);

    
logic[COUNT_MAX-1:0] cnt_cur;
logic last_one;

// sending last
assign ready_out = ready_in & last_one;

assign last_one = (cnt_cur[COUNT_0-1] & (~count_sel) ) | 
                  (cnt_cur[COUNT_1-1] & count_sel );
    
assign cnt_out = cnt_cur;
assign valid_out = valid_in;

// Output MUXing
genvar i, w;
generate 
  if (COUNT_MAX == 1) begin
        assign serial_out = parallel_in;
        assign cnt_cur[0] = 1'b1;
  end     
  else begin
        // Counter update (one-hot ring)
        always_ff @(posedge clk, posedge rst)
          begin
            if (rst)
              cnt_cur <= 1;
            else
              if (valid_in & ready_in & last_one) // reset
                cnt_cur <= 1;
              else
                if (valid_in & ready_in) // rol
                  cnt_cur <= { cnt_cur[COUNT_MAX-2:0], cnt_cur[COUNT_MAX-1] };
          end
        
        //  --- Mux output ---
        and_or_multiplexer #(.INPUTS     (COUNT_MAX),
                             .DATA_WIDTH (SER_WIDTH))
            outmux (.data_in    (parallel_in),
                    .sel        (cnt_cur),
                    .data_out   (serial_out));
  end
endgenerate
    
endmodule    
