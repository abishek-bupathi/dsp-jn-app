-- Engineer: Fearghal Morgan
-- Create Date: 13/09/2015 
-- FD5CL0E 5-bit register with asynchronous reset, load 0 and chip enable

-- Signal data dictionary
-- clk 		: in STD_LOGIC; 					-- clk strobe, rising edge active
-- rst 		: in STD_LOGIC; 					-- asynch, high asserted rst   
-- ld0	    : in std_logic;	                    -- assert to synchronously load 0      
-- ce	    : in STD_LOGIC; 					-- chip enable, asserted high
-- D	    : in STD_LOGIC_VECTOR(4 downto 0); 	-- register data in 

-- Q	    : out STD_LOGIC_VECTOR(4 downto 0) 	-- register data out

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity FD5CL0E is
 Port ( clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        ld0	: in std_logic;	
        ce	: in STD_LOGIC;  
        D	: in STD_LOGIC_VECTOR(4 downto 0);  
        Q   : out STD_LOGIC_VECTOR(4 downto 0)
      );
end FD5CL0E;

architecture RTL of FD5CL0E is
-- declare internal signals
signal NS : STD_LOGIC_vector(4 downto 0);
signal CS : STD_LOGIC_vector(4 downto 0);

begin

NSDecode_i: process (CS, ld0, ce, D)
begin
    NS <= CS; -- default assignment     
	if ld0 = '1' then 
        NS <= (others => '0'); 
    elsif ce = '1' then
        NS <= D; 
    end if;
end process;

stateReg_i: process(clk, rst) 
begin
	if rst = '1' then
		CS <= (others => '0');
	elsif clk'event and clk = '1' then
		CS <= NS;
	end if;
end process;

asgn_Q: Q <= CS;

end RTL;