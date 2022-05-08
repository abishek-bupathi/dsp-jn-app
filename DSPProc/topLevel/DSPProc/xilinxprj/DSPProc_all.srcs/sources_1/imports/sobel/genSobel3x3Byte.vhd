-- Description: genSobel3x34Byte 
-- Author: Fearghal Morgan
-- Date: 14/10/2021

-- Load 3 x 34-byte array from sourceMem(255:0)

-- YAdd = 0 
--	 CS(2)(271:0) = 0x00 & 256{0}                   & 0x00 
--     sel_0_or_sourceMem = 1, ldSobelBuf = 1, clk active edge
--	 CS(1)(271:0) = 0x00 & sourceMem(YAdd  )(255:0) & 0x00 
--     sel_0_or_sourceMem = 0, ldSobelBuf = 1, clk active edge
--	 CS(0)(271:0) = 0x00 & sourceMem(YAdd+1)(255:0) & 0x00 
--     sel_0_or_sourceMem = 0, ldSobelBuf = 1, clk active edge
--   sel_0_or_sourceMem = 0, ldSobelBuf = 0
--   XAdd = 0 Perform soble kernel operation on least significant (right side) 3x3-byte array, sobel3x3Byte
--   On clk active edge, rotate CS right 8 bits. Repeat for XAdd 1 - 0d31, 
--   After 32 rotates CS(2:0)(271:0) is restored to starting value

-- Repeat for YAdd = 1 - 0d30
--   sel_0_or_sourceMem = 0, ldSobelBuf = 1
--	   CS(2)(271:0) = 0x00 & sourceMem(YAdd-1)(255:0) & 0x00   Already have this 
--	   CS(1)(271:0) = 0x00 & sourceMem(YAdd  )(255:0) & 0x00   Already have this
--	   CS(0)(271:0) = 0x00 & sourceMem(YAdd+1)(255:0) & 0x00 
--     clk active edge
--   sel_0_or_sourceMem = 0, ldSobelBuf = 0
--   XAdd = 0 Perform soble kernel operation on least significant (right side) 3x3-byte array, sobel3x3Byte 
--   On clk active edge, rotate CS right 8 bits. Repeat for XAdd 1 - 0d31, 
--   After 32 rotates CS(2:0)(271:0) is restored to starting value

-- YAdd = 31 
--   sel_0_or_sourceMem = 1, ldSobelBuf = 1
--	   CS(2)(271:0) = 0x00 & sourceMem(YAdd-1)(255:0) & 0x00   Already have this 
--	   CS(1)(271:0) = 0x00 & sourceMem(YAdd  )(255:0) & 0x00   Already have this
--	   CS(0)(271:0) = 0x00 & 256{0}                   & 0x00 
--     clk active edge
--   sel_0_or_sourceMem = 0, ldSobelBuf = 0
--   XAdd = 0 Perform soble kernel operation on least significant (right side) 3x3-byte array, sobel3x3Byte 
--   On clk active edge, rotate CS right 8 bits. Repeat for XAdd 1 - 0d31, 
--   After 32 rotates CS(2:0)(271:0) is restored to starting value


-- signal dictionary
--  clk 		 			system clock strobe
--  rst 		 			assertion (high) asynchronously clears all registers
--  ld0                     assertion (h) synchronously clears all register
--  ldSobelBuf 				assert to load CS array 
--  sel_0_or_sourceMem 		select 0s (high) or (0x00 & sourceMem(271:0) & 0x00)
--  sourceMem 	   	  	    256-bit sourceMem data 
--  rot24BitRightCE         assertion (h) synchronously rotate CS(2:0)(7:0) right 
--  sobel3x3Byte	     	3x24 byte data = CS(2:0)(23:0), for input to Sobel kernel 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity genSobel3x3Byte is
    Port ( clk 		          : in STD_LOGIC;                       
           rst 		          : in STD_LOGIC; 
		   ld0	 	   	  	  : in std_logic;
           ldSobelBuf         : in STD_LOGIC;  
           sel_0_or_sourceMem : in STD_LOGIC;
		   sourceMem 	   	  : in std_logic_vector(255 downto 0);
		   rot24BitRightCE    : in std_logic;
           sobel3x3Byte       : out array3x24 					 
         );
end genSobel3x3Byte;

architecture RTL of genSobel3x3Byte is 
signal NS : array3x272;
signal CS : array3x272;

begin

stateReg_i: process (clk, rst)
begin
	if rst = '1' then 
		CS <= (others => (others => '0'));
	elsif rising_Edge (clk) then 
		CS <= NS;
	end if;
end process;

NSDecode_i: process (CS, ld0, sourceMem, sel_0_or_sourceMem, ldSobelBuf, rot24BitRightCE)
begin
	NS <= CS; -- default
	if ld0 = '1' then 
		NS <= (others => (others => '0'));
	else 
	    if ldSobelBuf = '1' then 
			NS(2) <= CS(1);
			NS(1) <= CS(0);
			NS(0) <= (others => '0');               -- load 0 (272-bits), when sel_0_or_sourceMem asserted
			if sel_0_or_sourceMem = '0' then     
				NS(0) <= X"00" & sourceMem & X"00"; -- 272-bits
			end if;
		else
			if rot24BitRightCE = '1' then 
				NS(2) <= CS(2)(7 downto 0) & CS(2)(271 downto 8); -- rotate 8 bits 
				NS(1) <= CS(1)(7 downto 0) & CS(1)(271 downto 8);  
				NS(0) <= CS(0)(7 downto 0) & CS(0)(271 downto 8);  
			end if;
		end if;
	end if;
end process;

asgnSobel3x3Byte_2_i: sobel3x3Byte(2) <= CS(2)(23 downto 0); -- tap least significant 24-bits
asgnSobel3x3Byte_1_i: sobel3x3Byte(1) <= CS(1)(23 downto 0);
asgnSobel3x3Byte_0_i: sobel3x3Byte(0) <= CS(0)(23 downto 0);

end RTL;