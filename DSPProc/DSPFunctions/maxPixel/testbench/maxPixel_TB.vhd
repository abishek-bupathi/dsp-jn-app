-- Description: maxPixel_TB testbench 
-- Engineer: Fearghal Morgan
-- National University of Ireland, Galway / viciLogic 
-- Date: 8/2/2021
-- Change History: Initial version

-- Reference: https://tinyurl.com/vicilogicVHDLTips   	A: VHDL IEEE library source code VHDL code
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrayPackage.all;

entity maxPixel_TB is end maxPixel_TB; -- testbench has no inputs or outputs

architecture Behavioral of maxPixel_TB is
-- component declaration is in package

-- Declare internal testbench signals, typically the same as the component entity signals
-- initialise signal clk to logic '1' since the default std_logic type signal state is 'U' 
-- and process clkStim uses clk <= not clk  
signal clk            : STD_LOGIC := '1'; 
signal rst            : STD_LOGIC;
signal go             : STD_LOGIC;

signal active         : std_logic;

signal CSR            : in  array4x32;
signal sourceMem      : STD_LOGIC_VECTOR(255 downto 0); 

signal memWr          : std_logic;
signal memAdd         : std_logic_vector(  7 downto 0);		   
signal datToMem	      : STD_LOGIC_VECTOR( 31 downto 0);

constant period       : time := 20 ns;    -- 50MHz clk
signal   endOfSim     : boolean := false; -- Default FALSE. Assigned TRUE at end of process stim
signal   testNo       : integer;          -- facilitates test numbers. Aids locating each simulation waveform test 

constant sourceArray : array32x256 :=
	(0  => X"ff090807ff080706ff070605ff060504ff050403ff040302ff030201ff020100",    
	 1  => X"ff0a0908ff090807ff080706ff070605ff060504ff050403ff040302ff030201",    
	 2  => X"ff0b0a09ff0a0908ff090807ff080706ff070605ff060504ff050403ff040302",    
	 3  => X"ff0c0b0aff0b0a09ff0a0908ff090807ff080706ff070605ff060504ff050403",    
	 4  => X"ff0d0c0bff0c0b0aff0b0a09ff0a0908ff090807ff080706ff070605ff060504",    
	 5  => X"ff0e0d0cff0d0c0bff0c0b0aff0b0a09ff0a0908ff090807ff080706ff070605",    
	 6  => X"ff0f0e0dff0e0d0cff0d0c0bff0c0b0aff0b0a09ff0a0908ff090807ff080706",    
	 7  => X"ff100f0eff0f0e0dff0e0d0cff0d0c0bff0c0b0aff0b0a09ff0a0908ff090807",    
	 8  => X"ff11100fff100f0eff0f0e0dff0e0d0cff0d0c0bff0c0b0aff0b0a09ff0a0908",    
	 9  => X"ff121110ff11100fff010f0eff0f0e0dff0e0d0cff0d0c0bff0c0b0aff0b0a09",    
	10  => X"ff131211ff121110ff11100fff100d0eff0f0e0dff0e0d0cff0d0c0bff0c0b0a",    
	11  => X"0000000000000000000000000000000000000000000000000000000000000000",
	12  => X"0000000000000000000000000000000000000000000000000000000000000000",
	13  => X"0000000000000000000000000000000000000000000000000000000000000000",
	14  => X"0000000000000000000000000000000000000000000000000000000000000000",
	15  => X"0000000000000000000000000000000000000000000000000000000000000000",
	16  => X"0000000000000000000000000000000000000000000000000000000000000000",
	17  => X"0000000000000000000000000000000000000000000000000000000000000000",
	18  => X"0000000000000000000000000000000000000000000000000000000000000000",
	19  => X"0000000000000000000000000000000000000000000000000000000000000000",
	20  => X"0000000000000000000000000000000000000000000000000000000000000000",
	21  => X"0000000000000000000000000000000000000000000000000000000000000000",
	22  => X"0000000000000000000000000000000000000000000000000000000000000000",
	23  => X"0000000000000000000000000000000000000000000000000000000000000000",
	24  => X"0000000000000000000000000000000000000000000000000000000000000000",
	25  => X"0000000000000000000000000000000000000000000000000000000000000000",
	26  => X"0000000000000000000000000000000000000000000000000000000000000000",
	27  => X"0000000000000000000000000000000000000000000000000000000000000000",
	28  => X"0000000000000000000000000000000000000000000000000000000000000000",
	29  => X"0000000000000000000000000000000000000000000000000000000000000000",
	30  => X"0000000000000000000000000000000000000000000000000000000000000000",
	31  => X"0000000000000000000000000000000000000000000000000000000000000000",
	others => X"0000000000000000000000000000000000000000000000000000000000000000"
   );

begin

uut: maxPixel
port map ( clk 		      => clk, 		 
           rst 		      => rst, 		 
           go             => go,
		   active         => active,

		   CSR            => CSR,       
           sourceMem      => sourceMem, 
						 
		   memWr          => memWr,
		   memAdd         => memAdd,    
		   datToMem	      => datToMem	 
           );

-- clk stimulus continuing until all simulation stimulus have been applied (endOfSim TRUE)
clkStim : process (clk)
begin
  if endOfSim = false then
     clk <= not clk after period/2;
  end if;
end process;

sourceMem  <= sourceArray(  to_integer(unsigned(memAdd))  ); 

stim: process -- no process sensitivity list to enable automatic process execution in the simulator
begin 
  report "%N : Simulation Start."; -- generate messages as the simulation executes 
  -- initialise all input signals   
  
  go <= '0'; 
  CSR <= (others => (others => '0'));
  CSR(0)(31 downto 6) <= (others => '0');
  CSR(0)( 5 downto 4) <= "10";             -- red pixel
  CSR(0)( 3 downto 1) <= "000";            -- maxPixel 
  CSR(0)( 0)          <= '1';              -- activate DSP

  testNo <= 0; -- include a unique test number to help browsing of the simulation waveform     
               -- apply rst signal pattern, to deassert 0.2*period after the active clk edge
  rst <= '1';
  wait for 1.2 * period;
  rst <= '0';
  wait for period;
  

  testNo <= 1; 
  go     <= '1'; 
  wait for period;  
  go     <= '0'; 
  wait for period;  

  wait for 300*period;  


  endOfSim <= true;   -- assert flag. Stops clk signal generation in process clkStim
  report "simulation done";   
  wait;               -- include to prevent the stim process from repeating execution, since it does not include a sensitivity list
  
end process;

end Behavioral;	 