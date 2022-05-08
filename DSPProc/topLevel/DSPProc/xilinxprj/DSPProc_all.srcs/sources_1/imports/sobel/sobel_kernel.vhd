-- sobel_kernel component. Combinational logic model
-- Engineer: Fearghal Morgan, National University of Ireland, Galway
-- Date: 26/1/2021

-- X, Y filter operation performed by Sobel kernel
-- Use 12-bit operations throughout

-- data index   = z1 z2 z3 
--                z4 z5 z6
--                z7 z8 z9 

-- Gx filter    = -1  0  1
--                -2  0  2
--                -1  0  1 

-- Gy filter    = -1 -2 -1
--                 0  0  0
--                 1  2  1 

-- signal dictionary 
--   xPos    : unsigned(11 downto 0) -- z7 + (2*z8) + z9 term (positive)
--   xNeg    : unsigned(11 downto 0) -- z1 + (2*z2) + z3 term (positive)
--   yPos    : unsigned(11 downto 0) -- z3 + (2*z6) + z9 term (positive)
--   yNeg    : unsigned(11 downto 0) -- z1 + (2*z4) + z7 term (positive)
--   Gx      : signed  (11 downto 0) -- xPos - xNeg 
--   Gy      : signed  (11 downto 0) -- yPos - yNeg 
--             Gx and Gy: use signed data format since values may be positive or negative
--   absGx   : signed  (11 downto 0) -- absolute value of Gx
--   absGy   : signed  (11 downto 0) -- absolute value of Gy 
--             absGx and absGy: use signed data format, though values are always positive 
--   addGxGy : filter output value. signed  (11 downto 0) -- 12-bit sum  absGx + absGy

-- =============  
-- Signal widths
-- Max positive Gx = xPos – xNeg  occurs when 
--     xPos (z7+2*z8+z9) is maximum (z7, z8, z9 = 0xff) 
-- and xNeg (z1+2*z2+z3) is minimum (z1, z2, z3 = 0), i.e, 
--     xPos= 0xff + 2*0xff + 0xff = 4*0xff = 0x3fc = 0b0011 1111 1100 (use 12-bit value) [4*=> shift left by 2 bits] 
-- and xNeg= 0 +2*0 + 0 = 0x00
-- Gx = xPos – xNeg = 0x3fc

-- Max negative Gx occurs when 
--     xPos (z7+2*z8+z9) is minimum (z7, z8, z9 = 0) 
-- and xNeg (z1+2*z2+z3) is maximum (z1, z2, z3 = 0xff), i.e, 
--     xPos= 0 +2*0 + 0 = 0x00
-- and xNeg= 0xff + 2*0xff + 0xff = 4*0xff = 0x3fc = 0b0011 1111 1100 
-- Gy = xPos – xNeg = -(4 x 0xff) = -(4 x 0b0000 1111 1111) = -(0b0011 1111 1100) = -(0d1020)  
-- Take 2s complement of -(0d1020)                     invert   0b1100 0000 0011
--                                                      add 1   0b1100 0000 0100 = 0xc04
-- 12-bit signed number: bit 11 is sign bit (asserted here) => negative value

-- Ensure that all vectors in arithmetic operations are 12 bits 
-- Pad with '0' &      or "00.." &      as required

-- =========== arithmetic library 
-- sobelBit generation using comparator function > 
--  Generate single bit sobel filter output signal
--  Use numeric_std library > (greater than) operator (https://www.csee.umbc.edu/portal/help/VHDL/packages/numeric_std.vhd)  
--  supports signed types  
--  Id: C.2
--    function ">"  ( L,R: SIGNED) return BOOLEAN;
--     Result subtype: BOOLEAN
--     Result: Computes "L > R" where L and R are SIGNED vectors possibly of different lengths.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.ALL;

entity sobel_kernel is
  port (z1  		   : in unsigned(7 downto 0);
	    z2  		   : in unsigned(7 downto 0);
	    z3  		   : in unsigned(7 downto 0);
	    z4  		   : in unsigned(7 downto 0);
	    z5  		   : in unsigned(7 downto 0);
	    z6  		   : in unsigned(7 downto 0);
	    z7  		   : in unsigned(7 downto 0);
	    z8  		   : in unsigned(7 downto 0);
	    z9  		   : in unsigned(7 downto 0);
	    threshVal12Bit : in STD_LOGIC_VECTOR(11 downto 0);
	    sobelBit       : out std_logic 
	   );
end sobel_kernel;

architecture comb of sobel_kernel is

signal xPos    : unsigned(11 downto 0);  
signal xNeg    : unsigned(11 downto 0);  
signal yPos    : unsigned(11 downto 0);  
signal yNeg    : unsigned(11 downto 0);  
signal Gx      : signed  (11 downto 0);  
signal Gy      : signed  (11 downto 0);  
signal absGx   : unsigned(11 downto 0);  
signal absGy   : unsigned(11 downto 0);  
signal addGxGy : unsigned(11 downto 0);  

begin

-- ========= Generate Gx and Gy
-- Could use a single Gy assignment, i.e, 
-- asgnGy_i: Gy    <= ("0000" & signed(z3)) + ("000" & signed(z6) & '0') + ("0000" & signed(z9))  
--	                - ("0000" & signed(z1)) - ("000" & signed(z4) & '0') - ("0000" & signed(z7)); 
-- In the solution, use intermediate signals, i.e, xPos/xNeg and yPos/yNeg etc in order to to provide visibility 
-- of arithmetic operations in simulation

-- X filter signals: apply filters. mult by 2 is 1-bit left shift
xPos_i:     xPos  <= ("0000" & z7) + ("000" & z8 & '0')  + ("0000" & z9); -- unsigned arith
xNeg_i:     xNeg  <= ("0000" & z1) + ("000" & z2 & '0')  + ("0000" & z3); -- unsigned arith 
Gx_i:       Gx    <= ( signed(xPos) - signed(xNeg) );                     -- signed arith. May be positive/negative (bit 11 sign bit = 0/1)

-- Y filter signals: apply filters. mult by 2 is 1-bit left shift
yPos_i:     yPos  <= ("0000" & z3) + ("000" & z6 & '0')  + ("0000" & z9); -- unsigned arith
yNeg_i:     yNeg  <= ("0000" & z1) + ("000" & z4 & '0')  + ("0000" & z7); -- unsigned arith
Gy_i:       Gy    <= ( signed(yPos) - signed(yNeg) );                     -- signed arith. May be positive/negative (bit 11 sign bit = 0/1)


-- Check if Gx or Gy is negative (bit 11 = 1). If so, generate abs* absolute value, i.e, get 2s complement 
-- In the solution, use a single concurrent statement rather than a VHDL process with if statement 
-- Concurrent statement format: <name> <= <expression> when <condition> else <expression>;
absGx_i:    absGx <= (not unsigned(Gx)) + 1  when Gx(10) = '1'  else unsigned(Gx); 
absGy_i:    absGy <= (not unsigned(Gy)) + 1  when Gy(10) = '1'  else unsigned(Gy); 

addGxGy_i:  addGxGy <= absGx + absGy; -- 12-bit addition


-- Check if  addGxGy >= threshVal12Bit (unsigned)
-- In the solution, use a single concurrent statement rather than a VHDL process with if statement 
sobelBit_i: sobelBit <= '1' when unsigned(addGxGy) > unsigned(threshVal12Bit) else '0'; 
				
end comb;