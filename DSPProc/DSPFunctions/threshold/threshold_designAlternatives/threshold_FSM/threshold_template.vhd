-- Description: threshold component
-- Describes most functionality in FSM, requiring less internal signals, or components
--
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 26/1/2021
--
-- For 32 x sourceMem 256-bit words 
--   state chk_srcMemByte_GE_threshVal
--   Generates threshVec(31:0) bits if sourceMem(255:0)(XAdd) byte is >= threshVal(7:0)
--   Repeat until XAdd = 31
-- When each sourceMem 256-bit byte is processed
--   state wr_threshVec_to_resultMem 
-- When all 32 x sourceMem 256-bit values are processed
--   state write_status_to_CSR0
--
--
-- Pause/continue DSP function processing 
-- use pauseY/pauseX non-zero addresses and releasing pause with assertion of signal continue
-- Enables pausing of algorithm finite state machine (FSM) at a specific sourceMem array pauseY/pauseX address combination
-- pauseY is configured in CSR(0)(28:24), pauseX is configured in CSR(0)(20:16)
-- pause operates when either pauseY or pauseX value > 0 
-- Assert signal pause when YAdd and XAdd match the selected pauseY/pauseX values 
-- pause assertion prevents FSM progression until external continue is asserted. 
-- Then, to progress, configure single step clk, step clk once to progress in FSM 
-- (increments XAdd so pause signal is no longer asserted)
-- Then step clk and observe signal behaviour  
--
--
-- Signal dictionary
--  clk					system clock strobe, rising edge active
--  rst	        		assertion (h) asynchronously clears all registers
--  continue  			assertion clears pause signal 

--	WDTimeout 	        Assertion return FSM to idle state 
--  go			        Assertion (H) detected in idle state to active threshold function 
--  active (Out)        Default asserted (h), except in idle state

--  CSR	        		4 x 32-bit Control & Status registers. Only CSR(0) is used 
--  sourceMem           Current source memory 256-bit data  
--  memWr  (Out)        Asserted to synchronously write to addressed memory
--  memAdd (Out)        Addressed memory
--                      reading sourceMem(255:0): use YAdd(4:0) to generate memAdd(4:0). 
-- 					      sourceMem read only uses address bits (4:0) 
-- 					    writing resultMem(31:0) : memAdd(7:5)=010, memAdd(4:0)=YAdd(4:0) 
-- 					    writing CSR(0): memAdd(7:0)=0
--  datToMem (Out)      32-bit data to addressed result or CSR memory 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all; -- stores array types and component declarations

entity threshold is
    Port ( clk 		 : in STD_LOGIC;   
           rst 		 : in STD_LOGIC;  
  		   continue  : in  std_logic;
		   
		   WDTimeout : in std_logic;
           go        : in  std_logic;                		 
		   active    : out std_logic;

		   CSR       : in  array4x32;
           sourceMem : in  std_logic_vector(255 downto 0); 
					 
		   memWr     : out std_logic;
		   memAdd    : out std_logic_vector(  7 downto 0);					 
		   datToMem	 : out std_logic_vector( 31 downto 0)
           );
end threshold;

architecture RTL of threshold is
-- Use the provided (recommended) signal names

-- Internal signal declarations
type stateType is (idle); -- (<to be included>, , , ); -- declare enumerated state type
signal CS, NS          : stateType;     		       -- declare state signals 

signal NSThreshVec, CSThreshVec : STD_LOGIC_VECTOR(31 downto 0); -- threshold vector, next state and current state 
signal NSYAdd, CSYAdd 			: std_logic_vector(4 downto 0);  -- Y address, 0-31 (next state and current state)
signal NSXAdd, CSXAdd  			: std_logic_vector(4 downto 0);  -- X address, 0-31 (next state and current state)

signal pause    	   : std_logic; 
signal pauseY 		   : std_logic_vector (4 downto 0);
signal pauseX 		   : std_logic_vector (4 downto 0);

begin

asgnpauseY_i: pauseY <= CSR(0)(28 downto 24);
asgnpauseX_i: pauseX <= CSR(0)(20 downto 16);
pause_i: process (CSR(0), continue, pauseY, pauseX, YAdd, XAdd)
begin
	pause <= '0'; -- default
	if continue = '0' then                -- assertion of continue clears signal pause 
		if unsigned(pauseY) > 0 or unsigned(pauseX) > 0 then -- pause only when one/both pauseY/X not 0
			if YAdd = pauseY and XAdd = pauseX then      
				pause <= '1'; 
			end if;
		end if;
	end if;
end process;

-- Next state and o/p decode process
NSAndOPDec_i: process (CS) -- <sensitivity list to be included, synthesis and review message for missing sensitivity list signals>, , ,) 
begin
   -- Review default values; refer to FSM flowchart key
   NSThreshVec        <= CSThreshVec;   
   NSYAdd  	          <= CSYAdd;   
   NSXAdd  	          <= CSXAdd;   

   active 		  	  <= '1';    -- default asserted. Deasserted only in idle state. 

   memWr              <= '0';
   memAdd(7 downto 5) <= "000";   
   memAdd(4 downto 0) <= "000000"; 
   datToMem           <= (others => '0');
							   
   case CS is  
		when idle => 			     
			null; -- <include state logic>
		    NS 	  <= idle; -- <include state transition assignments, avoid NS <= current state, i.e, this NS <= idle example, since NS <= CS covers this assignment> 

		when others => 
			null;
	end case;
	
end process; 

-- Synchronous process defining FSM state values, including CSThreshVec
-- Assertion of WDTimeout (watchdog timeout) synchronously returns FSM to idle state. Do not clear CSThreshVec
stateReg_i: process (clk, rst) -- < to be completed>
begin
  CS <= idle;		
  CSThreshVec <= (others => '0');		
  CSYAdd      <= (others => '0');		
  CSXAdd      <= (others => '0');		
end process; 

end RTL;