-- Description: memory_top_TB testbench 
-- Engineer: Fearghal Morgan
-- National University of Ireland, Galway / viciLogic 
-- Date: 30/10/2019
-- Change History: Initial version

-- Reference: https://tinyurl.com/vicilogicVHDLTips   	A: VHDL IEEE library source code VHDL code
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrayPackage.all;

entity memory_top_TB is end memory_top_TB; -- testbench has no inputs or outputs

architecture Behavioral of memory_top_TB is
-- component declaration is in package

-- Declare internal testbench signals, typically the same as the component entity signals
-- initialise signal clk to logic '1' since the default std_logic type signal state is 'U' 
-- and process clkStim uses clk <= not clk  
signal clk       : STD_LOGIC := '1'; 
signal rst       : STD_LOGIC;

signal host_memWr    : std_logic;
signal host_memAdd   : std_logic_vector(7 downto 0);
signal host_datToMem : std_logic_vector(255 downto 0);
signal host_sourceMemRd_SelWord : std_logic_vector(2 downto 0);

signal DSP_memWr     : std_logic;
signal DSP_memAdd    : std_logic_vector(7 downto 0);
signal DSP_datToMem  : std_logic_vector(31 downto 0);

signal datToHost     : std_logic_vector(31 downto 0);

signal WDTimeout     : std_logic;
signal CSR           : array4x32;
signal sourceMem     : std_logic_vector(255 downto 0);

constant CSRMemAdd_7DT5     : std_logic_vector(2 downto 0) := "000";
constant sourceMemAdd_7DT5  : std_logic_vector(2 downto 0) := "001";
constant resultMem0Add_7DT5 : std_logic_vector(2 downto 0) := "010";


constant period   : time := 20 ns;    -- 50MHz clk
signal   endOfSim : boolean := false; -- Default FALSE. Assigned TRUE at end of process stim
signal   testNo   : integer;          -- facilitates test numbers. Aids locating each simulation waveform test 

begin

uut: memory_top -- instantiate unit under test (UUT)
port map (  clk  	      => clk,  	     
            rst           => rst,          
            			   			 
	        host_memWr    => host_memWr,   
	        host_memAdd   => host_memAdd,  
		    host_datToMem => host_datToMem,
			host_sourceMemRd_SelWord => host_sourceMemRd_SelWord,
						   			 
	        DSP_memWr     => DSP_memWr,    
	        DSP_memAdd    => DSP_memAdd,   
		    DSP_datToMem  => DSP_datToMem, 
						   			 
 	 	    datToHost     => datToHost,
			
			WDTimeout     => WDTimeout,      			 
			CSR           => CSR,          
			sourceMem     => sourceMem    
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
  host_memWr    <= '0';
  host_memAdd   <= (others => '0'); 
  host_datToMem <= (others => '0');   			   			 
  DSP_memWr     <= '0';
  DSP_memAdd    <= (others => '0'); 
  DSP_datToMem  <= (others => '0'); 
  host_sourceMemRd_SelWord <= (others => '0'); 
  
  testNo <= 0; -- include a unique test number to help browsing of the simulation waveform     
  -- apply rst signal pattern, to deassert 0.2*period after the active clk edge
  rst <= '1';
  wait for 1.2 * period;
  rst <= '0';
  wait for period;  


  testNo  <= 1;                                                      -- host write to all CSR memory locations 
  host_memAdd(7 downto 5) <= CSRMemAdd_7DT5;                         -- CSR memory bank
  host_memWr <= '1';
  for i in 0 to 3 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i,5) ); -- write each register. 
    host_datToMem(255 downto 1) <= std_logic_vector( to_unsigned((i+1),255) ); -- Do not write CSR(0)(0) = 1, or control is passed from host to DSP 
    host_datToMem(0)            <= '0';
    wait for period;  
  end loop;
  host_datToMem <= (others => '0');   			   			 
  host_memWr <= '0';
  wait for period;  
  
  testNo  <= 2;                                                      -- host write to all sourceMem locations 
  host_memAdd(7 downto 5) <= sourceMemAdd_7DT5;                      -- source memory bank
  host_memWr <= '1';
  for i in 0 to 31 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i,5) ); -- write each row
    host_datToMem <= std_logic_vector( to_unsigned((i+1),256) );     -- with data = row index + 1
    wait for period;  
  end loop;
  host_datToMem <= (others => '0');   			   			 
  host_memWr <= '0';
  wait for period;  

  testNo  <= 3;                                                      -- host write to all resultMem locations 
  host_memAdd(7 downto 5) <= resultMem0Add_7DT5;                     -- result memory bank
  host_memWr <= '1';
  for i in 0 to 31 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i,5) ); -- write each row
    host_datToMem <= std_logic_vector( to_unsigned((i+1),256) );     -- with data = row index + 1
    wait for period;  
  end loop;
  host_datToMem <= (others => '0');   			   			 
  host_memWr <= '0';
  wait for period;  



  testNo  <= 4;                                                      -- host write CSR(0)(0) = '1'
  host_memAdd(7 downto 5) <= CSRMemAdd_7DT5;                         -- CSR memory bank
  host_memWr <= '1';
  host_memAdd(4 downto 0) <= "00000";								 -- CSR(0) 
  host_datToMem(255 downto 1) <= (others => '0'); 
  host_datToMem(0)            <= '1';
  wait for period;  
  host_datToMem <= (others => '0');   			   			 
  host_memWr <= '0';
  wait for period;  

  testNo  <= 5;                                                      -- DSP write to all CSR memory locations 
  DSP_memAdd(7 downto 5) <= CSRMemAdd_7DT5;                          -- CSR memory bank
  DSP_memWr <= '1';
  DSP_memAdd(4 downto 0) <= "00000";                                 -- CSR(0)
  DSP_datToMem <= X"0000000b";	 	  		   	                     -- Keep CSR(0)(0) = 1. If 0, control will pass from DSP to host 
  wait for period;  
  for i in 1 to 3 loop
    DSP_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i,5) );  -- write CSR registers 1-3
    DSP_datToMem(31 downto 0) <= std_logic_vector( to_unsigned((i+1),32) ); 
    wait for period;  
  end loop;
  DSP_datToMem <= (others => '0');   			   			 
  DSP_memWr <= '0';
  wait for period;  
  
  testNo  <= 6;                                                      -- DSP write to all sourceMem locations 
  DSP_memAdd(7 downto 5) <= sourceMemAdd_7DT5;                       -- source memory bank
  DSP_memWr <= '1';
  for i in 0 to 31 loop
    DSP_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i,5) );  -- write each row
    DSP_datToMem <= std_logic_vector( to_unsigned((i+2),32) );       -- with data = row index + 2
    wait for period;  
  end loop;
  DSP_datToMem <= (others => '0');   			   			 
  DSP_memWr <= '0';
  wait for period;  

  testNo  <= 7;                                                      -- DSP write to all resultMem locations 
  DSP_memAdd(7 downto 5) <= resultMem0Add_7DT5;                      -- result memory bank
  DSP_memWr <= '1';
  for i in 0 to 31 loop
    DSP_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i,5) );  -- write each row
    DSP_datToMem <= std_logic_vector( to_unsigned((i+2),32) );       -- with data = row index + 2
    wait for period;  
  end loop;
  DSP_datToMem <= (others => '0');   			   			 
  DSP_memWr <= '0';
  wait for period;  




  testNo  <= 8;                                                      -- host read all CSR memory locations 
  host_memAdd(7 downto 5) <= CSRMemAdd_7DT5;                         -- CSR memory bank
  host_memWr <= '0';
  for i in 0 to 3 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i,5) ); -- address each register 
    wait for period;  
  end loop;
  
  testNo  <= 9;                                                      -- host read all sourceMem locations 
  host_memAdd(7 downto 5) <= sourceMemAdd_7DT5;                      -- source memory bank
  host_memWr <= '0';
  for i in 0 to 31 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i,5) ); -- address each row
    wait for period;  
  end loop;

  testNo  <= 10;                                                     -- host read all resultMem locations 
  host_memAdd(7 downto 5) <= resultMem0Add_7DT5;                     -- result memory bank
  host_memWr <= '0';
  for i in 0 to 31 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i,5) ); -- address each row
    wait for period;  
  end loop;


  endOfSim <= true;   		 -- assert flag. Stops clk signal generation in process clkStim
  report "simulation done";   
  wait; 					 -- include to prevent the stim process from repeating execution, since it does not include a sensitivity list
  
end process;

end Behavioral;