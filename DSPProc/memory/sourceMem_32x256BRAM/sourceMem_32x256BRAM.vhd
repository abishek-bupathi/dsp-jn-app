-- sourceMem_32x256BRAM synthesisable VHDL model for dualPort32x256 BRAM 
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 10 Oct 2019

--Description
-- 32 x 256-bit Block RAM (BRAM) memory array
-- Assertion of wr, synchronous store data in memory(add)(255:0) = dIn(255:0) 
-- rst assertion   asynchronously clears all registers

-- Signal dictionary
--  clk				system strobe, rising edge asserted
--  wr 				assertion (h)  synchronously (rising clk edge) writes dIn(31:0) to memory (add)
--  add(10:8)		3-bit sourceMem BRAM memory word address 
--  add( 7:5)		3-bit memory base address select. Not used in this component.
--  add( 4:0)		5-bit address, addressing one of 32 x 256-bit BRAM memory locations
--  dIn(31:0)		32-bit data to be written to memory(add) 
--  dOut(31:0)	    = memory array (add), valid on falling edge of clk 

-- Uses BRAM generated using Xilinx Vivado IP Catalog tool
-- Vivado repository > Memories & Storage Elements > RAMS & ROMS & BRAM > Block Memory Generator
-- BRAM component name is blk_mem_gen_0_32x256

-- Internal signal dictionary
-- clkL    	active falling edge clk  
-- wea     	BRAM component generator provides signal 
--     		wea : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);  
-- 			Therefore, signal wea should be declared as 
--     		signal wea      : STD_LOGIC_VECTOR(0 DOWNTO 0);
-- 			and assigned using wea <= (others => wr);
-- addra    Identical to input signal add (could use input signal add)
-- FM TBD to be completed
-- signal intDIn          : std_logic_vector(255 downto 0)
-- signal intDOut         : std_logic_vector(255 downto 0)
-- signal add10DT8Integer : integer range 0 to 7;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity sourceMem_32x256BRAM is
    Port ( clk    : in  std_logic;   
           wr     : in  std_logic;    				       
	       add    : in  std_logic_vector( 10 downto 0);	  
	       dIn    : in  std_logic_vector( 31 downto 0);	  
           dOut   : out std_logic_vector(255 downto 0)
 		 );
end sourceMem_32x256BRAM;

architecture RTL of sourceMem_32x256BRAM is
signal clkL            : std_logic;
signal wea             : STD_LOGIC_VECTOR(  0 DOWNTO 0);	       
signal addra           : STD_LOGIC_VECTOR(  4 DOWNTO 0);	       
signal intDIn          : std_logic_vector(255 downto 0);
signal intDOut         : std_logic_vector(255 downto 0);
signal add10DT8Integer : integer range 0 to 7;

component blk_mem_gen_0_32x256 IS
  PORT (
    clka  : IN  STD_LOGIC;
    ena   : IN  STD_LOGIC;
    wea   : IN  STD_LOGIC_VECTOR(  0 DOWNTO 0);
    addra : IN  STD_LOGIC_VECTOR(  4 DOWNTO 0);
    dina  : IN  STD_LOGIC_VECTOR(255 DOWNTO 0);
    clkb  : IN  STD_LOGIC;
    addrb : IN  STD_LOGIC_VECTOR(  4 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(255 DOWNTO 0)
  );
END component;

begin

clkL  <= not clk; -- using falling clk edge for synchronous BRAM reads
wea   <= (others => wr);
addra <= add(4 downto 0);

add10DT8Integer <= to_integer( unsigned(add(10 downto 8)) );
process (add10DT8Integer, intDOut)
begin
	intDIn <= intDOut;
	intDIn((32*add10DT8Integer+31) downto 32*add10DT8Integer) <= dIn; -- update one word of sourceMem(255:0)
end process;

u1: blk_mem_gen_0_32x256 PORT MAP -- BRAM component instantiation
(   clka  => clk, 
    ena   => '1',
    wea   => wea, 
    addra => addra, 
    dina  => intDIn,
    clkb  => clkL, 
    addrb => addra, 
    doutb => intDOut
 );
 asgnDOut_i: dOut <= intDOut;
 
end RTL;