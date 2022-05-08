-- Description: DSPProc testbench 
-- Engineer: Fearghal Morgan
-- National University of Ireland, Galway / viciLogic 
-- Date: 30/10/2019
-- Change History: Initial version

-- Reference: https://tinyurl.com/vicilogicVHDLTips   	A: VHDL IEEE library source code VHDL code
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.arrayPackage.all;

entity DSPProc_TB is end DSPProc_TB; -- testbench has no inputs or outputs

architecture Behavioral of DSPProc_TB is
-- component declaration is in package

-- Declare internal testbench signals, typically the same as the component entity signals
-- initialise signal clk to logic '1' since the default std_logic type signal state is 'U' 
-- and process clkStim uses clk <= not clk  
signal clk               : STD_LOGIC := '1'; 
signal rst               : STD_LOGIC;
signal continue          : std_logic;

signal host_memWr        : STD_LOGIC;
signal host_memAdd       : STD_LOGIC_VECTOR( 10 downto 0);
signal host_datToMem     : STD_LOGIC_VECTOR( 31 downto 0);

signal datToHost         : STD_LOGIC_VECTOR( 31 downto 0);

constant CSRAdd_7DT5        : std_logic_vector(2 downto 0) := "000";
constant sourceMemAdd_7DT5  : std_logic_vector(2 downto 0) := "001";
constant resultMem0Add_7DT5 : std_logic_vector(2 downto 0) := "010";

signal   maxPixelRedCmd_byte0    : std_logic_vector(7 downto 0) := "00100001"; -- X"21", 00 10 (red)   000 (max pixel) 1 (DSPMaster)
signal   maxPixelGreenCmd_byte0  : std_logic_vector(7 downto 0) := "00010001"; -- X"11", 00 01 (green) 000 (max pixel) 1 (DSPMaster)
signal   maxPixelBlueCmd_byte0   : std_logic_vector(7 downto 0) := "00000001"; -- X"01", 00 00 (blue)  000 (max pixel) 1 (DSPMaster)
signal   histogramRedCmd_byte0   : std_logic_vector(7 downto 0) := "00100011"; -- X"23", 00 10 (red)   001 (histogram) 1 (DSPMaster)
signal   histogramGreenCmd_byte0 : std_logic_vector(7 downto 0) := "00010011"; -- X"13", 00 01 (green) 001 (histogram) 1 (DSPMaster)
signal   histogramBlueCmd_byte0  : std_logic_vector(7 downto 0) := "00000011"; -- X"03", 00 11 (blue)  001 (histogram) 1 (DSPMaster)
signal   thresholdCmd_byte0      : std_logic_vector(7 downto 0) := "00000101"; -- X"05", 00 00         010 (threshold) 1 (DSPMaster)
signal   sobelCmd_byte0          : std_logic_vector(7 downto 0) := "00000111"; -- X"07", 00 00         011 (sobel)     1 (DSPMaster)
signal   DSPExACmd_byte0         : std_logic_vector(7 downto 0) := "00001001"; -- X"09", 00 00         100 (DSPExA)    1 (DSPMaster)
signal   DSPExBCmd_byte0         : std_logic_vector(7 downto 0) := "00001001"; -- X"0a", 00 00         101 (DSPExB)    1 (DSPMaster)

signal   threshVal   : std_logic_vector(7 downto 0);
signal   add         : std_logic_vector (4 downto 0);
signal   CSRAdd      : std_logic_vector (1 downto 0);
signal   CSRDat      : std_logic_vector (31 downto 0);
				     
constant period      : time := 20 ns;    -- 50MHz clk
signal   endOfSim    : boolean := false; -- Default FALSE. Assigned TRUE at end of process stim
signal   testNo      : integer;          -- facilitates test numbers. Aids locating each simulation waveform test 

signal   sourceArray  : array32x256; 
signal   sourceByte   : std_logic_vector (7 downto 0); 
signal   resultArray  : array32x32; 
signal   CSRArray     : array4x32; 
signal   CSRArrayA    : array4x32; 

signal   resultArrayA : array32x32; 
signal   sourceArrayA, sourceArrayB, sourceArrayC, sourceArrayD, sourceArrayE, sourceArrayF, sourceArrayG: array32x256; -- reference arrays for use in testbench
signal   r5, r4, r3, r2, r1, r0 : std_logic_vector (7 downto 0); -- histogram ranges

signal   WDogWDEnable          : std_logic;
signal   WDogWDTMOutValue28DT0 : std_logic_vector (28 downto 0); -- 29-bit watchdog timeout value (num of clks)


-- ================ Reset and watchdog control START ===============
procedure rstProc (signal rst : out std_logic) is
begin
  -- apply rst signal pattern, to deassert 0.2*period after the active clk edge
  rst <= '1';
  wait for 1.2 * period;
  rst <= '0';
  wait for period;
end procedure;

-- enables watchdog time CSR(3)(29). This bit is initialised asserted 
-- enables 15 clk period timeout
-- timeout number of clk periods is CSR(3)(28:0), 29 bits 
procedure enWDog15 (   signal host_datToMem : out std_logic_vector(31 downto 0);
                       signal host_memWr : out std_logic;
                       signal host_memAdd : out std_logic_vector(10 downto 0)
              ) is
begin
  host_datToMem 			   <= (others => '0'); -- clear host_datToMem
  host_memWr                   <= '1'; 
  host_memAdd(7 downto 5)      <= CSRAdd_7DT5;     -- select CSR memory array
  host_memAdd(4 downto 0)      <= "000" & "11";    -- CSR(3)
  host_datToMem                <= X"2000000f";     -- watchdog enabled (bit 29) and 15 clk periods
  wait for period;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
end procedure;	

-- CSR(0)(6) asserted on occurrence of watchdog timeout
-- CSR(3)(29) enables watchdog timer. Initialised asserted
-- CSR(3)(28:0), 29 bits. @20ns clk period = 10.73741974 seconds, if CSR3(28:0) = 0x1fffffff
procedure enWDogWithValue (  signal WDEnable          : std_logic;
                             signal WDTMOutValue28DT0 : std_logic_vector(28 downto 0);
							 signal host_datToMem     : out std_logic_vector(31 downto 0);
                             signal host_memWr        : out std_logic;
                             signal host_memAdd       : out std_logic_vector(10 downto 0)
              ) is
begin
  host_datToMem 			   <= (others => '0'); -- clear host_datToMem
  host_memWr                   <= '1'; 
  host_memAdd(7 downto 5)      <= CSRAdd_7DT5;     -- select CSR memory array
  host_memAdd(4 downto 0)      <= "000" & "11";    -- CSR(3)
  host_datToMem                <= "00" & WDEnable & WDTMOutValue28DT0; -- watchdog enabled & 29 bit timeout counter value (max 0x1fffffff" clk periods
  wait for period;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
end procedure;	

-- ================ Reset and watchdog control END ===============


-- ================ Activate DSP functions START ===============
procedure maxPixelCmd (signal pixelColour : in std_logic_vector(7 downto 0);
                       signal host_datToMem : out std_logic_vector(31 downto 0);
                       signal host_memWr : out std_logic;
                       signal host_memAdd : out std_logic_vector(10 downto 0)
                       ) is
begin
  host_memWr                   <= '1'; 
  host_memAdd(7 downto 5)      <= CSRAdd_7DT5;     -- select CSR memory array
  host_memAdd(4 downto 0)      <= "000" & "00";    -- CSR(0)
  host_datToMem(  7 downto  0) <= pixelColour;
  wait for period;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
  wait for 700*period;
end procedure;	


procedure thresholdCmd (signal threshVal : in std_logic_vector(7 downto 0);
                        signal host_datToMem : out std_logic_vector(31 downto 0);
                        signal host_memWr : out std_logic;
                        signal host_memAdd : out std_logic_vector(10 downto 0)
                       ) is
begin
  host_memWr                   <= '1'; 
  host_memAdd(7 downto 5)      <= CSRAdd_7DT5;     -- select CSR memory array
  host_memAdd(4 downto 0)      <= "000" & "00";    -- CSR(0)
  host_datToMem( 15 downto  8) <= threshVal;       -- build host_datToMem()
  host_datToMem(  7 downto  0) <= thresholdCmd_byte0;
  wait for period;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
  wait for 1200*period;
end procedure;	


procedure cfgHistogram(signal r5: in std_logic_vector(7 downto 0); signal r4: in std_logic_vector(7 downto 0); signal r3: in std_logic_vector(7 downto 0);  
                       signal r2: in std_logic_vector(7 downto 0); signal r1: in std_logic_vector(7 downto 0); signal r0: in std_logic_vector(7 downto 0);
					   signal pixelColour : in std_logic_vector(7 downto 0);
					   signal host_datToMem : out std_logic_vector(31 downto 0);
                       signal host_memWr : out std_logic;
                       signal host_memAdd : out std_logic_vector(10 downto 0)
					  ) is
begin
  host_memWr                   <= '1'; 
  host_memAdd(7 downto 5)      <= CSRAdd_7DT5;        -- select CSR memory base address 
  host_memAdd(4 downto 0)      <= "000" & "10";       -- CSR(2)
  host_datToMem                <= X"0000" & r5 & r4;  -- range(5:4)(7:0)
  wait for period;
  host_memAdd(4 downto 0)      <= "000" & "01";       -- CSR(1)
  host_datToMem                <= r3 & r2 & r1 & r0;  -- range(3:0)(7:0)
  wait for period;
  host_memAdd(4 downto 0)      <= "000" & "00";       -- CSR(0)
  host_datToMem( 31 downto 8)  <= (others => '0'); 
  host_datToMem(  7 downto 0)  <= pixelColour;         -- 00, 10 (red pixel), 001 (histogram) 1 (activate function), X"23"
  wait for period;
  
  host_memAdd(4 downto 0)      <= "000" & "00";    -- CSR(0)
  host_datToMem(  7 downto  0) <= histogramRedCmd_byte0;
  wait for period;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
  wait for 300*period;                                 -- > 32 x 8 pixel histogram steps = 256
end procedure;	


-- -- sobel edge detection
procedure sobelCmd     (signal host_datToMem : out std_logic_vector(31 downto 0);
                        signal host_memWr : out std_logic;
                        signal host_memAdd : out std_logic_vector(10 downto 0)
                       ) is
begin
  host_memWr                   <= '1'; 
  host_memAdd(7 downto 5)      <= CSRAdd_7DT5;     -- select CSR memory array
  host_memAdd(4 downto 0)      <= "000" & "00";    -- CSR(0)
  host_datToMem(  7 downto  0) <= sobelCmd_byte0;
  wait for period;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
  wait for 1200*period;                            -- > 32 x 32 pixel histogram steps = 1024, plus register setup 
end procedure;	

-- ================ Activate DSP functions END ===============



-- ================ Memory wr/rd access procedures START ===============
-- ==== CSR procedures
procedure writeCSRs    (signal CSRArray : in array4x32; 
                          signal host_datToMem : out std_logic_vector(31 downto 0);
                          signal host_memWr : out std_logic;
                          signal host_memAdd : out std_logic_vector(10 downto 0)
                         ) is
begin
  host_memAdd(7 downto 5)      <= CSRAdd_7DT5;       -- select CSR array base address
  host_memWr                   <= '1'; 
  for i in 0 to 3 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i, 2) ); -- generate sub-address 0-3
    host_datToMem <= CSRArray(i);  
    wait for period;
  end loop;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
end procedure;	


procedure writeSingleCSR  (signal CSRAdd : in std_logic_vector(1 downto 0);
						   signal CSRDat : in std_logic_vector(31 downto 0);
                           signal host_datToMem : out std_logic_vector(31 downto 0);
                           signal host_memWr : out std_logic;
                           signal host_memAdd : out std_logic_vector(10 downto 0)
                          ) is
begin
  host_memAdd(7 downto 5)      <= CSRAdd_7DT5;       -- select CSR array base address
  host_memAdd(4 downto 2)      <= "000";       
  host_memWr                   <= '1'; 
  host_memAdd(1 downto 0)      <= CSRAdd; 
  host_datToMem                <= CSRDat;  
  wait for period;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
end procedure;	


procedure readSingleCSRAddress       ( signal CSRAdd : in std_logic_vector(1 downto 0); 
                             signal host_memWr : out std_logic;
                             signal host_memAdd : out std_logic_vector(10 downto 0)
                           ) is
begin
  host_memAdd(7 downto 5)      <= CSRAdd_7DT5; -- select CSR array base address
  host_memAdd(4 downto 2)      <= (others => '0');
  host_memWr                   <= '0'; 
  host_memAdd(1 downto 0)      <= CSRAdd;     -- generate sub-address 0-3
  wait for period;  
  host_memAdd			       <= (others => '0');
end procedure;	


procedure readCSRArray     ( signal host_memWr : out std_logic;
                             signal host_memAdd : out std_logic_vector(10 downto 0)
                           ) is
begin
  host_memAdd(7 downto 5)      <= CSRAdd_7DT5; -- select CSR array base address
  host_memAdd(4 downto 2)      <= (others => '0');
  host_memWr                   <= '0'; 
  for i in 0 to 3 loop 
	host_memAdd(1 downto 0)    <= std_logic_vector( to_unsigned(i, 2) );  -- generate sub-address 0-3
  end loop;
  wait for period;  
  host_memAdd			       <= (others => '0');
end procedure;	



-- ==== sourceMem procedures
procedure writeSourceMem (signal sourceArray : in array32x256; 
                          signal host_datToMem : out std_logic_vector(31 downto 0);
                          signal host_memWr : out std_logic;
                          signal host_memAdd : out std_logic_vector(10 downto 0)
                         ) is
begin
  host_memAdd(7 downto 5)      <= sourceMemAdd_7DT5;                  -- select sourceMem array base address
  host_memWr                   <= '1'; 
  for i in 0 to 31 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i, 5) ); -- generate sub-address 0-31
    for j in 0 to 7 loop
      host_datToMem <= sourceArray(i)( (32*j+31) downto 32*j ); -- write 32-bit data to the selected sourceMem word
    end loop;
    wait for period;
  end loop;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
end procedure;	

procedure writeSameByteToAllSourceMem (signal sourceByte : in std_logic_vector(7 downto 0); 
                          signal host_datToMem : out std_logic_vector(31 downto 0);
                          signal host_memWr : out std_logic;
                          signal host_memAdd : out std_logic_vector(10 downto 0)
                         ) is
begin
  host_memWr                   <= '1'; 
  for i in 0 to 31 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i, 5) ); -- generate sub-address 0-31
    for j in 0 to 7 loop     -- for each of 8 x 32-bit words
		for j in 0 to 3 loop -- generate 32-bit word with sourceByte as each byte
			host_datToMem((j*8+7) downto j*8) <= sourceByte; -- write 32-bit data to the selected sourceMem word
		end loop;
    end loop;
    wait for period;
  end loop;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
end procedure;	

procedure readSourceMemArray ( signal host_memWr : out std_logic;     -- read lower 32-bits of sourceMem
                          signal host_memAdd : out std_logic_vector(10 downto 0)
                         ) is
begin
  host_memAdd(7 downto 5)      <= sourceMemAdd_7DT5;                  -- select resultMem array base address
  host_memWr                   <= '0'; 
  for i in 0 to 31 loop
    host_memAdd(4 downto 0)    <= std_logic_vector( to_unsigned(i, 5) ); -- generate sub-address 0-31
    for j in 0 to 7 loop
      host_memAdd(10 downto 8) <= std_logic_vector( to_unsigned(j, 3) ); -- generate sub-address 0-7
    end loop;
    wait for period;
  end loop;
  host_memAdd			       <= (others => '0');
end procedure;	

procedure readSingleSourceMemAddress ( signal add : in std_logic_vector(4 downto 0);
                             signal host_memWr : out std_logic;
                             signal host_memAdd : out std_logic_vector(10 downto 0)
                           ) is
begin
  host_memAdd(7 downto 5)      <= sourceMemAdd_7DT5; -- select sourceMem array base address
  host_memWr                   <= '0'; 
  host_memAdd(4 downto 0)      <= add;               -- generate sub-address 0-31
  for j in 0 to 7 loop
    host_memAdd(10 downto 8)   <= std_logic_vector( to_unsigned(j, 3) ); -- generate sub-address 0-7
  end loop;
  wait for period;  
  host_memAdd			       <= (others => '0');
end procedure;	



-- ==== resultMem procedures
procedure clearResultMem (signal host_datToMem : out std_logic_vector(31 downto 0); -- write to CSR(3)(31)
                          signal host_memWr : out std_logic;
                          signal host_memAdd : out std_logic_vector(10 downto 0)
                          ) is
begin
  host_memWr                   <= '1'; 
  host_memAdd(7 downto 5)      <= resultMem0Add_7DT5;      			-- select resultMem array base address
  host_memAdd(4 downto 0)      <= "000" & "11";    -- CSR(3)
  host_datToMem(31)            <= '1';
  wait for period;
  host_datToMem(31)            <= '0';
  wait for period;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
end procedure;	

procedure writeResultMem (signal resultArray : in array32x32; 
                          signal host_datToMem : out std_logic_vector(31 downto 0);
                          signal host_memWr : out std_logic;
                          signal host_memAdd : out std_logic_vector(10 downto 0)
                         ) is
begin
  host_memAdd(7 downto 5)      <= resultMem0Add_7DT5;                 -- select resultMem array base address
  host_memWr                   <= '1'; 
  for i in 0 to 31 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i, 5) ); -- generate sub-address 0-31
    host_datToMem <= resultArray(i); -- data 
    wait for period;
  end loop;
  host_memWr                   <= '0'; 
  host_memAdd			       <= (others => '0');
  host_datToMem                <= (others => '0'); 
end procedure;	

procedure readResultMemArray ( signal host_memWr : out std_logic;
                          signal host_memAdd : out std_logic_vector(10 downto 0)
                         ) is
begin
  host_memAdd(7 downto 5)      <= resultMem0Add_7DT5;                 -- select resultMem array base address
  host_memWr                   <= '0'; 
  for i in 0 to 31 loop
    host_memAdd(4 downto 0) <= std_logic_vector( to_unsigned(i, 5) ); -- generate sub-address 0-31
    wait for period;
  end loop;
  host_memAdd			       <= (others => '0');
end procedure;	

procedure readSingleResultMemAddress ( signal add : in std_logic_vector(4 downto 0);
                             signal host_memWr : out std_logic;
                             signal host_memAdd : out std_logic_vector(10 downto 0)
                           ) is
begin
  host_memAdd(7 downto 5)      <= resultMem0Add_7DT5; -- select resultMem array base address
  host_memWr                   <= '0'; 
  host_memAdd(4 downto 0)      <= add;                -- generate sub-address 0-31
  wait for period;  
  host_memAdd			       <= (others => '0');
end procedure;	
-- ================ Memory wr/rd access procedures END ===============



begin



uut: DSPProc -- instantiate unit under test (UUT)
port map ( clk           => clk,       		  
           rst           => rst,
           continue      => continue,
                  		   
           host_memWr    => host_memWr,  			   
           host_memAdd   => host_memAdd,
           host_datToMem => host_datToMem, 	   
           
           datToHost => datToHost
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

  rst 					   <= '0'; -- default signal values
  continue 				   <= '0';
  host_memWr               <= '0'; 
  host_memAdd              <= "00000000000";
  host_datToMem            <= (others => '0');
  CSRAdd                   <= (others => '0'); 
  CSRDat                   <= (others => '0'); 
  add                      <= (others => '0');  
  sourceByte               <= (others => '0'); 
  threshVal                <= (others => '0');
  sourceArray              <= (others => (others => '0'));
  r5                       <= X"f2"; 
  r4                       <= X"e1"; 
  r3                       <= X"d0"; 
  r2                       <= X"cf"; 
  r1                       <= X"be"; 
  r0                       <= X"ad";
  CSRArray                 <= (others => (others => '0'));
  resultArray              <= (others => (others => '0'));
  WDogWDEnable             <= '0';
  WDogWDTMOutValue28DT0    <= (others => '0');


  testNo <= 0; -- include a unique test number to help browsing of the simulation waveform     
  rstProc(rst);  


  testNo <= 81; sourceArray <= sourceArrayG; 
				wait for period;
				writeSourceMem 				( sourceArray, host_datToMem, host_memWr, host_memAdd);
  testNo <= 82; readSourceMemArray 			( host_memWr, host_memAdd);
  testNo <= 83;	threshVal <= X"56"; 
				wait for period; 
				thresholdCmd				( threshVal, host_datToMem, host_memWr, host_memAdd);



  -- == write / read CSRs
  testNo <= 10;	CSRArray <= CSRArrayA; 
				wait for period;
				writeCSRs            		( CSRArray, host_datToMem, host_memWr, host_memAdd);
  testNo <= 11; readCSRArray         		( host_memWr, host_memAdd); 
  testNo <= 12;	CSRAdd <= "01"; 
				CSRDat <= X"45456767"; 
 				wait for period; 
				writeSingleCSR       		( CSRAdd, CSRDat, host_datToMem, host_memWr, host_memAdd);
  testNo <= 13;	CSRAdd <= "10"; 
				wait for period; 
				readSingleCSRAddress 		( CSRAdd, host_memWr, host_memAdd);




  -- == write / read resultMem
  testNo <= 20;	resultArray <= resultArrayA;
				wait for period;
				writeResultMem       		( resultArray, host_datToMem, host_memWr, host_memAdd);
  testNo <= 21;	readResultMemArray   		( host_memWr, host_memAdd);
  testNo <= 22; add <= "11110"; 
				wait for period; 
				readSingleResultMemAddress 	( add, host_memWr, host_memAdd);




  -- == write / read sourceMem
  testNo <= 30; sourceArray <= sourceArrayE; 
				wait for period;
				writeSourceMem 				( sourceArray, host_datToMem, host_memWr, host_memAdd);
  testNo <= 31; readSourceMemArray 			( host_memWr, host_memAdd);
  testNo <= 32; add <= "11110"; 
				wait for period; 
				readSingleSourceMemAddress 	( add, host_memWr, host_memAdd);





  -- == threshold functions 
 
  testNo <= 491; sourceArray <= sourceArrayG; 
				wait for period;
				writeSourceMem 				( sourceArray, host_datToMem, host_memWr, host_memAdd);
  testNo <= 492; rstProc(rst); 
				threshVal <= X"04"; 
				wait for period; 
				thresholdCmd				( threshVal, host_datToMem, host_memWr, host_memAdd);
                readResultMemArray 			( host_memWr, host_memAdd);
  		
 
  testNo <= 40; sourceByte <=X"56";
				wait for period;
				writeSameByteToAllSourceMem	( sourceByte, host_datToMem, host_memWr, host_memAdd);
  testNo <= 41; rstProc(rst); 
				threshVal <= X"56"; 
				wait for period; 
				thresholdCmd				( threshVal, host_datToMem, host_memWr, host_memAdd);
  testNo <= 42;	readResultMemArray 			( host_memWr, host_memAdd);
				CSRAdd <= "00"; 
				wait for period; 
				readSingleCSRAddress 		( CSRAdd, host_memWr, host_memAdd);

  testNo <= 43; rstProc(rst); 
				threshVal <= X"55"; 
				wait for period; 
				thresholdCmd				( threshVal, host_datToMem, host_memWr, host_memAdd);
                readResultMemArray 			( host_memWr, host_memAdd);				

  testNo <= 44; rstProc(rst); 
				WDogWDEnable <= '1';
				WDogWDTMOutValue28DT0 <= '0' & X"fffffff";
				wait for period;
			    enWDogWithValue             (  WDogWDEnable, WDogWDTMOutValue28DT0, host_datToMem, host_memWr, host_memAdd);
				threshVal <= X"57"; 
				wait for period; 
				thresholdCmd				( threshVal, host_datToMem, host_memWr, host_memAdd);
                readResultMemArray 			( host_memWr, host_memAdd);				

  testNo <= 45; sourceByte <=X"72";
				wait for period;
				writeSameByteToAllSourceMem ( sourceByte, host_datToMem, host_memWr, host_memAdd);
  testNo <= 46; rstProc(rst); 
				threshVal <= X"72"; 
				wait for period; 
				thresholdCmd				( threshVal, host_datToMem, host_memWr, host_memAdd);
                readResultMemArray 			( host_memWr, host_memAdd);
  testNo <= 47; rstProc(rst); 
				threshVal <= X"71"; 
				wait for period; 
				thresholdCmd				( threshVal, host_datToMem, host_memWr, host_memAdd);
                readResultMemArray 			( host_memWr, host_memAdd);				
  testNo <= 48; rstProc(rst); 
				threshVal <= X"73"; 
				wait for period; 
				thresholdCmd				( threshVal, host_datToMem, host_memWr, host_memAdd);
                readResultMemArray 			( host_memWr, host_memAdd);				
  testNo <= 49; rstProc(rst); 
				threshVal <= X"72"; 
				wait for period;
				WDogWDEnable <= '0';
				WDogWDTMOutValue28DT0 <= '0' & X"000000f";
				wait for period;
			    enWDogWithValue             (  WDogWDEnable, WDogWDTMOutValue28DT0, host_datToMem, host_memWr, host_memAdd);
                -- times out after 15 clk cycles and set CSR(3)(31) and clears CSR(0)(0) to return control to host. Doesn't assert CSR(0)(7)
				thresholdCmd				( threshVal, host_datToMem, host_memWr, host_memAdd);
				WDogWDEnable <= '1';
				WDogWDTMOutValue28DT0 <= '0' & X"fffffff";
				wait for period;
			    enWDogWithValue             (  WDogWDEnable, WDogWDTMOutValue28DT0, host_datToMem, host_memWr, host_memAdd);
                -- still to test CSR(3)(30) watchdog timer clear (load 0)

 					
			
  -- == maxPixel functions 
  testNo <= 50; sourceArray <= sourceArrayF; 
				wait for period;
				writeSourceMem 				(sourceArray, host_datToMem, host_memWr, host_memAdd);
  testNo <= 51; rstProc(rst); 
				maxPixelCmd					( maxPixelRedCmd_byte0, host_datToMem, host_memWr, host_memAdd);   	
  testNo <= 52; readCSRArray         		( host_memWr, host_memAdd); 
  testNo <= 53;	CSRAdd <= "00"; 
				wait for period; 
				readSingleCSRAddress 		( CSRAdd, host_memWr, host_memAdd);
  testNo <= 55; rstProc(rst); 
  				maxPixelCmd					( maxPixelGreenCmd_byte0, host_datToMem, host_memWr, host_memAdd);
  testNo <= 56; readCSRArray         		( host_memWr, host_memAdd); 
  testNo <= 57; rstProc(rst); 
  				maxPixelCmd					( maxPixelBlueCmd_byte0, host_datToMem, host_memWr, host_memAdd);
  testNo <= 58; readCSRArray         		( host_memWr, host_memAdd); 



  testNo <= 60; rstProc(rst); 
				clearResultMem				( host_datToMem, host_memWr, host_memAdd);
  testNo <= 61; sourceArray <= sourceArrayE; 
				wait for period;
				writeSourceMem 				(sourceArray, host_datToMem, host_memWr, host_memAdd);
  testNo <= 62; r5 <= X"f2"; 
                r4 <= X"e1"; 
                r3 <= X"d0"; 
                r2 <= X"cf"; 
                r1 <= X"be"; 
                r0 <= X"ad";
				wait for period;				
				cfgHistogram				( r5, r4, r3, r2, r1, r0, histogramRedCmd_byte0, host_datToMem, host_memWr, host_memAdd);
  testNo <= 64; readCSRArray         		( host_memWr, host_memAdd); 


  testNo <= 71; sourceArray <= sourceArrayB; 
				rstProc(rst); 
				wait for period; 
				sobelCmd     				( host_datToMem, host_memWr, host_memAdd);
                readResultMemArray 			( host_memWr, host_memAdd);				


  endOfSim <= true;   		 -- assert flag. Stops clk signal generation in process clkStim
  report "simulation done";   
  wait; 					 -- include to prevent the stim process from repeating execution, since it does not include a sensitivity list
  
end process;


   sourceArrayA <=
   (0     => X"0000000000000000000000000000000000000000000000000000000000000000",      
    1     => X"0000000000000000000000000000000000000000000000000000000000000000",    
    2     => X"0000000000000000000000000000000000000000000000000000000000000000",
    3     => X"0000000000000000000000000000000000000000000000000000000000000000",    
    4     => X"0000000000000000000000000000000000000000000000000000000000000000",    
    5     => X"0000000000000000000000000000000000000000000000000000000000000000",    
    6     => X"0000000000000000000000000000000000000000000000000000000000000000",    
    7     => X"0000000000000000000000000000000000000000000000000000000000000000",    
    8     => X"0000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000",    
    9     => X"0000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000",    
   10     => X"0000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000",    
   11     => X"0000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000",    
   12     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   13     => X"0000000000000000000000000000000000000000000000000000000000000000",
   14     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   15     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   16     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   17     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   18     => X"0000000000000000000000000000000000000000000000000000000000000000",
   19     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   20     => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
   21     => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
   22     => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
   23     => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
   24     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   25     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   26     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   27     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   28     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   29     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   30     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   31     => X"0000000000000000000000000000000000000000000000000000000000000000",    
   others => X"0000000000000000000000000000000000000000000000000000000000000000"
   );
  
   sourceArrayB <=
   (0  => X"0123456789123456789123456789123456789123456789123456789123445670",      
    1  => X"0333333333333333333333333333333333333333333333333333333333333330",    
    2  => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
    3  => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
    4  => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
    5  => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
    6  => X"000000000000000000000000dddddddddddddddd000000000000000000000000",    
    7  => X"000000000000000000000000dddddddddddddddd000000000000000000000000", 
    8  => X"000000000000000000000000dddddddddddddddd000000000000000000000000",    
    9  => X"000000000000000000000000dddddddddddddddd000000000000000000000000",   
    10 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",   
    11 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",   
    12 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",   
    13 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",   
    14 => X"000000000000000000000000dddddddddddddddd000000000000000000000000",   
    15 => X"000000000000000000000000dddddddddddddddd000000000000000000000000", 
    16 => X"000000000000000000000000dddddddddddddddd000000000000000000000000",      
    17 => X"000000000000000000000000dddddddddddddddd000000000000000000000000",    
    18 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
    19 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
    20 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
    21 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",    
    22 => X"000000000000000000000000dddddddddddddddd000000000000000000000000",    
    23 => X"000000000000000000000000dddddddddddddddd000000000000000000000000", 
    24 => X"000000000000000000000000dddddddddddddddd000000000000000000000000",    
    25 => X"000000000000000000000000dddddddddddddddd000000000000000000000000",   
    26 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",   
    27 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",   
    28 => X"0000000000000000dddddddddddddddddddddddddddddddd0000000000000000",   
    29 => X"0000000000000000efffddddddddddddddddddddddddddee0000000000000000",   
    30 => X"0000000000000000000000000000000000000000000000000000000000000000",   
    31 => X"0444444444444444444444444444444444444444444444444444444444444440",
   others => X"0767676767676767676767676767676767676767676767676767676767676760"
  );

  sourceArrayC <=
   (0     => X"ffeeddccbbaa99881122334455667788ffeeddccbbaa99881122334455667788",      
    1     => X"1234567812345678123456781234567812345678123456781234567812345678",      
    2     => X"7867564578675645786756457867564578675645786756457867564578675645",      
    3     => X"11eeddccbbaa99881122334455667788ffeeddccbbaa99881122334455667744",      
    4     => X"0000000000000000000000000000000000000000000000000000000000000000",      
    5     => X"0000000000000000000000000000000000000000000000000000000000000000",      
    6     => X"0000000000000000000000000000000000000000000000000000000000000000",      
    7     => X"0000000000000000000000000000000000000000000000000000000000000000",      
    8     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
    9     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
   10     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
   11     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
   12     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   13     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   14     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   15     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   16     => X"000000000000888888888888eeeeeeeeeeeeeeee888888888888000000000000",      
   17     => X"000000000000888888888888eeeeeeeeeeeeeeee888888888888000000000000",      
   18     => X"000000000000888888888888eeeeeeeeeeeeeeee888888888888000000000000",      
   19     => X"000000000000888888888888eeeeeeeeeeeeeeee888888888888000000000000",      
   20     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   21     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   22     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   23     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   24     => X"000000006666666600000000efdf00000000efdf000000006666666600000000",      
   25     => X"000000006666666600000000efdf00000000efdf000000006666666600000000",      
   26     => X"000000006666666600000000efdf00000000efdf000000006666666600000000",      
   27     => X"000000006666666600000000efdf00000000efdf000000006666666600000000",      
   28     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   29     => X"9823982398239823982398239823982398239823982398239823982398239823",  
   30     => X"ffeeddccbbaa99881122334455667788ffeeddccbbaa99881122334455667788",      
   others => X"1234567812345678123456781234567812345678123456781234567812345678"
  );

  sourceArrayD <=
   (0     => X"33eeddccbbaa991122334455667788aaaa887766554433221199aabbccddee33",      
    1     => X"00112233445566778899aabbccddeebbbbeeddccbbaa99887766554433221100",      
    2     => X"2222ddcc3333cccc5555dddd6666777777776666dddd5555cccc3333ccdd2222",      
    3     => X"4477447799bbddbb33336666eeeeeeeeeeeeeeee66663333bbddbb9977447744",      
    4     => X"0000000000000000000000000000000000000000000000000000000000000000",      
    5     => X"0000000000000000000000000000000000000000000000000000000000000000",      
    6     => X"0000000000000000000000000000000000000000000000000000000000000000",      
    7     => X"0000000000000000000000000000000000000000000000000000000000000000",      
    8     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
    9     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
   10     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
   11     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
   12     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   13     => X"00ff000000000000000000000000000000000000000000000000000000000000",      
   14     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   15     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   16     => X"000000000000888844448888eeeeeeeeeeeeeeee888844448888000000000000",      
   17     => X"000000000000888844448888eeeeeeeeeeeeeeee888844448888000000000000",      
   18     => X"000000000000888844448888eeeeeeeeeeeeeeee888844448888000000000000",      
   19     => X"000000000000888844448888eeeeeeeeeeeeeeee888844448888000000000000",      
   20     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   21     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   22     => X"000000000000000000000000000000000000000000000000000000000000ff00",      
   23     => X"0000000000000000000000000000000000000000000000000000000000000000",      
   24     => X"000000006666666600000000ddeefd0000fdeedd000000006666666600000000",      
   25     => X"000000006666666600000000ddee33000033eedd000000006666666600000000",      
   26     => X"000000ff6666666600000000ddeefe0000feeedd000000006666666600000000",      
   27     => X"000000006666666600000000ddeefc0000fceedd000000006666666600000000",      
   28     => X"fbeeddccbbaa9911223344556677883333887766554433221199aabbccddeefb",      
   29     => X"00112233445566778899aabbccddee4444eeddccbbaa99887766554433221100",      
   30	  => X"22221111333300005555dddd6666777777776666dddd55550000333311112222",      
   others => X"4477447799bbddcc33336666eeeeeeeeeeeeeeee66663333ccddbb9977447744" 
);

  sourceArrayE <=
     (0     => X"33eeddccbbaa991122334455667788aaaa887766554433221199aabbccddee33",      
      1     => X"00112233445566778899aabbccddeebbbbeeddccbbaa99887766554433221100",      
      2     => X"2222ddcc3333cccc5555dddd6666777777776666dddd5555cccc3333ccdd2222",      
      3     => X"4477447799bbddbb33336666eeeeeeeeeeeeeeee66663333bbddbb9977447744",      
      4     => X"0000000000000000000000000000000000000000000000000000000000000000",      
      5     => X"0000000000000000000000000000000000000000000000000000000000000000",      
      6     => X"0000000000000000000000000000000000000000000000000000000000000000",      
      7     => X"0000000000000000000000000000000000000000000000000000000000000000",      
      8     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
      9     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
     10     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
     11     => X"000000000000bbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbb000000000000",      
     12     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     13     => X"00ff000000000000000000000000000000000000000000000000000000000000",      
     14     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     15     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     16     => X"000000000000888844448888eeeeeeeeeeeeeeee888844448888000000000000",      
     17     => X"000000000000888844448888eeeeeeeeeeeeeeee888844448888000000000000",      
     18     => X"000000000000888844448888eeeeeeeeeeeeeeee888844448888000000000000",      
     19     => X"000000000000888844448888eeeeeeeeeeeeeeee888844448888000000000000",      
     20     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     21     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     22     => X"000000000000000000000000000000000000000000000000000000000000ff00",      
     23     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     24     => X"000000006666666600000000ddeefd0000fdeedd000000006666666600000000",      
     25     => X"000000006666666600000000ddee33000033eedd000000006666666600000000",      
     26     => X"000000ff6666666600000000ddeefe0000feeedd000000006666666600000000",      
     27     => X"000000006666666600000000ddeefc0000fceedd000000006666666600000000",      
     28     => X"fbeeddccbbaa9911223344556677883333887766554433221199aabbccddeefb",      
     29     => X"00112233445566778899aabbccddee4444eeddccbbaa99887766554433221100",      
     30	  => X"22221111333300005555dddd6666777777776666dddd55550000333311112222",      
     others => X"4477447799bbddcc33336666eeeeeeeeeeeeeeee66663333ccddbb9977447744" 
  );


  sourceArrayF <=
     (0     => X"01234567891234567891234567891234567891234567891234567891234456e3",      
      1     => X"0123456789123456789123456789123456789123456789123456789123445678",      
      2     => X"e11245678912345678912345678912345678912345678912345678912344e270",      
      3     => X"0000000000000000000000000000000000000000000000000000000000000000",      
      4     => X"0000000000000000000000000000000000000000000000000000000000000000",      
      5     => X"0000000000000000000000000000000000000000000000000000000000000000",      
      6     => X"0000000000000000000000000000000000000000000000000000000000000000",      
      7     => X"0000000000000000000000000000000000000000000000000000000000000000",      
      8     => X"0000000000000000000000000000000000000000000000000000000000000000",      
      9     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     10     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     11     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     12     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     13     => X"00ff000000000000000000000000000000000000000000000000000000000000",      
     14     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     15     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     16     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     17     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     18     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     19     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     20     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     21     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     22     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     23     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     24     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     25     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     26     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     27     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     28     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     29     => X"0000000000000000000000000000000000000000000000000000000000000000",      
     30	    => X"0000000000000000000000000000000000000000000000000000000000000000",      
     others => X"0000000000000000000000000000000000000000000000000000000000000000" 
  );


  sourceArrayG <=
     (0     => X"1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100",      
      1     => X"3f3e3d3c3b3a393837363534333231302f2e2d2c2b2a29282726252423222120",      
      2     => X"5f5e5d5c5b5a595857565554535251504f4e4d4c4b4a49484746454443424140",      
      3     => X"7f7e7d7c7b7a797877767574737271706f6e6d6c6b6a69686766656463626160",      
      4     => X"9f9e9d9c9b9a999897969594939291908f8e8d8c8b8a89888786858483828180",      
      5     => X"bfbebdbcbbbab9b8b7b6b5b4b3b2b1b0afaeadacabaaa9a8a7a6a5a4a3a2a1a0",      
      6     => X"dfdedddcdbdad9d8d7d6d5d4d3d2d1d0cfcecdcccbcac9c8c7c6c5c4c3c2c1c0",      
      7     => X"fffefdfcfbfaf9f8f7f6f5f4f3f2f1f0efeeedecebeae9e8e7e6e5e4e3e2e1e0",      
      8     => X"1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100",      
      9     => X"3f3e3d3c3b3a393837363534333231302f2e2d2c2b2a29282726252423222120",      
     10     => X"5f5e5d5c5b5a595857565554535251504f4e4d4c4b4a49484746454443424140",      
     11     => X"7f7e7d7c7b7a797877767574737271706f6e6d6c6b6a69686766656463626160",      
     12     => X"9f9e9d9c9b9a999897969594939291908f8e8d8c8b8a89888786858483828180",      
     13     => X"bfbebdbcbbbab9b8b7b6b5b4b3b2b1b0afaeadacabaaa9a8a7a6a5a4a3a2a1a0",      
     14     => X"dfdedddcdbdad9d8d7d6d5d4d3d2d1d0cfcecdcccbcac9c8c7c6c5c4c3c2c1c0",      
     15     => X"fffefdfcfbfaf9f8f7f6f5f4f3f2f1f0efeeedecebeae9e8e7e6e5e4e3e2e1e0",      
     16     => X"1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100",      
     17     => X"3f3e3d3c3b3a393837363534333231302f2e2d2c2b2a29282726252423222120",      
     18     => X"5f5e5d5c5b5a595857565554535251504f4e4d4c4b4a49484746454443424140",      
     19     => X"7f7e7d7c7b7a797877767574737271706f6e6d6c6b6a69686766656463626160",      
     20     => X"9f9e9d9c9b9a999897969594939291908f8e8d8c8b8a89888786858483828180",      
     21     => X"bfbebdbcbbbab9b8b7b6b5b4b3b2b1b0afaeadacabaaa9a8a7a6a5a4a3a2a1a0",      
     22     => X"dfdedddcdbdad9d8d7d6d5d4d3d2d1d0cfcecdcccbcac9c8c7c6c5c4c3c2c1c0",      
     23     => X"fffefdfcfbfaf9f8f7f6f5f4f3f2f1f0efeeedecebeae9e8e7e6e5e4e3e2e1e0",      
     24     => X"1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100",      
     25     => X"3f3e3d3c3b3a393837363534333231302f2e2d2c2b2a29282726252423222120",      
     26     => X"5f5e5d5c5b5a595857565554535251504f4e4d4c4b4a49484746454443424140",      
     27     => X"7f7e7d7c7b7a797877767574737271706f6e6d6c6b6a69686766656463626160",      
     28     => X"9f9e9d9c9b9a999897969594939291908f8e8d8c8b8a89888786858483828180",      
     29     => X"bfbebdbcbbbab9b8b7b6b5b4b3b2b1b0afaeadacabaaa9a8a7a6a5a4a3a2a1a0",      
     30	    => X"dfdedddcdbdad9d8d7d6d5d4d3d2d1d0cfcecdcccbcac9c8c7c6c5c4c3c2c1c0",      
     others => X"fffefdfcfbfaf9f8f7f6f5f4f3f2f1f0efeeedecebeae9e8e7e6e5e4e3e2e1e0" 
  );


resultArrayA <=
     (0     => X"ccddee33",      
      1     => X"33221100",      
      2     => X"ccdd2222",      
      3     => X"77447744",      
      4     => X"00000000",      
      5     => X"00000000",      
      6     => X"00000000",      
      7     => X"00000000",      
      8     => X"00000000",      
      9     => X"00000000",      
     10     => X"00000000",      
     11     => X"00000000",      
     12     => X"00000000",      
     13     => X"00000000",      
     14     => X"00000000",      
     15     => X"00000000",      
     16     => X"00000000",      
     17     => X"00000000",      
     18     => X"00000000",      
     19     => X"00000000",      
     20     => X"00000000",      
     21     => X"00000000",      
     22     => X"0000ff00",      
     23     => X"00000000",      
     24     => X"00000000",      
     25     => X"00000000",      
     26     => X"00000000",      
     27     => X"00000000",      
     28     => X"ccddeefb",      
     29     => X"33221100",      
     30	    => X"11222233",      
     others => X"77447744" 
  );
  
  CSRArrayA <=
     (0     => X"beefcafe",      
      1     => X"f00dcafe",      
      2     => X"deadbeef",      
     others => X"7edcba98"  -- (31) is synchronously ld0 in result memory 
  );

end Behavioral;
