-- Component: DSP_top top level data processor   
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 26/1/2021
  
-- FM TBD
-- Signal dictionary
--  clk			 System clock strobe, rising edge active
--  rst			 Synchronous reset signal. Assertion clears all registers, count=00

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity DSP_top is 
    Port (  clk  	         : in  STD_LOGIC;
            rst              : in  STD_LOGIC;
			continue         : in  std_logic;
			
            CSR              : in array4x32;
            sourceMem        : in std_logic_vector(255 downto 0); 
			
	        memWr            : out std_logic; 
	        memAdd           : out std_logic_vector(7 downto 0); 
		    datToMem         : out std_logic_vector(31 downto 0);
		    WDTimeout        : out std_logic
		   );
end DSP_top;

architecture RTL of DSP_top is
signal DSP_activeIndex : std_logic_vector(5 downto 0); 
-- 5:0 is DSPExA, DSPExB, sobel, threshold, histogram, maxPixel
signal DSP_memWr    : std_logic_vector(5 downto 0); 
signal DSP_memAdd   : array6x8;                     
signal DSP_datToMem : array6x32;                     
signal DSP_goIndex  : std_logic_vector(5 downto 0); 
signal intWDTimeout : std_logic := '0';  

begin

asgnWDTimeout_i: WDTimeout <= intWDTimeout; 

DSP_decodeCmdAndWDogCtrl_i: DSP_decodeCmdAndWDogCtrl 
Port map (clk  	           => clk, 
          rst              => rst, 
          CSR              => CSR, 
		  DSP_activeIndex  => DSP_activeIndex,
          DSP_goIndex      => DSP_goIndex, 
		  WDTimeout        => intWDTimeout
          );

DSP_selMemMaster_i: DSP_selMemMaster 
Port map ( DSP_activeIndex => DSP_activeIndex,   
	       DSP_memWr       => DSP_memWr,    
	       DSP_memAdd      => DSP_memAdd,   
		   DSP_datToMem    => DSP_datToMem, 
						   
	       memWr           => memWr,            
	       memAdd          => memAdd,           
		   datToMem        => datToMem         
           );

maxPixel_i: maxPixel
 Port map ( clk       => clk, 	 
            rst       => rst, 
			continue  => continue, 
			
			WDTimeout => intWDTimeout, 			
            go        => DSP_goIndex(0),
			active    => DSP_activeIndex(0),
			
		    CSR       => CSR,
            sourceMem => sourceMem,  
			
			memWr     => DSP_memWr(0),   
            memAdd    => DSP_memAdd(0),  
            datToMem  => DSP_datToMem(0)  
           );
	   
histogram_i: histogram 
Port map ( clk 	 	 => clk,  
           rst 	 	 => rst,
		   continue  => continue, 
		   
		   WDTimeout => intWDTimeout, 
           go        => DSP_goIndex(1),
		   active    => DSP_activeIndex(1),
					  
		   CSR       => CSR,
           sourceMem => sourceMem,
					  
		   memWr     => DSP_memWr(1),    
		   memAdd    => DSP_memAdd(1),   
		   datToMem	 => DSP_datToMem(1)
           );


threshold_i: threshold 
 Port map ( clk	          => clk,  
            rst           => rst, 
			continue      => continue,
			
			WDTimeout     => intWDTimeout, 
            go            => DSP_goIndex(2),
	  	    active        => DSP_activeIndex(2),

		    CSR           => CSR,
            sourceMem     => sourceMem,
			
			memWr         => DSP_memWr(2),    
		    memAdd        => DSP_memAdd(2),   
		    datToMem	  => DSP_datToMem(2)
           );
		   		   
sobel_i: sobel
 Port map ( clk	          => clk,  
            rst           => rst,
			continue  => continue, 
			
			WDTimeout     => intWDTimeout, 
			go            => DSP_goIndex(3),
	  	    active        => DSP_activeIndex(3),

	  	    CSR           => CSR,
            sourceMem     => sourceMem,
			
			memWr         => DSP_memWr(3),    
		    memAdd        => DSP_memAdd(3),   
		    datToMem	  => DSP_datToMem(3)
          );
		  
DSPExA_i: DSPStub
 Port map ( clk	          => clk,  
            rst           => rst,  
			continue      => continue, 

			WDTimeout     => intWDTimeout, 
			go            => DSP_goIndex(4),
	  	    active        => DSP_activeIndex(4),

	  	    CSR           => CSR,
            sourceMem     => sourceMem,
			
			memWr         => DSP_memWr(4),    
		    memAdd        => DSP_memAdd(4),   
		    datToMem	  => DSP_datToMem(4)
          );

DSPExB_i: DSPStub
 Port map ( clk	          => clk,  
            rst           => rst,  
			continue      => continue, 

			WDTimeout     => intWDTimeout, 
			go            => DSP_goIndex(5),
	  	    active        => DSP_activeIndex(5),

	  	    CSR           => CSR,
            sourceMem     => sourceMem,
			
			memWr         => DSP_memWr(5),    
		    memAdd        => DSP_memAdd(5),   
		    datToMem	  => DSP_datToMem(5)
          );
		    		   
end RTL;