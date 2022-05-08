-- resultMem0_32x32Reg VHDL model, with synchronous ld0 control
-- Created : Oct 2019
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 10 Oct 2019

--Description
-- 32 x 32-bit register array
-- Assertion of wr, synchronous store data in register (add)(31:0) = dIn(31:0) 
-- rst assertion   asynchronously clears all registers

-- Signal dictionary
--  clk				system strobe, rising edge asserted
--  rst				assertion (h) asynchronously clears all registers
--  ld0				assertion (h)  synchronously clears all registers
--  wr 				assertion (h)  synchronously writes dIn(31:0) to register array (add)
--  add(4:0)		5-bit address, addressing one of 32 registers
--  dIn(31:0)		32-bit data to be written to register array (add) 
--  dOut(31:0)	    = register array (add) combinational output

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity resultMem0_32x32Reg is
    Port ( clk    : in std_logic;   
           rst    : in std_logic;
           ld0    : in std_logic;     

           wr     : in std_logic;    				       
	       add    : in std_logic_vector(4 downto 0);	  
	       dIn    : in std_logic_vector(31 downto 0);	  

           dOut   : out std_logic_vector(31 downto 0)
 		 );
end resultMem0_32x32Reg;

architecture RTL of resultMem0_32x32Reg is
signal XX_NS_ResultMem32x32 : array32x32; -- internal next state signal
signal CS_ResultMem32x32    : array32x32; -- internal current state signal

begin

NSDecode_i: process(CS_ResultMem32x32)                   -- complete sensitivity list, including all combinational NSDecode process input signals
begin
	XX_NS_ResultMem32x32 <= (others => (others => '0')); -- to be completed 
end process;

stateReg_i: process(clk, rst)                            -- include only signal clk and rst (asynchronous reset) in sensitivity list
begin
	CS_ResultMem32x32 <= (others => (others => '0'));    -- to be completed 
end process;

asgnDOut_i: dOut <= (others => '0');                     -- to be completed

end RTL;