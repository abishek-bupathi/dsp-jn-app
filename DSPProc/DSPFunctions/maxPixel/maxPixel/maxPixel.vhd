-- Description: maxPixel component
-- Describes most functionality in FSM, requiring less internal signals, or components

-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 26/1/2021
-- 
-- For 32 sourceMem 256-bit words
--   data format: eight x 32-bit colour sourceMemRGBPixels, X, Red, Green, Blue. X is unused.
-- select sourceMemRGBPixel byte defined by RGBIndex (CSR(5:4)), i.e, 10:Red, 01:Green, 00:Blue
-- CSMaxRGBPixVal (0 initially) = sourceMemRGBPixel if sourceMemRGBPixel > current CSMaxRGBPixVal
--
-- When all 32 x sourceMem 256-bit values are processed
--   wr_1_To_ResultMem_At_MaxXYPt  
--           assert a single bit in resultMem memAdd(7:4)=010 (resultMem

-- wr_CSMaxRGBPixValAndXYAndStatus_To_CSR0. 
--    A single CSR will hold all of this data. 
--    memAdd(7:0)=X"00" addresses CSR(0)
--    write CSMaxRGBPixVal(7:0) to CSR(1)(31:24) -- FM TBD
--    write CSMaxRGBPixY(4:0)    to CSR(1)(20:16)
--    write CSMaxRGBPixX(4:0)    to CSR(1)(12:8)
--    Assert CSR(0)(7) to indicate task complete
--    Deassert CSR(0)(0) to return control to host 
--    Other CSR(0) bits unchanged
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
--                      reading sourceMem(255:0): use CSYAdd(4:0) to generate memAdd(4:0). 
-- 					      sourceMem read only uses address bits (4:0) 
-- 					    writing resultMem(31:0) : memAdd(7:5)=010, memAdd(4:0)=CSYAdd(4:0) 
-- 					    writing CSR(0): memAdd(7:0)=0
--  datToMem (Out)      32-bit data to addressed result or CSR memory 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity maxPixel is
    Port ( clk 		 : in  std_logic;   
           rst 		 : in  std_logic; 
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
end maxPixel;

architecture RTL of maxPixel is
type stateType is (idle, upd_maxPixValAndXY_if_RGBPix_ge_curMaxRGBPixVal, wr_1_To_ResultMem_At_MaxXYPt, 
                   wr_CSMaxRGBPixValAndXYAndStatus_To_CSR0); -- declare enumerated state type

signal CS, NS                         : stateType;     		   	       -- FSM state signals 

signal NSYAdd		      	  		  : std_logic_vector(4 downto 0);  -- Y address, 0-31 (next state)
signal CSYAdd           	  		  : std_logic_vector(4 downto 0);  -- Y address, 0-31 (current state). YAdd is identical (used in vicilogic)
signal NSXAdd  	    		  		  : std_logic_vector(2 downto 0);  -- X address, 0-7 (next state)
signal CSXAdd       	      		  : std_logic_vector(2 downto 0);  -- X address, 0-7 (current state). XAdd is identical (used in vicilogic)

signal NSMaxRGBPixVal, CSMaxRGBPixVal : STD_LOGIC_VECTOR(7 downto 0);  -- max sourceMemRGBPixel value
signal NSMaxRGBPixY, CSMaxRGBPixY     : STD_LOGIC_VECTOR(4 downto 0);  -- max sourceMemRGBPixel Y address 
signal NSMaxRGBPixX, CSMaxRGBPixX     : STD_LOGIC_VECTOR(2 downto 0);  -- max sourceMemRGBPixel X address 					   

signal RGBIndex          : STD_LOGIC_VECTOR(1 downto 0);  -- from CSR(0)(5:4), i.e, CSR(0)(5:4), defines sourceMemRGBPixel byte: 11:Unused, 10:Red, 01:Green or 00:Blue in 8 x 32-bit words in each 256-bit data value
signal RGBIndexInteger   : integer range 0 to 3;
signal sourceMemWord     : STD_LOGIC_VECTOR(31 downto 0); -- 32-bit slice of sourceMem(255:0) 
signal sourceMemRGBPixel : STD_LOGIC_VECTOR(7 downto 0);  -- currently selected R, G or B sourceMemRGBPixel data 
				
signal pause    	     : std_logic; 
signal pauseY 		     : std_logic_vector (4 downto 0);
signal pauseX 		     : std_logic_vector (4 downto 0);

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

-- generate signals used in the FSM
asgnRGBIndex_i:          RGBIndex          <= CSR(0)(5 downto 4);
asgnRGBIndexInt_i:       RGBIndexInteger   <= to_integer(unsigned(RGBIndex)); -- RGBIndex integer format, for use in generating sourceMemRGBPixel
asgnSourceMemWord_i: 	 sourceMemWord     <= sourceMem( ( (to_integer(unsigned(CSXAdd))*32)+31 ) downto (to_integer(unsigned(CSXAdd))*32) ); -- 32-bit slice of sourceMem(255:0) 
asgnSourceMemRGBPixel_i: sourceMemRGBPixel <= sourceMemWord( (8*RGBIndexInteger + 7) downto (8*RGBIndexInteger) ); -- select byte from XRGB word 

-- Next state and o/p decode process
NSAndOPDec_i: process (CS, go, pause, sourceMemRGBPixel, RGBIndexInteger, CSMaxRGBPixVal, CSMaxRGBPixY, CSMaxRGBPixX, CSYAdd, CSXAdd, CSR(0))
begin
   -- include NS* <= CS* in default section. Removes the need to these NS assignments in FSM state sections (where they apply)
   NS 	 		      <= CS; 	         -- default signal assignments
   NSYAdd             <= CSYAdd;
   NSXAdd             <= CSXAdd;
   NSMaxRGBPixVal     <= CSMaxRGBPixVal; 
   NSMaxRGBPixY       <= CSMaxRGBPixY;   
   NSMaxRGBPixX       <= CSMaxRGBPixX;   
   active 		      <= '1';            -- default asserted. Deasserted only in idle state, when go is deasseerted
   memWr              <= '0';
   memAdd(7 downto 5) <= "010";          -- default is resultMem address
   memAdd(4 downto 0) <= CSYAdd;         -- default memory address (4:0) = CSYAdd(4:0)
   datToMem           <= (others => '0');

   case CS is 

		when idle => 			     
            if go = '1' then 
				NSMaxRGBPixVal<= (others => '0'); -- clear. stateReg registers 0 values (at start), on subsequent clk edge
				NSMaxRGBPixY  <= (others => '0');   
				NSMaxRGBPixX  <= (others => '0');
				NSYAdd        <= (others => '0');  
				NSXAdd        <= (others => '0');   
				NS 	          <= upd_maxPixValAndXY_if_RGBPix_ge_curMaxRGBPixVal;
			else 
				active        <= '0';
			end if;
   
		when upd_maxPixValAndXY_if_RGBPix_ge_curMaxRGBPixVal => 
		    if pause = '0' then                                       -- normal operation
				if unsigned(sourceMemRGBPixel) > unsigned(CSMaxRGBPixVal) then -- if pixel value > current max sourceMemRGBPixel
					NSMaxRGBPixVal <= sourceMemRGBPixel;                       -- update values, to be registered on next active clk edge
					NSMaxRGBPixY   <= CSYAdd;                     
					NSMaxRGBPixX   <= CSXAdd;                     
				end if;
				NSXAdd             <= std_logic_vector(unsigned(CSXAdd) + 1);  -- always increment CSXAdd counter, on next active clk edge
				if unsigned(CSXAdd) = "111" then          		               -- if CSXAdd counter = 7 => final RGB byte of sourceMem(255:0)
					NSYAdd         <= std_logic_vector(unsigned(CSYAdd) + 1);  -- increment CSYAdd counter, on next active clk edge
					if unsigned(CSYAdd) = "11111" then                         -- exit loop if at final sourceMem(255:0) value 
						NS 		       <= wr_1_To_ResultMem_At_MaxXYPt;         
					end if;
				end if;
			end if;

		when wr_1_To_ResultMem_At_MaxXYPt =>       -- to resultMem
		    memWr              <= '1';					
            memAdd(4 downto 0) <= CSMaxRGBPixY;    -- write to CSYAdd of max pixel
			datToMem           <= (others => '0'); -- assign data = 0, then assert single bit
		    datToMem( (4*to_integer(unsigned(CSMaxRGBPixX))) + RGBIndexInteger ) <= '1';     -- CSMaxRGBPix=0-7. Generate integer index = 4*CSMaxRGBPixX (integer type) + RGBIndexInteger
			-- or 
		    -- datToMem(to_integer ( unsigned(CSMaxRGBPixX) & unsigned(RGBIndex) )) <= '1'; -- shift CSMaxRGBPixX left 2 bits (multiply by 4) and concatentate with 2-bit RGB index 
			NS                 <= wr_CSMaxRGBPixValAndXYAndStatus_To_CSR0;

		when wr_CSMaxRGBPixValAndXYAndStatus_To_CSR0 =>
		    memWr    <= '1';					
            memAdd   <= X"00"; -- CSR(0)
		    datToMem <= CSMaxRGBPixVal 
			            & "000" & CSMaxRGBPixY  
						-- CSMaxRGBPix=0-7, *4 to give 0,4,8 .... 28, and add RGBIndex
				        & "000" & std_logic_vector(   to_unsigned(( 4*to_integer(unsigned(CSMaxRGBPixX)) + RGBIndexInteger ),5)   ) 
			            & '1' & CSR(0)(6 downto 1) & '0'; 
            -- could define each byte separately
		    --datToMem(31 downto 24) <= CSMaxRGBPixVal;
		    --datToMem(23 downto 16) <= "000" & CSMaxRGBPixY;
		    --datToMem(15 downto  8) <= "000" & std_logic_vector(   to_unsigned(( 4*to_integer(unsigned(CSMaxRGBPixX)) + RGBIndexInteger ),5)   ); 
		    --datToMem( 7 downto  0) <=  '1' & CSR(0)(6 downto 1) & '0';
		    NS       <= idle;
		
		when others => 
			null;
	end case;

end process; 

-- state registers
maxsourceMemRGBPixelRegisters_i:  process (clk, rst) -- generate CS()
begin
	if rst = '1' then           		
        CS <= idle;		
        CSMaxRGBPixVal <= (others => '0');
        CSMaxRGBPixY   <= (others => '0');
        CSMaxRGBPixX   <= (others => '0');
		CSYAdd         <= (others => '0');  
		CSXAdd         <= (others => '0');   
	elsif clk'event and clk = '1' then	
		CS <= NS;
		CSMaxRGBPixVal <= NSMaxRGBPixVal;
		CSMaxRGBPixY   <= NSMaxRGBPixY;
		CSMaxRGBPixX   <= NSMaxRGBPixX;
		CSYAdd         <= NSYAdd;
		CSXAdd         <= NSXAdd;
	end if;
end process;

end RTL;