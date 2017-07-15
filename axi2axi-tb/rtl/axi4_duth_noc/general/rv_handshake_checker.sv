/** 
 * @info 
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief 
 *
 * @param 
 */ 

import axi4_duth_noc_pkg::*;

module rv_handshake_checker
	#(parameter int DATA_WIDTH = 32,
      parameter logic ASSERT_EN = 1'b1)
	(input logic clk,
	 input logic rst,
	 // Input Channel
     input logic[DATA_WIDTH-1:0] data,
     input logic                 valid,
     input logic                 ready);

// pragma synthesis_off
// pragma translate_off

//logic[DATA_WIDTH-1:0] last_data;
logic cur_data_pending;

// Check that data are consistent
always @(posedge clk, posedge rst) begin: check_data
    if (rst) begin
        cur_data_pending <= 1'b0;
    end else begin
        if (!cur_data_pending) begin
            // last data was successfully received
            if (valid && !ready) begin
                cur_data_pending <= 1'b1;
            end
        end else begin
            // last data was not received
            if (valid) begin
                // sender should retry on the same data!
                if (ready) begin
                    cur_data_pending <= 1'b0;
                end
            end
        end
    end
end

assert property (@(posedge clk) disable iff(rst) (valid && !ready) |=> $stable(data)) else $warning("V: Sender data was not received but Sender changed them!");
assert property (@(posedge clk) disable iff(rst) cur_data_pending |-> $stable(data)) else $warning("C: Sender data was not received but Sender changed them!");
assert property (@(posedge clk) disable iff(rst) (valid && !ready) |=> $stable(valid)) else $warning("Sender dropped its valid before reception!");

// pragma translate_on
// pragma synthesis_on


endmodule
