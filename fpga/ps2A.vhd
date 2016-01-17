----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:18:43 01/16/2016 
-- Design Name: 
-- Module Name:    ps2A - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity ps2A is 
 port (     -- Bus Interface
			  clk              : in  std_logic;
           reset            : in  std_logic;
           AdrBus      		 : in  std_logic_vector(1 downto 0);
           data_in          : in  std_logic_vector(7 downto 0);
           data_out         : out std_logic_vector(7 downto 0);
           cs               : in  std_logic; -- chip select 
           req_read         : in  std_logic;
			  req_write			 : in  std_logic;
			  interrupt        : out std_logic;
			  --
			  clk32Mhz			 : in  std_logic;
			  ps2_clk      	 : IN  STD_LOGIC;                     --clock signal from PS/2 keyboard
           ps2_data    	    : IN  STD_LOGIC                     --data signal from PS/2 keyboard
           
    );
end ps2A;

architecture Behavioral of ps2A is

   COMPONENT ps2_keyboard
	 GENERIC(
    clk_freq              : INTEGER;
    debounce_counter_size : INTEGER );         --set such that (2^size)/clk_freq = 5us (size = 8 for 50MHz)
	PORT(
		clk : IN std_logic;
		ps2_clk : IN std_logic;
		ps2_data : IN std_logic;          
		ps2_code_new : OUT std_logic;
		ps2_code : OUT std_logic_vector(7 downto 0)
		);
	END COMPONENT;


  signal dataRegister : std_logic_vector(7 downto 0); -- Input register
  signal statusRegister,intEnableRegister : std_logic;
  signal ps2Data : std_logic_vector(7 downto 0);
  signal  dataReady,dataReadyLatch,resDRLatch : std_logic;
  
  signal clk32b : std_logic ; -- buffered clock

  
begin

  clk32buf : BUFG
  port map
   (O => clk32b,
    I => clk32Mhz);

  
  ips2PortA:  ps2_keyboard
  generic map (
    clk_freq => 32_000_000,
	 debounce_counter_size => 8
  )
  PORT MAP(
		clk => clk32b,
		ps2_clk => ps2_clk,
		ps2_data => ps2_data ,
		ps2_code_new => dataReady,
		ps2_code => ps2Data
	);
	
	
	-- combinatorial logic
	
	
	
	-- CPU Output Bus Multiplexer
	
	process(AdrBus) begin	 	 
       case AdrBus(0) is 
			 when '0' => data_out<= "000000" & intEnableRegister & statusRegister;						    
			 when '1' => data_out <= dataRegister;			 
			 when others => data_out <= (others => 'X');
		  end case;	 	
   end process;	
	
	
	-- Synchronous logic
	
	process(dataReady,resDRLatch) begin
	  if resDRLatch='1' then
	    dataReadyLatch<='0';
	  elsif rising_edge(dataReady) then
	    dataReadyLatch<='1';
	  end if;	 
	end process;
	
	
	process(clk) begin 

     -- The Status Register is set when a new char has received by the PS2 controller
	  -- it is cleared when reading from the data port   
	  -- clearing has priority over set - so in case of an overlap the status bit will be set
	  -- on next clk after the I/O cycle 
	  -- Write to Bit 1 of the control port will set/reset the IntEnable Flag
     -- The interrupt is acknowledged with writing a 1 to bit 7 of the control port 	  
	
	  if rising_edge(clk) then 
	    if reset='1' then  
	      statusRegister<='0';
			intEnableRegister<='0';		  	  
	    elsif req_write='1' and cs='1' and AdrBus(0)='0' then -- write to control port
		 			
			if data_in(7) = '1' then -- int Acknwoledge
			   interrupt <= '0'; 
			end if;
			
			intEnableRegister<=data_in(1);	
			
		 elsif req_read = '1' and cs='1' and AdrBus(0)='1' then -- read from data port
			statusRegister<='0'; -- will reset status Register	
			
		 elsif dataReadyLatch='1' then 
		    -- Latch Data from Keyboard Controller to I/O registers
	      statusRegister<='1';
		   dataRegister<=ps2Data;
			if intEnableRegister='1' then
			  interrupt <= '1';
			end if;  
			resDRLatch<='1'; -- clear Latch 
		 else
			resDRLatch<='0';
	    end if;		 
	  end if;
	
	
	end process;
	

end Behavioral;

