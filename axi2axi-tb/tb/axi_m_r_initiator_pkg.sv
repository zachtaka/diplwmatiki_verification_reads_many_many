package axi_m_r_initiator_pkg;

import axi_global_pkg::*;
import noc_global::*;
import tb_pkg_general::*;
import axi_transactions_pkg::*;
import axi_rv_if_m_r_abstract_pkg::*;

class axi_m_r_initiator 
#(
    parameter int MASTERS       = 1,
    parameter int ADDR_MSTTID_P = 10,
    // AWR widths - WARNING! these are the whole system's MAX values!
    // Don't rely on them for assuming the specific initator's config!
    // E.g. # of TIDs is found through constructor parameter 'TIDS'
    // (i.e. # of TIDs is not implied by TID_WIDTH)
    // Get these actual values by the contructor's params!
    // General
    parameter int ADDR_WIDTH    = 32,
    parameter int LEN_WIDTH     = 8,
    parameter int SIZE_WIDTH    = 3,
    parameter int BURST_WIDTH   = 2,
    parameter int LOCK_WIDTH    = 1,
    parameter int CACHE_WIDTH   = 4,
    parameter int PROT_WIDTH    = 3,
    parameter int QOS_WIDTH     = 4,
    parameter int REGION_WIDTH  = 4,
    // AR
    parameter int AR_TID_WIDTH  = 1,
    parameter int AR_USER_WIDTH = 2,
    // R
    parameter int R_DATA_WIDTH  = 64,
    parameter int R_RESP_WIDTH  = 2,
    parameter int R_USER_WIDTH  = 22,
    
    parameter int MASTERWTFW    = MASTERS > 1 ? $clog2(MASTERS) : 1
);

    const int MASTER_ID;
    const int TIDS;
    const int DATA_LANES;
    const logic[ADDR_WIDTH-1:0] ADDR_MAX;
    const logic WRITE_TO_FILE;
    const string FLNAME;
    int fl_report;
    
    const tb_gen_mode_t tb_gen_mode;
    
    const int STALL_RATE_R;
    const int IDLE_RATE_AR;
    
    int gen_rate;
    int trans_to_generate;
    int trans_generated;
    
    
    //  vIF
    axi_rv_if_m_r_abstract
        #(  .PORTS          (MASTERS),
            .ADDR_WIDTH     (ADDR_WIDTH),
            .LEN_WIDTH      (LEN_WIDTH),
            .SIZE_WIDTH     (SIZE_WIDTH),
            .BURST_WIDTH    (BURST_WIDTH),
            .LOCK_WIDTH     (LOCK_WIDTH),
            .CACHE_WIDTH    (CACHE_WIDTH),
            .PROT_WIDTH     (PROT_WIDTH),
            .QOS_WIDTH      (QOS_WIDTH),
            .REGION_WIDTH   (REGION_WIDTH),
            .AR_TID_WIDTH   (AR_TID_WIDTH),
            .AR_USER_WIDTH  (AR_USER_WIDTH),
            .R_DATA_WIDTH   (R_DATA_WIDTH),
            .R_RESP_WIDTH   (R_RESP_WIDTH),
            .R_USER_WIDTH   (R_USER_WIDTH)) vif;
    
    //transaction generator
    axi_transaction_generator #(.ADDRESS_WIDTH(ADDR_WIDTH)) t_gen;
    axi_payload_translator #(.ADDRESS_WIDTH(ADDR_WIDTH), .DATA_WIDTH(R_DATA_WIDTH))
        d_gen;
    // queue of transaction channels
    mailbox #(axi_awr_chan #( .TID_WIDTH (AR_TID_WIDTH), .ADDR_WIDTH (ADDR_WIDTH), .LEN_WIDTH (LEN_WIDTH), .SIZE_WIDTH (SIZE_WIDTH), .BURST_WIDTH (BURST_WIDTH), .LOCK_WIDTH (LOCK_WIDTH), .CACHE_WIDTH (CACHE_WIDTH), .PROT_WIDTH (PROT_WIDTH), .QOS_WIDTH (QOS_WIDTH), .REGION_WIDTH (REGION_WIDTH), .USER_WIDTH (AR_USER_WIDTH)))
	    ar_q; // AR
    //
    mailbox #(axi_awr_chan #(.TID_WIDTH (AR_TID_WIDTH), .ADDR_WIDTH (ADDR_WIDTH), .LEN_WIDTH (LEN_WIDTH), .SIZE_WIDTH (SIZE_WIDTH), .BURST_WIDTH (BURST_WIDTH), .LOCK_WIDTH (LOCK_WIDTH), .CACHE_WIDTH (CACHE_WIDTH), .PROT_WIDTH (PROT_WIDTH), .QOS_WIDTH (QOS_WIDTH), .REGION_WIDTH (REGION_WIDTH), .USER_WIDTH (AR_USER_WIDTH)))
        w_t_req_mb[];
    
    // SB mailboxes
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)))    rd_req_byte_mb_to_slave[];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)))    rd_resp_byte_mb;

    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) rd_req_byte_mb_m2m[];
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) rd_resp_byte_mb_m2m;
    
    
    function new(int MASTER_ID_, int TIDS_, int DATA_LANES_, logic[ADDR_WIDTH-1:0] ADDR_MAX_,
                 int STALL_RATE_R_, int IDLE_RATE_AR_,
                 int gen_rate_, tb_gen_mode_t tb_gen_mode_, string INP_FILENAME,
                 int trans_to_generate_,
                 int fixed_distr, int incr_distr, int wrap_distr, logic DO_UNALIGNED_,
                 int MIN_BURST_LEN_, int MAX_BURST_LEN_,
                 int MIN_BURST_SIZE_, int MAX_BURST_SIZE_,
                 logic IS_RANDOM_DATA_,
                 mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) rd_req_byte_mb_to_slave_[],
                 mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) rd_resp_byte_mb_,
                 
                 mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) rd_req_byte_mb_m2m_[],
                 mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) rd_resp_byte_mb_m2m_,
                 logic WRITE_TO_FILE_,
                 string FLNAME_);
        
        int type_distr[2];
        type_distr[int'(WRITE_TRANSACTION)] = 0;
        type_distr[int'(READ_TRANSACTION)]  = 1;
        
        MASTER_ID       = MASTER_ID_;
        TIDS            = TIDS_;
        DATA_LANES      = DATA_LANES_;
        ADDR_MAX        = ADDR_MAX_;
        gen_rate        = gen_rate_;
        WRITE_TO_FILE   = WRITE_TO_FILE_;
        
        STALL_RATE_R    = STALL_RATE_R_;
        IDLE_RATE_AR    = IDLE_RATE_AR_;
        
        tb_gen_mode = tb_gen_mode_;
        
        // ---------------------------->
        t_gen = new(TIDS, DATA_LANES,  ADDR_MAX, tb_gen_mode, INP_FILENAME,
                    type_distr[int'(WRITE_TRANSACTION)], type_distr[int'(READ_TRANSACTION)],
                    fixed_distr, incr_distr, wrap_distr, DO_UNALIGNED_,
                    MIN_BURST_LEN_, MAX_BURST_LEN_, MIN_BURST_SIZE_, MAX_BURST_SIZE_, IS_RANDOM_DATA_);
        t_gen.srandom((MASTER_ID+3)*17+23);
        d_gen = new(DATA_LANES);
        // <----------------------------
        
        ar_q  = new();
        
        
        trans_to_generate = trans_to_generate_;
        
        // SB mailboxes
        w_t_req_mb    = new[TIDS];
        foreach(w_t_req_mb[t]) begin
            w_t_req_mb[t] = new();
        end
        
        //
        assert (rd_req_byte_mb_to_slave_.size() == TIDS);
        rd_req_byte_mb_to_slave = rd_req_byte_mb_to_slave_;
        rd_resp_byte_mb = rd_resp_byte_mb_;
        
        assert (rd_req_byte_mb_m2m_.size() == TIDS);
        rd_req_byte_mb_m2m  = rd_req_byte_mb_m2m_;
        rd_resp_byte_mb_m2m = rd_resp_byte_mb_m2m_;
        
        
    endfunction
    
    function void do_reset();
        trans_generated = 0;
    endfunction
    
    // AR Output Channel Manager
    task ar_channel_manager();
        forever begin
            axi_awr_chan #( .TID_WIDTH (AR_TID_WIDTH), .ADDR_WIDTH (ADDR_WIDTH), .LEN_WIDTH (LEN_WIDTH), .SIZE_WIDTH (SIZE_WIDTH), .BURST_WIDTH (BURST_WIDTH), .LOCK_WIDTH (LOCK_WIDTH), .CACHE_WIDTH (CACHE_WIDTH), .PROT_WIDTH (PROT_WIDTH), .QOS_WIDTH (QOS_WIDTH), .REGION_WIDTH (REGION_WIDTH), .USER_WIDTH (AR_USER_WIDTH))
                t_now;
            // read from top of queue
            ar_q.get(t_now);
`ifdef VERBOSE
            $display("%0t: m%0d --> AR %s", $time, MASTER_ID, t_now.to_str());
`endif
            vif.write_ar(MASTER_ID, t_now.tid, t_now.addr, t_now.len, t_now.size, t_now.burst, t_now.lock, t_now.cache, t_now.prot, t_now.qos, t_now.region, t_now.user, IDLE_RATE_AR);
        end
    endtask
    
    // Transaction generation
    task transaction_generation();
        axi_transaction #(.ADDRESS_WIDTH(ADDR_WIDTH)) axi_t;
        automatic logic[AR_USER_WIDTH-1:0] ar_user = '{AR_USER_WIDTH{1'b1}};
        
        if ( tb_gen_mode == TBGMT_DIRECTED) begin
            // always more than generated so that it keeps up until all lines are read
            // yes, lazy, I know
            trans_to_generate = 1;
        end
        
        while (trans_generated < trans_to_generate) begin
            vif.posedge_clk();
            // try generate
            if ($urandom_range(99) < gen_rate) begin
                axi_awr_chan #(.TID_WIDTH (AR_TID_WIDTH), .ADDR_WIDTH (ADDR_WIDTH), .LEN_WIDTH (LEN_WIDTH), .SIZE_WIDTH (SIZE_WIDTH), .BURST_WIDTH (BURST_WIDTH), .LOCK_WIDTH (LOCK_WIDTH), .CACHE_WIDTH (CACHE_WIDTH), .PROT_WIDTH (PROT_WIDTH), .QOS_WIDTH (QOS_WIDTH), .REGION_WIDTH (REGION_WIDTH), .USER_WIDTH (AR_USER_WIDTH))
                    t_push;
                int                         burst_length;
                int                         cur_byte;
                logic[R_DATA_WIDTH-1:0]     data_gen[];
                logic[R_DATA_WIDTH/8-1:0]   strb_gen[];
                logic                       last_gen[];
                logic[ADDR_WIDTH-1:0]       cur_beat_addr[];
                
                if (t_gen.do_generate()) begin
                    axi_t = t_gen.to_axi_transaction();
                    assert(axi_t.t_type == READ_TRANSACTION) else $fatal(1, "Impossible - R only!");
                    // Alter address bits to indicate Initiator and Transaction IDs
                    axi_t.address[ADDR_MSTTID_P +: MASTERWTFW] = MASTER_ID;
                    axi_t.address[ADDR_MSTTID_P +  MASTERWTFW +: AR_TID_WIDTH] = axi_t.tid;
                    
                    // AR
                    t_push = new(axi_t.tid, axi_t.address, axi_t.len, axi_t.size, axi_t.burst, axi_t.lock, axi_t.cache, axi_t.prot, axi_t.qos, axi_t.region, ar_user);
                    if (WRITE_TO_FILE) begin
                        $fwrite(fl_report, "%s\n", axi_t.to_str());
                    end
                    
                    assert(ar_q.try_put(t_push));
                    assert(w_t_req_mb[axi_t.tid].try_put(t_push));
                    
                    
                    // -- Byte Generation -- //
`ifdef VERBOSE_BYTES
                    $write("%0t: Rm%0d to SB:\n", $time, MASTER_ID);
`endif
                    burst_length = d_gen.get_payload(axi_t.len, axi_t.size, axi_t.address, axi_burst_type'(axi_t.burst), axi_t.payload, data_gen, strb_gen, last_gen, cur_beat_addr);
                    cur_byte = 0;
                    for(int l=0; l<burst_length; l++) begin
                        // Push bytes to MB
                        for (int b=0; b<DATA_LANES; b++) begin
                            if (strb_gen[l][b]) begin
                                axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)) byte_push_r_m2s;
                                axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)) byte_push_r_m2m;
                                
                                byte_push_r_m2s = new(MASTER_ID, 1'b1, int'(data_gen[l][b*8 +: 8]), axi_t.tid, cur_beat_addr[l]+b);
                                assert(rd_req_byte_mb_to_slave[axi_t.tid].try_put(byte_push_r_m2s)) else $fatal(1, "can't push byte [r]");
                                
                                
                                byte_push_r_m2s.hard_copy(byte_push_r_m2m);
                                byte_push_r_m2m.has_value = 1'b0;
                                assert(rd_req_byte_mb_m2m[axi_t.tid].try_put(byte_push_r_m2m)) else $fatal(1, "can't push byte [r]");
`ifdef VERBOSE_BYTES
                                $write(" | %s - beat_addr = %0h\n", byte_push_r_m2s.to_str(), cur_beat_addr[l]);
`endif
                                if (WRITE_TO_FILE) begin
                                    $fwrite(fl_report, "%s\n", byte_push_r_m2s.to_str());
                                end
                                
                                cur_byte++;
                            end
                        end
                    end
                    trans_generated++;

                    if ( tb_gen_mode == TBGMT_DIRECTED ) begin
                        trans_to_generate++;
                    end
                end else begin
                    assert (tb_gen_mode == TBGMT_DIRECTED) else $fatal(1, "----");
                    trans_to_generate--;                    
                end
            end
        end
    endtask
    
    // R
    local task r_channel_manager();
        automatic int   cur_len[]               = new[TIDS];
        automatic logic is_active[]             = new[TIDS];
        automatic logic[ADDR_WIDTH-1:0] addrs[] = new[TIDS];
        automatic logic is_aligned[]            = new[TIDS];
        
        for(int t=0; t<TIDS; t++) begin
            cur_len[t]   = 0;
            is_active[t] = 0;
            is_aligned[t]= 0;
        end
        
        forever begin
            axi_r_chan #(.TID_WIDTH(AR_TID_WIDTH), .DATA_WIDTH(R_DATA_WIDTH), .RRESP_WIDTH(R_RESP_WIDTH), .USER_WIDTH(R_USER_WIDTH))
                r_now;
            axi_awr_chan #(.TID_WIDTH (AR_TID_WIDTH), .ADDR_WIDTH (ADDR_WIDTH), .LEN_WIDTH (LEN_WIDTH), .SIZE_WIDTH (SIZE_WIDTH), .BURST_WIDTH (BURST_WIDTH), .LOCK_WIDTH (LOCK_WIDTH), .CACHE_WIDTH (CACHE_WIDTH), .PROT_WIDTH (PROT_WIDTH), .QOS_WIDTH (QOS_WIDTH), .REGION_WIDTH (REGION_WIDTH), .USER_WIDTH (AR_USER_WIDTH))
                t_expected;
            
            logic[AR_TID_WIDTH-1:0] r_tid;
            logic[R_DATA_WIDTH-1:0] r_data;
            logic[R_RESP_WIDTH-1:0] r_resp;
            logic                   r_last;
            logic[R_USER_WIDTH-1:0] r_user;
            
            vif.read_r(MASTER_ID, r_tid, r_data, r_resp, r_last, r_user, STALL_RATE_R);
            r_now = new(r_tid, r_data, r_resp, r_last, r_user);
            
            assert(w_t_req_mb[int'(r_tid)].try_peek(t_expected)) else $fatal(1, "m%0d t%0d: Got undexpected response (NO PENDING AR REQ)!", MASTER_ID, int'(r_tid));
            cur_len[int'(r_tid)]++;
`ifdef VERBOSE
            $display("%0t: m%0d R <-- %s (%0d/%0d)", $time, MASTER_ID, r_now.to_str(), cur_len[int'(r_tid)], t_expected.len+1);
`endif
            assert( cur_len[int'(r_tid)] <= (int'(t_expected.len)+1) ) else $fatal(1, "m%0d %0d: Got more R data beats than expected (AR length=%0d but now just received %0d'th data beat)!", MASTER_ID, int'(r_tid), int'(t_expected.len), cur_len[int'(r_tid)]);
            
            
            // -- Byte Generation -- //
            if (!is_active[int'(r_tid)]) begin
                addrs[int'(r_tid)] = t_expected.addr;
                assert (axi_burst_type'(t_expected.burst) == AXI_BURST_INCR) else $fatal(1, "Only INCR burst are supported!");
            end
            
            begin
                automatic int byte_mask                      = 2**int'(t_expected.size) - 1;
                automatic logic[ADDR_WIDTH-1:0] aligned_addr = addrs[int'(r_tid)] & ~byte_mask;
                automatic logic[ADDR_WIDTH-1:0] addr_misalign;
                int lower_byte_lane, upper_byte_lane;
                
                if (!is_active[int'(r_tid)]) begin
                    is_aligned[int'(r_tid)]  = (aligned_addr == t_expected.addr);
                end else begin
                    assert (aligned_addr == addrs[int'(r_tid)]) else $fatal(1, "not first beat but unaligned?!");
                    is_aligned[int'(r_tid)] = 1;
                end
                is_active[int'(r_tid)] = 1;
                
                addr_misalign = addrs[int'(r_tid)] & ~(DATA_LANES-1);
                lower_byte_lane = addrs[int'(r_tid)] - addr_misalign;
                
                if (is_aligned[int'(r_tid)]) begin
                    upper_byte_lane = lower_byte_lane + 2**int'(t_expected.size) - 1;
                end else begin
                    upper_byte_lane = aligned_addr + 2**int'(t_expected.size) - 1 - addr_misalign;
                end
                
                for (int i=lower_byte_lane; i<=upper_byte_lane; i++) begin
                    automatic logic[7:0] bt = r_now.data[i*8 +: 8];
                    axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)) byte_push_s2m;
                    axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)) byte_push_m2m;
                    
                    byte_push_s2m = new(MASTER_ID, 1'b1, int'(bt), int'(r_tid), addrs[int'(r_tid)]);
                    assert(rd_resp_byte_mb.try_put(byte_push_s2m)) else $fatal(1, "can't push byte [r]");
                    
                    byte_push_s2m.hard_copy(byte_push_m2m);
                    byte_push_m2m.has_value = 1'b0;
                    assert(rd_resp_byte_mb_m2m.try_put(byte_push_m2m)) else $fatal(1, "can't push byte [r]");
                    
                
                    addrs[int'(r_tid)] = addrs[int'(r_tid)] + 1;
                end
            end
            
            if ( cur_len[int'(r_tid)] == (int'(t_expected.len)+1) ) begin
                // should be last
                assert(r_now.last) else $fatal(1, "m%0d %0d: Got last R data beat but LAST was not asserted!", MASTER_ID, int'(r_tid));
                assert(w_t_req_mb[int'(r_tid)].try_get(t_expected));
                cur_len[int'(r_tid)] = 0;
                is_active[int'(r_tid)] = 0;
            end else begin
                assert(!r_now.last) else $fatal(1, "m%0d %0d: Got R indicating LAST, but now at beat %0d (L=%0d)", MASTER_ID, int'(r_tid), cur_len[int'(r_tid)], int'(t_expected.len));
            end
        end
    endtask
    
    local task wait_r_mb_drain(int tid);
        // VCS does not support this
`ifdef VCS
        // replacing with this crap
        while (w_t_req_mb[tid].num() > 0) begin
            vif.posedge_clk();
        end
`else
        wait(w_t_req_mb[tid].num() == 0);
`endif //  VCS
    endtask
    
    task start();
        fork
            ar_channel_manager();
            r_channel_manager();
        join_none
        
        transaction_generation();
        
        $display("%0t: R-Master %0d transaction generation stopped - Waiting to drain", $time, MASTER_ID);
        vif.posedge_clk();
        vif.posedge_clk();
        
        // VCS does not support this:
`ifdef VCS
        //replacing by this crap:
        while (ar_q.num() > 0) begin
            vif.posedge_clk();
        end
`else
        wait(ar_q.num() == 0);
`endif //  VCS


        // disable fork;
        
        $display("%0t: R-Master %0d drained - Waiting for responses to get back...", $time, MASTER_ID);
        
        fork begin: iso_thread
            for(int tt=0; tt<TIDS; tt++) begin: for_tt
                fork
                    automatic int t = tt;
                begin
                    wait_r_mb_drain(t);
                end join_none
                wait fork;
            end
        end join
        
        // for(int t=0; t<TIDS; t++) begin
            // $display("%0t: M[%0d] T[%0d]: w=%0d, r=%0d", $time, MASTER_ID, t, w_req_mb[t].num(), w_t_req_mb[t].num());
        // end
        
        $display("%0t: R-Master %0d done - all responses are back", $time, MASTER_ID);
    endtask
    
    //~ task stop_it();
        //~ stop = 1'b1;
    //~ endtask
endclass

endpackage
