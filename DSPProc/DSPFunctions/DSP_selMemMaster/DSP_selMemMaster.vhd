-- Description: memCtrlr
-- Engineer: Fearghal Morgan, National University of Ireland, Galway

-- Date: 7/1/2021
-- Selects DSP component which drives memory 

-- TBD
-- Signal data dictionary
--  CSR(0)(0)    
--  CSR			 in  8 x 16 data array 
--  memAdd       out 8-bit address to memory_top 
--  sourceMem    in  256-bit source memory data  
--  maxPixel_memWr out assert to write datToMem(15:0) to memAdd(7:0) 
--  datToMem     out Assertion of maxPixel_memWr enables write of 16-bit datToMem to CSR(memAdd)  
--              	 CSR(2)  X"00" & CSMaxVal
--      		     CSR(1) ("000" & CSMaxY)  &  ("00000" & CSMaxX)
-- 		             CSR(0) XX_CSR0(15 downto 1) & '0'.  CSR(0)(0) = 0. Remainder of CSR(0) is unchanged 
--  maxPixel_active out Assert when maxPixel component is active

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity DSP_selMemMaster is
    Port ( DSP_activeIndex   : in std_logic_vector(5 downto 0); 
	       -- 5:0 is viewSourceMemInResultMem, userFunct, sobel, threshold, histogram, maxPixel
           DSP_memWr    : in std_logic_vector(5 downto 0); 
           DSP_memAdd   : in array6x8;                     
           DSP_datToMem : in array6x32;                     

		   memWr             : out std_logic;
	       memAdd            : out std_logic_vector(7 downto 0);
		   datToMem          : out std_logic_vector(31 downto 0)
           );
end DSP_selMemMaster;
						 
architecture comb of DSP_selMemMaster is
signal activeIndex : integer range 0 to 5;

begin

process (DSP_activeIndex)
begin
	activeIndex <= 0;
	case DSP_activeIndex is 
		when "000010" =>  activeIndex <= 1;
		when "000100" =>  activeIndex <= 2;
		when "001000" =>  activeIndex <= 3;
		when "010000" =>  activeIndex <= 4;
		when "100000" =>  activeIndex <= 5;
		when others  => null;
	end case;			
end process;

asgnmemWr_i:    memWr    <= DSP_memWr(activeIndex); 
asgnmemAdd_i:	memAdd   <= DSP_memAdd(activeIndex); 
asgndatToMem_i:	datToMem <= DSP_datToMem(activeIndex);

end comb;