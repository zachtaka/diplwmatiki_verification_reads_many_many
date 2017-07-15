package ni_global;

// import mnoc_sni_inl2axi_general_pkg::*;

// AXI Channel Specs
parameter AXI_SPECS_WIDTH_LEN    = 8;
parameter AXI_SPECS_WIDTH_SIZE   = 3;
parameter AXI_SPECS_WIDTH_BURST  = 2;
parameter AXI_SPECS_WIDTH_LOCK   = 1;
parameter AXI_SPECS_WIDTH_CACHE  = 4;
parameter AXI_SPECS_WIDTH_PROT   = 3;
parameter AXI_SPECS_WIDTH_QOS    = 4;
parameter AXI_SPECS_WIDTH_REGION = 4;
parameter AXI_SPECS_WIDTH_LAST   = 1;
parameter AXI_SPECS_WIDTH_RESP   = 2;



localparam AXI_LEN_W             = 8;
localparam AXI_SIZE_W            = 3;
localparam AXI_BURST_W           = 2;
localparam AXI_LOCK_W            = 2;
localparam AXI_CACHE_W           = 4;
localparam AXI_PROT_W            = 3;
localparam AXI_QOS_W             = 4;
localparam AXI_REGION_W          = 4;
localparam AXI_LAST_W            = 1;
localparam AXI_RESP_W            = 2;

typedef enum logic[AXI_BURST_W-1:0]
{
    AXI_BURST_FIXED = 2'b00,
    AXI_BURST_INCR  = 2'b01,
    AXI_BURST_WRAP  = 2'b10
} axi_burst_type;

typedef enum logic[AXI_LOCK_W-1:0]
{
    AXI_LOCK_NORMAL     = 2'b00,
    AXI_LOCK_EXCLUSIVE  = 2'b01
} axi_lock_type;

typedef enum logic[AXI_RESP_W-1:0]
{
    AXI_RESP_OKAY       = 2'b00,
    AXI_RESP_EXOKAY     = 2'b01,
    AXI_RESP_SLVERR     = 2'b10,
    AXI_RESP_DECERR     = 2'b11
} axi_resp_type;


//~ typedef enum logic[AXI_SPECS_WIDTH_BURST-1:0]
        //~ {   AXI_BURST_FIXED = 2'b00,
            //~ AXI_BURST_INCR  = 2'b01,
            //~ AXI_BURST_WRAP  = 2'b10}
     //~ axi_burst_type_TB;
// typedef enum logic[AXI_SPECS_WIDTH_LOCK-1:0]
//         {   AXI_LOCK_NORMAL     = 1'b0,
//             AXI_LOCK_EXCLUSIVE  = 1'b1}
//     axi_lock_type;
// typedef enum logic[AXI_SPECS_WIDTH_CACHE-1:0]
        // {   AXI_CACHE_W0_R0_M0_B0   = 4'b0000,
            // AXI_CACHE_W0_R0_M0_B1   = 4'b0001,
            // AXI_CACHE_W0_R0_M1_B0   = 4'b0010,
            // AXI_CACHE_W0_R0_M1_B1   = 4'b0011,
            // AXI_CACHE_W0_R1_M0_B0   = 4'b0100,
            // AXI_CACHE_W0_R1_M0_B1   = 4'b0101,
            // AXI_CACHE_W0_R1_M1_B0   = 4'b0110,
            // AXI_CACHE_W0_R1_M1_B1   = 4'b0111,
            // AXI_CACHE_W1_R0_M0_B0   = 4'b1000,
            // AXI_CACHE_W1_R0_M0_B1   = 4'b1001,
            // AXI_CACHE_W1_R0_M1_B0   = 4'b1010,
            // AXI_CACHE_W1_R0_M1_B1   = 4'b1011,
            // AXI_CACHE_W1_R1_M0_B0   = 4'b1100,
            // AXI_CACHE_W1_R1_M0_B1   = 4'b1101,
            // AXI_CACHE_W1_R1_M1_B0   = 4'b1110,
            // AXI_CACHE_W1_R1_M1_B1   = 4'b1111}
    // axi_cache_type;
parameter int AXI_MAX_ADDR_BOUNDARY = 4*(2**10); // 4KB

// OP
parameter logic OP_ID_WRITE = 1'b0;
parameter logic OP_ID_READ = 1'b1;

// Sum of standard AW/AR fields width
parameter AXI_W_AWR_STD_FIELDS = AXI_SPECS_WIDTH_LEN + 
                                 AXI_SPECS_WIDTH_SIZE + 
                                 AXI_SPECS_WIDTH_BURST + 
                                 AXI_SPECS_WIDTH_LOCK + 
                                 AXI_SPECS_WIDTH_CACHE + 
                                 AXI_SPECS_WIDTH_PROT + 
                                 AXI_SPECS_WIDTH_QOS + 
                                 AXI_SPECS_WIDTH_REGION;

parameter logic[4*4-1:0] AXI_LEGAL_WRAP_LEN = {4'h1, 4'h3, 4'h7, 4'hF};
parameter int AXI_ADDR_BOUNDARY = 4*(2**10); // 4KB address boundary
// returns
function automatic int get_addr_penalty(int MAX_LINK_WIDTH, 
                              int AXI_W_ADDR_NOTID, 
                              int AXI_W_DATA_NOTID, 
                              int HEADER_FULL, 
                              int HEADER_SMALL);
  int hdr_pen, addr_w_remaining;
  
  if ( (HEADER_FULL + AXI_W_ADDR_NOTID + AXI_W_DATA_NOTID) <= MAX_LINK_WIDTH)
    // Both fit in one flit -> Zero Header Penalty
    return 0;
  else begin
    // At least one flit penalty
    hdr_pen = 1;
    // First Flit has a Full Header (Head Flit)
    addr_w_remaining = AXI_W_ADDR_NOTID - (MAX_LINK_WIDTH - HEADER_FULL);
    // Width of ADDRESS fit in current flit
    while (addr_w_remaining > 0) begin
      // Subsequent flits have a Small header (Body Flits)
      addr_w_remaining = addr_w_remaining - (MAX_LINK_WIDTH - HEADER_SMALL);
      hdr_pen = hdr_pen + 1;
    end        
            
    return hdr_pen;
  end;
endfunction

function automatic int get_flits_per_data(int MAX_LINK_WIDTH, 
                                int AXI_W_ADDR_NOTID, 
                                int AXI_W_DATA_NOTID, 
                                int HEADER_FULL, 
                                int HEADER_SMALL);
  int flits_per_data, data_w_remaining;
  
  if ( (HEADER_FULL + AXI_W_ADDR_NOTID + AXI_W_DATA_NOTID) <= MAX_LINK_WIDTH)
  // Both fit in one flit (next DATA fit in a single flit - no further optimization)
    return 1;
  else begin
    flits_per_data = 1;
    data_w_remaining = AXI_W_DATA_NOTID;
    while ( (MAX_LINK_WIDTH - HEADER_SMALL) < data_w_remaining ) begin
                data_w_remaining = data_w_remaining - (MAX_LINK_WIDTH - HEADER_SMALL);
                flits_per_data = flits_per_data + 1;
    end;
            
    return flits_per_data;
  end
endfunction
    
function automatic int get_addr_flit_width_first(int MAX_LINK_WIDTH, 
                                       int AXI_W_ADDR_NOTID, 
                                       int AXI_W_DATA_NOTID, 
                                       int HEADER_FULL);
                                       
  if ( (HEADER_FULL + AXI_W_ADDR_NOTID + AXI_W_DATA_NOTID) <= MAX_LINK_WIDTH )
    return HEADER_FULL + AXI_W_ADDR_NOTID + AXI_W_DATA_NOTID;
  else
    if ( ( AXI_W_ADDR_NOTID + HEADER_FULL ) <= MAX_LINK_WIDTH )
      return AXI_W_ADDR_NOTID + HEADER_FULL;
    else
      return MAX_LINK_WIDTH;          
endfunction

function automatic int get_data_flit_width_first(int MAX_LINK_WIDTH, 
                                       int AXI_W_ADDR_NOTID, 
                                       int AXI_W_DATA_NOTID, 
                                       int HEADER_FULL, 
                                       int HEADER_SMALL);
                                       
  if  ( (HEADER_FULL + AXI_W_ADDR_NOTID + AXI_W_DATA_NOTID ) <= MAX_LINK_WIDTH )
    return HEADER_FULL + AXI_W_ADDR_NOTID + AXI_W_DATA_NOTID;
  else
    if ( (AXI_W_DATA_NOTID + HEADER_SMALL) <= MAX_LINK_WIDTH)
      return AXI_W_DATA_NOTID + HEADER_SMALL;
    else
      return MAX_LINK_WIDTH;
endfunction
    
function automatic int get_flits_per_resp(int MAX_LINK_WIDTH, 
                                int AXI_CHAN_NOTID, 
                                int HEADER_FULL, 
                                int HEADER_SMALL); 
  int flits_per_resp, chan_remaining;

  flits_per_resp = 1;
  chan_remaining = AXI_CHAN_NOTID - (MAX_LINK_WIDTH - HEADER_FULL);
  while (chan_remaining > 0) begin
     chan_remaining = chan_remaining - (MAX_LINK_WIDTH - HEADER_SMALL);
     flits_per_resp = flits_per_resp + 1;
  end;
            
  return flits_per_resp;
endfunction
    
function automatic int get_resp_flit_width_first(int MAX_LINK_WIDTH, 
                                       int AXI_CHAN_NOTID, 
                                       int HEADER_FULL, 
                                       int HEADER_SMALL);
                                       
  if ( (AXI_CHAN_NOTID + HEADER_FULL) <= MAX_LINK_WIDTH)
    return AXI_CHAN_NOTID + HEADER_FULL;
  else
    return MAX_LINK_WIDTH;
    
endfunction

function automatic int get_addr_flit_pad_last(int LINK_WIDTH, 
                                    int AXI_W_ADDR_NOTID, 
                                    int AXI_W_DATA_NOTID, 
                                    int HEADER_FULL, 
                                    int HEADER_SMALL);
                                    
int addr_w_remaining;

  if ( (HEADER_FULL + AXI_W_ADDR_NOTID + AXI_W_DATA_NOTID) <= LINK_WIDTH)
    // Zero-Penalty (Width of last flit should be ignored)
    return 0;
  else begin
    // Penalty > 0
    // First flit carries a Full Header
    addr_w_remaining = AXI_W_ADDR_NOTID - (LINK_WIDTH - HEADER_FULL);
    while (addr_w_remaining > 0) begin
      //Following flits (if any) carry small header
      addr_w_remaining = addr_w_remaining - (LINK_WIDTH - HEADER_SMALL);
    end
    // Leaving loop -> addr_w_remaining <= 0
    // if 0 -> last flit perfectly fit MAX_LINK_WIDTH
    // if < 0 -> remaining is the width of last flit
    return addr_w_remaining * (-1);
  end;
endfunction

function automatic int get_data_flit_pad_last(int LINK_WIDTH,
                                    int AXI_W_ADDR_NOTID,
                                    int AXI_W_DATA_NOTID,
                                    int HEADER_FULL,
                                    int HEADER_SMALL);
int data_w_remaining;

  if ( ( HEADER_FULL + AXI_W_ADDR_NOTID + AXI_W_DATA_NOTID ) <= LINK_WIDTH )
    // Zero Address-Penalty (Width of last flit should be ignored)
    return 0;
  else begin
      // Data follow address & they are never Head flit (Small Header ONLY!)
      data_w_remaining = AXI_W_DATA_NOTID - (LINK_WIDTH - HEADER_SMALL);
      while ( data_w_remaining > 0 ) 
        data_w_remaining = data_w_remaining - (LINK_WIDTH - HEADER_SMALL);
            
      return data_w_remaining * (-1);
  end
endfunction
    
function automatic int get_resp_flit_pad_last(int LINK_WIDTH, 
                                    int AXI_CHAN_NOTID,
                                    int HEADER_FULL,
                                    int HEADER_SMALL);
int chan_remaining;

  chan_remaining = AXI_CHAN_NOTID - (LINK_WIDTH - HEADER_FULL);
  while ( chan_remaining > 0 ) 
    // Following flits (if any) carry small header
    chan_remaining = chan_remaining - (LINK_WIDTH - HEADER_SMALL);
  
  // Leaving loop -> addr_w_remaining <= 0
  // if 0 -> last flit perfectly fit MAX_LINK_WIDTH
  // if < 0 -> remaining is the width of last flit
  return chan_remaining * (-1);

endfunction



endpackage
