-- Description: resultMem0_32x32Reg_TB testbench 
-- Engineer: Fearghal Morgan
-- National University of Ireland, Galway / viciLogic 
-- Date: 30/10/2019
-- Change History: Initial version

-- Reference: https://tinyurl.com/vicilogicVHDLTips   	A: VHDL IEEE library source code VHDL code
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrayPackage.all;

entity resultMem0_32x32Reg_TB is end resultMem0_32x32Reg_TB; -- testbench has no inputs or outputs

architecture Behavioral of resultMem0_32x32Reg_TB is
-- component declaration is in package

-- Declare internal testbench signals, typically the same as the component entity signals
-- initialise signal clk to logic '1' since the default std_logic type signal state is 'U' 
-- and process clkStim uses clk <= not clk  
signal clk       : STD_LOGIC := '1'; 
signal rst       : STD_LOGIC;

signal ld0       : std_logic;

signal wr        : std_logic;
signal add       : std_logic_vector( 4 downto 0);					 
signal dIn       : std_logic_vector(31 downto 0);
signal dOut      : std_logic_vector(31 downto 0);

constant period   : time := 20 ns;    -- 50MHz clk
signal   endOfSim : boolean := false; -- Default FALSE. Assigned TRUE at end of process stim
signal   testNo   : integer;          -- facilitates test numbers. Aids locating each simulation waveform test 

begin

uut: resultMem0_32x32Reg -- instantiate unit under test (UUT)
port map ( clk       => clk,       		  
		   rst	     => rst,
		   ld0	     => ld0,
		   
		   wr	     => wr,
		   add       => add,  
		   dIn       => dIn,
		   
           dOut    => dOut
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

  ld0     <= '0';
  wr      <= '0';
  add     <= (others => '0'); 
  dIn     <= (others => '0'); 
  
  testNo <= 0; -- include a unique test number to help browsing of the simulation waveform     
  -- apply rst signal pattern, to deassert 0.2*period after the active clk edge
  rst <= '1';
  wait for 1.2 * period;
  rst <= '0';
  wait for period;  

  testNo  <= 1;  -- write to all memory locations 
  wr      <= '1';
  for i in 0 to 31 loop
    add <= std_logic_vector( to_unsigned(i,5) );      -- write each row 
    dIn <= std_logic_vector( to_unsigned((i+1),32) ); -- with data = row index + 1
    wait for period;  
  end loop;
  
  testNo  <= 2; -- read memory 
  wr      <= '0';
  dIn     <= (others => '0'); 
  for i in 0 to 31 loop
    add   <= std_logic_vector( to_unsigned(i,5) );
    wait for period;  
  end loop;

  testNo  <= 3; -- ld0 memory 
  ld0     <= '1';
  wait for period;  

  endOfSim <= true;   		 -- assert flag. Stops clk signal generation in process clkStim
  report "simulation done";   
  wait; 					 -- include to prevent the stim process from repeating execution, since it does not include a sensitivity list
  
end process;

end Behavioral;