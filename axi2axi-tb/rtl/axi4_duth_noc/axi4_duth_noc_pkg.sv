package axi4_duth_noc_pkg;
  typedef enum {RC_ALGO_XBAR, RC_ALGO_MERGE_TREE, RC_ALGO_DISTRIBUTE_TREE} rc_algo_type;
  typedef enum {ARB_TYPES_NONE, ARB_TYPES_FPA, ARB_TYPES_RR} ArbForm;
  typedef enum {FLOW_CONTROL_CREDITS, FLOW_CONTROL_ELASTIC} flow_control_type;

  parameter logic CLOCK_GATING_FIRENDLY = 1'b1;
  
  typedef struct packed {
  //typedef union packed {
    flow_control_type FC_TYPE;
    logic PUSH_CHECK_READY;
    int  CR_MAX_CREDITS;
    logic CR_REG_DATA;
    logic CR_REG_CR_UPD;
    logic CR_USE_INCR;
    // Elastic (ready/valid) params
    int  RV_BUFF_DEPTH;
  } link_fc_params_snd_type;  
    
  typedef struct packed {
    // general
    flow_control_type FC_TYPE;
    int BUFF_DEPTH;
    logic POP_CHECK_VALID;
    // Credit-based params
    logic CR_REG_CR_UPD;
    // Elastic (ready/valid) params
    logic RV_PUSH_CHECK_READY;
  } link_fc_params_rcv_type;
  
  
  parameter link_fc_params_snd_type RTR_CREDITS_3_FC_SND    = '{FLOW_CONTROL_CREDITS, 1'b0, 3,     1'b1, 1'b0, 1'b1, 0};
  parameter link_fc_params_rcv_type RTR_CREDITS_3_FC_RCV    = '{FLOW_CONTROL_CREDITS, 3,     1'b0, 1'b1, 1'b0};
  
  parameter link_fc_params_snd_type RTR_ELASTIC_FC_SND      = '{FLOW_CONTROL_ELASTIC, 1'b0, 3, 1'b0, 1'b0, 1'b0, 2}; // 3 is ignored
  parameter link_fc_params_rcv_type RTR_ELASTIC_FC_RCV      = '{FLOW_CONTROL_ELASTIC, 2, 1'b0, 1'b0, 1'b1};
  
  parameter link_fc_params_snd_type NI_NOC_ZERO_BUFF_FC_SND = '{FLOW_CONTROL_ELASTIC, 1'b0, 3, 1'b0, 1'b0, 1'b0, 0}; // 3 is ignored
  parameter link_fc_params_rcv_type NOC_NI_ZERO_BUFF_FC_RCV = '{FLOW_CONTROL_ELASTIC, 0, 1'b1, 1'b1, 1'b1};
  
  parameter link_fc_params_snd_type NI_NOC_CREDITS_3_FC_SND = '{FLOW_CONTROL_CREDITS, 1'b1, 3, 1'b1, 1'b0, 1'b1, 0};
  parameter link_fc_params_rcv_type NOC_NI_CREDITS_3_FC_RCV = '{FLOW_CONTROL_CREDITS, 3, 1'b1, 1'b1, 1'b0};
	
	parameter int FLIT_FIELD_WIDTH = 2;
	typedef enum logic[FLIT_FIELD_WIDTH-1:0] {FLIT_HEAD = 2'b00, FLIT_BODY = 2'b01, FLIT_SINGLE = 2'b10, FLIT_TAIL = 2'b11} flit_type;
	
    // returns max(val1, val2)
    function automatic int get_max2(int val1, int val2);
        return (val1 > val2)? val1: val2;    
    endfunction
    // returns min(val1, val2)
    function automatic int get_min2(int val1, int val2);
        return (val1 < val2)? val1: val2;    
    endfunction

    // logarithm base 2
    function automatic int log2c(int N);
        int ret;
        N = N-1;
        ret = 0;
        while (N > 0) begin
            N = N >> 1;
            ret++;
        end
        return ret;
    endfunction
    
    // log2c that returns 1 if N == 1
    function automatic int log2c_1if1(int N);
        return (N > 1 ? log2c(N) : 1);
    endfunction
    
    // logarithm base B
    function automatic int logBc(int B, int N);
        int shift, ret;
        shift = log2c(B);
        N = N-1;
        ret = 0;
        
        while (N > 0) begin
            N = N >> shift;
            ret++;
        end
        return ret;
    endfunction
  
    function automatic int divceil(int a, int b);
        if ( (a % b) == 0) begin
            return a / b;
        end else begin
            return a / b + 1;
        end 
    endfunction
    
   function automatic logic flit_is_head(logic[FLIT_FIELD_WIDTH-1:0] flit_in);
     return (flit_in[FLIT_FIELD_WIDTH-1: 0] == FLIT_HEAD)? 1'b1 : 1'b0;
   endfunction
 
   function automatic logic flit_is_tail(logic[FLIT_FIELD_WIDTH-1:0] flit_in);
     return (flit_in[FLIT_FIELD_WIDTH-1: 0] == FLIT_TAIL)? 1'b1 : 1'b0;
   endfunction
 
   function automatic logic flit_is_single(logic[FLIT_FIELD_WIDTH-1:0] flit_in);
    return (flit_in[FLIT_FIELD_WIDTH-1: 0] == FLIT_SINGLE)? 1'b1 : 1'b0;
  endfunction
 
 
 function automatic string flittype_to_str(logic[FLIT_FIELD_WIDTH-1:0] ft);
    return ft == FLIT_TAIL   ? "T" : (
           ft == FLIT_BODY   ? "B" : (
           ft == FLIT_SINGLE ? "S" : (
                               "H")));
endfunction

endpackage   
 

