
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2024 11:39:12 AM
// Design Name: 
// Module Name: pcie_cq_engine_64
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
`timescale 1ns / 1ps

`include "pcie_parameters.vh"
`include "bram_parameters.vh"

module pcie_cq_engine_64(
  input                               CLK                   ,
  input                               RST_N                 ,

  // < Completer Request IP Interfaces
  input      [`PCIE_DATA_WIDTH-1:0]   M_AXIS_CQ_TDATA       ,
  input                               M_AXIS_CQ_TLAST       ,
  input                               M_AXIS_CQ_TVALID      ,
  input  [`AXI4_CQ_TUSER_WIDTH-1:0]   M_AXIS_CQ_TUSER       ,
  input      [`PCIE_KEEP_WIDTH-1:0]   M_AXIS_CQ_TKEEP       ,
  output                              M_AXIS_CQ_TREADY      ,
  //   Completer Request IP Interfaces >

  // < Other IP Interfaces
  input                       [5:0]   PCIE_CQ_NP_REQ_COUNT  ,
  output                              PCIE_CQ_NO_REQ        ,
  //   Other IP Interfaces >

  // < Memory Write Request and finished (ack)
  input                               MEM_WR_ACK            ,
  output                              MEM_WR_REQ            ,
  //   Memory Write Request and finished (ack) >

  // < Memory Fifo TLP Read
  input                               FIFO_RD_EN            ,
  output     [`FIFO_DATA_WIDTH-1:0]   FIFO_RD_DATA          ,
  output                              FIFO_RD_EMPTY         ,
  output                      [8:0]   FIFO_RD_COUNT         ,
  //   Memory Fifo TLP Read >

  // < test
  output                              wFifoWrFull,
  output [`BRAM_DATA_WIDTH-1:0]   wMemWrData           ,
  output [`BRAM_ADDR_WIDTH-1:0]   wMemWrAddr           ,
  output                          wMemWrVald           ,
  output                  [7:0]   st_test
  //   test >
);

reg                              rFiforst     = 1'b0  ;
reg                              rMemWrReq    = 1'b0  ;
reg                              rFifoTlpBad  = 1'b0  ;

wire                             wFifoWrFull           ;
wire    [`BRAM_DATA_WIDTH-1:0]   wMemWrData           ;
wire    [`BRAM_ADDR_WIDTH-1:0]   wMemWrAddr           ;
wire    [`BRAM_KEEP_WIDTH-1:0]   wMemWrKeep           ;
wire                             wMemWrVald           ;
wire                             wMemWrErro           ;
wire                             wMemWrLast           ;

wire    [`FIFO_DATA_WIDTH-1:0]   wFifoWrData          ;
wire                     [8:0]   FIFO_WR_COUNT        ;


assign MEM_WR_REQ  = rMemWrReq    ;

assign wFifoWrData = {wMemWrKeep, wMemWrAddr, wMemWrData} ;


generate

  if ( `PCIE_DATA_WIDTH == 64 && `AXISTEN_IF_CQ_ALIGNMENT_MODE == "DWORD" ) begin: pcie_cq_engine_64_dword_aligned
    pcie_cq_engine_64_dword pcie_cq_engine_inst (
      .CLK                    (CLK                        ),
      .RST_N                  (RST_N                      ),

      .M_AXIS_CQ_TDATA        (M_AXIS_CQ_TDATA            ),
      .M_AXIS_CQ_TLAST        (M_AXIS_CQ_TLAST            ),
      .M_AXIS_CQ_TVALID       (M_AXIS_CQ_TVALID           ),
      .M_AXIS_CQ_TUSER        (M_AXIS_CQ_TUSER            ),
      .M_AXIS_CQ_TKEEP        (M_AXIS_CQ_TKEEP            ),
      .M_AXIS_CQ_TREADY       (M_AXIS_CQ_TREADY           ),
      .PCIE_CQ_NP_REQ_COUNT   (PCIE_CQ_NP_REQ_COUNT       ),
      .PCIE_CQ_NO_REQ         (PCIE_CQ_NO_REQ             ),

      .MEM_WR_BUSY            (rFifoTlpBad | rMemWrReq    ),
      .MEM_WR_DATA            (wMemWrData                 ),
      .MEM_WR_ADDR            (wMemWrAddr                 ),
      .MEM_WR_KEEP            (wMemWrKeep                 ),
      .MEM_WR_VALD            (wMemWrVald                 ),
      .MEM_WR_ERRO            (wMemWrErro                 ),
      .MEM_WR_LAST            (wMemWrLast                 ),
      
      
      .st_test(st_test)
    );
 end

endgenerate


always @(posedge CLK) begin
  if ( ~RST_N )
    rFiforst <= 1'b1  ;
  else if ( wMemWrVald && wMemWrLast && wMemWrErro ) 
    rFiforst <= 1'b1  ;
  else
    rFiforst <= 1'b0  ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    rFifoTlpBad <= 1'b0 ;
  else if ( wMemWrVald && wMemWrLast && wMemWrErro ) 
    rFifoTlpBad <= 1'b1 ;
  else if ( rFifoTlpBad && ~wFifoWrFull )
    rFifoTlpBad <= 1'b0 ;
  else
    rFifoTlpBad <= rFifoTlpBad  ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    rMemWrReq <= 1'b0   ;
  else if ( wMemWrVald && wMemWrLast && ~wMemWrErro ) 
    rMemWrReq <= 1'b1   ;
  else if ( MEM_WR_ACK )
    rMemWrReq <= 1'b0   ;
  else
    rMemWrReq <= rMemWrReq  ;
end


async_rq_tlp_fifo rq_tlp_fifo_inst (
  .rst            (rFiforst             ),    // input wire rst
  .wr_clk         (CLK                  ),    // input wire wr_clk
  .rd_clk         (CLK                  ),    // input wire rd_clk
  .din            (wFifoWrData          ),    // input wire [103 : 0] din
  .wr_en          (wMemWrVald           ),    // input wire wr_en
  .rd_en          (FIFO_RD_EN           ),    // input wire rd_en
  .dout           (FIFO_RD_DATA         ),    // output wire [103 : 0] dout
  .full           (wFifoWrFull          ),    // output wire full
  .empty          (FIFO_RD_EMPTY        ),    // output wire empty
  .rd_data_count  (FIFO_RD_COUNT        ),    // output wire [8 : 0] rd_data_count
  .wr_data_count  (FIFO_WR_COUNT        )     // output wire [8 : 0] wr_data_count
);


endmodule
