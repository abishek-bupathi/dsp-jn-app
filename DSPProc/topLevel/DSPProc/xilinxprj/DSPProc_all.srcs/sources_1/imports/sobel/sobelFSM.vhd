-- Sobel component 

-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 26/1/2021

-- Description: Sobel component 
-- Process sobel filering over 32 clk periods per 256-bit source mem row
--     Then write to resultMem 
-- Repeat for all 32 source mem rows
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
--  clk			 system clock strobe, rising edge active
--  rst	         assertion (h) asynchronously clears all registers
--  continue  			assertion clears pause signal 

--	WDTimeout 	 Assertion return FSM to idle_or_loadCS0 state 
--  go			 Assertion (H) activates function 
--  active 	     Asserted while function executes 

--  CSR	         4 x 32-bit Control & Status registers. Only CSR(0) is used 
--  sourceMem    256-bit source memory 

--  sobelBit           asserted by Sobel Kernel if addGxGy > '0' & threshVal & "000". threshVal = CSR(0)(15:8)
--  rot24BitRightCE    assert to rotate 3 x 272-bit buffer  one byte to right
--  ld0                assert to clear local registers and 3 x 272-bit buffer
--  sel_0_or_sourceMem assert to load 0 into buffer CS(0)(271:0).  deassert to load 0x00 & sourceMem & 0x00 into CS(271:0)
--  ldSobelBuf         assert to load sobel buffer (FIFO-type operation)

--  memWr        assert to synchronously write to memory  
--  memAdd       memory address 
--  datToMem	 32-bit data to memory 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity sobelFSM is
    Port ( clk 		 : in STD_LOGIC;   
           rst 		 : in STD_LOGIC;
   		   continue  : in  std_logic;
		   
		   WDTimeout : in std_logic;
           go        : in  std_logic; 		   
		   active    : out std_logic;

		   CSR       : in  array4x32;
           sourceMem : in  std_logic_vector(255 downto 0); 

		   sobelBit           : in  std_logic;  
		   rot24BitRightCE    : out  std_logic;
		   ld0                : out std_logic; 
		   sel_0_or_sourceMem : out std_logic;
		   ldSobelBuf         : out std_logic; 

		   memWr     : out std_logic;
		   memAdd    : out std_logic_vector(  7 downto 0);					 
		   datToMem	 : out std_logic_vector( 31 downto 0)
           );
end sobelFSM;

architecture RTL of sobelFSM is

-- Internal signal declarations
-- declare enumerated state type
type stateType is (idle_or_loadCS0With0s, loadCS1WithSourceMem0, loadCS2WithSourceMem1, sobelLoop, rotate2ndLast, rotateLast, wrSobelVecToResultMem, ldCS0With0, parallelLoadCS, write_status_to_CSR0); -- to be completed
signal CS, NS                 : stateType; -- declare state signals 

signal NSSobelVec, CSSobelVec : STD_LOGIC_VECTOR(31 downto 0); -- result register 
signal NSYAdd, CSYAdd 	      : std_logic_vector(4 downto 0);  -- Y address, 0-31 (next state and current state)
signal NSXAdd, CSXAdd  		  : std_logic_vector(4 downto 0);  -- X address, 0-31 (next state and current state)

begin

-- Next state and o/p decode process   
NSAndOPDec_i: process (CS, go, sobelBit, CSSobelVec, CSXAdd, CSYAdd, CSR(0), continue)
begin
   NS 	 		  	  <= CS; 	 -- default signal assignments
   active 		  	  <= '1';    -- default asserted. Deasserted only in idle_or_loadCS0 state, when go is deasseerted
   NSSobelVec         <= CSSobelVec;
   NSXAdd             <= CSXAdd;
   NSYAdd             <= CSYAdd;
   rot24BitRightCE    <= '0';
   ld0                <= '0'; 
   sel_0_or_sourceMem <= '0';
   ldSobelBuf         <= '0';
   memWr              <= '0';
   memAdd(7 downto 5) <= "010";  -- default is resultMem address
   memAdd(4 downto 0) <= CSYAdd; -- default memory address (4:0) = YAdd(4:0)
   datToMem           <= (others => '0'); 

   case CS is
   
		when idle_or_loadCS0With0s => 	          
			if go = '1' then -- only clear registers when go is asserted (keep previous values)
				ld0                <= '1'; 
				sel_0_or_sourceMem <= '1';
				ldSobelBuf		   <= '1';
				NSSobelVec		   <= (others => '0'); 
				NSXAdd			   <= (others => '0'); 
				NSYAdd			   <= (others => '0');	
				NS				   <= loadCS1WithSourceMem0;
			else                      
				active             <= '0';
			end if;			  
		
		when loadCS1WithSourceMem0 =>
			ldSobelBuf <= '1';
			NSYAdd 	   <= "00001";
			NS	 	   <= loadCS2WithSourceMem1;

		when loadCS2WithSourceMem1 =>
			ldSobelBuf <= '1';
			NSYAdd	   <= (others => '0');	
			NS		   <= sobelLoop;

		when sobelLoop =>
			if continue = '0' 
			   and unsigned( CSR(0)(28 downto 24) ) > 0 
			   and unsigned( CSR(0)(20 downto 16) ) > 0  
               and  CSYAdd = CSR(0)(28 downto 24) 
			   and  CSXAdd = CSR(0)(20 downto 16) then
				
				NS	<= sobelLoop;
			else	
				rot24BitRightCE <= '1';
				NSXAdd			<= std_logic_vector(unsigned(CSXAdd) + 1);
				NSSobelVec(to_integer(unsigned(CSXAdd))) <= sobelBit;
				
				if unsigned(CSXAdd) = X"1f" then                      
					NS      <= rotate2ndLast;	
				end if;
			end if;
		
		when rotate2ndLast =>
			rot24BitRightCE <= '1';
			NS				<= rotateLast;

		when rotateLast =>
			rot24BitRightCE <= '1';
			NS				<= wrSobelVecToResultMem;
			

		when wrSobelVecToResultMem =>
			memWr	 <= '1';
			datToMem <= CSSobelVec;
			
			if unsigned(CSYAdd) = X"1e" then
				NS <= ldCS0With0;
			elsif unsigned(CSYAdd) = X"1f" then
				NS <= write_status_to_CSR0;
			else 
				NSYAdd <= std_logic_vector(unsigned(CSYAdd) + 2);
				NS <= parallelLoadCS;
			end if;
			

		when parallelLoadCS =>
			ldSobelBuf		   <= '1';			
			NSYAdd			   <= std_logic_vector(unsigned(CSYAdd) - 1);
			NS				   <= sobelLoop;
			
		when ldCS0With0 =>
			sel_0_or_sourceMem <= '1';
			ldSobelBuf		   <= '1';
			NSYAdd			   <= std_logic_vector(unsigned(CSYAdd) + 1);
			NS				   <= sobelLoop;
			
		when write_status_to_CSR0 =>
			memWr       <= '1';
            memAdd      <= X"00";     -- address CSR(0) 
		    datToMem    <= CSR(0)(31 downto 8) & '1' & CSR(0)(6 downto 1) & '0'; 
			NSYAdd 		<= (others => '0');
		    NS          <= idle_or_loadCS0With0s;
		
		when others => 
			null; 	  -- do nothing. Default assignments apply
   end case;
end process; 

-- FSM state register. Cleared on WDTimeout assertion
stateReg_i: process (clk, rst)
begin
  if rst = '1' then 		
    CS <= idle_or_loadCS0With0s;		
  elsif clk'event and clk = '1' then 
	if WDTimeout= '1' then -- return to idle state 
		CS <= idle_or_loadCS0With0s;		
	else
		CS <= NS;
	end if;
  end if;
end process;

-- Sobel registers. Not cleared on WDTimeout assertion
functionRegs_i:  process (clk, rst) 
begin
	if rst = '1' then 
        CSYAdd 			<= (others => '0');
        CSXAdd 			<= (others => '0');
        CSSobelVec      <= (others => '0');
	elsif clk'event and clk = '1' then	
		CSYAdd 		<= NSYAdd;
        CSXAdd 		<= NSXAdd;
		CSSobelVec 	<= NSSobelVec;
	end if;
end process;

end RTL;