-- Component: memory_top 
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 26/1/2021

-- Description
-- Integrates 3 memory elements  
--   4 x 32-bit  control and status registers, CSR(3:0)(31:0)
--  32 x 256-bit source memory (Block RAM)
--               BRAM is synchronously written on rising clk edge   
--               BRAM is synchronously read    on falling clk edge  
--  32 x 32-bit  result memory (registers)

-- processes:
--  memory_selDSPOrHostCtrl  	select wr, add, dat
--                              if DSPMaster is asserted, select DSP function as master, else host as master 
--  memory_decodeMemWrCtrl 		decodes memAdd(7:5) to select memory component to write to 
--  memory_selDatToHost			decodes memAdd(7:5) to select memory component to read

-- Signal dictionary 
-- clk  	                     system clock strobe, rising edge active 
-- rst                           assertion (h) asynchronously clears CSR and result register arrays (though not BRAM)  			        
-- host memory interface signals 		
--  host_memWr                   assertion writes memory(add) = datToMem
--  host_memAdd               
--  host_datToMem             
--  host_memAdd(10:8) 			 selects source memory 32-bit word (000 => word 0 bits 31:0, 111 => word 7 bits 255:224) 
-- DSP memory interface signals
--  DSP_memWr                    assertion writes memory(add) = datToMem
--  DSP_memAdd               
--  DSP_datToMem             
-- datToHost                     32-bit data read by host  
-- WDTimeout                     assertion (h) 
--                                  synchronously returns all DSP function finite state machines to idle state : in std_logic;   
-- 							     	synchronously clears CSR(0)(0) to return control to host, asserts (CSR(3)(31) status bit) 
-- CSR                           4 x 32-bit control and status register memory array  
--  						     CSR(0)(6) assertion synchronously clears resultMem0 array and 
-- sourceMem                     256-bit source memory data, input to DSP functions

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity memory_top is 
    Port (  clk  	      : in  STD_LOGIC;
            rst           : in  STD_LOGIC;
			            			  
	        host_memWr    : in  std_logic;
	        host_memAdd   : in  std_logic_vector(10 downto 0);
		    host_datToMem : in  std_logic_vector(31 downto 0);
			
	        DSP_memWr     : in  std_logic;
	        DSP_memAdd    : in  std_logic_vector( 7 downto 0);
		    DSP_datToMem  : in  std_logic_vector(31 downto 0);
						  
 	 	    datToHost     : out std_logic_vector(31 downto 0);
						  
            WDTimeout     : in std_logic;   
			CSR           : out array4x32;
			sourceMem     : out std_logic_vector(255 downto 0)
		 );
end memory_top;

architecture RTL of memory_top is
signal memWr             : std_logic;
signal memAdd            : std_logic_vector( 10 downto 0);
signal datToMem          : std_logic_vector( 31 downto 0);

signal CSRWr             : std_logic;
signal XX_int_CSR        : array4x32;
signal CSROut            : std_logic_vector( 31 downto 0);

signal sourceMemWr       : std_logic;
signal XX_int_sourceMem  : std_logic_vector(255 downto 0);

signal resultMem0Wr      : std_logic;
signal ld0ResultMem      : std_logic;
signal resultMem0        : std_logic_vector( 31 downto 0);
signal memAdd10DT8       : std_logic_vector(  2 downto 0);
signal memAdd7DT5        : std_logic_vector(  2 downto 0);
signal memAdd4DT0        : std_logic_vector(  4 downto 0); -- internal signal. Could be removed.
signal DSPMaster   	     : std_logic;

begin

asgnMemAdd_10Dt8_i:memAdd10DT8<= memAdd(10 downto 8);
asgnMemAdd_7Dt5_i: memAdd7DT5 <= memAdd( 7 downto 5);
asgnMemAdd_4Dt0_i: memAdd4DT0 <= memAdd( 4 downto 0); 
asgnCSR_i: 		   CSR        <= XX_int_CSR;
asgnSourceMem_i:   sourceMem  <= XX_int_sourceMem;
asgnSelDSPMaster_i:DSPMaster  <= XX_int_CSR(0)(0);

memory_selDSPOrHostCtrl_i: memory_selDSPOrHostCtrl
Port map ( DSPMaster      => DSPMaster,              
						  				 
	       host_memWr     => host_memWr,   
	       host_memAdd    => host_memAdd,  
		   host_datToMem  => host_datToMem,
		   
	       DSP_memWr      => DSP_memWr,    
	       DSP_memAdd     => DSP_memAdd,   
		   DSP_datToMem   => DSP_datToMem, 			 		 
		   
	       memWr          => memWr,             
	       memAdd         => memAdd,            
		   datToMem       => datToMem          
           );

-- === select memory write/read datapath 
memory_decodeMemWrCtrl_i: memory_decodeMemWrCtrl 
Port map ( memWr        => memWr,       
	       memAdd       => memAdd,      
		   CSRWr        => CSRWr,       
           sourceMemWr  => sourceMemWr, 
           resultMem0Wr => resultMem0Wr
 		 );
		 
memory_selDatToHost_i: memory_selDatToHost 
Port map ( memAdd               => memAdd,
		   CSROut               => CSROut,       
		   sourceMem            => XX_int_sourceMem,
		   resultMem0           => resultMem0,  
		   datToHost            => datToHost	   
 		 );

-- ============== instantiate memory components
CSR_4x32Reg_i: CSR_4x32Reg_withWDogCtrl
Port map ( clk       => clk,    
           rst       => rst,    
           WDTimeout => WDTimeout, 
           wr        => CSRWr,    
	       add       => memAdd(1 downto 0), 
	       dIn       => datToMem,
           CSR       => XX_int_CSR,
		   dOut      => CSROut
 		 );

sourceMem_32x256BRAM_i: sourceMem_32x256BRAM 
Port map  (clk   => clk,    
           wr    => sourceMemWr,    
	       add   => memAdd, 
	       dIn   => datToMem,
           dOut  => XX_int_sourceMem
 		 );

asgnLd0ResultMem_i: ld0ResultMem <= XX_int_CSR(0)(6);
resultMem0_32x32Reg_i: resultMem0_32x32Reg 
Port map ( clk   => clk,   
           rst   => rst,
           ld0   => ld0ResultMem, 
           wr    => resultMem0Wr,    
	       add   => memAdd(4 downto 0), 
	       dIn   => datToMem, 
           dOut  => resultMem0
 		 );
		 		           
end RTL;