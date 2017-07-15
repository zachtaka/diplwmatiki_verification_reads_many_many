/** 
 * @info Fixed Priority Arbiter (FPA)
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Fixed Priority Arbiter (Priority Encoder). Grant the first request found from 0--to-->N-1
 *        position of 'request'. 'grant' is at-most-one-hot - 'anygrant' is the OR-reduced request vector
 *
 * @param N number of input requestors
 */
 
module fpa_smart
  #(parameter int N = 4)
   (input  logic[N-1:0] request,
    output logic[N-1:0] grant,
    output logic        anygrant);
    
logic[N-1:0] winner;

assign winner = (~request)+1;
assign grant  = request & winner;
assign anygrant = |request;

endmodule
