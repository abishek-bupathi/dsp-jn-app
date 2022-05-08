-- Component: CSR_4x32Reg 
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 26/1/2021

--Description
-- 4 x 32-bit control and status register array
-- Assertion of wr, synchronous store data in register CSR(add)(31:0) = dIn(31:0) 
-- Combinationally output all 4 x register data array values on CSR(3:0)(31:0)
-- CSROut(31:0) combinationally = CSR(add)
-- rst assertion asynchronously clears all registers

-- To create integer format of std_logic_vector address, for use with array addressing,
-- use ieee.numeric_std library to_integer(unsigned(<signal>))

-- Signal dictionary
--  clk				system strobe, rising edge asserted
--  rst				assertion (h) asynchronously clears all registers
--  wr 				assertion (h) synchronously writes dIn(31:0) to CSR(add)
--  add(1:0)		2-bit address, addressing one of 4 CSRs 
--  dIn(31:0)		32-bit data to be written to CSR(add) 
--  CSR(3:0)(31:0)	4 x 32-bit register array 
--  dOut(31:0)	    = CSR(add) combinational output 

-- Internal signal dictionary
--  NS			    Next state signal (3 x 32-bit array) 
--  CS			    Current state signal (3 x 32-bit array)

-- XX_ signal prefix, if used for any signals, excludes the signal from the vicilogic probe register array, 
-- during the vicilogic FPGA bitstream configuration build process

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.arrayPackage.all;

entity CSR_4x32Reg is
    Port ( clk       : in std_logic;   
           rst       : in std_logic;   
		   
           wr        : in std_logic;  
	       add       : in std_logic_vector(1 downto 0);
	       dIn       : in std_logic_vector(31 downto 0);	  

           CSR       : out array4x32;
           dOut      : out std_logic_vector(31 downto 0)
 		 );
end CSR_4x32Reg;

architecture RTL of CSR_4x32Reg is
signal NS : array4x32;	  
signal CS : array4x32;	

begin

NSDecode_i: process(CS)      				-- complete sensitivity list, including all combinational NSDecode process input signals
begin
	NS <= (others => (others => '0')); 	-- to be completed 
end process;

stateReg_i: process(clk, rst) 				-- include only signal clk and rst (asynchronous reset) in sensitivity list
begin
	CS <= (others => (others => '0')); 		-- to be completed 
end process;
asgnCSR_i:   CSR    <= CS;    				-- assigning CSR (output signal) = CS (VHDL internal signal)

genDOut_i:   dOut <= (others => '0'); 	-- to be completed

end RTL;