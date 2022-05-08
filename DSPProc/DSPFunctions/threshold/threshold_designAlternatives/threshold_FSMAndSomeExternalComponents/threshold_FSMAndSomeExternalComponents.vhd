-- Description: threshold component, 
-- threshold_moreFunctionalityInFSM_lessInternalSignals
-- Includes more functionality described in FSM, requiring less internal signals, or components
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
-- Internal signal declarations
type stateType is (idle, chk_srcMemByte_GE_threshVal, wr_threshVec_to_resultMem, 
                   write_status_to_CSR0); -- declare enumerated state type
signal NS, CS          			: stateType;     		   	     -- declare FSM state 

signal NSThreshVec, CSThreshVec : STD_LOGIC_VECTOR(31 downto 0); -- threshold vector, next state and current state 

-- address counter signals
signal ldXYAdd0        : std_logic;                     -- assert to synchronously ld0 X and Y address counters
signal YAdd_ce         : std_logic;                     -- assert to enable Y address counter
signal YAdd            : std_logic_vector(4 downto 0);  -- Y address, 0-31 
signal YAdd_TC         : std_logic;                     -- assert when Y address = max value = 31
signal XAdd_ce         : std_logic;                     -- assert to enable X address counter
signal XAdd            : std_logic_vector(4 downto 0);  -- Y address, 0-31 
signal XAdd_TC         : std_logic;                     -- assert when X address = max value = 31

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

YAdd_i: CB5CLE -- use for 5-bit (0-31) address of sourceMem and resultMem 
Port map(  clk 		 => clk, 		
           rst 		 => rst, 		
           loadDat	 => "00000", -- always 0
           load		 => ldXYAdd0,		
           ce 		 => YAdd_ce, 		
           count	 => YAdd,	
           TC        => YAdd_TC,     
           ceo       => open     -- not used 
           );

XAdd_i: CB5CLE -- use for 5-bit (0-31) address of byte slice in sourceMem(255:0)
Port map(  clk 		 => clk, 		
           rst 		 => rst, 		
           loadDat	 => "00000", -- always 0
           load		 => ldXYAdd0,		
           ce 		 => XAdd_ce, 		
           count	 => XAdd,	
           TC        => XAdd_TC,     
           ceo       => open     -- not used 
           );

-- FSM next state and o/p decode process
NSAndOPDec_i: process (CS, go, hold, sourceMem, CSThreshVec, YAdd, XAdd, XAdd_TC, YAdd_TC, CSR(0))
begin
   NS 	 		  	  <= CS;   -- default signal assignments
   NSThreshVec        <= CSThreshVec;   

   active 		  	  <= '1';  -- default asserted. Deasserted only in idle state. 

   ldXYAdd0   	   	  <= '0';    		    
   YAdd_ce        	  <= '0';				  
   XAdd_ce        	  <= '0';
   memWr              <= '0';
   memAdd(7 downto 5) <= "010";-- default is resultMem address
   memAdd(4 downto 0) <= YAdd; -- default memory address (4:0) = YAdd(4:0)
   datToMem           <= (others => '0');

   case CS is  
		when idle => 			     
			active          <= '0';  
			NSThreshVec     <= (others => '0');                    -- clear vector 
			ldXYAdd0        <= '1';                                -- clear XAdd and YAdd counters 
            if go = '1' then 
				NS 	        <= chk_srcMemByte_GE_threshVal;
			end if;

		when chk_srcMemByte_GE_threshVal => 
		    if hold = '0' then                                       -- normal operation
				if unsigned(sourceMem(  ((8*to_integer(unsigned(XAdd))) + 7) downto 8*to_integer(unsigned(XAdd))  )) >= unsigned(CSR(0)(15 downto 8)) then 
					NSThreshVec( to_integer(unsigned(XAdd)) ) <= '1'; 
				end if; 
				if XAdd_TC = '1' then                                  -- final byte slice (of 32) of sourceMem(255:0)? 
					NS                 <= wr_threshVec_to_resultMem;   -- final threshVec value is ready in wr_threshVec_to_resultMem state
				end if;
				XAdd_ce                <= '1';                         -- increment X address
			end if;
			
		when wr_threshVec_to_resultMem =>                          -- XAdd is 0 in this state (rolled over from 31 in previous state)
		    memWr                  <= '1';                         -- memory address is defined in default assignments
			datToMem               <= CSThreshVec;
			if YAdd_TC = '1' then                                  -- exit loop if at final sourceMem(255:0) value (YAdd = 31)? 
				NS                 <= write_status_to_CSR0;             
			else						
	   	  	    NSThreshVec     <= (others => '0');                -- clear vector 
				NS                 <= chk_srcMemByte_GE_threshVal; -- loop, to process next sourceMem(255:0)
			end if;			
  	  	    YAdd_ce                <= '1'; 					       -- Increment Y address. Address next 256-bit sourceMem value
			
		when write_status_to_CSR0 => 	                           -- CSR(0)(7)=1 (task done), CSR(0)(0)=0 (return control to host). Remainder of CSR(0) is unchanged 		    
			memWr              <= '1';
            memAdd             <= X"00";                           -- address CSR(0) 
		    datToMem           <= CSR(0)(31 downto 8) & '1' & CSR(0)(6 downto 1) & '0'; 
		    NS                 <= idle;
		
		when others => 
			null;
	end case;
end process; 

-- Synchronous process registering current FSM state value and CSThreshVec
stateReg_i: process (clk, rst)
begin
  if rst = '1' then 		
    CS 				<= idle;		
	CSThreshVec  	<= (others => '0');		
  elsif clk'event and clk = '1' then 
	if WDTimeout= '1' then -- return to idle state on watchdog timeout. Do not clear CSThreshVec
		CS 			<= idle;		
	else
		CS 			<= NS;
		CSThreshVec <= NSThreshVec;
	end if;
  end if;
end process; 

end RTL;