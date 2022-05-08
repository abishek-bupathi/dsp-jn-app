-- Component: DSPProc, top level data processor   
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 26/1/2021

--Description

-- Write interface
--  32-bit data
--  Decodes address
--  Write CSR(1:0), source mem, result mem 
-- Read interface
--  32-bit data
--  Decodes address
--  Read CSR(1:0), source mem row (lower 32-bits), result mem (lower 32-bits) 
-- FM TBD: add function to select row 32-bit (require 3 bit sub address)

-- Write data pattern to source mem
-- Write command to CSR(0)
--   CSR(0)(0) = 1, DSPPRoc is active. FSM decodes rest of command and activates function
--   Max byte value, assuming XRGB pixel pattern
--     command CSR(0)(31:10) = 
--     RGB selection CSR(0)(9:8) 
--   Histogram, assuming XRGB pixel pattern
--     command CSR(0)(31:10) = 
--     RGB selection CSR(0)(9:8) 
--   Threshold, assuming 256x256 byte array 
--     command CSR(0)(31:8) = 
--     processes 32 x 256-bit vectors
--     For each, writes 1 to 32-bit vector if byte >= threshVal(7:0)
--     Result is resultMem (32x32-bit array)
--   Sobel edge detector  
--     command CSR(0)(31:8) = 
--     processes 32 x 32-bit vectors (from resultMem)
--     32 steps
--         load sobelReg(2:0)(31:0), perform filter with 3x3 matrix, 
--         generate 32-bit result value, write to result2Mem
--         option of combination process or 32-bit vector in one clk period  
--         or over 32 clock periods
  
-- FM TBD
-- Signal dictionary
--  clk			 System clock strobe, rising edge active
--  rst			 Synchronous reset signal. Assertion clears all registers, count=00

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity DSPProc is 
    Port (  clk  	      : in  STD_LOGIC;
            rst           : in  STD_LOGIC;
			continue_proc : in  std_logic;
			
            host_memWr    : in  STD_LOGIC;
            host_memAdd   : in  STD_LOGIC_VECTOR(10 downto 0);
            
			host_datToMem : in  STD_LOGIC_VECTOR(31 downto 0);
            datToHost     : out STD_LOGIC_VECTOR(31 downto 0)
		   );
end DSPProc;

architecture RTL of DSPProc is
signal CSR          : array4x32;
signal sourceMem    : std_logic_vector(255 downto 0);
signal DSP_memWr    : STD_LOGIC;
signal DSP_memAdd   : STD_LOGIC_VECTOR(  7 downto 0);
signal DSP_datToMem : STD_LOGIC_VECTOR( 31 downto 0);
signal WDTimeout    : std_logic; 

begin

DSP_top_i: DSP_top 
Port map (clk  	             => clk,  	          
          rst                => rst,
		  continue           => continue_proc,
            
	   	  CSR                => CSR,             
          sourceMem          => sourceMem, 
							    				  
	      memWr              => DSP_memWr,             
	      memAdd             => DSP_memAdd(7 downto 0),            
		  datToMem           => DSP_datToMem,
 	      WDTimeout          => WDTimeout
		 );

memory_top_i: memory_top         
Port map (  clk  	         => clk, 	        
            rst              => rst,
			
	        host_memWr       => host_memWr,       
	        host_memAdd      => host_memAdd,     
		    host_datToMem    => host_datToMem,    
			
	        DSP_memWr        => DSP_memWr,        
	        DSP_memAdd       => DSP_memAdd,       
		    DSP_datToMem     => DSP_datToMem, 
			
 	 	    datToHost        => datToHost, 
							 				
            WDTimeout        => WDTimeout, 
			CSR              => CSR,             
			sourceMem        => sourceMem
		 );

end RTL;