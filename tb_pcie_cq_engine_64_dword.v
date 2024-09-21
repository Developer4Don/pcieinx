`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/18/2024 11:26:20 AM
// Design Name: 
// Module Name: tb_pcie_cq_engine_64_dword
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "pcie_parameters.vh"
`include "bram_parameters.vh"

module tb_pcie_cq_engine_64_dword();

// System
reg   CLK   = 1'b1  ;
reg   RST_N = 1'b0  ; 


// M_AXIS_*
reg       [`PCIE_DATA_WIDTH-1:0]    M_AXIS_CQ_TDATA   ;
reg                                 M_AXIS_CQ_TLAST   ;
reg                                 M_AXIS_CQ_TVALID  ;
reg   [`AXI4_CQ_TUSER_WIDTH-1:0]    M_AXIS_CQ_TUSER   ;
reg       [`PCIE_KEEP_WIDTH-1:0]    M_AXIS_CQ_TKEEP   ;
wire                                M_AXIS_CQ_TREADY  ;
// IP other interface
reg  [5:0]  PCIE_CQ_NP_REQ_COUNT  ;
wire        PCIE_CQ_NO_REQ        ;

// tuser
reg    [3:0]  first_be      ;
reg    [7:4]  last_be       ;
reg   [31:0]  byte_en       ;
reg           sop           ;
reg           discontinue   = 1'b0 ;
reg           tph_present   ;
reg    [1:0]  tph_type      ;
reg    [7:0]  tph_st_tag    ;
reg   [31:0]  parity        ;


// Memory Write
reg                           MEM_WR_BUSY      = 1'b0    ;
wire   [`BRAM_DATA_WIDTH-1:0] MEM_WR_DATA   ;
wire   [`BRAM_ADDR_WIDTH-1:0] MEM_WR_ADDR   ;
wire   [`BRAM_KEEP_WIDTH-1:0] MEM_WR_KEEP   ;
wire                          MEM_WR_LAST   ;
wire                          MEM_WR_VALD   ;

reg    [1:0]  rAddressType    =  2'b00  ;
reg   [61:0]  rAddress        =  62'h2  ;

reg   [10:0]  rDWCount        = 11'd3   ;
reg    [3:0]  rRqType         =  4'b0001;
reg   [15:0]  rRqID           = 16'h99  ;
reg    [7:0]  rTag            = 16'he   ;
reg    [7:0]  rTargetFunction =  8'h3   ;
reg    [2:0]  rBarID          =  3'h1   ;
reg    [5:0]  rBarAperture    =  6'h2   ;
reg    [2:0]  rTransClass     =  3'h1   ;
reg    [2:0]  rAttributes     =  3'h2   ; 

// simulation indicator
wire    [63:0]  qw0 ;
wire    [63:0]  qw1 ;



assign qw0 = {rAddress, rAddressType} ;
assign qw1 = {1'b0, rAttributes, rTransClass, rBarAperture, rBarID, rTargetFunction, rTag, rRqID, 1'b0, rRqType, rDWCount};


always #5 CLK = ~CLK  ;

always @(*) begin
    M_AXIS_CQ_TUSER = {3'b000, parity, tph_st_tag, tph_type, tph_present, discontinue, sop, byte_en, last_be, first_be};
end


initial begin
  #3
  RST_N = 1'b1    ;

  #10
  // Indicator 0 - 1
  sop = 1'b1      ;
  M_AXIS_CQ_TDATA  = qw0  ;
  M_AXIS_CQ_TVALID = 1'b1 ;
  

  #10
  // Indicator 2 - 3
  sop = 1'b0              ;
  M_AXIS_CQ_TDATA = qw1   ;
  M_AXIS_CQ_TVALID = 1'b1 ;
  
  #10
  // dword 0 - 1
  byte_en = 32'h000000ff  ;
  M_AXIS_CQ_TDATA  = 64'h123;
  M_AXIS_CQ_TVALID = 1'b1 ;

  #10
  // dword 2 - 3
  byte_en          = 32'h0000000f  ;
  discontinue      = 1'b1          ;
  M_AXIS_CQ_TDATA  = 64'h456       ;
  M_AXIS_CQ_TVALID = 1'b1 ;
  M_AXIS_CQ_TLAST  = 1'b1 ;

  #10
  // end
  byte_en = 32'h00000000  ;
  discontinue      = 1'b0 ;
  M_AXIS_CQ_TVALID = 1'b0 ;
  M_AXIS_CQ_TLAST  = 1'b0 ;
  
  
  #30
  MEM_WR_BUSY = 1'b1     ;
  
  #10
  MEM_WR_BUSY = 1'b0     ;
end


pcie_cq_engine_64_dword cq_inst (
  .CLK                   (CLK           ),
  .RST_N                 (RST_N         ),

  // < Completer Request IP Interface
  .M_AXIS_CQ_TDATA       (M_AXIS_CQ_TDATA     ),
  .M_AXIS_CQ_TLAST       (M_AXIS_CQ_TLAST     ),
  .M_AXIS_CQ_TVALID      (M_AXIS_CQ_TVALID    ),
  .M_AXIS_CQ_TUSER       ({3'b000, parity, tph_st_tag, tph_type, tph_present, discontinue, sop, byte_en, last_be, first_be}     ),
  .M_AXIS_CQ_TKEEP       (M_AXIS_CQ_TKEEP     ),
  .M_AXIS_CQ_TREADY      (M_AXIS_CQ_TREADY    ),
  //   Completer Request IP Interface >
  // < Other IP Interfaces
  .PCIE_CQ_NP_REQ_COUNT  (PCIE_CQ_NP_REQ_COUNT),
  .PCIE_CQ_NO_REQ        (PCIE_CQ_NO_REQ      ),
  //   Other IP Interfaces >

  .MEM_WR_BUSY           (MEM_WR_BUSY         ),
  .MEM_WR_DATA           (MEM_WR_DATA         ),
  .MEM_WR_ADDR           (MEM_WR_ADDR         ),
  .MEM_WR_KEEP           (MEM_WR_KEEP         ),
  .MEM_WR_LAST           (MEM_WR_LAST         ),
  .MEM_WR_VALD           (MEM_WR_VALD         ),


  // test
  .st_test               (st_test           )
);

wire [7:0]  st_test;


endmodule
