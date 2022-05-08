-- Description: CB3CLE 3-bit up, loadable counter with chip enable, asynchronous rst
-- Outputs: count(2:0), TC, ceo
-- Engineer: Fearghal Morgan
-- Date: 12/10/2019
-- 
-- signal data dictionary
--  clk			system clock strobe, rising edge active
--  rst	        assertion (h) asynchronously clears all registers
--  loadDat(2:0) 3-bit load data value
--  load		Assertion (H) synchronously loads count(2:0) register with loadDat(2:0) 
--              Load function does not require assertion of signal ce
--  ce			Assertion (H) enable synchronous count behaviour 
--  count(2:0)	Counter value, changes synchronously on active (rising) clk edge
--  TC	        Asserted (H) when count = 7
--  ceo	        Asserted (H) when ce = '1' and TC is asserted

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CB3CLE is
    Port ( clk 		: in STD_LOGIC;   
           rst 		: in STD_LOGIC;   
           loadDat	: in STD_LOGIC_VECTOR (2 downto 0); 
           load		: in STD_LOGIC;                
           ce 		: in STD_LOGIC;                
           count	: out STD_LOGIC_VECTOR (2 downto 0);
           TC       : out STD_LOGIC;
           ceo      : out STD_LOGIC                    
           );
end CB3CLE;

architecture RTL of CB3CLE is
signal XX_NS : STD_LOGIC_VECTOR(2 downto 0); -- next state
signal XX_CS : STD_LOGIC_VECTOR(2 downto 0); -- current state  
signal intTC : std_logic;

begin

XX_NSDecode_i: process(XX_CS, loadDat, load, ce)
	begin
		XX_NS <= XX_CS; -- default assignment
		if load = '1' then
			XX_NS <= loadDat;
		elsif ce = '1' then
			XX_NS <= std_logic_vector( unsigned(XX_CS) + 1 );
		end if;
end process;

stateReg_i: process(clk, rst)
begin
	if rst = '1' then           		
        XX_CS <= (others => '0');
	elsif clk'event and clk = '1' then	
        XX_CS <= XX_NS;
	end if;
end process;
asgnCount_i: count <= XX_CS; 

OPDecode: process (XX_CS)
begin
	intTC <= '0'; -- default
	if XX_CS = "111" then 
	   intTC <= '1';   
    end if;
end process;
asgnceo_i: ceo <= ce and intTC; 
asgnTC_i:  TC  <= intTC; 

end RTL;