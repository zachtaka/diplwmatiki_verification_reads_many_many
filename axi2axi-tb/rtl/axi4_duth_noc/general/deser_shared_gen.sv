/** 
 * @info deserializer supporting 2 different serialization values
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Deserializer that supports 2 deser values (COUNT_0, COUNT_1), with the currently active one is selected by 'count_sel'.
 *        The COUNT_MAX=max(COUNT_0, COUNT_1) determines the amount of registers required (COUNT_MAX-1).
 *        Either count value can be 1, even both of them, in which case a dummy module is generated (no deserialization)
 *        Caution: Once 'valid_in' is asserted, 'count_sel' signal should remain unchanged until all data are flushed
 *        
 * @param SER_WIDTH Width of input data
 * @param COUNT_0 1st seriliazation value
 * @param COUNT_2 2nd seriliazation value
 */         

import axi4_duth_noc_pkg::*;

module deser_shared_gen
  #(parameter int SER_WIDTH	= 16,
    parameter int COUNT_0	= 2,
    parameter int COUNT_1	= 1)
   (input logic clk, 
    input logic rst,
    input logic count_sel,

    // Input Channel (ready/valid assumed)
    input logic[SER_WIDTH-1:0] serial_in,
    input logic valid_in,
    output logic ready_out,
   
    // Output Channel (ready/valid assumed)
    output logic[SER_WIDTH*COUNT_0-1:0] parallel_out_0,
    output logic[SER_WIDTH*COUNT_1-1:0] parallel_out_1,
    output logic valid_out,
    input  logic ready_in);

localparam COUNT_MAX = get_max2(COUNT_0, COUNT_1);

logic[COUNT_MAX-1:0] cnt_cur;
logic last_remaining, ready_out_tmp;

assign ready_out = ready_out_tmp;
assign valid_out = last_remaining & valid_in;
    
// it's actually full when not(last_remaining)
assign ready_out_tmp = ready_in | (~last_remaining);
    
// serial_in is the last data packet expected
// data = serial_in & data(m-2) & ... & data(0)
    
// Out 0
genvar r;
generate
    if (COUNT_0 == 1) 
        assign parallel_out_0 = serial_in;

    if (COUNT_1 == 1)
        assign parallel_out_1 = serial_in;

    // Check to see if made as a packed logic type
    logic[SER_WIDTH-1:0] regf[COUNT_MAX-2:0];
   
    if (COUNT_MAX > 1) begin
        // Out 0
        if (COUNT_0 > 1) begin
            assign parallel_out_0[COUNT_0*SER_WIDTH-1: (COUNT_0-1)*SER_WIDTH] = serial_in;
            for (r = 0; r < COUNT_0-1; r=r+1) begin: for_r
                assign parallel_out_0[(r+1)*SER_WIDTH-1:r*SER_WIDTH] = regf[r];
			   end
        end

        //Out 1
        if (COUNT_1 > 1) begin
            assign parallel_out_1[COUNT_1*SER_WIDTH-1:(COUNT_1-1)*SER_WIDTH] = serial_in;
            for (r=0; r < COUNT_1-1; r=r+1) begin: for_r
                assign parallel_out_1[(r+1)*SER_WIDTH-1:r*SER_WIDTH] = regf[r];
				end
          end        
        
        // sync write data
        always_ff @(posedge clk) begin
            for (int i=0; i < COUNT_MAX-1; i++)
                if (valid_in & ready_out_tmp & cnt_cur[i])
                    regf[i] <= serial_in;
            end
        
        // Counter update (one-hot ring)
        always_ff @ (posedge clk, posedge rst) begin
            if (rst)
                cnt_cur <= 1;
            else
                if (valid_in & ready_in & last_remaining) // reset
                    cnt_cur <= 1;
                else if (valid_in & ready_out_tmp)// rol
                    cnt_cur <= { cnt_cur[COUNT_MAX-2:0], cnt_cur[COUNT_MAX-1]};
        end
    end  // if (count_max > 1)

    if (COUNT_MAX == 1)
        assign cnt_cur[0]= 1'b1;

    assign last_remaining = (cnt_cur[COUNT_1-1] & count_sel) | 
                            (cnt_cur[COUNT_0-1] & (~count_sel) );


    
endgenerate



endmodule
