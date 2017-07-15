package axi_s_r_responder_pkg;
import noc_global::*;
import ni_global::*;
import tb_pkg_general::*;
import axi_transactions_pkg::*;
import axi_rv_if_s_r_abstract_pkg::*;

class axi_s_r_responder
#(
    parameter int SLAVES        = 1,
    parameter int MASTERS       = 1,
    parameter int ADDR_MSTTID_P = 10,
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
    parameter int R_USER_WIDTH  = 2,

    parameter int AR_MTID_W     = 1,
    parameter int MASTERWTFR    = MASTERS > 1 ? $clog2(MASTERS) : 1
);
    
    const int SLAVE_ID;
    const int TIDS_M;
    const int DATA_LANES;
    const int TIDS_S;
    const int READ_INTERLEAVE;
    // const logic PUSH_TO_MB;
    int serve_rate;
    int error_rate;
    int stall_rate_ar;
    
    // vIF
    axi_rv_if_s_r_abstract
    #(
        .PORTS          (SLAVES),
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
        .R_USER_WIDTH   (R_USER_WIDTH)
    ) vif;
    // input queues
    mailbox #(axi_awr_chan #(.TID_WIDTH(AR_TID_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .LOCK_WIDTH(LOCK_WIDTH), .CACHE_WIDTH(CACHE_WIDTH), .PROT_WIDTH(PROT_WIDTH), .QOS_WIDTH(QOS_WIDTH), .REGION_WIDTH(REGION_WIDTH), .USER_WIDTH(AR_USER_WIDTH)))
        inp_ar_q[]; // AR
    rr_arb_c r_arb;
    // TODO: Use one per TID!
    mailbox #(axi_r_chan #(.TID_WIDTH(AR_TID_WIDTH), .DATA_WIDTH(R_DATA_WIDTH), .RRESP_WIDTH(R_RESP_WIDTH), .USER_WIDTH(R_USER_WIDTH)))
        out_r_q;
    
    // Read Data generation
    payload_generator p_gen;
    axi_payload_translator #(.ADDRESS_WIDTH(ADDR_WIDTH), .DATA_WIDTH(R_DATA_WIDTH))
        d_gen;
    
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) resp_byte_mb_to_sb[];
    
    function new(int SLAVE_ID_, int TIDS_M_, int DATA_LANES_,
                 int IS_RANDOM_DATA_,
                 logic READ_INTERLEAVE_,
                 int serve_rate_, int error_rate_, int stall_rate_ar_,
                 mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) resp_byte_mb_to_sb_[]);
                 
        SLAVE_ID    = SLAVE_ID_;
        TIDS_M      = TIDS_M_;
        DATA_LANES  = DATA_LANES_;
        TIDS_S      = 2**AR_TID_WIDTH;
        READ_INTERLEAVE = READ_INTERLEAVE_;
        serve_rate  = serve_rate_;
        error_rate  = error_rate_;
        stall_rate_ar  = stall_rate_ar_;
        
        
        inp_ar_q = new[TIDS_S];
        for(int t=0; t<TIDS_S; t++) begin
            inp_ar_q[t] = new();
        end
        
        out_r_q = new();
        
        r_arb = new(TIDS_S);
        
        p_gen = new(IS_RANDOM_DATA_);
        d_gen = new(DATA_LANES);
        
        assert (resp_byte_mb_to_sb_.size == TIDS_M);
        resp_byte_mb_to_sb = resp_byte_mb_to_sb_;
    endfunction
    
    // R Output Channel Manager
    task r_channel_manager();
        forever begin
            axi_r_chan #(.TID_WIDTH(AR_TID_WIDTH), .DATA_WIDTH(R_DATA_WIDTH), .RRESP_WIDTH(R_RESP_WIDTH), .USER_WIDTH(R_USER_WIDTH))
                r_now;
            out_r_q.get(r_now);
`ifdef VERBOSE
            $display("%0t: R %s <-- s%0d", $time, r_now.to_str(), SLAVE_ID);
`endif
            vif.write_r(SLAVE_ID, r_now.tid, r_now.data, r_now.resp, r_now.last, r_now.user);
        end
    endtask
    
    // R Reponders
    task r_responder();
        automatic logic[R_USER_WIDTH-1:0] r_user                                = '{R_USER_WIDTH{1'b1}};
        automatic logic arb_reqs[]                                              = new[TIDS_S];
        automatic logic has_active[]                                            = new[TIDS_S];
        automatic int cur_beat[]                                                = new[TIDS_S];
        automatic axi_transaction #(.ADDRESS_WIDTH(ADDR_WIDTH)) t_now[]         = new[TIDS_S];
        automatic array_wrapper #(logic[R_DATA_WIDTH-1:0])   data_chans[]       = new[TIDS_S];
        automatic array_wrapper #(logic)                     last_chans[]       = new[TIDS_S];
        automatic array_wrapper #(logic[R_DATA_WIDTH/8-1:0]) strb_chans[]       = new[TIDS_S];
        automatic logic[AR_TID_WIDTH-1:0] tid_v[]                               = new[TIDS_S];
        
        automatic int last_byte_val[][]                                         = new[MASTERS];
        
        logic rd_locked;
        int locked_tid;
        
        for(int t=0; t<TIDS_S; t++) begin
            cur_beat[t]         = 0;
            has_active[t]       = 0;
            data_chans[t]       = new();
            last_chans[t]       = new();
            strb_chans[t]       = new();
        end
        
        for(int m=0; m<MASTERS; m++) begin
            last_byte_val[m]    = new[TIDS_M];
            for(int t=0; t<TIDS_M; t++) begin
                last_byte_val[m][t] = 0;
            end
        end
        
        rd_locked = 1'b0;
        
        forever begin
            vif.posedge_clk();
            if ($urandom_range(0, 99) < serve_rate) begin
                int winner_tid;
                if (!rd_locked) begin
                    for(int t=0; t<TIDS_S; t++) begin
                        arb_reqs[t] = (inp_ar_q[t].num() > 0) | has_active[t];
                    end
                    winner_tid = r_arb.arbitrate(arb_reqs, 1'b1);
                    if (winner_tid >= 0 && !READ_INTERLEAVE) begin
                        rd_locked = 1'b1;
                        locked_tid = winner_tid;
                    end
                end else begin
                    winner_tid = locked_tid;
                end
                
                if (winner_tid >= 0) begin
                    axi_r_chan #(.TID_WIDTH(AR_TID_WIDTH), .DATA_WIDTH(R_DATA_WIDTH), .RRESP_WIDTH(R_RESP_WIDTH), .USER_WIDTH(R_USER_WIDTH))
                        r_send;
                    
                    if (!has_active[winner_tid]) begin
                        axi_awr_chan #(.TID_WIDTH(AR_TID_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .LOCK_WIDTH(LOCK_WIDTH), .CACHE_WIDTH(CACHE_WIDTH), .PROT_WIDTH(PROT_WIDTH), .QOS_WIDTH(QOS_WIDTH), .REGION_WIDTH(REGION_WIDTH), .USER_WIDTH(AR_USER_WIDTH))
                            ar_got;
                        logic[7:0]              payload_now[];
                        int                     total_bytes;
                        logic[ADDR_WIDTH-1:0]   cur_beat_addr[];
                        
                        int master_id    ;
                        int tid_in_master;
                        int burst_length;
                        
                        assert(inp_ar_q[winner_tid].try_get(ar_got));
                        t_now[winner_tid] = new(READ_TRANSACTION, int'(ar_got.tid), ar_got.addr, int'(ar_got.len), int'(ar_got.size), int'(ar_got.burst), int'(ar_got.lock), int'(ar_got.cache), int'(ar_got.prot), int'(ar_got.qos), int'(ar_got.region));
                        
                        // payload_now = p_gen.gen_payload(t_now[winner_tid].len, t_now[winner_tid].size);
                        total_bytes = axi_transaction#(.ADDRESS_WIDTH(ADDR_WIDTH))::get_total_bytes(t_now[winner_tid].address, t_now[winner_tid].len, t_now[winner_tid].size);
`ifdef VERBOSE_BYTES
                        $display("%0t: TOTAL BYTES = %0d", $time, total_bytes);
`endif
                        master_id = int'(ar_got.addr[ADDR_MSTTID_P +: MASTERWTFR]);
                        tid_in_master = int'(ar_got.addr[ADDR_MSTTID_P + MASTERWTFR +: AR_MTID_W]);
                        
                        //~ $display("%0t: PRE: last_byte_val[%0d][%0d] = %0d", $time, master_id, tid_in_master, last_byte_val[master_id][tid_in_master]);
                        $display("%0t: Slave generating %0d bytes for m=%0d, t_m=%0d, starting from val %0d", $time, total_bytes, master_id, tid_in_master, last_byte_val[master_id][tid_in_master]);
                        payload_now = p_gen.gen_payload(total_bytes, last_byte_val[master_id][tid_in_master]);
                        
                        //~ $display("%0t: (%0d + %0d) mod 256 = %0d", $time, last_byte_val[master_id][tid_in_master], total_bytes, (last_byte_val[master_id][tid_in_master] + total_bytes) % 256);
                        last_byte_val[master_id][tid_in_master] = (last_byte_val[master_id][tid_in_master] + total_bytes) % 256;
                        burst_length = d_gen.get_payload(t_now[winner_tid].len, t_now[winner_tid].size, t_now[winner_tid].address, axi_burst_type'(t_now[winner_tid].burst), payload_now, data_chans[winner_tid].arr, strb_chans[winner_tid].arr, last_chans[winner_tid].arr, cur_beat_addr);
                        assert(cur_beat[winner_tid] == 0);
                        
                        tid_v[winner_tid] = ar_got.tid;
                        
                        has_active[winner_tid] = 1'b1;
                        
                        
                        // Handle bytes from Master
                        for (int l=0; l<burst_length; l++) begin
                            for (int b=0; b<DATA_LANES; b++) begin
                                axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)) byte_m_top;
                                axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)) byte_push;
                                
                                if (strb_chans[winner_tid].arr[l][b]) begin
                                    automatic logic[ADDR_WIDTH-1:0] cur_addr = cur_beat_addr[l];
                                    byte_push = new(master_id, 1'b1, int'(data_chans[winner_tid].arr[l][b*8 +: 8]), tid_in_master, cur_addr+b);
                                    // $display("%0t: Slave pushing byte to SB MB: %s", $time, byte_push.to_str());
                                    assert (resp_byte_mb_to_sb[tid_in_master].try_put(byte_push) ) else $fatal(1, "Can't put to resp mb");
                                end
                            end
                        end
                        
                        // $display("%0t: ***** Slave pushed %0d bytes for AR: %s", $time, matched_bytes, ar_got.to_str());
                    end
                    
                    // NO ERRORS!
                    begin
                        automatic logic[R_RESP_WIDTH-1:0] resp_v = ($urandom_range(0, 99) < error_rate) ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
                        r_send = new(tid_v[winner_tid], data_chans[winner_tid].arr[cur_beat[winner_tid]], resp_v, last_chans[winner_tid].arr[cur_beat[winner_tid]], r_user);
                    end
                    assert(out_r_q.try_put(r_send));
                    
                    //~ $display("%0t: %0s s%0d %0d/%0d", $time, SLAVE_ID, r_send.to_str(), cur_beat[winner_tid]+1, t_now[winner_tid].len+1);
                    
                    if (last_chans[winner_tid].arr[cur_beat[winner_tid]]) begin
                        cur_beat[winner_tid] = 0;
                        has_active[winner_tid] = 1'b0;
                        rd_locked = 1'b0;
                    end else begin
                        cur_beat[winner_tid]++;
                    end
                end
            end
        end     
    endtask
    
    // AR Input Channel Manager
    task ar_channel_manager();
        logic[AR_TID_WIDTH-1:0]     ar_tid;
        logic[ADDR_WIDTH-1:0]       ar_addr;
        logic[LEN_WIDTH-1:0]        ar_len;
        logic[SIZE_WIDTH-1:0]       ar_size;
        logic[BURST_WIDTH-1:0]      ar_burst;
        logic[LOCK_WIDTH-1:0]       ar_lock;
        logic[CACHE_WIDTH-1:0]      ar_cache;
        logic[PROT_WIDTH-1:0]       ar_prot;
        logic[QOS_WIDTH-1:0]        ar_qos;
        logic[REGION_WIDTH-1:0]     ar_region;
        logic[AR_USER_WIDTH-1:0]    ar_user;
        axi_awr_chan #(.TID_WIDTH(AR_TID_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .LOCK_WIDTH(LOCK_WIDTH), .CACHE_WIDTH(CACHE_WIDTH), .PROT_WIDTH(PROT_WIDTH), .QOS_WIDTH(QOS_WIDTH), .REGION_WIDTH(REGION_WIDTH), .USER_WIDTH(AR_USER_WIDTH))
            ar_c_push;
        
        forever begin
            vif.read_ar(SLAVE_ID, ar_tid, ar_addr, ar_len, ar_size, ar_burst, ar_lock, ar_cache, ar_prot, ar_qos, ar_region, ar_user, stall_rate_ar);
            ar_c_push = new(ar_tid, ar_addr, ar_len, ar_size, ar_burst, ar_lock, ar_cache, ar_prot, ar_qos, ar_region, ar_user);
            assert(inp_ar_q[int'(ar_tid)].try_put(ar_c_push));
`ifdef VERBOSE
            $display("%0t: AR --> s%0d  %s", $time, SLAVE_ID, ar_c_push.to_str());
`endif
        end
    endtask
    
    task start();
        fork
            ar_channel_manager();
            r_channel_manager();
            
            r_responder();
        join_none
    endtask
endclass
endpackage
