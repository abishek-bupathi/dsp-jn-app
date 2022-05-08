-- Description: CB48CLE loadable, counter, with chip enable, asynchronous rst
-- Outputs: count(48:0), TC, ceo
-- Engineer: Fearghal Morgan
-- Date: 10/2/2021
-- 
-- signal data dictionary
--  clk			system clock strobe, rising edge active
--  rst	        assertion (h) asynchronously clears all registers
--  loadDat     48-bit value 
--  load		Assertion (H) synchronously loads count register with loadDat
--              Load function does not require assertion of signal ce
--  ce			Assertion (H) enable synchronous count behaviour 
--  count    	Integer counter value, changes synchronously on active (rising) clk edge
--  TC	        Asserted (H) when count = max = X"FFFFFFFFFFFF"
--  ceo	        Asserted (H) when ce = '1' and TC is asserted

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CB48CLE is
    Port ( clk 		: in STD_LOGIC;   
           rst 		: in STD_LOGIC;   
           loadDat	: in std_logic_vector(47 downto 0);
           load		: in STD_LOGIC;                
           ce 		: in STD_LOGIC;                
           count	: out std_logic_vector(47 downto 0);
           TC       : out STD_LOGIC;
           ceo      : out STD_LOGIC                    
           );
end CB48CLE;

architecture RTL of CB48CLE is
signal XX_NS : std_logic_vector(47 downto 0); -- next state
signal XX_CS : std_logic_vector(47 downto 0); -- current state
signal intTC : std_logic; 

begin

NSDecode_i: process(XX_CS, loadDat, load, ce)
	begin
		XX_NS <= XX_CS; -- default assignment
		if load = '1' then
			XX_NS <= loadDat;
		elsif ce = '1' then
				XX_NS <= std_logic_vector( unsigned(XX_CS)+ 1 );			
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
	if XX_CS = X"ffffffffffff" then 
	   intTC <= '1';   
    end if;
end process;
asgnceo_i: ceo <= ce and intTC; 
asgnTC_i:  TC  <= intTC; 

end RTL;