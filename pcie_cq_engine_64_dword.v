`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/14/2024 10:35:24 AM
// Design Name: 
// Module Name: pcie_cq_engine_64_dword
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

// < Completer Request Type
`define PIO_RX_MEM_RD_FMT_TYPE    4'b0000         // Memory Read
`define PIO_RX_MEM_WR_FMT_TYPE    4'b0001         // Memory Write
`define PIO_RX_IO_RD_FMT_TYPE     4'b0010         // IO Read
`define PIO_RX_IO_WR_FMT_TYPE     4'b0011         // IO Write
`define PIO_RX_ATOP_FAA_FMT_TYPE  4'b0100         // Fetch and ADD
`define PIO_RX_ATOP_UCS_FMT_TYPE  4'b0101         // Unconditional SWAP
`define PIO_RX_ATOP_CAS_FMT_TYPE  4'b0110         // Compare and SWAP
`define PIO_RX_MEM_LK_RD_FMT_TYPE 4'b0111         // Locked Read Request
// `define PIO_CONF0_RD_FMT_TYPE     4'b1000         // Type 0 Configuration Read Request (on Requester side only)
// `define PIO_CONF1_RD_FMT_TYPE     4'b1001         // Type 1 Configuration Read Request (on Requester side only)
// `define PIO_CONF0_WR_FMY_TYPE     4'b1010         // Type 0 Configuration Write Request(on Requester side only)
// `define PIO_CONF1_WR_FMY_TYPE     4'b1011         // Type 1 Configuration Write Request(on Requester side only)
`define PIO_RX_MSG_FMT_TYPE       4'b1100         // MSG Transaction apart from Vendor Defined and ATS
`define PIO_RX_MSG_VD_FMT_TYPE    4'b1101         // MSG Transaction apart from Vendor Defined and ATS
`define PIO_RX_MSG_ATS_FMT_TYPE   4'b1110         // MSG Transaction apart from Vendor Defined and ATS
//   Completer Request Type >


// < State Machine
`define ST_RX_RST         8'b00000000     // idle state, waiting for sop signal
`define ST_RX_WAIT        8'b00000001     // wait state, waiting for CC finished or TLP Memory Write FIFO not busy
`define ST_RX_64_QW1      8'b00000010     // Receiving for Indicator
`define ST_RX_MEM_WR      8'b00000011     // Memory Write
//   State Machine >


module pcie_cq_engine_64_dword(
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

  // < Bram Write FIFO Interfaces
  input                               MEM_WR_BUSY           ,
  output     [`BRAM_DATA_WIDTH-1:0]   MEM_WR_DATA           ,
  output     [`BRAM_ADDR_WIDTH-1:0]   MEM_WR_ADDR           ,
  output     [`BRAM_KEEP_WIDTH-1:0]   MEM_WR_KEEP           ,
  output                              MEM_WR_VALD           ,
  output                              MEM_WR_ERRO           ,
  output                              MEM_WR_LAST           ,

  // < test
  output                    [7:0]     st_test             
  //   test >
);


// < test
assign st_test = st_current ;
//   test >



localparam BAR_ID_SELECT = ( `PCIE_DATA_WIDTH == 64 ) ? 48 : 112 ;

// < M_AXIS Related Register
reg   rMAxisCqTReady =  1'b1  ; 
//   M_AXIS Related Register >


// < Indicator latch
reg   [63:0]    rDescHdrQw0       = 64'd0 ;
reg   [63:0]    rDescHdrQw1       = 64'd0 ;
//   Indicator latch


// < Memory Write Related Register
reg   [`BRAM_DATA_WIDTH-1:0]    rMemWrData        = {`BRAM_DATA_WIDTH{1'b0}}  ;
reg   [`BRAM_ADDR_WIDTH-1:0]    rMemWrAddr        = {`BRAM_ADDR_WIDTH{1'b0}}  ;
reg   [`BRAM_KEEP_WIDTH-1:0]    rMemWrKeep        = {`BRAM_KEEP_WIDTH{1'b0}}  ;
reg                             rMemWrVald        =  1'b0                     ;
reg                             rMemWrErro        =  1'b0                     ;
reg                             rMemWrLast        =  1'b0                     ;

reg                   [10:0]    rWrLenLeft        = 11'd0                     ;

reg                             rMemWrBusy        =  1'b0                     ;
reg                             _rMemWrBusy       =  1'b0                     ;
//   Memory Write Related Register >


reg                    [7:0]    st_current  = `ST_RX_RST                ;
reg                    [7:0]    st_next     = `ST_RX_RST                ;


wire                            wMAxisCqEn      ;

wire                            wSop            ;
wire                            wRequestType    ;

wire                            wMemWrBusyNeg   ;

assign M_AXIS_CQ_TREADY = rMAxisCqTReady                        ;
assign wMAxisCqEn       = M_AXIS_CQ_TVALID && M_AXIS_CQ_TREADY  ;

assign wSop             = wMAxisCqEn && M_AXIS_CQ_TUSER[40]     ;
assign wRequestType     = rDescHdrQw1[14:11]                    ;

assign wMemWrBusyNeg    = (~rMemWrBusy) && _rMemWrBusy          ;

assign MEM_WR_DATA      = rMemWrData                            ;
assign MEM_WR_ADDR      = rMemWrAddr                            ;
assign MEM_WR_KEEP      = rMemWrKeep                            ;
assign MEM_WR_VALD      = rMemWrVald                            ;
assign MEM_WR_ERRO      = rMemWrErro                            ;
assign MEM_WR_LAST      = rMemWrLast                            ;




// < state machine
always @(posedge CLK) begin
  if ( !RST_N )
    st_current <= `ST_RX_RST  ;
  else
    st_current <= st_next     ;
end

always @(*) begin
  if ( !RST_N )
    st_next = `ST_RX_RST  ;
  else begin
    st_next = st_current  ;
    case(st_current)
    
      `ST_RX_RST: begin
        if ( wSop )
          st_next = `ST_RX_64_QW1 ;
      end // ST_RX_RST

      `ST_RX_64_QW1: begin
        if ( wMAxisCqEn )
          case ( M_AXIS_CQ_TDATA[14:11] ) // check request type

            `PIO_RX_MEM_WR_FMT_TYPE:
              if ( M_AXIS_CQ_TDATA[10:0] != 11'h000 )
                st_next = `ST_RX_MEM_WR ;
              else
                st_next = `ST_RX_RST    ;



            default:
              st_next = `ST_RX_RST  ;   // Don't regonize the request type

          endcase // // check request type
      end // // ST_RX_64_QW1

      `ST_RX_MEM_WR: begin
        if ( wMAxisCqEn && M_AXIS_CQ_TLAST)
            st_next = `ST_RX_WAIT   ;
      end // ST_RX_MEM_WR

      `ST_RX_WAIT: begin
        case ( wRequestType )
          `PIO_RX_MEM_WR_FMT_TYPE:
            if ( wMemWrBusyNeg )
              st_next = `ST_RX_RST    ;
            else
              st_next = `ST_RX_WAIT   ;
        
          default:
            st_next = st_next ;
        endcase
      end // ST_RX_WAIT
    
    endcase
  end
end
//   state machine >


// < M_AXIS_Tready

// always @(posedge CLK) begin
//   if ( !RST_N )
//     rMAxisCqTReady <= 1'b0  ;
//   else if ( st_current == ST_RX_RST && )
// end

//  M_AXIS_Tready >



// < Indicator latch

always @(posedge CLK) begin
  if ( !RST_N )
    rDescHdrQw0 <= 64'd0    ;
  else if ( st_current == `ST_RX_RST && wSop )
    rDescHdrQw0 <= M_AXIS_CQ_TDATA  ;
  else
    rDescHdrQw0 <= rDescHdrQw0      ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    rDescHdrQw1 <= 64'd0    ;
  else if ( st_current == `ST_RX_64_QW1 && wMAxisCqEn )
    rDescHdrQw1 <= M_AXIS_CQ_TDATA  ;
  else
    rDescHdrQw1 <= rDescHdrQw1      ;
end

//   Indicator latch


// < Memory Write Process

always @(posedge CLK) begin
  if ( !RST_N )
    rWrLenLeft <= 11'd0   ;
  else if ( st_current == `ST_RX_64_QW1 && M_AXIS_CQ_TDATA[14:11] == `PIO_RX_MEM_WR_FMT_TYPE && wMAxisCqEn )
    rWrLenLeft <= M_AXIS_CQ_TDATA[10:0] ;
  else if ( st_current == `ST_RX_MEM_WR && rWrLenLeft > 2  && wMAxisCqEn )
    rWrLenLeft <= rWrLenLeft - 2  ;
  else if ( st_current == `ST_RX_MEM_WR && rWrLenLeft <= 2 && wMAxisCqEn )
    rWrLenLeft <= 11'd0           ;
  else
    rWrLenLeft <= rWrLenLeft      ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    rMemWrData = {`BRAM_DATA_WIDTH{1'b0}}  ;
  else if ( st_current == `ST_RX_MEM_WR && wMAxisCqEn )
    rMemWrData = M_AXIS_CQ_TDATA           ;
  else
    rMemWrData = rMemWrData                ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    rMemWrAddr <= {`BRAM_ADDR_WIDTH{1'b0}}  ;
  else if ( st_current == `ST_RX_MEM_WR && wMAxisCqEn )
    rMemWrAddr <= ( rDescHdrQw0[31:2] + rDescHdrQw1[10:0] - rWrLenLeft )  ;
  else
    rMemWrAddr <= rMemWrAddr    ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    rMemWrKeep <= {`BRAM_KEEP_WIDTH{1'b0}}  ;
  else if ( st_current == `ST_RX_MEM_WR && wMAxisCqEn )
    rMemWrKeep <= M_AXIS_CQ_TUSER[15:8]     ;
  else
    rMemWrKeep <= {`BRAM_KEEP_WIDTH{1'b0}}  ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    rMemWrVald <= 1'b0  ;
  else if ( st_current == `ST_RX_MEM_WR && wMAxisCqEn )
    rMemWrVald <= 1'b1  ;
  else
    rMemWrVald <= 1'b0  ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    rMemWrErro <= 1'b0  ;
  else if ( st_current == `ST_RX_MEM_WR && wMAxisCqEn && M_AXIS_CQ_TLAST )
    rMemWrErro <= M_AXIS_CQ_TUSER[41] ;
  else
    rMemWrErro <= 1'b0  ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    rMemWrLast <= 1'b0  ;
  else if ( st_current == `ST_RX_MEM_WR && wMAxisCqEn && M_AXIS_CQ_TLAST )
    rMemWrLast <= 1'b1  ;
  else
    rMemWrLast <= 1'b0  ;
end

always @(posedge CLK) begin
  if ( !RST_N )
    {_rMemWrBusy, rMemWrBusy} <= 2'b00  ;
  else
    {_rMemWrBusy, rMemWrBusy} <= {rMemWrBusy, MEM_WR_BUSY}  ;
end

//   Memory Write Process >


endmodule
