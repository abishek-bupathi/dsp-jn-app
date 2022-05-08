-- Description: memory_decodeMemWrCtrl
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 9/1/2021

-- Description
-- generate memory component write signal from input signal wr and memAdd(7:5)  

-- Signal data dictionary
--  memWr        write signal selected from host or DSP function  
--  memAdd       (7:5) selects memory component  
--  CSRWr        assertion (h) synchronously performs write to addressed 32-bit CSR register 
--  sourceMemWr  assertion (h) synchronously performs write to addressed 256-bit source memory BRAM address  
--  resultMem0Wr assertion (h) synchronously performs write to addressed 32-bit result memory register 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity memory_decodeMemWrCtrl is
    Port ( memWr        : in  std_logic;
	       memAdd       : in  std_logic_vector(10 downto 0);
		   CSRWr        : out std_logic;
           sourceMemWr  : out std_logic;
           resultMem0Wr : out std_logic
    	  );
end memory_decodeMemWrCtrl;

architecture comb of memory_decodeMemWrCtrl is
constant CSRAdd            : std_logic_vector(2 downto 0) := "000";
constant sourceMemAdd      : std_logic_vector(2 downto 0) := "001";
constant resultMem0Add     : std_logic_vector(2 downto 0) := "010";

-- signals used in vicilogic -- could be omitted from model
signal CSRRd        : std_logic;
signal sourceMemRd  : std_logic;
signal resultMem0Rd : std_logic;

begin

decodeMemoryWr_i: process (memWr, memAdd)
begin 
  CSRWr        <= '0'; -- defaults
  sourceMemWr  <= '0';
  resultMem0Wr <= '0'; 
  if memWr = '1' then 
    if    memAdd(7 downto 5) = CSRAdd then        -- CSR array (8 x 32-bit),       memAdd(7:5) = 0b000, address range 0b00000000 to 0b00000111 
		CSRWr        <= '1';
    elsif memAdd(7 downto 5) = sourceMemAdd then  -- source memory (32 x 256-bit), memAdd(7:5) = 0b001, address range 0b00100000 to 0b00111111 
	    sourceMemWr  <= '1'; 
    elsif memAdd(7 downto 5) = resultMem0Add then -- result memory (32 x 32-bit),  memAdd(7:5) = 0b010, address range 0b01000000 to 0b01011111 
    	resultMem0Wr <= '1'; 
    end if;
  end if;
end process;

-- signals used in vicilogic -- could be omitted from model
decodeMemoryRd_i: process (memAdd, MemWr)
begin 
  CSRRd        <= '0'; -- defaults
  sourceMemRd  <= '0';
  resultMem0Rd <= '0'; 

  if memWr = '0' then 
    if    memAdd(7 downto 5) = CSRAdd then        -- CSR array (8 x 32-bit),       memAdd = 0b00000000 to 0b00000111 
		CSRRd    <= '1';
    elsif memAdd(7 downto 5) = sourceMemAdd then  -- source memory (32 x 256-bit), memAdd = 0b00100000 to 0b00111111 
	    sourceMemRd <= '1'; 
    elsif memAdd(7 downto 5) = resultMem0Add then -- result memory (32 x 32-bit),  memAdd = 0b01000000 to 0b01011111 
    	resultMem0Rd <= '1'; 
    end if;
  end if;
end process;

end comb;