package axi_m_w_initiator_pkg;

import axi_global_pkg::*;
import noc_global::*;
import axi_transactions_pkg::*;
import axi_rv_if_m_w_abstract_pkg::*;
import tb_pkg_general::*;


class axi_m_w_initiator 
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
    // AW / W
    parameter int AW_USER_WIDTH = 2,
    parameter int AW_TID_WIDTH  = 1,
    parameter int W_DATA_WIDTH  = 64,
    parameter int W_USER_WIDTH  = 2,
    // B
    parameter int B_RESP_WIDTH  = 2,
    parameter int B_USER_WIDTH  = 2,

    parameter int MASTERWTFW    = MASTERS > 1 ? $clog2(MASTERS) : 1
);


    const int MASTER_ID;
    const int TIDS;
    const int DATA_LANES;
    const logic[ADDR_WIDTH-1:0] ADDR_MAX;
    // file
    const logic WRITE_TO_FILE;
    const string FLNAME;
    int fl_report;
    
    const tb_gen_mode_t tb_gen_mode;
    
    const int STALL_RATE_B;
    const int IDLE_RATE_AW;
    const int IDLE_RATE_W;
    const int STROBE_MASK_RATE;
    
    int gen_rate;
    //  vIF
    axi_rv_if_m_w_abstract
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
        .AW_USER_WIDTH  (AW_USER_WIDTH),
        .AW_TID_WIDTH   (AW_TID_WIDTH),
        .W_DATA_WIDTH   (W_DATA_WIDTH),
        .W_USER_WIDTH   (W_USER_WIDTH),
        .B_RESP_WIDTH   (B_RESP_WIDTH),
        .B_USER_WIDTH   (B_USER_WIDTH)
    ) vif;
    
    //transaction generator
    axi_transaction_generator #(.ADDRESS_WIDTH(ADDR_WIDTH)) t_gen;
    axi_payload_translator #(.ADDRESS_WIDTH(ADDR_WIDTH), .DATA_WIDTH(W_DATA_WIDTH)) d_gen;
    //
    int trans_to_generate;
    int trans_generated;
    int bytes_generated;
    // queue of transaction channels
    // TODO: Add class specialization
    mailbox #(axi_awr_chan #( .TID_WIDTH (AW_TID_WIDTH), .ADDR_WIDTH (ADDR_WIDTH), .LEN_WIDTH (LEN_WIDTH), .SIZE_WIDTH (SIZE_WIDTH), .BURST_WIDTH (BURST_WIDTH), .LOCK_WIDTH (LOCK_WIDTH), .CACHE_WIDTH (CACHE_WIDTH), .PROT_WIDTH (PROT_WIDTH), .QOS_WIDTH (QOS_WIDTH), .REGION_WIDTH (REGION_WIDTH), .USER_WIDTH (AW_USER_WIDTH)))
        aw_q; // AW
    mailbox #(axi_w_chan #( .TID_WIDTH (AW_TID_WIDTH), .DATA_WIDTH (W_DATA_WIDTH), .USER_WIDTH (W_USER_WIDTH)))
        w_q; // W
    // mailbox for asserting that no more responses received than expected
    // TODO: DUMP and keep just byte verif
    mailbox #(axi_awr_chan #(.TID_WIDTH (AW_TID_WIDTH), .ADDR_WIDTH (ADDR_WIDTH), .LEN_WIDTH (LEN_WIDTH), .SIZE_WIDTH (SIZE_WIDTH), .BURST_WIDTH (BURST_WIDTH), .LOCK_WIDTH (LOCK_WIDTH), .CACHE_WIDTH (CACHE_WIDTH), .PROT_WIDTH (PROT_WIDTH), .QOS_WIDTH (QOS_WIDTH), .REGION_WIDTH (REGION_WIDTH), .USER_WIDTH (AW_USER_WIDTH)))
        w_t_req_mb[];
    // SB mailbox
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)))
        byte_mb[];
    
    function new(int MASTER_ID_, int TIDS_, int DATA_LANES_, logic[ADDR_WIDTH-1:0] ADDR_MAX_,
                 int STALL_RATE_B_, int IDLE_RATE_AW_, int IDLE_RATE_W_, int STROBE_MASK_RATE_,
                 int gen_rate_,
                 tb_gen_mode_t tb_gen_mode_, string INP_FILENAME,
                 int trans_to_generate_,
                 int fixed_distr, int incr_distr, int wrap_distr, logic DO_UNALIGNED_,
                 int MIN_BURST_LEN_, int MAX_BURST_LEN_, int MIN_BURST_SIZE_, int MAX_BURST_SIZE_,
                 logic IS_RANDOM_DATA_,
                 mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) byte_mb_[],
                 logic WRITE_TO_FILE_, string FLNAME_);
        int type_distr[2];
        type_distr[int'(WRITE_TRANSACTION)] = 1;
        type_distr[int'(READ_TRANSACTION)]  = 0;
        
        MASTER_ID       = MASTER_ID_;
        TIDS            = TIDS_;
        DATA_LANES      = DATA_LANES_;
        ADDR_MAX        = ADDR_MAX_;
        gen_rate        = gen_rate_;
        WRITE_TO_FILE   = WRITE_TO_FILE_;
        
        tb_gen_mode = tb_gen_mode_;
        
        STALL_RATE_B        = STALL_RATE_B_;
        IDLE_RATE_AW        = IDLE_RATE_AW_;
        IDLE_RATE_W         = IDLE_RATE_W_;
        STROBE_MASK_RATE    = STROBE_MASK_RATE_;
        
        // ---------------------------->
        t_gen = new(TIDS, DATA_LANES, ADDR_MAX, tb_gen_mode, INP_FILENAME,
                    type_distr[int'(WRITE_TRANSACTION)], type_distr[int'(READ_TRANSACTION)],
                    fixed_distr, incr_distr, wrap_distr, DO_UNALIGNED_,
                    MIN_BURST_LEN_, MAX_BURST_LEN_, MIN_BURST_SIZE_, MAX_BURST_SIZE_, IS_RANDOM_DATA_);
        t_gen.srandom((MASTER_ID+3)*17+23);
        d_gen = new(DATA_LANES);
        // <----------------------------
        
        // Queues
        aw_q  = new();
        w_q   = new();
        
        // Local mailbox
        w_t_req_mb = new[TIDS];
        foreach(w_t_req_mb[t]) begin
            w_t_req_mb[t] = new();
        end
        
        // SB mailbox
        assert (byte_mb_.size == TIDS);
        byte_mb = byte_mb_;
        
        trans_to_generate = trans_to_generate_;
        
        if (WRITE_TO_FILE) begin
            FLNAME = FLNAME_;
            fl_report = $fopen(FLNAME, "w");
            if (!fl_report) begin
                $display("Could not open file \"%s\"", FLNAME);
            end
        end
    endfunction
    
    function void do_reset();
        // stop        = 1'b0;
        // stopped         = 1'b0;
        trans_generated = 0;
        bytes_generated = 0;
        
        // measure_on_pending = 1'b0;
        // measure_off_pending = 1'b0;
        // measure_on = 1'b0;
    endfunction
    
    // AW Output Channel Manager
    local task aw_channel_manager();
        forever begin
            axi_awr_chan #( .TID_WIDTH (AW_TID_WIDTH), .ADDR_WIDTH (ADDR_WIDTH), .LEN_WIDTH (LEN_WIDTH), .SIZE_WIDTH (SIZE_WIDTH), .BURST_WIDTH (BURST_WIDTH), .LOCK_WIDTH (LOCK_WIDTH), .CACHE_WIDTH (CACHE_WIDTH), .PROT_WIDTH (PROT_WIDTH), .QOS_WIDTH (QOS_WIDTH), .REGION_WIDTH (REGION_WIDTH), .USER_WIDTH (AW_USER_WIDTH))
                t_now;
            // read from top of queue
            aw_q.get(t_now);
`ifdef VERBOSE
            $display("%0t: m%0d --> AW %s", $time, MASTER_ID, t_now.to_str());
`endif
            vif.write_aw(MASTER_ID, t_now.tid, t_now.addr, t_now.len, t_now.size, t_now.burst, t_now.lock, t_now.cache, t_now.prot, t_now.qos, t_now.region, t_now.user, IDLE_RATE_AW);
        end
    endtask
    
    // W Output Channel Manager
    local task w_channel_manager();
        forever begin
            axi_w_chan #( .TID_WIDTH (AW_TID_WIDTH), .DATA_WIDTH (W_DATA_WIDTH), .USER_WIDTH (W_USER_WIDTH))
                t_now;
            // read from top of queue
            w_q.get(t_now);
`ifdef VERBOSE
            $display("%0t: m%0d --> W %s", $time, MASTER_ID, t_now.to_str());
`endif
            vif.write_w(MASTER_ID, t_now.tid, t_now.data, t_now.strb, t_now.last, t_now.user, IDLE_RATE_W);
        end
    endtask
    
    // Transaction generation
    local task transaction_generation();
        axi_transaction #(.ADDRESS_WIDTH(ADDR_WIDTH)) axi_t;
        automatic logic[AW_USER_WIDTH-1:0] aw_user = '{AW_USER_WIDTH{1'b1}};
        automatic logic[W_USER_WIDTH-1:0]  w_user  = '{W_USER_WIDTH{1'b1}};
        
        if ( tb_gen_mode == TBGMT_DIRECTED) begin
            // always more than generated so that it keeps up until all lines are read
            // yes, lazy, I know
            trans_to_generate = 1;
        end
        
        while(trans_generated < trans_to_generate) begin
            vif.posedge_clk();
            // try generate
            if ($urandom_range(99) < gen_rate) begin
                axi_awr_chan #(.TID_WIDTH (AW_TID_WIDTH), .ADDR_WIDTH (ADDR_WIDTH), .LEN_WIDTH (LEN_WIDTH), .SIZE_WIDTH (SIZE_WIDTH), .BURST_WIDTH (BURST_WIDTH), .LOCK_WIDTH (LOCK_WIDTH), .CACHE_WIDTH (CACHE_WIDTH), .PROT_WIDTH (PROT_WIDTH), .QOS_WIDTH (QOS_WIDTH), .REGION_WIDTH (REGION_WIDTH), .USER_WIDTH (AW_USER_WIDTH))
                    t_push;
                axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)) byte_push;
                int                         cur_byte;
                
                int                         burst_length;
                logic[W_DATA_WIDTH-1:0]     data_gen[];
                logic[W_DATA_WIDTH/8-1:0]   strb_gen[];
                logic                       last_gen[];
                logic[ADDR_WIDTH-1:0]       cur_beat_addr[];
                
                
                // assert(t_gen.randomize()) else $fatal(1, "Rand error");
                if (t_gen.do_generate()) begin
                    // ....
                    axi_t = t_gen.to_axi_transaction();
                    assert(axi_t.t_type == WRITE_TRANSACTION) else $fatal(1, "Impossible - W only!");
                    // Alter address bits to indicate Initiator and Transaction IDs
                    axi_t.address[ADDR_MSTTID_P +: MASTERWTFW] = MASTER_ID;
                    axi_t.address[ADDR_MSTTID_P +  MASTERWTFW +: AW_TID_WIDTH] = axi_t.tid;
                    
                    // AW
                    t_push = new(axi_t.tid, axi_t.address, axi_t.len, axi_t.size, axi_t.burst, axi_t.lock, axi_t.cache, axi_t.prot, axi_t.qos, axi_t.region, aw_user);
                    if (WRITE_TO_FILE) begin
                        $fwrite(fl_report, "%s\n", axi_t.to_str());
                    end
                    
                    assert(aw_q.try_put(t_push)) else $fatal(1, "Could not push to AW q");
                    assert(w_t_req_mb[axi_t.tid].try_put(t_push)) else $fatal(1, "Could not push to MB req q");
                    
                    // -- Byte Generation -- //
                    // -- W -- //
                    // get the payload
`ifdef VERBOSE_M
                    $write("%0t: Wm%0d to SB:\n", $time, MASTER_ID);
`endif
                    burst_length = d_gen.get_payload(axi_t.len, axi_t.size, axi_t.address, axi_burst_type'(axi_t.burst), axi_t.payload, data_gen, strb_gen, last_gen, cur_beat_addr);
                    cur_byte = 0;
                    for(int l=0; l<burst_length; l++) begin
                        axi_w_chan #(.TID_WIDTH (AW_TID_WIDTH), .DATA_WIDTH(W_DATA_WIDTH), .USER_WIDTH(W_USER_WIDTH)) d_push;
                        // ------------------------------------------------ //
                        // ------------------------------------------------ //
                        // ------------------------------------------------ //
                        // Fill it in with strobe masking code here -- Sample:
                        logic[W_DATA_WIDTH/8-1:0]   strobe_mask;
                        // make sure that there will be at least one left
                        automatic int max_strobes = $countones(strb_gen[l]) - 1;
                        // the number of masked-out strobes will be determined by the rate
                        // (e.g. a 50% rate means that, whenever I have 5 strobes ON, it's going to mask out 2 on average)
                        automatic real off_weight = real'(STROBE_MASK_RATE) / 100.0;
                        automatic int max_strobes_weighted = int'(off_weight * real'(max_strobes));
                        automatic int off_strobes = $urandom_range(max_strobes_weighted);
                        while (off_strobes > 0) begin
                            automatic int idx = $urandom_range(DATA_LANES-1);
                            if (strb_gen[l][idx]) begin
                                strb_gen[l][idx] = 1'b0;
                                off_strobes--;
                                // $display("idx: %0d -- strb_gen[l] = %0b", idx, strb_gen[l]);
                            end
                        end
                        // ------------------------------------------------ //
                        // ------------------------------------------------ //
                        // ------------------------------------------------ //
                        d_push = new(axi_t.tid, data_gen[l], strb_gen[l], last_gen[l], w_user);
                        assert(w_q.try_put(d_push));
                        
                        // Push bytes to MB
                        for (int b=0; b<DATA_LANES; b++) begin
                            if (strb_gen[l][b]) begin
                                byte_push = new(MASTER_ID, 1'b1, int'(data_gen[l][b*8 +: 8]), axi_t.tid, cur_beat_addr[l]+b);
`ifdef VERBOSE_M
                                $write(" | %s - beat_addr = %0h\n", byte_push.to_str(), cur_beat_addr[l]);
`endif
                                if (WRITE_TO_FILE) begin
                                    $fwrite(fl_report, "%s\n", byte_push.to_str());
                                end
                                assert(byte_mb[axi_t.tid].try_put(byte_push));
                                
                                cur_byte++;
                            end
                        end
                    end
                    bytes_generated += cur_byte;
                    trans_generated++;
`ifdef VERBOSE
                    $display("%0t: Wm%0d generated %s - TOTAL BYTES = %0d", $time, MASTER_ID, axi_t.to_str(), cur_byte);
`endif
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
    
    // B Input Channel Managers
    local task b_channel_manager();
        forever begin
            axi_b_chan #(.TID_WIDTH(AW_TID_WIDTH), .BRESP_WIDTH(B_RESP_WIDTH), .USER_WIDTH(B_USER_WIDTH))
                b_now;
            axi_awr_chan #(.TID_WIDTH (AW_TID_WIDTH), .ADDR_WIDTH (ADDR_WIDTH), .LEN_WIDTH (LEN_WIDTH), .SIZE_WIDTH (SIZE_WIDTH), .BURST_WIDTH (BURST_WIDTH), .LOCK_WIDTH (LOCK_WIDTH), .CACHE_WIDTH (CACHE_WIDTH), .PROT_WIDTH (PROT_WIDTH), .QOS_WIDTH (QOS_WIDTH), .REGION_WIDTH (REGION_WIDTH), .USER_WIDTH (AW_USER_WIDTH))
                t_expected;
            logic[AW_TID_WIDTH-1:0] b_tid;
            logic[B_RESP_WIDTH-1:0] b_resp;
            logic[B_USER_WIDTH-1:0] b_user;
            vif.read_b(MASTER_ID, b_tid, b_resp, b_user, STALL_RATE_B);
            b_now = new(b_tid, b_resp, b_user);
`ifdef VERBOSE
            $display("%0t: m%0d B <-- %s", $time, MASTER_ID, b_now.to_str());
`endif
            
            assert(w_t_req_mb[int'(b_tid)].try_get(t_expected)) else $fatal(1, "m%0d t%0d: Got unexpected B response (NO AW REQ PENDING)!", MASTER_ID, int'(b_tid));
        end
    endtask
    
    local task start_resp_channels();
        fork
            b_channel_manager();
        join_none
    endtask
    
    local task start_req_channels();
        fork
            aw_channel_manager();
            w_channel_manager();
        join_none
    endtask
    
    local task wait_w_mb_drain(int tid);
    // VCS does not support this
`ifdef VSIM
        wait(w_t_req_mb[tid].num() == 0);
`else
        // replacing with this crap
        while (w_t_req_mb[tid].num() > 0) begin
            vif.posedge_clk();
        end
        
`endif // VSIM
        //~ $display("%0t: M[%0d] T[%0d] END .......................", $time, MASTER_ID, tid);
    endtask
    
    task start();
        start_resp_channels();
        start_req_channels();
        
        transaction_generation();
        
        $display("%0t: W-Master %0d transaction generation stopped - Waiting to drain", $time, MASTER_ID);
        vif.posedge_clk();
        vif.posedge_clk();
        
        
        // VCS does not support this:
`ifdef VSIM
        wait(aw_q.num() == 0 && w_q.num() == 0);
`else
        //replacing by this crap:
        while (aw_q.num() > 0 || w_q.num() > 0) begin
            vif.posedge_clk();
        end
`endif //  VSIM


        // disable fork;
        
        $display("%0t: W-Master %0d drained - Waiting for responses to get back...", $time, MASTER_ID);
        
        fork begin: iso_thread
            for(int tt=0; tt<TIDS; tt++) begin: for_tt
                fork
                    automatic int t = tt;
                begin
                    wait_w_mb_drain(t);
                end join_none
                wait fork;
            end
        end join
        
        $fclose(fl_report);
        
        $display("%0t: W-Master %0d done - all responses are back", $time, MASTER_ID);
    endtask
    
    // task stop_it();
        // stop = 1'b1;
    // endtask
endclass

endpackage
