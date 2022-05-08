-- Description: memory_selDatToHost
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 7/2/2021

-- Description
-- decodes memAdd(7:5) to select memory component data output on datToHost 

-- signal dictionary
--  memAdd(10:8) 		     	selects source memory 32-bit word (000 => word 0 bits 31:0, 111 => word 7 bits 255:224) 
--  memAdd(7:5) 		     	3-bit memory component base address select
--  CSROut                      addressed 32-bit data from control and status register array
--  sourceMem                   addressed 256-bit data from 32 x 256-bit BRAM source memory array  
--  resultMem0                  addressed 32-bit data from result memory word
--  datToHost                   32-bit data to host 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity memory_selDatToHost is
    Port ( memAdd     : in  std_logic_vector( 10 downto 0);
		   CSROut     : in  std_logic_vector( 31 downto 0);
		   sourceMem  : in  std_logic_vector(255 downto 0);
		   resultMem0 : in  std_logic_vector( 31 downto 0);
		   datToHost  : out std_logic_vector( 31 downto 0)		   
 		 );
end memory_selDatToHost;

architecture comb of memory_selDatToHost is
constant CSRAdd        : std_logic_vector(2 downto 0) := "000";
constant sourceMemAdd  : std_logic_vector(2 downto 0) := "001";
constant resultMem0Add : std_logic_vector(2 downto 0) := "010";
signal   index         : integer range 0 to 7; 

begin

-- sourceMem is 32x256-bit array = 32x (8x32)-bits 
-- Use memAdd(10 downto 8) to select the 32-bit slice of sourceMem, i.e, index
asgnIndex_i: index <= to_integer( unsigned(memAdd(10 downto 8)) );

asgndatToHost_i: process (memAdd, CSROut, sourceMem, resultMem0, index)
begin 
  datToHost    <= (others => '0'); -- default
  if    memAdd(7 downto 5) = CSRAdd then
     datToHost <= CSROut; 
  elsif memAdd(7 downto 5) = sourceMemAdd then    -- source memory (32 x 256-bit), memAdd = 0b00100000 to 0b00111111 
     datToHost <= sourceMem( (32*index + 31) downto (32*index) );
  elsif memAdd(7 downto 5) = resultMem0Add then   -- result memory (32 x 32-bit),  memAdd = 0b01000000 to 0b01011111 
     datToHost <= resultMem0;
  end if;
end process;

end comb;