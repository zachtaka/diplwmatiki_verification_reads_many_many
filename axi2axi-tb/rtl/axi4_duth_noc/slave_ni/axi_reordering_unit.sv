/** 
 * @info Transaction Reordering Unit (Slave NI)
 * 
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 * 
 * @brief Tracks transactions leaving the Slave NI and:
 *        Allows multiple transactions, only to the same external Slave destination
 *        Max in-flight transactions required only for counting (set to 1 if slave reorders!)
 *        Request Path:
 *        A transaction presents its TID (req_tid), the Slave(s) (req_avail_dsts) which are available for the transaction's
 *        address (determined by @see axi_address_lut) and the Reordering Unit replies by asserting the 'req_qualifies' signal
 *        if the transaction can be injected to the NoC. If not, the transaction has to wait until it does.
 *        Response Path:
 *        A returning transaction presents its TID (resp_tid) and if valid (resp_valid), the unit decrements its counter to
 *        show that a pending transaction has returned.
 *
 * @param TRANSACTION_IDS specifies the number of AXI Transaction IDs
 * @param EXT_SLAVES specifies the number of External AXI Slave
 * @param OVERLAPPING_ADDRS specifies if the address ranges between different external Slaves. The reordering operation
 *        changes when==true, in which case load-balancing is also activated.
 * @param MAX_PENDING_SAME_DST specifies the maximum number of transactions that are allowed to be in-flight for a single destination
 * @param MASTER_ID specifies the ID of the External Master, attached to the Slave NI
 */

import axi4_duth_noc_pkg::*;
import axi4_duth_noc_ni_pkg::*;

module axi_reordering_unit
  #(parameter int TRANSACTION_IDS       = 16,
    parameter int EXT_SLAVES            = 4,
    parameter logic OVERLAPPING_ADDRS   = 1'b0,
    parameter int MAX_PENDING_SAME_DST  = 16,
    parameter int MASTER_ID             = 0)
   (input logic clk,
    input logic rst,
    // Request
    input logic req_valid,
    input logic[log2c_1if1(TRANSACTION_IDS)-1 : 0]  req_tid, // wbin enc
    input logic[EXT_SLAVES-1 : 0]                   req_avail_dsts, // multiple slaves may be asserted when OVERLAPPING_ADDRS == true
    output logic                                    req_qualifies,
    output logic[ log2c_1if1(EXT_SLAVES)-1 : 0]     req_dst_final,
    // Response returns
    input logic                                     resp_valid,
    input logic[log2c_1if1(TRANSACTION_IDS)-1 : 0]  resp_tid); // wbin enc

function logic[log2c_1if1(EXT_SLAVES)-1:0] onehot_to_wbin_dst(logic[EXT_SLAVES-1:0] inp);
    logic[log2c_1if1(EXT_SLAVES)-1:0] ret;
    ret = 0;
    for (int i=0; i<EXT_SLAVES; i++)
        if (inp[i])
            ret = ret | i;
    return ret;
endfunction
    
// stored DSTs
logic[TRANSACTION_IDS-1 : 0][log2c_1if1(EXT_SLAVES)-1 : 0] last_dst;
    
logic[TRANSACTION_IDS-1 : 0][log2c(MAX_PENDING_SAME_DST+1)-1 : 0] trans_pending;

// request path
logic[TRANSACTION_IDS-1 : 0] req_tid_onehot;
logic[log2c(MAX_PENDING_SAME_DST+1)-1 : 0] req_pending_muxed;
logic req_zero_pending, req_max_pending;
    
logic[log2c_1if1(EXT_SLAVES)-1 : 0] last_dst_muxed_bin;
logic qualifies_with_pending, qualifies_s;
logic[log2c_1if1(EXT_SLAVES)-1 : 0] req_dst_final_s;
    
logic[TRANSACTION_IDS-1 : 0] resp_tid_onehot;
    
// incr/decr
logic[TRANSACTION_IDS-1 : 0] decr, incr;

// Request Path -------------------------------------------------------------------------------
assign req_qualifies = qualifies_s;
assign req_dst_final = req_dst_final_s;
    
// Request qualifies when either (no transaction is pending) OR (pending AND the DST is the same AD not reached MAX)
assign qualifies_s = req_zero_pending | qualifies_with_pending;
    
// Single Destination Slave Allowed
generate
  if (!OVERLAPPING_ADDRS) begin: not_overlap
      logic req_dsts_equal;
      logic[log2c_1if1(EXT_SLAVES)-1 : 0] req_dst_wbin;
      // When transactions are pending, can qualify only when dsts equal and not reached max value
      assign qualifies_with_pending = req_dsts_equal & (~req_max_pending);
      assign req_dst_final_s = req_dst_wbin;
      // convert to wbin
      assign req_dst_wbin = EXT_SLAVES > 1 ? onehot_to_wbin_dst(req_avail_dsts) : 0;
      // compare
      assign req_dsts_equal = (last_dst_muxed_bin == req_dst_wbin) ? 1'b1 : 1'b0;
  end else begin: overlap
      logic[EXT_SLAVES-1 : 0] last_dst_muxed_oh, selected_dst_oh;
      // policy of upd_pri might need to be changed (different priority for each ?)
      logic[EXT_SLAVES-1 : 0] upd_pri;
        
      logic[log2c_1if1(EXT_SLAVES)-1 : 0] selected_dst_bin;
      logic pending_dst_in_avail;
      
      // qualified even if pending only if: DST of pending is among the available DSTs
      assign qualifies_with_pending = pending_dst_in_avail & (~req_max_pending);
      // the final DST is either (the selected one, if no transactions are pending) OR (the dst for which transaction is pending)
      assign req_dst_final_s = (req_zero_pending) ? selected_dst_bin : last_dst_muxed_bin;
        
      // whether the pending DST is among the available ones
      assign pending_dst_in_avail = |(req_avail_dsts & last_dst_muxed_oh);
        
      // last dst wbin -> one-hot
      // wbin_to_onehot
      assign last_dst_muxed_oh = (1'b1 << last_dst_muxed_bin);
      
      // Select one dst from available
      arbitration #(.N          (EXT_SLAVES),
                    .ARB_TYPE   (ARB_TYPES_RR),
                    .PRI_RST    (MASTER_ID % EXT_SLAVES))
      arb_sel (.clk         (clk),
               .rst         (rst),
               .reqs        (req_avail_dsts),
               .grants      (selected_dst_oh),
               .anygnt      (       ),
               .update_pri  (upd_pri));
               
      // logic[EXT_SLAVES-1 : 0] temp_req;
      // assign temp_req = {EXT_SLAVES{req_zero_pending}};
      assign upd_pri = {EXT_SLAVES{req_qualifies & req_valid}};
      // convert it to binary
      assign selected_dst_bin = EXT_SLAVES > 1 ? onehot_to_wbin_dst(selected_dst_oh) : 0;
      
      // using arbiter's result, MUST have selected one!
      assert property (@(posedge clk) disable iff(rst) (req_valid && req_zero_pending) |-> $onehot(selected_dst_oh)) else
        $fatal(1, "Qualifying without pending, but selected dst is NOT one-hot!");
      
    // pragma synthesis_off
    // pragma translate_off
    int count_per_dst_bin[EXT_SLAVES-1:0];
    int count_per_dst_oh[EXT_SLAVES-1:0];
    always_ff @(posedge clk, posedge rst)
        if (rst) begin
            count_per_dst_bin <= '{EXT_SLAVES{0}};
            count_per_dst_oh  <= '{EXT_SLAVES{0}};
        end else if ( req_valid && req_qualifies ) begin
            count_per_dst_bin[int'(req_dst_final)] <= count_per_dst_bin[int'(req_dst_final)] + 1;
            for (int d=0; d<TRANSACTION_IDS; d++)
                if (req_zero_pending && selected_dst_oh[d])
                    count_per_dst_oh[d] <= count_per_dst_oh[d] + 1;
                else if (!req_zero_pending && last_dst_muxed_oh[d])
                    count_per_dst_oh[d] <= count_per_dst_oh[d] + 1;
            // $display(" [reorder] d=%d", req_dst_final);
        end
    
    //assert property (@(posedge clk) disable iff(rst) (req_valid && req_qualifies) |=> (count_per_dst_oh == count_per_dst_bin)) else
    //    $fatal(1, "ineq dst tracking!");
    // pragma translate_on
    // pragma synthesis_on
    end
endgenerate

// compare for Zero & Max
assign req_zero_pending = (!req_pending_muxed) ? 1'b1 : 1'b0;
assign req_max_pending =  (req_pending_muxed == MAX_PENDING_SAME_DST) ? 1'b1 : 1'b0;
// MUX to get last DST for TID
if (EXT_SLAVES > 1) begin: if_sl_gt1
    if (TRANSACTION_IDS > 1) begin
        and_or_multiplexer
                #(  .INPUTS     (TRANSACTION_IDS),
                    .DATA_WIDTH (log2c_1if1(EXT_SLAVES)))
            mux_dst
                (   .data_in    (last_dst),
                    .sel        (req_tid_onehot),
                    .data_out   (last_dst_muxed_bin));
    end else begin
        assign last_dst_muxed_bin = last_dst[0];
    end
end else begin: if_sl_eq1
    assign last_dst_muxed_bin = 1'b0;
end

if (TRANSACTION_IDS > 1) begin
    // MUX to get the number of pending transactions for TID
    and_or_multiplexer
            #(  .INPUTS     (TRANSACTION_IDS),
                .DATA_WIDTH (log2c(MAX_PENDING_SAME_DST+1)))
        mux_pending
            (   .data_in    (trans_pending),
                .sel        (req_tid_onehot),
                .data_out   (req_pending_muxed));
end else begin
    assign req_pending_muxed = trans_pending[0];
end
// Decode TIDs --------------------------------------------------------------------------------
logic[2**log2c_1if1(TRANSACTION_IDS)-1 : 0] dec_tid_req_tmp, dec_tid_ret_tmp;

assign dec_tid_req_tmp = TRANSACTION_IDS > 1 ? (1'b1 << req_tid) : 1'b1;
assign req_tid_onehot = dec_tid_req_tmp[TRANSACTION_IDS-1 : 0];

assign dec_tid_ret_tmp = TRANSACTION_IDS > 1 ? (1'b1 << resp_tid) : 1'b1;
assign resp_tid_onehot = dec_tid_ret_tmp[TRANSACTION_IDS-1 : 0];

genvar i;
generate
for (i = 0; i < TRANSACTION_IDS; i++) begin: for_t
    // final increment or decrement must check req validity
    assign decr[i] = resp_valid & resp_tid_onehot[i];
    assign incr[i] = req_valid & qualifies_s & req_tid_onehot[i];
    always_ff @(posedge clk, posedge rst) begin: cnt_pending
        if (rst) begin
            trans_pending[i] <= 0;
            //  no need to reset DST (when pending=0, 'qualifies_s' is asserted regardless of DST in that case)
        end else
            if (decr[i] & ~incr[i]) begin
                // Transaction resp_valid -> Decrease
                trans_pending[i] <= trans_pending[i] - 1;
            end else if (~decr[i] & incr[i]) begin
                // Transaction Qualifies -> Increase + Save DST
                trans_pending[i] <= trans_pending[i] + 1;
                last_dst[i] <= req_dst_final_s;
            end
    end

    assert property (@(posedge clk) disable iff(rst)  (decr[i] && !incr[i]) |-> trans_pending[i] > 0) else
        $fatal(0, "[reorder] trans_pending decreased but ZERO!");
    assert property (@(posedge clk) disable iff(rst)  (!decr[i] && incr[i]) |-> trans_pending[i] <= MAX_PENDING_SAME_DST) else
        $fatal(0, "[reorder] trans_pending increased but MAX!");
end

assert property (@(posedge clk) disable iff(rst)  $onehot0(decr)) else $fatal(1, "[reorder] multiple TID return?");
assert property (@(posedge clk) disable iff(rst)  $onehot0(incr)) else $fatal(1, "[reorder] multiple TID request?");

endgenerate
endmodule
