-- Description: DSP_selMemMaster_TB testbench component 
--
-- Engineer: Fearghal Morgan
-- National University of Ireland, Galway / viciLogic 
-- Date: 30/8/2021
-- Change History: Initial version

-- Reference: https://tinyurl.com/vicilogicVHDLTips   	A: VHDL IEEE library source code VHDL code
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrayPackage.all;

entity DSP_selMemMaster_TB is end DSP_selMemMaster_TB; -- testbench has no inputs or outputs

architecture Behavioral of DSP_selMemMaster_TB is
-- component declaration is in package

-- Declare internal testbench signals, typically the same as the component entity signals
signal DSP_activeIndex : std_logic_vector(5 downto 0);
signal DSP_memWr       : std_logic_vector(5 downto 0);
signal DSP_memAdd      : array6x8;
signal DSP_datToMem    : array6x32;
signal memWr           : std_logic; 
signal memAdd          : std_logic_vector(7 downto 0);
signal datToMem        : std_logic_vector(31 downto 0); 

signal   endOfSim : boolean := false; -- Default FALSE. Assigned TRUE at end of process stim
signal   testNo   : integer;          -- facilitates test numbers. Aids locating each simulation waveform test 

begin

uut: DSP_selMemMaster -- instantiate unit under test (UUT)
port map ( DSP_activeIndex => DSP_activeIndex,       		  
           DSP_memWr       => DSP_memWr, 
		   DSP_memAdd      => DSP_memAdd,
		   DSP_datToMem    => DSP_datToMem,
		   memWr           => memWr,  
		   memAdd          => memAdd,
 		   datToMem        => datToMem
         );

stim: process -- no process sensitivity list to enable automatic process execution in the simulator
begin 
  report "%N : Simulation Start."; -- generate messages as the simulation executes 
  -- initialise all input signals 

  testNo <= 0; -- include a unique test number to help browsing of the simulation waveform     
  DSP_activeIndex <= (others => '0');
  DSP_memWr       <= (others => '0');
  DSP_memAdd      <= (others => (others => '0'));
  DSP_datToMem    <= (others => (others => '0'));
      
  -- include stimulus 
  
  endOfSim <= true;   		 -- assert flag. Stops clk signal generation in process clkStim
  report "simulation done";   
  wait; 					 -- include to prevent the stim process from repeating execution, since it does not include a sensitivity list
  
end process;

end Behavioral;