-- DSP_decodeCmdFSM

-- Description
-- generates go signal pulse to DSP function
-- FSM waits for all active signals to deassert before checking CSR again for new command, i.e, CSR(0) and CSR(3:1)
-- Asserts WDTimeout if watchdog timer is active and reaches max configured value

-- command field reference
--	case command is 
--		when "000" =>  DSP_goIndex(0) <= '1'; -- maxPixel
--		when "001" =>  DSP_goIndex(1) <= '1'; -- histogram
--		when "010" =>  DSP_goIndex(2) <= '1'; -- threshold
--		when "011" =>  DSP_goIndex(3) <= '1'; -- sobel
--      not used currently 
--		 when "100" =>  DSP_goIndex(4) <= '1'; 
--		 when "101" =>  DSP_goIndex(5) <= '1'; 
--		 when "110" =>  DSP_goIndex(6) <= '1'; 
--		 when "111" =>  DSP_goIndex(7) <= '1'; 
--		when others  => null;
--	end case;			

-- Signal dictionary FM TBD
-- Refer to WDogTimer.vhd for watchdog timer description

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.arrayPackage.all;

entity DSP_decodeCmdAndWDogCtrl is 
    Port (clk  	           : in  STD_LOGIC;
          rst              : in  STD_LOGIC;		  
          CSR              : in array4x32;
		  DSP_activeIndex  : in  std_logic_vector(5 downto 0);
          DSP_goIndex      : out std_logic_vector(5 downto 0);
		  WDTimeout        : out std_logic
          );	
end DSP_decodeCmdAndWDogCtrl;

architecture RTL of DSP_decodeCmdAndWDogCtrl is
type stateType is (idle, waitForDone); -- declare enumerated state type
signal CS, NS         : stateType;              -- declare state signals 
signal intDSP_goIndex : std_logic_vector(7 downto 0);
signal DSPMaster      : std_logic;
signal command        : std_logic_vector(2 downto 0);

begin

asgnDSP_goIndex_i: DSP_goIndex <= intDSP_goIndex(5 downto 0);

asgnSelDSPMaster_i: DSPMaster <= CSR(0)(0);          -- asserted => DSP function is active, deasserted => DSP function is not active, host active
asgnCommand_i:      command   <= CSR(0)(3 downto 1); -- command fields

decodeCmd_i: process (CS, DSPMaster, DSP_activeIndex, command)
begin
  NS <= CS; -- default
  intDSP_goIndex <= (others => '0'); 
  case CS is 
	when idle => 
		if DSPMaster = '1' then 
			if unsigned(command) < "110" then -- legal commands are = 0 - 5
				intDSP_goIndex(to_integer(unsigned(command)))  <= '1'; -- assert DSP function go signal 
				NS <= waitForDone;
			end if;
		end if;
	when waitForDone => 
		if DSP_activeIndex = "000000" then -- wait for DSP task done, i.e, active signals are all deasserted
			NS <= idle; 
		end if;
	when others => 
		null;
  end case;
end process;

stateReg_i: process (clk, rst)
begin
  if rst = '1' then 		
    CS <= idle;		
  elsif clk'event and clk = '1' then 
    CS <= NS;
  end if;
end process; 

WDogTimer_i: WDogTimer
Port map(   clk  	        => clk, 	        
            rst             => rst,   
			CSR             => CSR,
			DSP_activeIndex => DSP_activeIndex,
			WDTimeout       => WDTimeout
			);

end RTL;