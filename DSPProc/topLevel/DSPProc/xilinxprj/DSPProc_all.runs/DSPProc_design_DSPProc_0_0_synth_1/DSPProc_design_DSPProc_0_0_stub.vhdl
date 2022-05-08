-- Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2019.1 (win64) Build 2552052 Fri May 24 14:49:42 MDT 2019
-- Date        : Sat Nov 20 11:54:35 2021
-- Host        : Helios running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
--               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ DSPProc_design_DSPProc_0_0_stub.vhdl
-- Design      : DSPProc_design_DSPProc_0_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7z020clg400-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix is
  Port ( 
    clk : in STD_LOGIC;
    rst : in STD_LOGIC;
    continue_proc : in STD_LOGIC;
    host_memWr : in STD_LOGIC;
    host_memAdd : in STD_LOGIC_VECTOR ( 10 downto 0 );
    host_datToMem : in STD_LOGIC_VECTOR ( 31 downto 0 );
    datToHost : out STD_LOGIC_VECTOR ( 31 downto 0 )
  );

end decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix;

architecture stub of decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,rst,continue_proc,host_memWr,host_memAdd[10:0],host_datToMem[31:0],datToHost[31:0]";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "DSPProc,Vivado 2019.1";
begin
end;
