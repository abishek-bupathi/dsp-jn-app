library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity sobel is
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
end sobel;

architecture struct of sobel is

component sobelFSM is
    Port ( clk 		 : in STD_LOGIC;   
           rst 		 : in STD_LOGIC;
   		   continue  : in  std_logic;
		   
		   WDTimeout : in std_logic;
           go        : in  std_logic; 		   
		   active    : out std_logic;

		   CSR       : in  array4x32;
           sourceMem : in  std_logic_vector(255 downto 0); 

		   sobelBit           : in std_logic;  
		   rot24BitRightCE    : out std_logic;
		   ld0        : out std_logic;
		   sel_0_or_sourceMem : out std_logic;
		   ldSobelBuf         : out std_logic; 

		   memWr     : out std_logic;
		   memAdd    : out std_logic_vector(  7 downto 0);					 
		   datToMem	 : out std_logic_vector( 31 downto 0)
           );
end component;

component gensobel3x3Byte is
    Port ( clk 		          : in STD_LOGIC;                       
           rst 		          : in STD_LOGIC; 
		   ld0	 	   	  	  : in std_logic;
           ldSobelBuf         : in STD_LOGIC;  
           sel_0_or_sourceMem : in STD_LOGIC;
		   sourceMem 	   	  : in std_logic_vector(255 downto 0);
		   rot24BitRightCE    : in std_logic;
           sobel3x3Byte       : out array3x24  					 
         );
end component;

component sobel_kernel is
  port (z1             : in unsigned(7 downto 0);
	    z2             : in unsigned(7 downto 0);
	    z3             : in unsigned(7 downto 0);
	    z4             : in unsigned(7 downto 0);
	    z5             : in unsigned(7 downto 0);
	    z6             : in unsigned(7 downto 0);
	    z7             : in unsigned(7 downto 0);
	    z8             : in unsigned(7 downto 0);
	    z9             : in unsigned(7 downto 0);
	    threshVal12Bit : in STD_LOGIC_VECTOR(11 downto 0);
	    sobelBit       : out std_logic 
	   );
end component;

signal rot24BitRightCE    : std_logic;
signal ld0                : std_logic;
signal sel_0_or_sourceMem : std_logic;
signal ldSobelBuf         : std_logic; 
signal sobel3x3Byte       : array3x24; 
signal sobelBit           : std_logic;  
signal threshVal12Bit     : std_logic_vector(11 downto 0);

begin

sobelFSM_i: sobelFSM 
Port map ( clk                 => clk, 
           rst 			       => rst, 
		   continue	 	   	   => continue,
		   
		   WDTimeout           => WDTimeout,
		   go				   => go,
		   active			   => active,

		   CSR				   => CSR,
		   sourceMem		   => sourceMem,
		   
           sobelBit            => sobelBit,   
		   rot24BitRightCE     => rot24BitRightCE, 
		   ld0                 => ld0, 
           sel_0_or_sourceMem  => sel_0_or_sourceMem,
           ldSobelBuf          => ldSobelBuf,

		   memWr     	   	   => memWr, 
		   memAdd     	   	   => memAdd,
		   datToMem     	   => datToMem
         );
   
gensobel3x3Byte_i: gensobel3x3Byte 
Port map ( clk 		          => clk, 		           
           rst 		          => rst, 		         
		   ld0	 	   	  	  => ld0,	 	   	  	 
           ldSobelBuf         => ldSobelBuf,            
           sel_0_or_sourceMem => sel_0_or_sourceMem,
		   sourceMem 	   	  => sourceMem, 	   	 
		   rot24BitRightCE    => rot24BitRightCE,  
           sobel3x3Byte       => sobel3x3Byte 	 
         );


asgnThreshVal12Bit_i: threshVal12Bit <= CSR(0)(15 downto 8) & CSR(0)(31 downto 29) & CSR(0)(21); -- 12-bit threshold 
-- filter index =  1  2  3      assign from sobel3x3Byte(2)(23 downto 0)
--                 4  5  6      assign from sobel3x3Byte(1)(23 downto 0)
--                 7  8  9      assign from sobel3x3Byte(0)(23 downto 0)
sobel_kernel_i: sobel_kernel port map
 (z1             => unsigned( sobel3x3Byte(2)(23 downto 16) ),
  z2             => unsigned( sobel3x3Byte(2)(15 downto  8) ),
  z3             => unsigned( sobel3x3Byte(2)( 7 downto  0) ),  
  z4             => unsigned( sobel3x3Byte(1)(23 downto 16) ),
  z5             => unsigned( sobel3x3Byte(1)(15 downto  8) ),
  z6             => unsigned( sobel3x3Byte(1)( 7 downto  0) ),
  z7             => unsigned( sobel3x3Byte(0)(23 downto 16) ), 
  z8             => unsigned( sobel3x3Byte(0)(15 downto  8) ), 
  z9             => unsigned( sobel3x3Byte(0)( 7 downto  0) ),
  threshVal12Bit => threshVal12Bit,
  sobelBit       => sobelBit 
  );

end struct;