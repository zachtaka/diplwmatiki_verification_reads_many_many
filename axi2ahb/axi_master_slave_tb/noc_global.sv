package noc_global;
  typedef enum {ARB_TYPES_NONE, ARB_TYPES_FPA, ARB_TYPES_RR} ArbForm;

  parameter logic CLOCK_GATING_FIRENDLY = 1'b1;
	
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

endpackage   
 

