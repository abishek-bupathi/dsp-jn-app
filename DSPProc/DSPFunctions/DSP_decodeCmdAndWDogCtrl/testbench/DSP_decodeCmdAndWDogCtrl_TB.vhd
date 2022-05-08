-- Description: DSP_decodeCmdAndWDogCtrl_TB testbench component 
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

entity DSP_decodeCmdAndWDogCtrl_TB is end DSP_decodeCmdAndWDogCtrl_TB; -- testbench has no inputs or outputs

architecture Behavioral of DSP_decodeCmdAndWDogCtrl_TB is
-- component declaration is in package

-- Declare internal testbench signals, typically the same as the component entity signals
-- initialise signal clk to logic '1' since the default std_logic type signal state is 'U' 
-- and process clkStim uses clk <= not clk 

signal clk             : STD_LOGIC := '1'; 
signal rst             : STD_LOGIC;
signal CSR             : array4x32;
signal DSP_activeIndex : std_logic_vector(5 downto 0);
signal DSP_goIndex     : std_logic_vector(5 downto 0);
signal WDTimeout       : std_logic;

constant period   : time := 20 ns;    -- 50MHz clk
signal   endOfSim : boolean := false; -- Default FALSE. Assigned TRUE at end of process stim
signal   testNo   : integer;          -- facilitates test numbers. Aids locating each simulation waveform test 

begin

uut: DSP_decodeCmdAndWDogCtrl -- instantiate unit under test (UUT)
port map ( clk             => clk,       		  
           rst             => rst, 
		   CSR             => CSR,
		   DSP_activeIndex => DSP_activeIndex,
		   DSP_goIndex     => DSP_goIndex,  
		   WDTimeout       => WDTimeout
         );

-- clk stimulus continuing until all simulation stimulus have been applied (endOfSim TRUE)
clkStim : process (clk)
begin
  if endOfSim = false then
     clk <= not clk after period/2;
  end if;
end process;

stim: process -- no process sensitivity list to enable automatic process execution in the simulator
begin 
  report "%N : Simulation Start."; -- generate messages as the simulation executes 
  -- initialise all input signals 

  CSR             <= (others => (others => '0')); -- defaults
  DSP_activeIndex <= (others => '0');
  
  testNo <= 0; -- include a unique test number to help browsing of the simulation waveform     
  -- apply rst signal pattern, to deassert 0.2*period after the active clk edge
  rst <= '1';
  wait for 1.2 * period;
  rst <= '0';
  wait for period;  

  testNo  <= 1;  
  DSP_activeIndex <= "000001";			  -- active DSP function 
  CSR(0)(0) <= '1';                       -- activate DSP function; DSPMaster asserted 
  CSR(3)(29)<= '1';                       -- enable watchdog counter 
  CSR(3)(28 downto 0)<= '0' & X"0000005"; -- watchdog timeout interval = 5 clock periods
  wait for 10*period;                     -- watchdog timeout should occur

  testNo  <= 2;  
  CSR(3)(30)<= '1';                       -- synchronously load 0 in watchdog counter (clear watchdog counter) 
  CSR(3)(29)<= '1';                       -- enable watchdog counter 
  wait for 3*period;  
  CSR(3)(30)<= '0';                       -- watchdog timer count should restart  
  wait for 10*period;                     -- watchdog timeout should occur

  testNo  <= 3;  
  CSR(3)(30)<= '1';                       -- synchronously load 0 in watchdog counter (clear watchdog counter) 
  CSR(3)(29)<= '1';                       -- enable watchdog counter 
  wait for 3*period;  
  CSR(3)(30)<= '0';                       -- watchdog timer count should restart  
  wait for 3*period;  
  DSP_activeIndex <= "000000";			  -- all DSP functions inactive
  wait for 10*period;  


  testNo  <= 4; 
  DSP_activeIndex <= "100000";			  -- all DSP functions inactive
  CSR(3)(30)<= '1';                       -- synchronously load 0 in watchdog counter (clear watchdog counter) 
  CSR(3)(29)<= '1';                       -- enable watchdog counter 
  wait for 3*period;    
  CSR(3)(29)<= '0';                       -- disable watchdog counter 
  wait for 5*period;  
  
  CSR(3)(30)<= '0';                       -- deassert load  
  
  endOfSim <= true;   		 -- assert flag. Stops clk signal generation in process clkStim
  report "simulation done";   
  wait; 					 -- include to prevent the stim process from repeating execution, since it does not include a sensitivity list
  
end process;

end Behavioral;