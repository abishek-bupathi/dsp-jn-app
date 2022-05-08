-- Description: CSR_4x32Reg_TB testbench 
-- Engineer: Fearghal Morgan
-- National University of Ireland, Galway / viciLogic 
-- Date: 30/10/2019
-- Change History: Initial version

-- Reference: https://tinyurl.com/vicilogicVHDLTips   	A: VHDL IEEE library source code VHDL code
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrayPackage.all;

entity CSR_4x32Reg_TB is end CSR_4x32Reg_TB; -- testbench has no inputs or outputs

architecture Behavioral of CSR_4x32Reg_TB is
-- component declaration is in package

-- Declare internal testbench signals, typically the same as the component entity signals
-- initialise signal clk to logic '1' since the default std_logic type signal state is 'U' 
-- and process clkStim uses clk <= not clk  
signal clk       : STD_LOGIC := '1'; 
signal rst       : STD_LOGIC;

signal wr        : std_logic;
signal add       : std_logic_vector( 1 downto 0);					 
signal dIn       : std_logic_vector(31 downto 0);
signal CSR       : array4x32;
signal dOut      : std_logic_vector(31 downto 0);

constant period   : time := 20 ns;    -- 50MHz clk
signal   endOfSim : boolean := false; -- Default FALSE. Assigned TRUE at end of process stim
signal   testNo   : integer;          -- facilitates test numbers. Aids locating each simulation waveform test 

begin

uut: CSR_4x32Reg -- instantiate unit under test (UUT)
port map ( clk       => clk,       		  
           rst       => rst, 

		   wr	     => wr,
		   add       => add,  
		   dIn       => dIn,
		   
		   CSR       => CSR, 
           dOut      => dOut
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
  
  wr        <= '0';  -- defaults
  add       <= (others => '0'); 
  dIn       <= (others => '0');
  
  testNo <= 0; -- include a unique test number to help browsing of the simulation waveform     
  -- apply rst signal pattern, to deassert 0.2*period after the active clk edge
  rst <= '1';
  wait for 1.2 * period;
  rst <= '0';
  wait for period;  

  testNo  <= 10; -- write and read 0xA5A5A5A5 to/from all CSR registers
  wr      <= '1';
  dIn <= X"A5A5A5A5"; 
  for i in 0 to 3 loop -- write all registers
    add   <= std_logic_vector( to_unsigned(i,2) );
    wait for period;  
  end loop;
  testNo  <= 11;       -- read all registers
  wr      <= '0';
  dIn     <= (others => '0'); 
  for i in 0 to 3 loop
    add   <= std_logic_vector( to_unsigned(i,2) );
    wait for period;  
  end loop;

  testNo  <= 20; -- write to all CSR registers. Invert data bits.
  wr      <= '1';
  dIn <= X"5A5A5A5A"; 
  for i in 0 to 3 loop -- write all registers
    add   <= std_logic_vector( to_unsigned(i,2) );
    wait for period;  
  end loop;
  testNo  <= 21;       -- read all registers
  wr      <= '0';
  dIn     <= (others => '0'); 
  for i in 0 to 3 loop
    add   <= std_logic_vector( to_unsigned(i,2) );
    wait for period;  
  end loop;
    
  endOfSim <= true;   		 -- assert flag. Stops clk signal generation in process clkStim
  report "simulation done";   
  wait; 					 -- include to prevent the stim process from repeating execution, since it does not include a sensitivity list
  
end process;

end Behavioral;