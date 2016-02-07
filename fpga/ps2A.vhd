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
			  int_req          : out std_logic;
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
	
	
	COMPONENT fifo
	 GENERIC(
        depth_log2  : integer; 
        hwm_space   : integer;
        width       : integer
    );
	PORT(
		clk : IN std_logic;
		reset : IN std_logic;
		write_en : IN std_logic;
		read_en : IN std_logic;
		data_in : IN std_logic_vector(7 downto 0);          
		write_ready : OUT std_logic;
		read_ready : OUT std_logic;
		data_out : OUT std_logic_vector(7 downto 0);
		high_water_mark : OUT std_logic;
		dbg_read_ptr : out std_logic_vector(depth_log2-1 downto 0);
		dbg_write_ptr : out std_logic_vector(depth_log2-1 downto 0)
		);
	END COMPONENT;


 
  signal fifoDataOut  : std_logic_vector(7 downto 0); -- wire Fifo->Data Bus
  signal intEnableRegister : std_logic;
  signal ps2Data : std_logic_vector(7 downto 0);
  signal  dataReady,oldDataReady, dataReadyLatch,resDRLatch : std_logic;
  signal fifoDataReady, fifoReadEn, dataReadEn, notFull, fifoReset : std_logic; 
  signal oldFifoReady : std_logic;
  signal interrupt : std_logic; -- Interrupt Request 
  signal rdCycleOld : std_logic; -- read cycle detection 
  signal fifoRdEn : std_logic; -- Signal for FIFO to increment read pointer 
  signal dbgReadPtr, dbgWritePtr : std_logic_vector(3 downto 0);
  
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
	
	
	ps2fifo: fifo
    generic map(
        depth_log2 => 4,  -- 16 Bytes FIFO
        hwm_space  => 1,
        width      => 8
    )
	PORT MAP(
		clk => clk,
		reset => fifoReset,
		write_en => dataReadyLatch,
		write_ready => notFull,
		read_en => fifoRdEn , -- will increment read pointer on clock
		read_ready => fifoDataReady,
		data_in => ps2Data,
		data_out => fifoDataOut,
		--high_water_mark => 
		dbg_read_ptr => dbgReadPtr,
		dbg_write_ptr => dbgWritePtr
	);
	
	
	-- combinatorial logic
	
	int_req <= interrupt; 
	
	dataReadEn <= cs and req_read and (not AdrBus(1)) and AdrBus(0); -- Read from Adr x1 
	
	
	-- CPU Output Bus Multiplexer
	
	process(AdrBus,interrupt,fifoDataOut) begin	 	 
       case AdrBus(1 downto 0) is 
			 when "00" => data_out<= interrupt&"00000" & intEnableRegister & fifoDataReady;						    
			 when "01" => data_out <= fifoDataOut;		
          when "11" => data_out <= dbgReadPtr & dbgWritePtr;			 
			 when others => data_out <= (others => 'X');
		  end case;	 	
   end process;	
	
	
	-- Synchronous logic
	
--	process(dataReady,resDRLatch) begin
--	  if resDRLatch='1' then
--	    dataReadyLatch<='0';
--	  elsif rising_edge(dataReady) then
--	    dataReadyLatch<='1';
--	  end if;	 
--	end process;
	
	
	process(clk) begin 
	
	  
	  -- Write to Bit 1 of the control port will set/reset the IntEnable Flag
     -- The interrupt is acknowledged with writing a 1 to bit 7 of the control port 	  
	
	  if rising_edge(clk) then
	    -- init defaults
	    fifoReset<='0';
		 
		 oldFifoReady<= fifoDataReady;
		 
		 rdCycleOld <= dataReadEn;
		 if rdCycleOld = '1' and dataReadEn = '0' then -- detect end of read cycle
		    fifoRdEn <= '1';
		 else	 
		    fifoRdEn <= '0';
		 end if; 	
	  	
       oldDataReady<=dataReady;
		 
		 if oldDataReady='0' and dataReady='1' then -- dataReady assert detected
		   dataReadyLatch<='1';
		 else
       	dataReadyLatch<='0';
       end if;			
		
	    if reset='1' then  
			intEnableRegister<='0';
         fifoReset<= '1';			
	    elsif req_write='1' and cs='1' and AdrBus(0)='0' then -- write to control port
		 			
			if data_in(7) = '1' then -- int Acknwoledge
			   interrupt <= '0'; 
			end if;
			if data_in(6) = '1' then -- controller Reset 
			   fifoReset<= '1';
				interrupt <= '0';
			end if;
			
			intEnableRegister<=data_in(1);	

		 -- Interrupt is asserted when FifoReady changes from not ready to ready 
		 -- and intEnableFlag is set to 1 
		 elsif oldFifoReady ='0' and fifoDataReady='1'  and intEnableRegister='1' then
			  interrupt <= '1';				
	    end if;		 
		 -- Reset Logic for DataReadyLatch
--		 if dataReadyLatch='1' then	
--		   resDRLatch<='1'; -- clear Latch 
--	    else
--	      resDRLatch<='0';
--		 end if; 
	  end if;
	
	
	end process;
	

end Behavioral;

