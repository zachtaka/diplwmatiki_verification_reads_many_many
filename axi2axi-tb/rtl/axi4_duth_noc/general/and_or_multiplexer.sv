/**
 * @info and-or-multiplexer
 *
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 *
 * @brief Multiplexer implemented by an AND-OR tree, selected by at-most-one-hot signal ('sel').
 * All inputs and the output have a width of 'DATA_WIDTH'.
 * Input data ('data_in') are in bit-blasted form, i.e. input i should be placed in bits [(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH]
 *
 * @param INPUTS number of inputs
 * @param DATA_WIDTH common data width for each input and the output
 */
 
module and_or_multiplexer
    #(parameter int INPUTS	    = 4,
      parameter int DATA_WIDTH	= 16)
    (input logic[INPUTS*DATA_WIDTH-1:0] data_in,
     input logic[INPUTS-1:0]            sel,
     output logic[DATA_WIDTH-1:0]       data_out);

// version 2, and using variable like operation.
// using 1-bit logic temp exactly as in VHDL. 
// When assignments are = (and not <=) in always blocks 
// temp signal behaves exactly as a variable in VHDL
logic tmp;

always_comb begin: mux
    for(int w=0; w < DATA_WIDTH; w=w+1) begin
        tmp = 0;
        for(int i=0; i < INPUTS; i=i+1) begin
            tmp = tmp | ( sel[i] & data_in[i*DATA_WIDTH + w] );
        end
        data_out[w] = tmp;
    end
end

endmodule
