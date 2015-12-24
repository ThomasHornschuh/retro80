----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    00:49:30 12/21/2015 
-- Design Name: 
-- Module Name:    vgatop - Behavioral 
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


-- Control register. Individual control signal
--  cur_mode  <= octl(4); 
--  cur_blink <= octl(5); 
--  cur_en    <= octl(6); 
--  vga_en    <= octl(7); 
--  ctl_r     <= octl(2);
--  ctl_g     <= octl(1);
--  ctl_b     <= octl(0);


----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vgatop is
    Port (
	        -- Video Output 
           O_VSYNC : out  STD_LOGIC;
           O_HSYNC : out  STD_LOGIC;
           O_VIDEO_B : out  STD_LOGIC_VECTOR (3 downto 0);
           O_VIDEO_G : out  STD_LOGIC_VECTOR (3 downto 0);
           O_VIDEO_R : out  STD_LOGIC_VECTOR (3 downto 0);
			  
			  -- Oszillator Clock  
           clk32Mhz : in  STD_LOGIC;
			  
			  -- CPU  Interface to Video RAM und Registers
			  DBOut : out  STD_LOGIC_VECTOR (7 downto 0);
           DBIn : in  STD_LOGIC_VECTOR (7 downto 0);
           AdrBus : in  STD_LOGIC_VECTOR (11 downto 0);
			  ENA : in  STD_LOGIC;
           WREN : in  STD_LOGIC;
			  clkA : in STD_LOGIC; -- CPU Bus  Clock
			  IO_cs : in STD_LOGIC; -- IO Register Chip Select
			  
           I_RESET : in  STD_LOGIC);
end vgatop;

architecture Behavioral of vgatop is
  
signal RESET,RES1 : STD_LOGIC;

signal clk25 : std_logic;
signal RomAdr : STD_LOGIC_VECTOR(11 DOWNTO 0);
signal RomData :  STD_LOGIC_VECTOR(7 DOWNTO 0);
signal r,g,b : std_logic;

signal VideoAdr : std_logic_vector(11 downto 0);
signal VideoData : STD_LOGIC_VECTOR(7 DOWNTO 0);

signal crx_oreg    : std_logic_vector(7 downto 0) := "00000000";
signal cry_oreg    : std_logic_vector(7 downto 0) := "00000000";
signal ctl_oreg    : std_logic_vector(7 downto 0) :="11110010";

signal VRAMDBOut   : std_logic_vector(7 downto 0); 




COMPONENT vga80x40
	PORT(
		reset : IN std_logic;
		clk25MHz : IN std_logic;
		TEXT_D : IN std_logic_vector(7 downto 0);
		FONT_D : IN std_logic_vector(7 downto 0);
		ocrx : IN std_logic_vector(7 downto 0);
		ocry : IN std_logic_vector(7 downto 0);
		octl : IN std_logic_vector(7 downto 0);          
		TEXT_A : OUT std_logic_vector(11 downto 0);
		FONT_A : OUT std_logic_vector(11 downto 0);
		R : OUT std_logic;
		G : OUT std_logic;
		B : OUT std_logic;
		hsync : OUT std_logic;
		vsync : OUT std_logic
		);
	END COMPONENT;


component clk25Mhz
port
 (-- Clock in ports
  CLK_IN1           : in     std_logic;
  -- Clock out ports
  CLK_OUT1          : out    std_logic
 );
end component;



COMPONENT fontrom
   generic (RamFileName : string );
	PORT(
		clka : IN std_logic;
		addra : IN std_logic_vector(11 downto 0);          
		douta : OUT std_logic_vector(7 downto 0)
		);
END COMPONENT;

COMPONENT VideoRam
   generic (RamFileName : string);
	PORT(
		DBIn : IN std_logic_vector(7 downto 0);
		AdrBus : IN std_logic_vector(11 downto 0);
		ENA : IN std_logic;
		WREN : IN std_logic;
	   clkA : in STD_LOGIC; 
		
		VAdr : IN std_logic_vector(11 downto 0);
		CLK : IN std_logic;          
		DBOut : OUT std_logic_vector(7 downto 0);
		VData : OUT std_logic_vector(7 downto 0)
		);
END COMPONENT;



begin

 -- Pixel Clock generator
 clk1 : clk25Mhz
  port map
   (-- Clock in ports
    CLK_IN1 => clk32Mhz,
    -- Clock out ports
    CLK_OUT1 => clk25);
	 
	 
 fontMem : fontrom
  generic map (RamFileName => "./lat0-12.mem")
  PORT MAP (
    clka => clk25,
    addra => RomAdr,
    douta => RomData
  );	 
  
  
  	Inst_VideoRam: VideoRam 
	generic map (RamFileName => "./vramtest.mem")
	PORT MAP(
		DBOut => VRAMDBOut ,
		DBIn => DBIn,
		AdrBus => AdrBus,
		ENA => ENA,
		WREN => WREN,
		clkA => clkA,
		
		VAdr => VideoAdr,
		VData => VideoData,
		CLK => clk25
	);
  
  Inst_vga80x40: vga80x40 PORT MAP(
		reset => reset,
		clk25MHz => clk25,
		TEXT_A => VideoAdr,
		TEXT_D => VideoData,
		FONT_A => RomAdr,
		FONT_D => RomData,
		ocrx => crx_oreg ,
		ocry => cry_oreg,
		octl => ctl_oreg,
		R => r,
		G => g,
		B => b,
		hsync => O_HSYNC,
		vsync => O_VSYNC
	);
	
	-- combinatorial logic
	
	-- CPU Output Bus Multiplexer
	
	
	process(IO_cs,AdrBus) begin
	  if IO_cs = '0' then 
	    DBOut <= VRAMDBOut;
     else 		 
       case AdrBus(1 downto 0) is 
			 when "00" => DBOut <= crx_oreg;
			 when "01" => DBOut <= cry_oreg;
			 when "10" => DBOut <= ctl_oreg;
			 when others => DBOut <= (others => 'X');
		end case;	 
	 end if;	
   end process;	
	
	
	
	-- Synchronous logic
	
	process (r,g,b) begin
	  for i in 0 to 3 loop 
        O_VIDEO_R(i) <= r;
		  O_VIDEO_G(i) <= g;
		  O_VIDEO_B(i) <= b;
	  end loop;
   end process;

-- RESET circuit
  -- Two FF (RES1=>RESET=>) behind each other
  -- assynchronous assert of RESET when I_RESET is asserted
  -- synchronous clear of RESET in two clocks
  
  process(clk25,I_RESET) begin
   
	 if I_RESET = '1' then
	   RES1 <= '1';
	   RESET <= '1';
	 elsif rising_edge(clk25) then
      RES1 <= '0';
		RESET <= RES1;
	 end if;	
    
  end process;
	
-- I/O Register Processing
  process(ClkA) begin
	
	 if rising_edge(ClkA) then
	   if I_RESET='1' then	
			crx_oreg    <=  "00000000";
			cry_oreg    <=  "00000000";
			ctl_oreg    <=  "11110010";
		elsif IO_cs='1' then	
		  if wren = '1' then -- write register
		    case AdrBus(1 downto 0) is 
			   when "00" => crx_oreg <= DBIn;
				when "01" => cry_oreg <= DBIn;
				when "10" => ctl_oreg <= DBIn;
				when others =>
			 end case;           			 		    
	    end if;
      end if; 		
	 end if;			
  end process;

end Behavioral;

