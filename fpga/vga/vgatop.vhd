----------------------------------------------------------------------------------
--+ RETRO80
--+ An 8-Bit Retro Computer running Digital Research MP/M II and CP/M. 
--+ Based on Will Sowerbutts  SOCZ80 Project:
--+ http://sowerbutts.com/
--+ RETRO80 extensions (c) 2015-2016 by Thomas Hornschuh
--+ This project is licensed under the GPLV3: https://www.gnu.org/licenses/gpl-3.0.txt



-- Create Date:    00:49:30 12/21/2015 
-- Design Name: 
-- Module Name:    vgatop - Behavioral 
-- VGA Module is based on http://opencores.org/project,interface_vga80x40
-- interfacevga80x40 is licensed under LGPL 
-- IO:
--   xxxxxxx00 : Cursor X register 1..80
--   xxxxxxx01 : Cursor Y register 0..39
--   xxxxxxx11 : Control Register:      

-- Control register. Individual control signal
--  cur_mode  <= octl(4); 
--  cur_blink <= octl(5); 
--  cur_en    <= octl(6); 
--  vga_en    <= octl(7); 
--  ctl_r     <= octl(2);
--  ctl_g     <= octl(1);
--  ctl_b     <= octl(0);

-- Memory: 4KB Page of Video Memory 

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
           --clk32Mhz : in  STD_LOGIC;
			  -- Pixel Clock
			  clk25 : in STD_LOGIC;
			  
			  -- CPU  Interface to Video RAM und Registers
			  DBOut : out  STD_LOGIC_VECTOR (7 downto 0);
           DBIn : in  STD_LOGIC_VECTOR (7 downto 0);
           AdrBus : in  STD_LOGIC_VECTOR (11 downto 0);
			  ENA : in  STD_LOGIC;
			  RDEN : in STD_LOGIC;
           WREN : in  STD_LOGIC;
			  clkA : in STD_LOGIC; -- CPU Bus  Clock
			  IO_cs : in STD_LOGIC; -- IO Register Chip Select
			  
           I_RESET : in  STD_LOGIC);
end vgatop;

architecture Behavioral of vgatop is
  

--signal clk25 : std_logic;
signal RomAdr : STD_LOGIC_VECTOR(11 DOWNTO 0);
signal RomData :  STD_LOGIC_VECTOR(7 DOWNTO 0);
signal r,g,b,hsync,vsync : std_logic;

signal VideoAdr : std_logic_vector(11 downto 0);
signal VideoData : STD_LOGIC_VECTOR(7 DOWNTO 0);

signal crx_oreg    : std_logic_vector(7 downto 0) := "00000000";
signal cry_oreg    : std_logic_vector(7 downto 0) := "00000000";
signal ctl_oreg    : std_logic_vector(7 downto 0) :="11110010";

signal VRAMDBOut   : std_logic_vector(7 downto 0); 

-- IO blocks
signal iob_r,iob_g,iob_b : STD_LOGIC_VECTOR (3 downto 0);
signal iob_hsync, iob_vsync : std_logic;
attribute IOB : string; 

attribute IOB of iob_r : signal is "TRUE"; 
attribute IOB of iob_g : signal is "TRUE";
attribute IOB of iob_b : signal is "TRUE";

attribute IOB of iob_hsync : signal is "TRUE";
attribute IOB of iob_vsync : signal is "TRUE";


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
		clkA : IN std_logic;
		ENA : IN std_logic;
		WREN : IN std_logic;
		RDEN : IN std_logic;
		VAdr : IN std_logic_vector(11 downto 0);
		CLK : IN std_logic;          
		DBOut : OUT std_logic_vector(7 downto 0);
		VData : OUT std_logic_vector(7 downto 0)
		);
END COMPONENT;



begin


	 
	 
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
		RDEN => RDEN,
		clkA => clkA,
		
		VAdr => VideoAdr,
		VData => VideoData,
		CLK => clk25
	);
  
  Inst_vga80x40: vga80x40 PORT MAP(
		reset => I_RESET,
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
		hsync => hsync,
		vsync => vsync
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
	
	
-- video output 	
   O_VSYNC <= iob_vsync;
	O_HSYNC <= iob_hsync;
       
   O_VIDEO_R <= iob_R;
	O_VIDEO_G <= iob_G;
	O_VIDEO_B <= iob_b;
	        
	
-- iob register clocking	
	process (clk25) begin
	  if rising_edge(clk25) then 
	    for i in 0 to 3 loop 
          iob_r(i) <= r;
		    iob_g(i) <= g;
		    iob_b(i) <= b;
	    end loop;
		 iob_hsync <= hsync;
		 iob_vsync <= vsync;
		 		 
	  end if;
   end process;
		
	-- Synchronous logic
	
	
	
-- I/O Register Processing
  process(ClkA) begin
	
	 if rising_edge(ClkA) then
	   if I_RESET='1' then	
			crx_oreg    <=  "00000001";
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

