-- Description: CB0To31CLEInteger counter up 0 to 31, loadable counter with chip enable, asynchronous rst
-- Outputs: count (integer range 0 to 31), TC, ceo
-- Engineer: Fearghal Morgan
-- Date: 12/10/2019
-- 
-- signal data dictionary
--  clk			system clock strobe, rising edge active
--  rst	        assertion (h) asynchronously clears all registers
--  loadDat     integer 0 to 31 data value
--  load		Assertion (H) synchronously loads count register with loadDat
--              Load function does not require assertion of signal ce
--  ce			Assertion (H) enable synchronous count behaviour 
--  count    	Integer counter value, changes synchronously on active (rising) clk edge
--  TC	        Asserted (H) when count = 31
--  ceo	        Asserted (H) when ce = '1' and TC is asserted

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CB0To31CLEInteger is
    Port ( clk 		: in STD_LOGIC;   
           rst 		: in STD_LOGIC;   
           loadDat	: in integer range 0 to 31; 
           load		: in STD_LOGIC;                
           ce 		: in STD_LOGIC;                
           count	: out integer range 0 to 31;
           TC       : out STD_LOGIC;
           ceo      : out STD_LOGIC                    
           );
end CB0To31CLEInteger;

architecture RTL of CB0To31CLEInteger is
signal XX_NS    : integer range 0 to 31; -- next state
signal XX_CS    : integer range 0 to 31; -- current state  
signal XX_intTC : std_logic; 

begin

NSDecode_i: process(XX_CS, loadDat, load, ce)
	begin
		XX_NS <= XX_CS; -- default assignment
		if load = '1' then
			XX_NS <= loadDat;
		elsif ce = '1' then
			if XX_CS < 31 then 
				XX_NS <= XX_CS + 1;
			else 
				XX_NS <= 0;
			end if;			
		end if;
end process;

stateReg_i: process(clk, rst)
begin
	if rst = '1' then           		
        XX_CS <= 0;
	elsif clk'event and clk = '1' then	
        XX_CS <= XX_NS;
	end if;
end process;
asgnCount_i: count <= XX_CS; 

OPDecode: process (XX_CS)
begin
	XX_intTC <= '0'; -- default
	if XX_CS = 31 then 
	   XX_intTC <= '1';   
    end if;
end process;
asgnceo_i: ceo <= ce and XX_intTC; 
asgnTC_i:  TC  <= XX_intTC; 

end RTL;