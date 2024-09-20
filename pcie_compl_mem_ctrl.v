
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2024 04:03:59 PM
// Design Name: 
// Module Name: pcie_compl_mem_ctrl
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

`include "bram_parameters.vh"

`define ST_CQ_WR_IDLE 8'b00000000
`define ST_CQ_WR_WORK 8'b00000001
`define ST_CQ_WR_WAIT 8'b00000010
`define ST_CC_RD_IDLE 8'b00000100
`define ST_CC_RD_WORK 8'b00001000
`define ST_CC_RD_WAIT 8'b00010000
`define ST_CC_WR_IDLE 8'b00100000
`define ST_CC_WR_WORK 8'b01000000
`define ST_CC_WR_WAIT 8'b10000000

module  pcie_compl_mem_ctrl (
  input                                   CLK                             ,
  input                                   RST_N                           ,

  // < cq_wr_mem_fifo
  input                                   CQ_MEM_WR_REQ                   ,
  output                                  CQ_MEM_WR_ACK                   ,


  input           [`FIFO_DATA_WIDTH-1:0]  CQ_WR_MEM_FIFO_RD_DATA          ,
  input                                   CQ_WR_MEM_FIFO_RD_EMPTY         ,
  input   [$clog2(`FIFO_DATA_WIDTH)+1:0]  CQ_WR_MEM_FIFO_RD_COUNT         ,
  output                                  CQ_WR_MEM_FIFO_RD_EN            ,
  //   cq_wr_mem_fifo >

  // < cc_rd_mem_fifo
  input                                   CC_MEM_RD_REQ                   ,
  output                                  CC_MEM_RD_ACK                   ,

  //   cc_rd_mem_fifo >

  // < cc_rd_mem_fifo
  input                                   CC_MEM_WR_REQ                   ,
  output                                  CC_MEM_WR_ACK                   ,


  input           [`FIFO_DATA_WIDTH-1:0]  CC_WR_MEM_FIFO_RD_DATA          ,
  input                                   CC_WR_MEM_FIFO_RD_EMPTY         ,
  input   [$clog2(`FIFO_DATA_WIDTH)+1:0]  CC_WR_MEM_FIFO_RD_COUNT         ,
  output                                  CC_WR_MEM_FIFO_RD_EN            ,
  //   cc_rd_mem_fifo >

  // < bram interfaces
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *)
  input     [`BRAM_DATA_WIDTH-1:0]    RAM_DOUT    ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK" *)
  output                              RAM_CLK     ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA RST" *)
  output                              RAM_RST     ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA EN" *)
  output                              RAM_EN      ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR" *)
  output    [`BRAM_ADDR_WIDTH-1:0]    RAM_ADDR    ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA DIN" *)
  output    [`BRAM_DATA_WIDTH-1:0]    RAM_DIN     ,
  (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA WE" *)
  output    [`BRAM_KEEP_WIDTH-1:0]    RAM_WE      
  //   bram interfaces >

);

localparam  BRAM_ADDR_SHIFT = `BRAM_DATA_WIDTH == 64 ? 3 : 0  ;

reg   [7:0] st_current = 8'd0, st_next = 8'd0   ;



reg   rCqMemWrAck       = 1'b0  ;
reg   rCqWrMemFifoRdEn  = 1'b0  ;


wire    [`BRAM_ADDR_WIDTH-1:0]    wRamAddr    ;


// < Cq Write assign

assign CQ_MEM_WR_ACK          = rCqMemWrAck       ;
assign CQ_WR_MEM_FIFO_RD_EN   = rCqWrMemFifoRdEn  ;

//   Cq Write assign


// < Bram assign

assign RAM_CLK    = CLK       ;
assign RAM_RST    = ~RST_N    ;

assign RAM_DIN    = st_current == `ST_CQ_WR_WORK ? CQ_WR_MEM_FIFO_RD_DATA[`BRAM_DATA_WIDTH-1:0] : 
                    (0)  ;
assign wRamAddr   = st_current == `ST_CQ_WR_WORK ? CQ_WR_MEM_FIFO_RD_DATA[`BRAM_DATA_WIDTH+`BRAM_ADDR_WIDTH-1:`BRAM_DATA_WIDTH] : 
                    (0) ;
assign RAM_WE     = st_current == `ST_CQ_WR_WORK ? CQ_WR_MEM_FIFO_RD_DATA[`BRAM_DATA_WIDTH+`BRAM_ADDR_WIDTH+`BRAM_KEEP_WIDTH-1:`BRAM_DATA_WIDTH+`BRAM_ADDR_WIDTH] : 
                    (0) ;

assign RAM_EN     = st_current == `ST_CQ_WR_WORK ? rCqWrMemFifoRdEn  :
                    (0) ;


assign RAM_ADDR   = wRamAddr << BRAM_ADDR_SHIFT  ;

//   Bram assign >




// < state machine

always @(posedge CLK) begin
  if ( !RST_N )
    st_current <= `ST_CQ_WR_IDLE  ;
  else
    st_current <= st_next         ;
end

always @(*) begin
  if ( !RST_N )
    st_next = `ST_CQ_WR_IDLE      ;
  else begin
    st_next = st_current          ;

    case(st_current)
      `ST_CQ_WR_IDLE:
        if ( CQ_MEM_WR_REQ && ~CQ_WR_MEM_FIFO_RD_EMPTY )
          st_next = `ST_CQ_WR_WORK  ;
        else
          st_next = `ST_CC_RD_IDLE  ;

      `ST_CQ_WR_WORK:
        if ( CQ_WR_MEM_FIFO_RD_DATA[`FIFO_DATA_WIDTH-1] )
          st_next = `ST_CQ_WR_WAIT  ;
        else
          st_next = `ST_CQ_WR_WORK  ;


      `ST_CQ_WR_WAIT:
        if ( ~CQ_MEM_WR_REQ )
          st_next = `ST_CC_RD_IDLE  ;
        else
          st_next = `ST_CQ_WR_WAIT  ;


      `ST_CC_RD_IDLE:
        if ( CC_MEM_RD_REQ )
          st_next = `ST_CC_RD_WORK  ;
        else
          st_next = `ST_CC_WR_IDLE  ;

      `ST_CC_RD_WORK:
        if ( ~CC_MEM_RD_REQ )
          st_next = `ST_CC_WR_IDLE  ;
        else
          st_next = `ST_CC_RD_WAIT  ;

      `ST_CC_WR_IDLE:
        if ( CC_MEM_WR_REQ )
          st_next = `ST_CC_WR_WORK  ;
        else
          st_next = `ST_CQ_WR_IDLE  ;

      `ST_CC_WR_WORK:
        if ( ~CC_MEM_WR_REQ )
          st_next = `ST_CQ_WR_IDLE  ;
        else
          st_next = `ST_CC_WR_WAIT  ;

    endcase
  end
end

//   state machine >


// < CQ Write Memory Process

always @(posedge CLK) begin
  if ( !RST_N )
    rCqMemWrAck <= 1'b0 ;
  else if ( st_current == `ST_CQ_WR_WORK && CQ_WR_MEM_FIFO_RD_DATA[`FIFO_DATA_WIDTH-1] )
    rCqMemWrAck <= 1'b1 ;
  else
    rCqMemWrAck <= 1'b0 ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    rCqWrMemFifoRdEn <= 1'b0  ;
  else if ( st_current == `ST_CQ_WR_WORK && ~CQ_WR_MEM_FIFO_RD_DATA[`FIFO_DATA_WIDTH-1] )
    rCqWrMemFifoRdEn <= 1'b1  ;
  else
    rCqWrMemFifoRdEn <= 1'b0  ;
end


//   CQ Write Memory Process >





endmodule
