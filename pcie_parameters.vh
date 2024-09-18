`ifndef __PCIE_PARAMETERS_VH
`define __PCIE_PARAMETERS_VH 1

`define AXISTEN_IF_RQ_ALIGNMENT_MODE "DWORD"
`define AXISTEN_IF_CC_ALIGNMENT_MODE "DWORD"
`define AXISTEN_IF_CQ_ALIGNMENT_MODE "DWORD"
`define AXISTEN_IF_RC_ALIGNMENT_MODE "DWORD"

// `define AXISTEN_IF_RQ_ALIGNMENT_MODE "ADDR"
// `define AXISTEN_IF_CC_ALIGNMENT_MODE "ADDR"
// `define AXISTEN_IF_CQ_ALIGNMENT_MODE "ADDR"
// `define AXISTEN_IF_RC_ALIGNMENT_MODE "ADDR"

`define AXISTEN_IF_RQ_PARITY_CHECK 0
`define AXISTEN_IF_CC_PARITY_CHECK 0
`define AXISTEN_IF_CQ_PARITY_CHECK 0
`define AXISTEN_IF_RC_PARITY_CHECK 0

`define AXI4_CQ_TUSER_WIDTH 88
`define AXI4_RC_TUSER_WIDTH 75
`define AXI4_CC_TUSER_WIDTH 33

`define PCIE_DATA_WIDTH   64
`define PCIE_STRB_WIDTH   `PCIE_DATA_WIDTH / 8
`define PCIE_KEEP_WIDTH   `PCIE_DATA_WIDTH / 32
`define PCIE_PARITY_WIDTH `PCIE_DATA_WIDTH / 8


`endif