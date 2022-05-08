-- Description: histogram component 
-- Describes most functionality in FSM, requiring less internal signals, or components

-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Created: 1/3/2021
--
-- For 32 sourceMem 256-bit words
--   data format: eight x 32-bit colour sourceMemRGBPixels, X, Red, Green, Blue. X is unused.
-- select sourceMemRGBPixel byte defined by RGBIndex (CSR(5:4)), i.e, 10:Red, 01:Green, 00:Blue
-- CSMaxRGBPixVal (0 initially) = sourceMemRGBPixel if sourceMemRGBPixel > current CSMaxRGBPixVal
--
-- For each of the 8 selected RGB pixel bytes in a 256-bit sourceMem word, increment one of 7 histogram counters 
-- 8 range limit values, 7 ranges (lowest to highest): range(i) to range(i+1) 
-- range limit 7: 0xff 
-- range limit 6: CSR(2)(15: 8)
-- range limit 5: CSR(2)( 7: 0)
-- range limit 4: CSR(1)(31:24) 
-- range limit 3: CSR(1)(23:16) 
-- range limit 2: CSR(1)(15: 8) 
-- range limit 1: CSR(1)( 7: 0) 
-- range limit 0: 0  
--
-- Generates 7 x count values (CSHistogram, array7x9), reflecting the selected pixel sourceMem values in each histogram range
-- sourceMem is X (unused), red, green or blue pixel, one byte in 32-bit vector. 
-- Max histogram count?
--  Could have 8 pixel values in same range in sourceMem(255:0) word 
--  32 sourceMem words, so need count to handle 0 - 256 (incl), so need 9 bit counters
--
-- When all 32 x sourceMem 256-bit values are processed
--   write_limits_and_histValues_to_ResultMem
-- 	   write the seven range limit pair value, and corresponding histogram result, to resultMem locations 0 - 6 
--   write_status_to_CSR0
--    (31:24): range value limits XX_histLimit(6)
--    (23: 8): "0000000" & corresponding 9-bit histogram result CS_histogram(7)
--    Assert CSR(0)(7) to indicate task complete
--    Deassert CSR(0)(0) to return control to host 
--    Other CSR(0) bits unchanged
-- 
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
--  CSR	                4 x 32-bit Control & Status registers. Only CSR(0) is used 
--  sourceMem           Current source memory 256-bit data  
--  memWr  (Out)        Asserted to synchronously write to addressed memory
--  memAdd (Out)        Addressed memory
--                      reading sourceMem(255:0): use YAdd(4:0) to generate memAdd(4:0). 
-- 					      sourceMem read only uses address bits (4:0) 
-- 					    writing resultMem(31:0) : memAdd(7:5)=010, memAdd(4:0)=YAdd(4:0) 
-- 					    writing CSR(0): memAdd(7:0)=0
--  datToMem (Out)      32-bit data to addressed result or CSR memory 

-- vicilogic-specific note
-- XX_ prefix used by vicilogic: internal signal not brought to design top for viewing on vicilogic

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity histogram is
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
end histogram;

architecture RTL of histogram is

type stateType is (idle, getHistogram, write_limits_and_histValues_to_ResultMem, write_status_to_CSR0); -- declare enumerated state type
signal CS, NS                       : stateType;     		   	     -- declare state signals 

signal clrLocalMem                  : std_logic;                     -- synchronously clear CS signals 

signal NSYAdd		      	  		  : std_logic_vector(4 downto 0);  -- Y address, 0-31 (next state)
signal CSYAdd            	  		  : std_logic_vector(4 downto 0);  -- Y address, 0-31 (current state). YAdd is identical (used in vicilogic)
signal NSXAdd  	    		  		  : std_logic_vector(2 downto 0);  -- X address, 0-7 (next state)
signal CSXAdd       	      		  : std_logic_vector(2 downto 0);  -- X address, 0-7 (current state). XAdd is identical (used in vicilogic)

signal sourceMemWord                : STD_LOGIC_VECTOR(31 downto 0); -- 32-bit slice of sourceMem(255:0) 
signal unsignedSourceMemRGBPixel    : unsigned(7 downto 0);          -- currently selected R, G or B pixel data 

-- XX_ prefix used for some signals by vicilogic. Use this signal name in this model
signal XX_histLimit                 : array8x8;                      -- 8 x histogram range values, defined in from CSR(2:1)
signal XX_NSHistogram, CSHistogram  : array7x9; 		             -- histogram counter next state and current state 

signal pause    	   : std_logic; 
signal pauseY 		   : std_logic_vector (4 downto 0);
signal pauseX 		   : std_logic_vector (4 downto 0);

begin

asgnpauseY_i: pauseY <= CSR(0)(28 downto 24);
asgnpauseX_i: pauseX <= CSR(0)(20 downto 16);
pause_i: process (CSR(0), continue, pauseY, pauseX, CSYAdd, CSXAdd)
begin
	pause <= '0'; -- default
	if continue = '0' then                -- assertion of continue clears signal pause 
		if unsigned(pauseY) > 0 or unsigned(pauseX) > 0 then -- pause only when one/both pauseY/X not 0
			if CSYAdd = pauseY and "00" & CSXAdd = pauseX then      
				pause <= '1'; 
			end if;
		end if;
	end if;
end process;

-- assign range limits
XX_histLimit(7) <= X"ff";
XX_histLimit(6) <= CSR(2)(15 downto  8);
XX_histLimit(5) <= CSR(2)( 7  downto 0);
XX_histLimit(4) <= CSR(1)(31 downto 24);
XX_histLimit(3) <= CSR(1)(23 downto 16);
XX_histLimit(2) <= CSR(1)(15 downto  8);
XX_histLimit(1) <= CSR(1)( 7 downto  0);
XX_histLimit(0) <= X"00";

asgnSourceMemWord_i:          sourceMemWord             <= sourceMem( ((to_integer(unsigned(CSXAdd)))*32)+31 downto (to_integer(unsigned(CSXAdd))*32) ); 
asgnUnsgnSourceMemRGBPixel_i: unsignedSourceMemRGBPixel <= unsigned(  sourceMemWord(    (   8*(to_integer(unsigned(CSR(0)(5 downto 4)))) + 7   )  downto  (   8*(to_integer(unsigned(CSR(0)(5 downto  4))))   )   )  );

-- Next state and o/p decode process
NSAndOPDec_i: process (CS, go, pause, unsignedSourceMemRGBPixel, XX_histLimit, CSHistogram, CSYAdd, CSXAdd, CSR)
begin
   NS 	 		  <= CS; 	      -- default signal assignments
   XX_NSHistogram <= CSHistogram;  
   NSYAdd  	      <= CSYAdd;   
   NSXAdd  	      <= CSXAdd;   

   active 		  <= '1';         -- default asserted. Deasserted only in idle state, when go is deasseerted
   clrLocalMem    <= '0';     			  
				  
   memWr              <= '0';
   memAdd(7 downto 5) <= "010";  -- default is resultMem address
   memAdd(4 downto 0) <= CSYAdd; -- default memory address (4:0) = YAdd(4:0)
   datToMem           <= (others => '0');

   case CS is  
   
		when idle => 			     
            if go = '1' then 
				clrLocalMem    <= '1'; 
				XX_NSHistogram <= (others => (others => '0')); -- clear vector 
				NSYAdd         <= (others => '0'); -- clear Y address counter
				NSXAdd         <= (others => '0'); -- clear X address counter
				NS 	           <= getHistogram;
			else 
				active         <= '0';
			end if;

		when getHistogram => 
		    if pause = '0' then                                       -- normal operation			
				-- process sourceMem(255:0) data
				for i in 0 to 6 loop       
					-- if pixel in range, incr corresponding histogram(1-5) count
					if    unsignedSourceMemRGBPixel >= unsigned(XX_histLimit(i)) and  unsignedSourceMemRGBPixel <  unsigned(XX_histLimit(i+1)) then           
   			 	          XX_NSHistogram(i) <= std_logic_vector(  unsigned(CSHistogram(i)) + 1  );
					end if;
				end loop;				
				-- manage X and Y addresses and FSM state 
				NSXAdd      <= std_logic_vector(unsigned(CSXAdd) + 1);                       -- increment XAdd counter
				if unsigned(CSXAdd) = "111" then          		   					         -- = 7 => final byte slice of sourceMem(255:0)? 
					NSYAdd      <= std_logic_vector(unsigned(CSYAdd) + 1);                    -- increment YAdd counter
					if unsigned(CSYAdd) = "11111" then          		   					     -- = 31 => final sourceMem(255:0) word?  
						NS <= write_limits_and_histValues_to_ResultMem;                      -- done, write status, else loop in currnet state again (default NS <= CS)
					end if;
				end if;
			end if;

        -- write the seven range limit pairs and corresponding histogram count to resultMem locations 0 - 6 
		-- Use XAdd as loop counter. XAdd = 0 on entry to this state
		when write_limits_and_histValues_to_ResultMem =>
	        memWr     <= '1';	
            memAdd(4 downto 0) <= "00" & CSXAdd;                         
	 	    datToMem  <= (
                	  	   XX_histLimit( to_integer(unsigned(CSXAdd) + 1)) )  
					     & XX_histLimit(to_integer(unsigned(CSXAdd))) 
						 & "0000000" & CSHistogram(to_integer(unsigned(CSXAdd))
						 );
  	    	NSXAdd    <= std_logic_vector(unsigned(CSXAdd) + 1); -- increment XAdd counter
			if unsigned(CSXAdd) = "110" then                     -- loop done? 
					NS <= write_status_to_CSR0;                  -- done, write status, else loop in currnet state again (default NS <= CS)
	   	  	end if;


		when write_status_to_CSR0 => -- (23:17) = 0
		    memWr    <= '1';					
            memAdd   <= X"00"; -- CSR(0)
		    datToMem <= XX_histLimit(6) & "0000000" & CSHistogram(6) & '1' & CSR(0)(6 downto 1) & '0'; 
		    NS       <= idle;
		
		when others => 
			null;
	end case;

end process; 

-- FSM state register. Cleared on WDTimeout assertion
stateReg_i: process (clk, rst)
begin
  if rst = '1' then 		
    CS <= idle;		
  elsif clk'event and clk = '1' then 
	if WDTimeout= '1' then -- return to idle state 
		CS <= idle;		
	else
		CS <= NS;
	end if;
  end if;
end process; 

-- Histogram registers. Not cleared on WDTimeout assertion
histogramRegisters_i:  process (clk, rst) 
begin
	if rst = '1' then           		
        CSYAdd <= (others => '0');
        CSXAdd <= (others => '0');
        CSHistogram <= (others => (others => '0'));
	elsif clk'event and clk = '1' then	
		if clrLocalMem = '1' then 
			CSYAdd <= (others => '0');
            CSXAdd <= (others => '0');
			CSHistogram <= (others => (others => '0'));
		else
			CSYAdd <= NSYAdd;
            CSXAdd <= NSXAdd;
			CSHistogram <= XX_NSHistogram;
		end if;
	end if;
end process;

end RTL;