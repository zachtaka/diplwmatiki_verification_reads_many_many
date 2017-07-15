
package axi_scoreboard_pkg;
import axi_transactions_pkg::*;

// Scoreboard assumes ORDERED arrival of the same TID to the same Destination!
class axi_data_scoreboard
#(
    parameter int ADDRESS_WIDTH = 32,
    parameter int SOURCES       = 1,
    parameter int DESTINATIONS  = 1
);
    //
    const int TIDS_M;
    const string MY_NAME;
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_byte_req_src[SOURCES][];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_byte_req_dst[DESTINATIONS];
    
    logic drained;
    semaphore lock_src_mb[SOURCES][];
    
    function new(int TIDS_M_,
                 mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_byte_req_src_[SOURCES][],
                 mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH))) mb_byte_req_dst_[DESTINATIONS],
                 string MY_NAME_);
        TIDS_M = TIDS_M_;
        MY_NAME = MY_NAME_;
        
        foreach(mb_byte_req_src_[s]) begin
            assert(mb_byte_req_src_[s].size() == TIDS_M) else $fatal(1, "SB %s: mb_byte_req_src_[%0d].size() == %0d - should be %0d", MY_NAME, s, mb_byte_req_src_[s].size(), TIDS_M);
        end
        
        mb_byte_req_src = mb_byte_req_src_;
        mb_byte_req_dst = mb_byte_req_dst_;
        
        for (int s=0; s<SOURCES; s++) begin
            lock_src_mb[s] = new[TIDS_M];
            for (int t=0; t<TIDS_M; t++) begin
                lock_src_mb[s][t] = new(1);
            end
        end
    endfunction
    
    // task wait_for_mb(int dst, output axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH)) byte_out);
        // mb_byte_req_dst[dst].get(byte_out);
        // // found = 1'b1;
    // endtask
    
    task wait_for_mb(int dst);
        axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH)) byte_got;
        axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH)) byte_top;
        
        forever begin
            // wait for a byte to be received on DST mb
            mb_byte_req_dst[dst].get(byte_got);
`ifdef SB_VERBOSE
            $display("%0t: SB %s: d=%0d - got a byte: %s", $time, MY_NAME, dst, byte_got.to_str());
`endif
            
            assert (byte_got.src inside {[0:SOURCES-1]}) else
                $fatal(1, "SB %s: %0d got a byte with src_id=%0d, out of range [%0d:%0d]", MY_NAME, dst, byte_got.src, 0, SOURCES-1);
            assert (byte_got.tid inside {[0:TIDS_M-1]}) else
                $fatal(1, "SB %s: %0d got a byte with tid=%0d, out of range [%0d:%0d]", MY_NAME, dst, byte_got.tid, 0, TIDS_M-1);
            
            // once the byte is got, wait for lock to be released on source mb
            lock_src_mb[byte_got.src][byte_got.tid].get();
            // Find it in source MB
            assert(mb_byte_req_src[byte_got.src][byte_got.tid].try_get(byte_top)) else
                $fatal(1, "SB %s: Got byte %0s but no byte at source %0d, tid %0d!", MY_NAME, byte_got.to_str(), byte_got.src, byte_got.tid);
            assert(byte_got.compare(byte_top)) else
                $fatal(1, "SB %s: Bytes not equal!\nReceived: %s\nExpected: %s", MY_NAME, byte_got.to_str(), byte_top.to_str());
            // release the lock
            lock_src_mb[byte_got.src][byte_got.tid].put();
        end
    endtask
    
    task start();
//        $display("%0t: SB ENTERS FORK --->", $time);
        fork begin: iso_thread
            for(int dd=0; dd<DESTINATIONS; dd++) begin
                fork
                    automatic int d = dd;
                begin
                    wait_for_mb(d);
                end join_none
            end
            
            wait fork;
        end join_none
//        $display("%0t: SB LEAVES FORK --->", $time);
    endtask
    
    task wait_for_drain(int CLK_PERIOD);
        fork begin: iso_thread
            for(int ss=0; ss<SOURCES; ss++) begin
                fork
                    automatic int s = ss;
                begin
                    for (int tt=0; tt<TIDS_M; tt++) begin
                        fork
                            automatic int t = tt;
                        begin
                            // VCS does not support this
`ifdef VSIM
                            wait(mb_byte_req_src[s][t].num() == 0);
`else
                            while (mb_byte_req_src[s][t].num() > 0) begin
                                #(CLK_PERIOD);
                            end
`endif // VSIM
                        end join_none
                    end
                    wait fork;
                end join_none
                
                $display("%0t: SB %s: waiting for source-side MBs to drain", $time, MY_NAME);
                wait fork;
            end
        end join
        
        drained = 1'b1;
        
        $display("%0t: SB %s:  drained", $time, MY_NAME);
    endtask
    
    task report_status();
        for (int s=0; s<SOURCES; s++) begin
            automatic int pending_b = 0;
            for (int t=0; t<TIDS_M; t++) begin
                $write("SB %s: s=%0d t=%0d - %0d", MY_NAME, s, t, mb_byte_req_src[s][t].num());
                if (mb_byte_req_src[s][t].num() > 0) begin
                    axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH)) byte_top;
                    assert(mb_byte_req_src[s][t].try_peek(byte_top)) else $fatal(1, "NO peeky-peeky?!");
                    pending_b = pending_b + mb_byte_req_src[s][t].num();
                    $write(": %s", byte_top.to_str());
                end
                $write("\n");
            end
        end
    endtask
    
    function void do_reset();
        drained = 1'b0;
    endfunction
endclass

endpackage
