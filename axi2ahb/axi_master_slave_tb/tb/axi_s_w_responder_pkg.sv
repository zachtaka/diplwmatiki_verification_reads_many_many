package axi_s_w_responder_pkg;
import noc_global::*;
import ni_global::*;
import tb_pkg_general::*;
import axi_transactions_pkg::*;
import axi_rv_if_s_w_abstract_pkg::*;

class axi_s_w_responder 
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
    // AW / W
    parameter int AW_USER_WIDTH = 2,
    parameter int AW_TID_WIDTH  = 2,
    parameter int W_DATA_WIDTH  = 64,
    parameter int W_USER_WIDTH  = 2,
    // B
    parameter int B_RESP_WIDTH  = 2,
    parameter int B_USER_WIDTH  = 2,

    parameter int AW_MTID_W     = 1,
    parameter int MASTERWTFW    = MASTERS > 1 ? $clog2(MASTERS) : 1
);
    
    const int SLAVE_ID;
    const int TIDS_M;
    const int DATA_LANES;
    const int TIDS_S;
    // const logic PUSH_TO_MB;
    int serve_rate;
    int error_rate;
    int stall_rate_aw;
    int stall_rate_w;
    //
    int trans_received;
    int bytes_received;
    
    // vIF
    axi_rv_if_s_w_abstract
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
        .AW_USER_WIDTH  (AW_USER_WIDTH),
        .AW_TID_WIDTH   (AW_TID_WIDTH),
        .W_DATA_WIDTH   (W_DATA_WIDTH),
        .W_USER_WIDTH   (W_USER_WIDTH),
        .B_RESP_WIDTH   (B_RESP_WIDTH),
        .B_USER_WIDTH   (B_USER_WIDTH)
    ) vif;
    
    // input queues
    mailbox #(axi_awr_chan #(.TID_WIDTH(AW_TID_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .LOCK_WIDTH(LOCK_WIDTH), .CACHE_WIDTH(CACHE_WIDTH), .PROT_WIDTH(PROT_WIDTH), .QOS_WIDTH(QOS_WIDTH), .REGION_WIDTH(REGION_WIDTH), .USER_WIDTH(AW_USER_WIDTH)))
        inp_aw_q[]; // AW
    mailbox #(int)
        inp_tid_w_q; // keeps track of the tids for the W chanel
    mailbox #(axi_w_chan #(.TID_WIDTH(AW_TID_WIDTH), .DATA_WIDTH(W_DATA_WIDTH), .USER_WIDTH(W_USER_WIDTH)))
        inp_w_q[];  // W
    rr_arb_c w_arb;
    // mbs to scoreboard
    // mailbox w_req_mb[MASTERS][];
    // mailbox w_resp_mb[MASTERS][];
    // output queues
    // TODO: Use one per TID!
    mailbox #(axi_b_chan #(.TID_WIDTH(AW_TID_WIDTH), .BRESP_WIDTH(B_RESP_WIDTH), .USER_WIDTH(B_USER_WIDTH)))
        out_b_q;
    
    // SB mailbox
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) byte_mb_p;
    mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) byte_mb_np;
    
    
    function new(int SLAVE_ID_, int TIDS_M_, int DATA_LANES_,
                 int IS_RANDOM_DATA_,
                 int serve_rate_, int error_rate_, int stall_rate_aw_, int stall_rate_w_,
                 mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) byte_mb_p_,
                 mailbox #(axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH))) byte_mb_np_);
        
        SLAVE_ID    = SLAVE_ID_;
        TIDS_M      = TIDS_M_;
        DATA_LANES  = DATA_LANES_;
        TIDS_S      = 2**AW_TID_WIDTH;
        serve_rate  = serve_rate_;
        error_rate  = error_rate_;
        stall_rate_aw  = stall_rate_aw_;
        stall_rate_w  = stall_rate_w_;
        
        inp_tid_w_q = new();
        inp_aw_q = new[TIDS_S]; //TIDS_M*MASTERS];
        inp_w_q  = new[TIDS_S]; //TIDS_M*MASTERS];
        for(int t=0; t<TIDS_S; t++) begin
            inp_aw_q[t] = new();
            inp_w_q[t]  = new();
        end
        
        out_b_q = new();
        
        w_arb = new(TIDS_S);
        
        byte_mb_p = byte_mb_p_;
        byte_mb_np = byte_mb_np_;
    endfunction
    
    // B Output Channel Mangemer
    task b_channel_manager();
        forever begin
            axi_b_chan #(.TID_WIDTH(AW_TID_WIDTH), .BRESP_WIDTH(B_RESP_WIDTH), .USER_WIDTH(B_USER_WIDTH))
                b_now;
            out_b_q.get(b_now);
`ifdef VERBOSE
            $display("%0t: B <-- s%0d  %s", $time, SLAVE_ID, b_now.to_str());
`endif
            vif.write_b(SLAVE_ID, b_now.tid, b_now.resp, b_now.user);
        end
    endtask
    
    // B Reponder
    task b_responder();
        automatic logic[B_USER_WIDTH-1:0] b_user                        = '{B_USER_WIDTH{1'b1}};
        automatic logic arb_reqs[]                                      = new[TIDS_S];
        automatic logic has_active[]                                    = new[TIDS_S];
        automatic int cur_byte[]                                        = new[TIDS_S];
        automatic int cur_beat[]                                        = new[TIDS_S];
        automatic axi_transaction #(.ADDRESS_WIDTH(ADDR_WIDTH)) t_now[] = new[TIDS_S];
        automatic array_wrapper #(logic[7:0]) payload_now[]             = new[TIDS_S];
        // automatic logic[AW_TID_WIDTH-1:0] tid_v[]                       = new[TIDS_S];
        automatic logic[ADDR_WIDTH-1:0]   addr_v[]                      = new[TIDS_S];
        automatic logic                   is_posted[]                   = new[TIDS_S];
        
        for(int t=0; t<TIDS_S; t++) begin
            cur_byte[t]     = 0;
            cur_beat[t]     = 0;
            has_active[t]   = 0;
            payload_now[t]  = new();
        end
        
        forever begin
            vif.posedge_clk();
			
            if ($urandom_range(0, 99) < serve_rate) begin
                int winner_tid;
                // arbitrate among TID queues
                for(int t=0; t<TIDS_S; t++) begin
                    arb_reqs[t] = ( has_active[t] & inp_w_q[t].num() > 0 ) |
                                  (~has_active[t] & inp_aw_q[t].num() > 0);
                end
                winner_tid = w_arb.arbitrate(arb_reqs, 1'b1);
                // master_id  = winner_tid / TIDS_M;
                if (winner_tid >= 0) begin
`ifdef VERBOSE_SSS
                    $display("%0t: ", $time,
                             "arb reqs[%0d] = (%0b & %0d > 0) | (%0b & %0d > 0) = %0b",
                              winner_tid, has_active[winner_tid], inp_w_q[winner_tid].num(), ~has_active[winner_tid], inp_aw_q[winner_tid].num(), arb_reqs[winner_tid]);
`endif
                    
                    if (!has_active[winner_tid]) begin
                        axi_awr_chan #(.TID_WIDTH(AW_TID_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .LOCK_WIDTH(LOCK_WIDTH), .CACHE_WIDTH(CACHE_WIDTH), .PROT_WIDTH(PROT_WIDTH), .QOS_WIDTH(QOS_WIDTH), .REGION_WIDTH(REGION_WIDTH), .USER_WIDTH(AW_USER_WIDTH))
                            aw_got;
                        
                        assert(inp_aw_q[winner_tid].try_get(aw_got)) else $fatal(1, "--");
                        
                        // t_now[winner_tid] = new(WRITE_TRANSACTION, int'(aw_got.tid), aw_got.addr, int'(aw_got.len), int'(aw_got.size), int'(aw_got.burst), int'(aw_got.lock), int'(aw_got.cache), int'(aw_got.prot), int'(aw_got.qos), int'(aw_got.region));
                        // t_now[winner_tid] = new(WRITE_TRANSACTION, tid_in_master   , aw_got.addr, int'(aw_got.len), int'(aw_got.size), int'(aw_got.burst), int'(aw_got.lock), int'(aw_got.cache), int'(aw_got.prot), int'(aw_got.qos), int'(aw_got.region));
                        t_now[winner_tid] = new(WRITE_TRANSACTION, int'(aw_got.tid), aw_got.addr, int'(aw_got.len), int'(aw_got.size), int'(aw_got.burst), int'(aw_got.lock), int'(aw_got.cache), int'(aw_got.prot), int'(aw_got.qos), int'(aw_got.region));
                        // $display("%0t: SSS::: %s", $time, t_now[winner_tid].to_str());
                        // $display("\n", axi_burst_type'(t_now[winner_tid].burst), " | ", AXI_BURST_WRAP, "\n");
                        // $display("\n", axi_burst_type'(t_now[winner_tid].burst) == AXI_BURST_WRAP, "\n");
                        trans_received++;
`ifdef VERBOSE_S
                        $display("%0t: S-W T received = %0d", $time, trans_received);
`endif
                        
                        // tid_v[winner_tid] = aw_got.tid;
                        addr_v[winner_tid] = aw_got.addr;
                        
                        is_posted[winner_tid] = aw_got.cache[0];
                        
                        //~ $display("%0t: ------------> addr_v[%0d] updated!!! to %0h", $time, winner_tid, addr_v[winner_tid],
                                 //~ "m=%0d, t=%0d", int'(addr_v[winner_tid][ADDR_MSTTID_P +: MASTERWTFW]), int'(addr_v[winner_tid][ADDR_MSTTID_P + MASTERWTFW +: AW_MTID_W]));
                        assert (int'(addr_v[winner_tid][ADDR_MSTTID_P +: MASTERWTFW]) inside {[0:MASTERS-1]}) else $fatal(1, "m_id out of range = %0d", int'(addr_v[winner_tid][ADDR_MSTTID_P +: MASTERWTFW]));
                        // len_v[winner_tid] = aw_got.len;
                        has_active[winner_tid] = 1'b1;
                        
                        // prepare payload array
                        payload_now[winner_tid].arr = new[ (t_now[winner_tid].len+1) * ( 2**(t_now[winner_tid].size)) ];
                        assert(cur_byte[winner_tid] == 0) else $fatal(1, "--");
                        assert(cur_beat[winner_tid] == 0) else $fatal(1, "--");
                    end
                    
                    if (inp_w_q[winner_tid].num() > 0) begin
                        int master_id, tid_in_master;
                        logic got_last_beat;
                        //master_id       = extract_master_from_addr(addr_v[winner_tid]); // int'(addr_v[winner_tid][ADDR_MSTTID_P                        +: log2c_1if1(MASTERS)]);
                        master_id       = int'(addr_v[winner_tid][ADDR_MSTTID_P +: MASTERWTFW]);
                        //tid_in_master   = extract_tid_from_addr(addr_v[winner_tid]); // int'(addr_v[winner_tid][ADDR_MSTTID_P +  log2c_1if1(MASTERS) +: log2c_1if1(TIDS_M)]);
                        tid_in_master   = int'(addr_v[winner_tid][ADDR_MSTTID_P + MASTERWTFW +: AW_MTID_W]);
                        assert (master_id inside {[0:MASTERS-1]}) else $fatal(1, "m_id=%0d", master_id, " out of range[%0d:%0d]", 0, MASTERS-1);
                        
                        got_last_beat = read_w_bytes(winner_tid, master_id, tid_in_master, t_now[winner_tid].len, t_now[winner_tid].size, t_now[winner_tid].burst, t_now[winner_tid].address,
                                                     payload_now[winner_tid].arr,
                                                     cur_byte[winner_tid],
                                                     cur_beat[winner_tid],
                                                     addr_v[winner_tid],
                                                     is_posted[winner_tid]);
                        if (got_last_beat) begin
                            axi_b_chan #(.TID_WIDTH(AW_TID_WIDTH), .BRESP_WIDTH(B_RESP_WIDTH), .USER_WIDTH(B_USER_WIDTH))
                                b_send;
                            automatic logic[B_RESP_WIDTH-1:0] resp_v = ($urandom_range(0, 99) < error_rate) ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
                            logic[AW_TID_WIDTH-1:0] tid_now;
                            tid_now = winner_tid;
                            t_now[winner_tid].payload = payload_now[winner_tid].arr;
                            // Push to output queue
                            // b_send = new(tid_int_to_vec(master_id, tid_in_master), resp_v, b_user);
                            b_send = new(tid_now, resp_v, b_user);
                            assert(out_b_q.try_put(b_send)) else $fatal(1, "--");
                            
                            has_active[winner_tid] = 1'b0;
                            cur_beat[winner_tid] = 0;
                            cur_byte[winner_tid] = 0;
                        end
                    end
                end
            end
        end
    endtask
    
    // return 1 when last beat is got
    function logic read_w_bytes(int winner_tid, int master_id, int tid_in_master, int len, int size, int burst, logic[ADDR_WIDTH-1:0] addr_start,
                                inout logic[7:0] payload_now[], inout int cur_byte, inout int cur_beat, inout logic[ADDR_WIDTH-1:0] addr_vec, input logic is_posted);
        axi_w_chan #(.TID_WIDTH(AW_TID_WIDTH), .DATA_WIDTH(W_DATA_WIDTH), .USER_WIDTH(W_USER_WIDTH))
            w_got;
        automatic logic got_last_beat = 1'b0;
        
        // WRAP //
        automatic int burst_length  = len+1;
        automatic int num_bytes     = 2**size;
        automatic int byte_mask     = num_bytes - 1;
        automatic logic[ADDR_WIDTH-1:0] burst_mask  = (burst_length * num_bytes) - 1;
        automatic logic[ADDR_WIDTH-1:0] wrap_lo = addr_start & ~burst_mask;
        automatic logic[ADDR_WIDTH-1:0] wrap_hi = wrap_lo + burst_length*num_bytes;
        // WRAP //
        
        //~ $display("SLAVEry: length=%0d / bytes=%0d / burst_mask = %0h", burst_length, num_bytes, burst_mask);
        
        
        while (inp_w_q[winner_tid].num() > 0 && !got_last_beat) begin
            assert(inp_w_q[winner_tid].try_get(w_got)) else $fatal(1, "--");
`ifdef VERBOSE_BYTES
            $write("%0t: Ws%0d to SB:\n", $time, SLAVE_ID);
`endif
            
            // make sure there are now strobes turned on for the unaligned part, if @ 1st beat
            if (cur_beat[winner_tid] == 0) begin
                automatic int strb_first = addr_vec % DATA_LANES;
                if (strb_first > 0) begin
                    for (int i=0; i<strb_first; i++) begin
                        assert (w_got.strb[i]==1'b0) else $fatal(1, "\nCurrent beat is 1st, addr MOD lanes == %0d", strb_first, " but strb == %b", w_got.strb, " [addr=%0h]", addr_vec);
                    end
                end
            end
            
            for(int b=0; b<DATA_LANES; b++) begin
                if (w_got.strb[b]) begin
                    axi_tb_byte #(.ADDRESS_WIDTH(ADDR_WIDTH)) byte_push;
                    payload_now[cur_byte] = w_got.data[b*8 +: 8];
                    
                    cur_byte++;
                    byte_push = new(master_id, 1'b1, int'(w_got.data[b*8 +: 8]), tid_in_master, addr_vec);
`ifdef SB_VERBOSE
                    $write(" | %s", byte_push.to_str());
`endif
                    
                    // $display("%0d/%0d: %s", cur_beat, len,  byte_push.to_str());
                    
                    
                    if (is_posted) begin
                        assert(byte_mb_p.try_put(byte_push)) else $fatal(1, "--");
                    end else begin
                        assert(byte_mb_np.try_put(byte_push)) else $fatal(1, "--");
                    end
                    addr_vec = addr_vec + 1;
                    
                    bytes_received++;
//~ `ifdef VERBOSE_S
                    //~ $display("%0t: S-W B received = %0d", $time, bytes_received);
//~ `endif
                end
            end
            
            if (cur_beat == len) begin
                got_last_beat = 1'b1;
                assert (w_got.last) else $fatal(1, "Length=%0d, now at beat %0d but did not find LAST asserted!", len, cur_beat);
            end else begin
                assert (!w_got.last) else $fatal(1, "Length=%0d, now at beat %0d but LAST was asserted!", len, cur_beat);
            end
            cur_beat++;
            
            if (axi_burst_type'(burst) == AXI_BURST_WRAP && addr_vec >= wrap_hi) begin
                addr_vec = wrap_lo;
            end else if (axi_burst_type'(burst) == AXI_BURST_FIXED) begin
                addr_vec = addr_start;
            end
            
            
            //~ $display("SLAVEEEEE: %0h / lo=%0h / hi=%0h", addr_vec, wrap_lo, wrap_hi);
        end
        
        // $display("**** S-W leaving %0d/%0d", cur_beat, len);

        return got_last_beat;
    // endtask
    endfunction
    
    // AW Input Channel Managemer
    task aw_channel_manager();
        logic[AW_TID_WIDTH-1:0]     aw_tid;
        logic[ADDR_WIDTH-1:0]       aw_addr;
        logic[LEN_WIDTH-1:0]        aw_len;
        logic[SIZE_WIDTH-1:0]       aw_size;
        logic[BURST_WIDTH-1:0]      aw_burst;
        logic[LOCK_WIDTH-1:0]       aw_lock;
        logic[CACHE_WIDTH-1:0]      aw_cache;
        logic[PROT_WIDTH-1:0]       aw_prot;
        logic[QOS_WIDTH-1:0]        aw_qos;
        logic[REGION_WIDTH-1:0]     aw_region;
        logic[AW_USER_WIDTH-1:0]    aw_user;
        axi_awr_chan #(.TID_WIDTH(AW_TID_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .LEN_WIDTH(LEN_WIDTH), .SIZE_WIDTH(SIZE_WIDTH), .BURST_WIDTH(BURST_WIDTH), .LOCK_WIDTH(LOCK_WIDTH), .CACHE_WIDTH(CACHE_WIDTH), .PROT_WIDTH(PROT_WIDTH), .QOS_WIDTH(QOS_WIDTH), .REGION_WIDTH(REGION_WIDTH), .USER_WIDTH(AW_USER_WIDTH))
            aw_c_push;
        forever begin
            vif.read_aw(SLAVE_ID, aw_tid, aw_addr, aw_len, aw_size, aw_burst, aw_lock, aw_cache, aw_prot, aw_qos, aw_region, aw_user, stall_rate_aw);
            aw_c_push = new(aw_tid, aw_addr, aw_len, aw_size, aw_burst, aw_lock, aw_cache, aw_prot, aw_qos, aw_region, aw_user);
            
            assert(inp_aw_q[int'(aw_tid)].try_put(aw_c_push)) else $fatal(1, "--");
            assert(inp_tid_w_q.try_put(int'(aw_tid))) else $fatal(1, "--");
`ifdef VERBOSE
            $display("%0t: AW --> s%0d  %s", $time, SLAVE_ID, aw_c_push.to_str());
`endif
        end
    endtask
    
    // W
    task w_channel_manager();
        logic[AW_TID_WIDTH-1:0]     w_tid;
        logic[W_DATA_WIDTH-1:0]     w_data;
        logic[W_DATA_WIDTH/8-1:0]   w_strb;
        logic                       w_last;
        logic[W_USER_WIDTH-1:0]     w_user;
        // int tid_now, m_now, tid_m_now;
        axi_w_chan #(.TID_WIDTH(AW_TID_WIDTH), .DATA_WIDTH(W_DATA_WIDTH), .USER_WIDTH(W_USER_WIDTH))
            w_c_push;
        
        forever begin
            int tid_from_aw;
            vif.read_w(SLAVE_ID, w_tid, w_data, w_strb, w_last, w_user, stall_rate_w);
            w_c_push = new(w_tid, w_data, w_strb, w_last, w_user);
            
            // Ignore tid read completely - AXI4 doesn't need it anyways
            //~ wait(inp_tid_w_q.num() > 0);
            inp_tid_w_q.peek(tid_from_aw);

            // use the last tid arrived at the AW channel
            //~ assert(inp_tid_w_q.try_peek(tid_from_aw)) else $fatal(1, "--");
            
            assert(inp_w_q[int'(tid_from_aw)].try_put(w_c_push)) else $fatal(1, "--");
            if (w_last) begin
                assert(inp_tid_w_q.try_get(tid_from_aw)) else $fatal(1, "--");
            end
`ifdef VERBOSE
            $display("%0t: W --> s%0d  %s [t=%0d]", $time, SLAVE_ID, w_c_push.to_str(), tid_from_aw);
`endif
            //end
        end
    endtask
    
    task start();
        fork
            aw_channel_manager();
            w_channel_manager();
            
            b_responder();
            b_channel_manager();
        join_none
    endtask
    
    function void do_reset();
        trans_received  = 0;
        bytes_received  = 0;
        // flush queues
    endfunction
endclass
endpackage

