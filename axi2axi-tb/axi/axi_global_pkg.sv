package axi_global_pkg;

// AXI Channel Specs
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
    AXI_BURST_FIXED     = 2'b00,
    AXI_BURST_INCR      = 2'b01,
    AXI_BURST_WRAP      = 2'b10,
    AXI_BURST_RESERVED  = 2'b11
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


parameter int AXI_MAX_ADDR_BOUNDARY = 4*(2**10); // 4KB

// // Sum of standard AW/AR fields width
// parameter AXI_W_AWR_STD_FIELDS = AXI_LEN_W + 
                                 // AXI_SIZE_W + 
                                 // AXI_BURST_W + 
                                 // AXI_LOCK_W + 
                                 // AXI_CACHE_W + 
                                 // AXI_PROT_W + 
                                 // AXI_QOS_W + 
                                 // AXI_REGION_W;

parameter logic[4*4-1:0] AXI_LEGAL_WRAP_LEN = {4'h1, 4'h3, 4'h7, 4'hF};
parameter int AXI_ADDR_BOUNDARY = 4*(2**10); // 4KB address boundary


endpackage
