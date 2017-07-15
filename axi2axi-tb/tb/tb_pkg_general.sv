package tb_pkg_general;

function automatic int get_first_ace_4(logic[3:0] inp);
    automatic int ret = 0;
    while ( !inp ) begin
        inp = inp >> 1;
        ret++;
    end
    return ret;
endfunction

function automatic int get_last_ace_4(logic[3:0] inp);
    automatic int ret = get_first_ace_4( {<<{inp}} );
    return {<<{ret}};
endfunction

typedef enum {
    TBGMT_RANDOM,
    TBGMT_DIRECTED
} tb_gen_mode_t;


// Round-Robin arbiter
// class rr_arb_c #( parameter int inps = 4);
class rr_arb_c;
    int inps;
    int pri;
    int last_grant;
    
    // initial priority
    function new(int inps_, int init_pri=0);
        inps = inps_;
        pri = init_pri;
        last_grant = -1;
    endfunction
    
    function void update_priority();
        pri = (last_grant + 1) % inps;
    endfunction
    
    function int arbitrate(logic reqs[], logic upd_pri);
        automatic int i = pri;
        // start arbitration from current priority
        do begin
            if (reqs[i]) begin
                last_grant = i;
                if (upd_pri) begin
                    update_priority();
                end
                return i;
            end
            i = (i+1) % inps;
            // stop when a whole cycle was performed (back to initial priority)
        end while (i !== pri);
        
        return -1;  
    endfunction
endclass

// class queue_wrapper #(parameter type T = int);
    // T q[$];
// endclass

class array_wrapper #(parameter type T = int);
    T arr[];
endclass

endpackage
