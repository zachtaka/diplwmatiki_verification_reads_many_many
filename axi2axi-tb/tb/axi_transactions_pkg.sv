
package axi_transactions_pkg;
import axi_global_pkg::*;
import noc_global::*;
import tb_pkg_general::*;

typedef enum logic { WRITE_TRANSACTION = 1'b0,
                     READ_TRANSACTION  = 1'b1 } transaction_type;

function automatic string trans_type_to_str(transaction_type t_in);
    return (t_in == WRITE_TRANSACTION) ? "W" : "R";
endfunction

function automatic string burst_to_str(axi_burst_type b_in);
    return (b_in == AXI_BURST_FIXED) ? "F" :
           (b_in == AXI_BURST_INCR)  ? "I" :
                                       "W";
endfunction

class axi_transaction #(parameter int ADDRESS_WIDTH = 32);
    transaction_type t_type;
    logic[ADDRESS_WIDTH-1:0] address;
    int size, len, tid;
    int burst, lock, cache, prot, qos, region; // <- convert them to enumerations!    
    // data, if any
    logic[7:0]  payload[];
    
    function new(transaction_type t_type_, int tid_, logic[ADDRESS_WIDTH-1:0] address_, int len_, int size_, int burst_, int lock_, int cache_, int prot_, int qos_, int region_);//, logic[7:0] payload_[]=null);
        t_type      = t_type_;
        address     = address_;
        size        = size_;
        len         = len_;
        tid         = tid_;
        burst       = burst_;
        lock        = lock_;
        cache       = cache_;
        prot        = prot_;
        qos         = qos_;
        region      = region_;
        // if (t_type == WRITE_TRANSACTION) begin
            // payload = payload_;
        // end
    endfunction
    
    // Hard Copy of the object
    function copy(ref axi_transaction #(ADDRESS_WIDTH) at);
        at = new(t_type, address, size, len, tid, burst, lock, cache, prot, qos, region);
        at.payload = payload;
    endfunction
    
    // returns transaction info a human readable format
    function string to_str();
        return $sformatf("%s [T=%0d] s=%0d l=%0d @ %0h - b=%0d %0d %0d %0d %0d %0d", trans_type_to_str(t_type), tid, size, len, address,
                                burst_to_str(axi_burst_type'(burst)), lock, cache, prot, qos, region);
    endfunction
    
    static function int get_total_bytes(logic[ADDRESS_WIDTH-1:0] address, int len, int size);
        automatic int num_bytes = 2**size;
        automatic int byte_mask = num_bytes - 1;
        logic[ADDRESS_WIDTH-1:0] addr_mod_size;
        addr_mod_size = address & byte_mask;
        return (2**size)*(len+1) - addr_mod_size;
    endfunction
    
    function logic[ADDRESS_WIDTH-1:0] get_addr_of_byte(int b, axi_burst_type burst);
        if (burst == AXI_BURST_INCR) begin
            automatic logic[ADDRESS_WIDTH-1:0] bv = b;
            return address + bv;
        end else begin
            assert (1'b0) else $fatal(1, "INCR ONLY");
        end
    endfunction
endclass

typedef logic[7:0] TD_DYN_ARR_8LOGIC[];

class payload_generator;
    const logic IS_RANDOM_DATA;
    
    function new(logic IS_RANDOM_DATA_);
        // len = len_;
        // size = size_;
        IS_RANDOM_DATA = IS_RANDOM_DATA_;
        assert (!IS_RANDOM_DATA) else $fatal(1, "No random data support");
    endfunction
    
    function TD_DYN_ARR_8LOGIC gen_payload(int total_bytes, int offset_val=0);
        gen_payload = new[total_bytes];
        if (!IS_RANDOM_DATA) begin
            for (int p=0; p<gen_payload.size(); p++) begin
                gen_payload[p] = offset_val+p;
            end
        end
    endfunction
endclass

// Generates AXI transactions
class axi_transaction_generator #(  parameter int ADDRESS_WIDTH = 32,
                                    parameter int STRB_WIDTH    = 8);
    const int TIDS;
    const int DATA_LANES;
    const int BURST_DISTR_FIXED;
    const int BURST_DISTR_INCR;
    const int BURST_DISTR_WRAP;
    
    const logic DO_UNALIGNED;
    
    const int MIN_BURST_LEN;
    const int MAX_BURST_LEN;
    const int MIN_BURST_SIZE;
    const int MAX_BURST_SIZE;
    const logic[ADDRESS_WIDTH-1:0] ADDR_MAX;
    
    const int WRITE_DISTR;
    const int READ_DISTR;
    
    const tb_gen_mode_t tb_gen_mode;
    string inptb_lines[$];
    
    rand transaction_type t_type;
    rand int size, len, tid;
    
	rand int lock, cache, prot, qos, region; // <- convert them to enumerations!
    rand axi_burst_type burst;
    
    rand logic[ADDRESS_WIDTH-1:0] address;
    payload_generator p_gen;
    logic[7:0] payload[];
    
    function new(int TIDS_, int DATA_LANES_, logic[ADDRESS_WIDTH-1:0] ADDR_MAX_,
                 tb_gen_mode_t tb_gen_mode_,
                 string INPFILE_NAME,
                 int WRITE_DISTR_, int READ_DISTR_,
                 int BURST_DISTR_FIXED_, int BURST_DISTR_INCR_, int BURST_DISTR_WRAP_, int DO_UNALIGNED_,
                 int MIN_BURST_LEN_, int MAX_BURST_LEN_,
                 int MIN_BURST_SIZE_, int MAX_BURST_SIZE_,
                 logic IS_RANDOM_DATA_);
        TIDS = TIDS_;
        DATA_LANES = DATA_LANES_;
        assert ( (2**log2c(DATA_LANES)) == DATA_LANES) else $fatal(1, "Data lanes = %d - must be power of 2", DATA_LANES);
        
        tb_gen_mode = tb_gen_mode_;
        if (tb_gen_mode == TBGMT_DIRECTED) begin
            automatic int inpfile_h = $fopen(INPFILE_NAME, "r");
            string line_now;
            automatic int lines_read = 0;
            
            assert(inpfile_h !== 0) else $fatal(1, "Failed to open file %s", INPFILE_NAME);
            // $display("FILE OPEN");
            
            while (!$feof(inpfile_h) && ($fgets(line_now, inpfile_h) != 0)) begin
                automatic string c_first = string'(line_now.getc(0));
                if ( c_first.compare("#") ) begin
                    // trim spaces
                    inptb_lines.push_back(line_now);
                    lines_read++;
                    // $display("got: %s", c_first);
                end
            end
            // $display("read %0d lines", lines_read);
            $fclose(inpfile_h);
        end
        
        WRITE_DISTR = WRITE_DISTR_;
        READ_DISTR  = READ_DISTR_;
        
        BURST_DISTR_FIXED   = BURST_DISTR_FIXED_;
        BURST_DISTR_INCR    = BURST_DISTR_INCR_;
        BURST_DISTR_WRAP    = BURST_DISTR_WRAP_;
        DO_UNALIGNED        = DO_UNALIGNED_;
        
        
        p_gen = new(IS_RANDOM_DATA_);
        
        // LEN (0...255)
        assert (MIN_BURST_LEN_ >= 0 && MIN_BURST_LEN_ <= 255) else $fatal(1, "MIN_BURST_LEN == %0d, limits: [%0d,%0d]", MIN_BURST_LEN_, 0, 255);
        MIN_BURST_LEN = MIN_BURST_LEN_;
        assert (MAX_BURST_LEN_ >= MIN_BURST_LEN_ && MAX_BURST_LEN_ <= 255) else $fatal(1, "MAX_BURST_LEN == %0d, limits: [%0d,%0d]", MAX_BURST_LEN_, MIN_BURST_LEN, 255);
        MAX_BURST_LEN = MAX_BURST_LEN_;
        
        // SIZE (0...log(lanes))
        assert (MIN_BURST_SIZE_ >= 0 && MIN_BURST_SIZE_ <= log2c(DATA_LANES) ) else $fatal(1, "MIN_BURST_SIZE == %0d, limits: [%0d,%0d]", MIN_BURST_SIZE_, 0, log2c(DATA_LANES));
        MIN_BURST_SIZE = MIN_BURST_SIZE_;
        assert (MAX_BURST_SIZE_ >= MIN_BURST_SIZE && MAX_BURST_SIZE_ <= log2c(DATA_LANES) ) else $fatal(1, "MAX_BURST_SIZE == %0d, limits: [%0d,%0d]", MAX_BURST_SIZE_, MIN_BURST_SIZE, log2c(DATA_LANES));
        MAX_BURST_SIZE = MAX_BURST_SIZE_;
        // $display("size = %0d...%0d", MIN_BURST_SIZE, MAX_BURST_SIZE);
        
        ADDR_MAX = ADDR_MAX_;
    endfunction
    
    function logic do_generate();
        int total_bytes;
        logic ret_val;
        if (tb_gen_mode == TBGMT_RANDOM) begin
            assert(this.randomize()) else $fatal(1, "failed to randomize");
            ret_val = 1'b1;
        end else if (tb_gen_mode == TBGMT_DIRECTED) begin
            // Format:
            // Type - Address - Burst - Size - Len - TID - Cache - Lock - Prot - QOS - Region
            string line_read;
            int dummy;
            if (inptb_lines.size > 0) begin
                int char_type;
                line_read = inptb_lines.pop_front();
                dummy = $sscanf(line_read, "\%c%h\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t",
                                char_type, address, burst, size, len, tid, cache, lock, prot, qos, region);
                assert(char_type == "W" || char_type == "R") else $fatal(1, "W or R for type only");
                assert(address < ADDR_MAX) else $fatal(1, "address must be less than MAX (%0h)", ADDR_MAX);
                t_type = char_type == "W" ? WRITE_TRANSACTION : READ_TRANSACTION;
                ret_val = 1;
                // $display(address, burst, size, len);
            end else begin
                ret_val = 0;
            end
        end
        
        if (ret_val) begin
            total_bytes = axi_transaction#(.ADDRESS_WIDTH(ADDRESS_WIDTH))::get_total_bytes(address, len, size);
            payload = p_gen.gen_payload(total_bytes);
        end
        
        return ret_val;
    endfunction
    
    // Constraint Order: W/R -> Burst -> Size -> Length
    constraint tt_order {
        solve t_type    before burst;
        solve burst     before size;
        solve size      before len;
        solve len       before address;
    }
    
    // Transaction type - Write/Read distribution
    constraint c_wr_distr {
        t_type dist { WRITE_TRANSACTION   := WRITE_DISTR,
                      READ_TRANSACTION    := READ_DISTR};
    }
    
    // BURST
    constraint c_burst {
        burst dist { AXI_BURST_FIXED    :=  BURST_DISTR_FIXED,
                     AXI_BURST_INCR     :=  BURST_DISTR_INCR,
                     AXI_BURST_WRAP     :=  BURST_DISTR_WRAP};
    }
    
    // SIZE
    constraint c_size {
        // note, size = 0 -> bytes/beat = 1 (2^0)
        size inside { [MIN_BURST_SIZE:MAX_BURST_SIZE] };
    }
    
    
    function int get_min3(int m0, int m1, int m2);
        if (m1 < m0 && m1 < m2) return m1;
        if (m2 < m0 && m2 < m1) return m2;
        return m0;
    endfunction
    

    // [FiXit][FiXit][FiXit][FiXit][FiXit][FiXit][FiXit][FiXit]
    // Fix! Length constraint is CRAP
    // Include address boundary!!!!
    // LEN
    constraint c_len_all {
        if (burst == AXI_BURST_WRAP) {
            // WRAP must have a length of 2/4/8/16
            len inside { 4'h1, 4'h3, 4'h7, 4'hF } ;
        } else {
            if (MIN_BURST_LEN<MAX_BURST_LEN) {
                len inside { [MIN_BURST_LEN:MAX_BURST_LEN] };
            } else {
                len == MIN_BURST_LEN;
            }
            ((len+1)*(2**size)) <= 2**12;
        }
    }
    // [FiXit][FiXit][FiXit][FiXit][FiXit][FiXit][FiXit][FiXit]
    
    // ADDRESS
    constraint c_address {
        // unconstrained when not(WRAP)
        if (!DO_UNALIGNED || burst == AXI_BURST_WRAP) {
            // must be aligned to the size of transfer
            (address % (2**size)) == 0;
        }
        // 4K
        (address[0 +: 12] <= (2**12-((len+1) << size))) &&
        (address < ADDR_MAX);
    }
    
    // everything else
    constraint c_others {
        tid     inside { [0:TIDS-1] };
        lock    == 0;
        cache   == 0;
        prot    == 0;
        qos     == 0;
        region  == 0;
    }
    
    // to axi_transaction, used to put to channel
    function axi_transaction #(ADDRESS_WIDTH) to_axi_transaction();
        axi_transaction #(.ADDRESS_WIDTH(ADDRESS_WIDTH)) ret_t;
        
        ret_t = new(t_type, tid, address, len, size, burst, lock, cache, prot, qos, region);
        ret_t.payload = payload;
        
        return ret_t;
    endfunction
    
    function string to_str();
        return $sformatf(" %s [T=%0d] s=%0d l=%0d @ %0h - b=%s l=%0d c=%0d p=%0d q=%0d r=%0d", trans_type_to_str(t_type), tid, size, len, address, burst_to_str(burst), lock, cache, prot, qos, region);
    endfunction
endclass

class axi_payload_translator #( parameter int ADDRESS_WIDTH = 32,
                                parameter int DATA_WIDTH    = 64);
    const int DATA_LANES;
    
    function new(int DATA_LANES_);
        DATA_LANES = DATA_LANES_;
    endfunction
    
    function int get_payload(int len, int size, logic[ADDRESS_WIDTH-1:0] address, axi_burst_type burst, logic[7:0] payload[], output logic[DATA_WIDTH-1:0] data[], output logic[DATA_WIDTH/8-1:0] strb[], output logic last[], output logic[ADDRESS_WIDTH-1:0] beat_addr[]);
        automatic int burst_length  = len+1;
        automatic int num_bytes     = 2**size;
        automatic int byte_mask     = num_bytes - 1;
        automatic int burst_mask    = (burst_length * num_bytes) - 1;
        
        automatic logic[ADDRESS_WIDTH-1:0] start_addr   = address;
        automatic logic[ADDRESS_WIDTH-1:0] aligned_addr = start_addr & ~byte_mask;
        // alt1: aligned_addr = (start_addr / num_bytes) * num_bytes; // alt2: aligned_addr = start_addr - (start_addr % num_bytes)
        automatic logic[ADDRESS_WIDTH-1:0] lower_wrap_bound = burst == AXI_BURST_WRAP ? start_addr & ~burst_mask : 0;
        automatic logic[ADDRESS_WIDTH-1:0] upper_wrap_bound = burst == AXI_BURST_WRAP ? lower_wrap_bound + burst_length * num_bytes : 0;
        automatic logic is_aligned  = (aligned_addr == start_addr);
        
        logic[ADDRESS_WIDTH-1:0] addr;
        logic[ADDRESS_WIDTH-1:0] addr_misalign;
        int lower_byte_lane, upper_byte_lane;
        automatic int cur_byte = 0;
        automatic int total_bytes = axi_transaction#(.ADDRESS_WIDTH(ADDRESS_WIDTH))::get_total_bytes(start_addr, len, size);
        
        const logic[ADDRESS_WIDTH-1:0] BUS_MASK = DATA_LANES-1;
        
        data = new[burst_length];
        strb = new[burst_length];
        last = new[burst_length];
        beat_addr = new[burst_length];
        

        addr = start_addr;
        for(int l=0; l<burst_length; l++) begin
            addr_misalign = addr & ~BUS_MASK;
            lower_byte_lane = addr - addr_misalign;
            
            if (is_aligned) begin
                upper_byte_lane = lower_byte_lane + num_bytes - 1;
            end else begin
                upper_byte_lane = aligned_addr + num_bytes - 1 - addr_misalign;
            end
            // $display("%0t:", $time,
                     // " addr=%0h, misalign = %0h (aligned? %0b)", addr, addr_misalign, is_aligned,
                     // "lo = %0d (%0h - %0h)", lower_byte_lane, addr, addr_misalign,
                     // " - hi = %0d (%0h + %0h - 1 - %0h)", upper_byte_lane, aligned_addr, num_bytes, addr_misalign);
            
            data[l] = {DATA_WIDTH{1'b1}}; // x}}; // WAS 1'bx
            strb[l] = 0;
            last[l] = l == (burst_length-1) ? 1 : 0;
            beat_addr[l] = addr_misalign;
            
            for(int b=0; b<DATA_LANES; b++) begin
                if (b >= lower_byte_lane && b <= upper_byte_lane) begin
                    data[l][b*8 +: 8] = payload[cur_byte];
                    strb[l][b]        = 1'b1;
                    
                    //~ byte_addr_offset[cur_byte] = (is_aligned ? addr : aligned_addr) + b - start_addr;
                    cur_byte++;
                end
            end
            // $display("%0t: [%0d] d=%0h s=%0b [byte0=%0d]", $time, l, data[l], strb[l], lower_byte_lane);
            if (burst != AXI_BURST_FIXED) begin
                if (is_aligned) begin
                    addr = addr + num_bytes;
                    if (burst == AXI_BURST_WRAP) begin
                        if (addr >= upper_wrap_bound) begin
                            addr = lower_wrap_bound;
                        end
                    end
                end else begin
                    addr = aligned_addr + num_bytes;
                    is_aligned = 1'b1;
                end
            end
        end
        
        return burst_length;
    endfunction
endclass

class axi_awr_chan #(   parameter int TID_WIDTH     = 1,
                        parameter int ADDR_WIDTH    = 32,
                        parameter int LEN_WIDTH     = 8,
                        parameter int SIZE_WIDTH    = 3,
                        parameter int BURST_WIDTH   = 2,
                        parameter int LOCK_WIDTH    = 1,
                        parameter int CACHE_WIDTH   = 4,
                        parameter int PROT_WIDTH    = 3,
                        parameter int QOS_WIDTH     = 4,
                        parameter int REGION_WIDTH  = 4,
                        parameter int USER_WIDTH    = 2);
    
    logic[TID_WIDTH-1:0]    tid;
    logic[ADDR_WIDTH-1:0]   addr;
    logic[LEN_WIDTH-1:0]    len;
    logic[SIZE_WIDTH-1:0]   size;
    logic[BURST_WIDTH-1:0]  burst;
    logic[LOCK_WIDTH-1:0]   lock;
    logic[CACHE_WIDTH-1:0]  cache;
    logic[PROT_WIDTH-1:0]   prot;
    logic[QOS_WIDTH-1:0]    qos;
    logic[REGION_WIDTH-1:0] region;
    logic[USER_WIDTH-1:0]   user;
    
    function new(logic[TID_WIDTH-1:0] tid_, logic[ADDR_WIDTH-1:0] addr_, logic[LEN_WIDTH-1:0] len_, logic[SIZE_WIDTH-1:0] size_, logic[BURST_WIDTH-1:0] burst_, logic[LOCK_WIDTH-1:0] lock_, logic[CACHE_WIDTH-1:0] cache_, logic[PROT_WIDTH-1:0] prot_, logic[QOS_WIDTH-1:0] qos_, logic[REGION_WIDTH-1:0] region_, logic[USER_WIDTH-1:0] user_);
        tid     = tid_;
        addr    = addr_;
        len     = len_;
        size    = size_;
        burst   = burst_;
        lock    = lock_;
        cache   = cache_;
        prot    = prot_;
        qos     = qos_;
        region  = region_;
        user    = user_;
    endfunction
    
    function string to_str();
        return $sformatf("[T=%0d] l=%0d s=%0d (%0d) @ %0h - b=%s l=%0d c=%0d p=%0d q=%0d r=%0d", tid, len, size, 2**size, addr, burst_to_str(axi_burst_type'(burst)), lock, cache, prot, qos, region);
    endfunction
endclass

class axi_w_chan #( parameter int TID_WIDTH     = 1,
                    parameter int DATA_WIDTH    = 64,
                    parameter int USER_WIDTH    = 2);
    
    logic[TID_WIDTH-1:0]    tid;
    logic[DATA_WIDTH-1:0]   data;
    logic[DATA_WIDTH/8-1:0] strb;
    logic                   last;
    logic[USER_WIDTH-1:0]   user;
    
    function new(logic[TID_WIDTH-1:0] tid_, logic[DATA_WIDTH-1:0] data_, logic[DATA_WIDTH/8-1:0] strb_, logic last_, logic[USER_WIDTH-1:0] user_);
        tid     = tid_;
        data    = data_;
        strb    = strb_;
        last    = last_;
        user    = user_;
    endfunction
    
    function string to_str();
        return $sformatf("[T=%0d] d=%0h s=%0b L=%b", tid, data, strb, last);
    endfunction
endclass

class axi_b_chan #( parameter int TID_WIDTH     = 1,
                    parameter int BRESP_WIDTH   = 2,
                    parameter int USER_WIDTH    = 2);
    
    logic[TID_WIDTH-1:0]    tid;
    logic[BRESP_WIDTH-1:0]  resp;
    logic[USER_WIDTH-1:0]   user;
    
    function new(logic[TID_WIDTH-1:0] tid_, logic[BRESP_WIDTH-1:0] resp_, logic[USER_WIDTH-1:0] user_);
        tid     = tid_;
        resp    = resp_;
        user    = user_;
    endfunction
    
    function string to_str();
        return $sformatf("[T=%0d] r=%0d", tid, resp);
    endfunction
endclass

class axi_r_chan #( parameter int TID_WIDTH     = 1,
                    parameter int DATA_WIDTH    = 64,
                    parameter int RRESP_WIDTH   = 2,
                    parameter int USER_WIDTH    = 2);
    
    logic[TID_WIDTH-1:0]    tid;
    logic[DATA_WIDTH-1:0]   data;
    logic[RRESP_WIDTH-1:0]  resp;
    logic                   last;
    logic[USER_WIDTH-1:0]   user;
    
    function new(logic[TID_WIDTH-1:0] tid_, logic[DATA_WIDTH-1:0] data_, logic[RRESP_WIDTH-1:0] resp_, logic last_, logic[USER_WIDTH-1:0] user_);
        tid     = tid_;
        data    = data_;
        resp    = resp_;
        last    = last_;
        user    = user_;
    endfunction
    
    function string to_str();
        return $sformatf("[T=%0d] d=%0h R=%0d L=%0b", tid, data, resp, last);
    endfunction
endclass


class axi_tb_byte
#(
    parameter int ADDRESS_WIDTH = 32
);
    logic                       be_fbelbe;
    int                         src;
    logic                       has_value;
    int                         value;
    int                         tid;
    logic[ADDRESS_WIDTH-1:0]    address;
    
    function new(int src_, logic has_value_, int value_, int tid_, logic[ADDRESS_WIDTH-1:0] address_);
    // function new(int src_, logic has_value_, int value_, logic be_fbelbe_, int tid_, logic[ADDRESS_WIDTH-1:0] address_);
        src         = src_;
        has_value   = has_value_;
        value       = value_;
        // be_fbelbe   = be_fbelbe_;
        tid         = tid_;
        address     = address_;
    endfunction
    
    function logic compare(axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH)) bt_in);
        automatic logic ret = (src == bt_in.src) && (address == bt_in.address) && (has_value == bt_in.has_value);
        
        if (has_value) begin
            ret = ret && (value == bt_in.value);
        end
        return ret;
    endfunction
    
    function string to_str();
        // if (has_value) begin
        //     return $sformatf("0x%0h @ 0x%0h - S=%0d / FLBE=%0b", value, address, src, be_fbelbe);
        // end else begin
        //     return $sformatf("0x?? @ 0x%0h - S=%0d / FLBE=%0b", address, src, be_fbelbe);
        // end
        if (has_value) begin
            return $sformatf("0x%0h @ 0x%0h - S=%0d", value, address, src);
        end else begin
            return $sformatf("0x?? @ 0x%0h - S=%0d", address, src);
        end
    endfunction
    
    function void hard_copy(ref axi_tb_byte #(.ADDRESS_WIDTH(ADDRESS_WIDTH)) bt_out);
        // bt_out = new(src, has_value, value, be_fbelbe, tid, address);
        bt_out = new(src, has_value, value, tid, address);
        // bt_out = new(src, value, tid, address);
    endfunction
endclass

endpackage

