-- Component: WDogTimer
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 26/1/2021
  

-- Descriptiopn
-- Generates WDTimeout timeout signal if watchdog timer enabled and DSP function does not 
-- return control to the host, allowing the host to reload the watchdog timer beofre activating the next DSP function.
-- Used to ensure that DSP function does not lock up, and provide control back to the host in the event of a watchdog timeout. 

-- CB32CLE is the watchdog timer 32-bit up counter with counter load 0 functionality

-- Signal dictionary  (to be reviewed) 
--  clk              System clock strobe, rising edge active
--  rst	             Synchronous reset signal. Assertion clears all registers, count=0
--  DSP_activeIndex  only activate watchdog timer when the DSP function is active 
--  CSR(3)           CSR(3)(31) assert (status) when watchdog timeout occurs. 
--                   Should be subsequently cleared by host before next DSP function activation
--                   CSR(3)(30) assert to synchronously load 0 in watchdog counter (clear watchdog counter). 
--                   CSR(3)(29) is watchdog timer enable 
--                   CSR(3)(28:0) WDTimeout count value
-- 					            29-bit watchdog timer counter, @20ns clk period = >10 seconds (10.73741974 seconds)
-- 								CSR3(28:0) initialises to 0x1fffffff (on rst assertion)
--  WDTimeout 	     Asserted when watchdog timeout occurs, 
-- 					 When watchdog timer counter = CSR(3)(28:0), if watchdog timer is enabled
--                   asserting WDTimeout to DSPProc components
--                   Assertion of WDTimeout also stops the timeout counter, and intWDTimeout remains asserted 
--                   Remains asserted until CSR(3)(30) is asserted to clear watchdog timer = 0, 
-- 					 or CSR(3)(29) is cleared (disable watchdog timer)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity WDogTimer is 
    Port (  clk  	        : in STD_LOGIC;
            rst             : in STD_LOGIC;
			CSR             : in array4x32; 
			DSP_activeIndex : in std_logic_vector(5 downto 0);
			WDTimeout       : out std_logic -- used to assert CSR(3)(30) on timeout occurrence
			);
end WDogTimer;

architecture RTL of WDogTimer is
signal CSR_WDTmrLd0       : std_logic; 
signal CSR_WDTmrCE        : std_logic; 
signal CB32CLE_CE         : std_logic; 
signal taskTime           : std_logic_vector(31 downto 0);

signal activeDSPFunct     : std_logic;
signal DSPFunctStartPulse : std_logic;
signal clearWDTmr         : std_logic;
signal intWDTimeout       : std_logic;

begin

asgnWDTmrLd0_i:   CSR_WDTmrLd0   <= CSR(3)(30); -- clear timer 
asgnWDTmrCE_i:    CSR_WDTmrCE    <= CSR(3)(29); -- timer enable
activeDSPFunct_i: activeDSPFunct <= '1' when unsigned(DSP_activeIndex) > 0 else '0'; 
		  
-- assert DSPFunctStartPulse for one clk period when activeDSPFunct is asserted (new task starts)
genDSPFunctStartPulse_i: singleShot 
Port map (clk   => clk,
          rst   => rst,
          sw    => activeDSPFunct,	
          aShot	=> DSPFunctStartPulse
	     ); 

--  when CSR(0)(30) is asserted or when new DSP task starts
clearWDTmr_i: clearWDTmr <= '1' when CSR_WDTmrLd0 = '1' or DSPFunctStartPulse = '1' else '0'; 

CB32CLE_CE_i: process (CSR_WDTmrCE, activeDSPFunct, intWDTimeout)
begin
	CB32CLE_CE <= '0'; -- default assignment
	-- enable timer when 1. CSR enable bit asserted, 2. DSP function is active 3. timeout has not occurred 
	-- This stops counter when watchdog timeout occurs
	if CSR_WDTmrCE = '1' and activeDSPFunct = '1' and intWDTimeout = '0' then 
		CB32CLE_CE <= '1';  
	end if;	
end process;

timer_i: CB32CLE 
Port map(  clk 		 => clk, 		
           rst 		 => rst, 		
           loadDat	 => X"00000000", 
           load		 => clearWDTmr,		
           ce 		 => CB32CLE_CE,     
           count	 => taskTime, 
           TC        => open,     
           ceo       => open    
           );
		   		   
intWDTimeout_i:     intWDTimeout <= '1' when CSR(3)(29)='1' and ( unsigned(taskTime(28 downto 0)) = unsigned(CSR(3)(28 downto 0)) ) else '0'; 
asgnIntWDTimeout_i: WDTimeout    <= intWDTimeout;
		   
end RTL;