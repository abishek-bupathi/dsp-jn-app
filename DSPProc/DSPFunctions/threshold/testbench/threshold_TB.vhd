-- Description: threshold_TB testbench 
-- Engineer: Fearghal Morgan
-- National University of Ireland, Galway / viciLogic 
-- Date: 30/10/2019
-- Change History: Initial version

-- Reference: https://tinyurl.com/vicilogicVHDLTips   	A: VHDL IEEE library source code VHDL code
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrayPackage.all;

entity threshold_TB is end threshold_TB; -- testbench has no inputs or outputs

architecture Behavioral of threshold_TB is
-- component declaration is in package

-- Declare internal testbench signals, typically the same as the component entity signals
-- initialise signal clk to logic '1' since the default std_logic type signal state is 'U' 
-- and process clkStim uses clk <= not clk  
signal clk       :  STD_LOGIC := '1'; 
signal rst       :  STD_LOGIC;
signal WDTimeout :  STD_LOGIC;

signal go        :  std_logic;                		 
signal active    :  std_logic;
				    
signal CSR       :  array4x32;
signal sourceMem :  std_logic_vector(255 downto 0); 
				    
signal memWr     :  std_logic;
signal memAdd    :  std_logic_vector(  7 downto 0);					 
signal datToMem	 :  std_logic_vector( 31 downto 0);

constant period   : time := 20 ns;    -- 50MHz clk
signal   endOfSim : boolean := false; -- Default FALSE. Assigned TRUE at end of process stim
signal   testNo   : integer;          -- facilitates test numbers. Aids locating each simulation waveform test 

begin
		 
uut: threshold -- instantiate unit under test (UUT)
 Port map ( clk	          => clk,  
            rst           => rst,  
			WDTimeout     => WDTimeout, 
            go            => go,
	  	    active        => active,

		    CSR           => CSR,
            sourceMem     => sourceMem,
			
			memWr         => memWr,    
		    memAdd        => memAdd,   
		    datToMem	  => datToMem
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

  WDTimeout <= '0';
  go        <= '0';
  CSR       <= (others => (others => '0')); 
  sourceMem <= (others => '0'); 
  
  testNo <= 0; -- include a unique test number to help browsing of the simulation waveform     
  -- apply rst signal pattern, to deassert 0.2*period after the active clk edge
  rst <= '1';
  wait for 1.2 * period;
  rst <= '0';
  wait for period;  

  testNo              <= 1; 
  
  -- Including CSR(0)(3:0) settings, though not required in this TB. 
  -- Handled outside threshold component to generate go signal pulse
  CSR(0)( 3 downto 1) <= "010"; -- threshold command 
  CSR(0)(0)           <= '1';   -- activate threshold function  
  go                  <= '1';
  CSR(0)(15 downto 8) <= X"04"; -- threshVal(7:0)  
  -- use the same sourceMem(255:0) vector for each row  
  sourceMem <= X"1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100"; 
  wait for period;  
  go        <= '0';  
  wait for 1200*period;  


   
  -- repeat above, though assert WDTimeour after interval
  testNo              <= 2; 
  go                  <= '1';
  wait for period;  
  go        <= '0';  
  wait for 6*period;  
  WDTimeout <= '1'; -- assert watchdog timeout
  wait for period;  
  WDTimeout <= '0';
  wait for 10*period;  


  endOfSim <= true;   		 -- assert flag. Stops clk signal generation in process clkStim
  report "simulation done";   
  wait; 					 -- include to prevent the stim process from repeating execution, since it does not include a sensitivity list
  
end process;

end Behavioral;