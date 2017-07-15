/**
 * @info fifo_duth
 *
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 *
 * @brief FIFO circular buffer. Uses an input decoder to store to the proper place and an output MUX to select the proper output data.
 *
 * @param DATA_WIDTH data width
 * @param RAM_DEPTH number of buffer slots. Note: If 1, leads to 50% throughput, so use @see eb_one_slot with FULL_THROUGHPUT asserted.
 */
 
module fifo_duth
    #(  parameter int DATA_WIDTH    = 16,
        parameter int RAM_DEPTH	    = 4)
    (   input  logic                    clk,
        input  logic                    rst,
        // input channel
        input  logic[DATA_WIDTH-1:0]    push_data,
        input  logic                    push,
        output logic                    ready,
        // output channel
        output logic[DATA_WIDTH-1:0]    pop_data,
        output logic                    valid,
        input  logic                    pop);
    
logic[DATA_WIDTH-1:0] mem[RAM_DEPTH-1:0];
    
logic[RAM_DEPTH-1:0] pop_pnt, push_pnt;
logic[RAM_DEPTH  :0] status_cnt;

assign valid = ~status_cnt[0];
assign ready = ~status_cnt[RAM_DEPTH];

//Pointer update (one-hot shifting pointers)
always_ff @ (posedge clk, posedge rst) begin: pnts
    if (rst) begin
        push_pnt <= 1;
        pop_pnt <= 1;
    end else begin
        // push pointer
        if (push) push_pnt <= {push_pnt[RAM_DEPTH-2:0], push_pnt[RAM_DEPTH-1]};
        // pop pointer
        if (pop)  pop_pnt <= {pop_pnt[RAM_DEPTH-2:0], pop_pnt[RAM_DEPTH-1]};
    end
end
    
// assign full_s = ;
// assign valid_s = ;
    
// Status (occupied slots) Counter
always_ff @ (posedge clk, posedge rst) begin: st_cnt
    if (rst) begin
        status_cnt <= 1; // status counter onehot coded
    end else if (push & (!pop) ) begin
        // shift left status counter (increment)
        status_cnt <= { status_cnt[RAM_DEPTH-1:0],1'b0 } ;
    end else if ( (!push) &  pop ) begin
	     // shift right status counter (decrement)
         status_cnt <= {1'b0, status_cnt[RAM_DEPTH:1] };
    end
end
 
// data write (push) 
// address decoding needed for onehot push pointer
always_ff @ (posedge clk) begin: reg_dec
    for (int i=0; i < RAM_DEPTH; i++) begin
        if ( push & push_pnt[i] ) begin
            mem[i] <= push_data;
        end
    end
end

// Convert Unpacked to Packed - Bit-Blasted to use with and_or_multiplexer
logic[RAM_DEPTH*DATA_WIDTH-1:0] mem_to_mux;
always_comb begin: type_ch
    for (int i=0; i<RAM_DEPTH; i++) begin
        mem_to_mux[i*DATA_WIDTH +: DATA_WIDTH] <= mem[i];
    end
end
// 
and_or_multiplexer #( .INPUTS       (RAM_DEPTH),
                      .DATA_WIDTH   (DATA_WIDTH))
    mux_out ( .data_in  (mem_to_mux),
              .sel      (pop_pnt),
              .data_out (pop_data));
    
assert property (@(posedge clk) disable iff(rst) push |-> ready) else $fatal(1, "Pushing on full!");
assert property (@(posedge clk) disable iff(rst) pop |-> valid) else $fatal(1, "Popping on empty!");
assert property (@(posedge clk) disable iff(rst) !$isunknown(push)) else $fatal(1, "X/Z on push");
assert property (@(posedge clk) disable iff(rst) !$isunknown(pop)) else $fatal(1, "X/Z on pop");
endmodule
