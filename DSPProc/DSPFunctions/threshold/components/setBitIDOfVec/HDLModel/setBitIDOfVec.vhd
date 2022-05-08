-- Description: setBitIDOfVec component 
--  Synchronously assert vec(bitID) when ce is asserted
--
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 26/1/2021
--
-- Signal dictionary
--  clk	    system clock strobe, rising edge active
--  rst	    assertion (h) asynchronously clears all registers
--  ld0     assertion (h) synchronously clears all registers
--  ce      assertion (h) enables synchronous set of vec(bitID) bit
--  bitID   vec(31:0) bitID to assert, when ce is asserted
--  vec     32-bit vector 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity setBitIDOfVec is
    Port ( clk : in STD_LOGIC;   
           rst : in STD_LOGIC;   
           ld0 : in STD_LOGIC;   
           ce  : in STD_LOGIC;   
           bitID : in  std_logic_vector( 4 downto 0); 
		   vec : out std_logic_vector(31 downto 0)
           );
end setBitIDOfVec;

architecture RTL of setBitIDOfVec is
-- Internal signal declarations
signal NS    : STD_LOGIC_VECTOR(31 downto 0); -- next state threshold vector
signal CS    : STD_LOGIC_VECTOR(31 downto 0); -- current state threshold vector

begin

asgnVec_i: vec <= CS;

NSDecode_i: process (CS, ld0, ce, bitID) 
begin
   NS <= CS;                     -- default = CS 
   if ld0 = '1' then 		     -- clear NS
	    NS <= (others => '0'); 
   else 
		if ce = '1' then 
			NS( to_integer( unsigned(bitID) ) ) <= '1'; -- NS(bitID) asserted if ce is asserted 
		end if;
   end if;
end process;

-- State register, synchronous process 
stateReg_i: process (clk, rst)
begin
  if rst = '1' then 		   -- asynch reset
    CS <= (others => '0');		
  elsif clk'event and clk = '1' then 
	CS <= NS;
  end if;
end process; 

end RTL;