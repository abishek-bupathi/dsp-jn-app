-- Description: DSPStub component stub
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Created: 1/3/2021

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity DSPStub is
    Port ( clk 		 : in STD_LOGIC;   
           rst 		 : in STD_LOGIC; 
  		   continue  : in  std_logic;
		   
		   WDTimeout : in std_logic;
           go        : in  std_logic;                		 
		   active    : out std_logic;

		   CSR       : in  array4x32;
           sourceMem : in  std_logic_vector(255 downto 0); 
					 
		   memWr     : out std_logic;
		   memAdd    : out std_logic_vector(  7 downto 0);					 
		   datToMem	 : out std_logic_vector( 31 downto 0)
           );
end DSPStub;

architecture RTL of DSPStub is

begin

active   <= '0';  
memWr    <= '0';
memAdd   <= (others => '0'); 
datToMem <= (others => '0');

end RTL;