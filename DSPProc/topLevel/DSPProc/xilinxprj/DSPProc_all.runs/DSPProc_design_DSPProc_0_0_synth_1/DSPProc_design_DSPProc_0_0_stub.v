// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.1 (win64) Build 2552052 Fri May 24 14:49:42 MDT 2019
// Date        : Sat Nov 20 11:54:35 2021
// Host        : Helios running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ DSPProc_design_DSPProc_0_0_stub.v
// Design      : DSPProc_design_DSPProc_0_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "DSPProc,Vivado 2019.1" *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix(clk, rst, continue_proc, host_memWr, host_memAdd, 
  host_datToMem, datToHost)
/* synthesis syn_black_box black_box_pad_pin="clk,rst,continue_proc,host_memWr,host_memAdd[10:0],host_datToMem[31:0],datToHost[31:0]" */;
  input clk;
  input rst;
  input continue_proc;
  input host_memWr;
  input [10:0]host_memAdd;
  input [31:0]host_datToMem;
  output [31:0]datToHost;
endmodule
