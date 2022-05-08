set_property SRC_FILE_INFO {cfile:E:/BE_Project/Project/Project_files/DSPProc/topLevel/DSPProc/xilinxprj/DSPProc_all.srcs/constrs_1/imports/pynq-z1_c/PYNQ-Z1_C.xdc rfile:../../../DSPProc_all.srcs/constrs_1/imports/pynq-z1_c/PYNQ-Z1_C.xdc id:1} [current_design]
set_property src_info {type:XDC file:1 line:8 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sysclk }]; #IO_L13P_T2_MRCC_35 Sch=sysclk
set_property src_info {type:XDC file:1 line:9 export:INPUT save:INPUT read:READ} [current_design]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { sysclk }];
