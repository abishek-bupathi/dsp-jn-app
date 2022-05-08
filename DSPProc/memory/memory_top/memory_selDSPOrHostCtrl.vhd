-- Description: memory_selDSPOrHostCtrl
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 7/1/2021

-- Description
-- select memory master (host or DSP function), and generates signals wr, add, datToMem 

-- TBD
-- Signal data dictionary
--  CSR(0)(0)    
--  CSR			 in  8 x 16 data array 
--  memAdd       out 8-bit address to memoryTop 
--  sourceMem    in  256-bit source memory data  
--  maxPixel_memWr out assert to write datToMem(31:0) to memAdd(7:0) 
--  datToMem     out Assertion of maxPixel_memWr enables write of 16-bit datToMem to CSR(memAdd)  
--              	 CSR(2)  X"00"  &  CSMaxVal
--      		     CSR(1) ("000" & CSMaxY)  &  ("00000" & CSMaxX)
-- 		             CSR(0) XX_CSR0(31 downto 1) & '0'.  CSR(0)(0) = 0. Remainder of CSR(0) is unchanged 
--  maxPixel_active out Assert when maxPixel component is active

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity memory_selDSPOrHostCtrl is
    Port ( DSPMaster           : in  std_logic;

	       host_memWr        : in  std_logic;
	       host_memAdd       : in  std_logic_vector(10 downto 0);
		   host_datToMem     : in  std_logic_vector(31 downto 0);
	       
	       DSP_memWr         : in  std_logic;
	       DSP_memAdd        : in  std_logic_vector( 7 downto 0);
		   DSP_datToMem      : in  std_logic_vector(31 downto 0);

	       memWr             : out std_logic;
	       memAdd            : out std_logic_vector(10 downto 0);
		   datToMem          : out std_logic_vector(31 downto 0)
           );
end memory_selDSPOrHostCtrl;
						 
architecture comb of memory_selDSPOrHostCtrl is

begin

process (DSPMaster, 
         host_memWr, host_memAdd, host_datToMem,
         DSP_memWr,  DSP_memAdd,  DSP_datToMem)
begin
	memWr    <= host_memWr; -- defaults
	memAdd   <= host_memAdd; 
	datToMem <= host_datToMem;
	if DSPMaster = '1' then
		memWr    <= DSP_memWr;
		memAdd   <= "000" & DSP_memAdd; 
		datToMem <= DSP_datToMem;
	end if;
end process;

end comb;