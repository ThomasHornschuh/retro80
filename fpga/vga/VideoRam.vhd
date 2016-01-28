----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    01:25:59 12/21/2015 
-- Design Name: 
-- Module Name:    VideoRam - Behavioral 
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
use IEEE.std_logic_textio.all; -- declares hread

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

library STD;
use STD.textio.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity VideoRam is
   generic (RamFileName : string := "");
    Port ( -- CPU Interface
	        DBOut : out  STD_LOGIC_VECTOR (7 downto 0);
           DBIn : in  STD_LOGIC_VECTOR (7 downto 0);
           AdrBus : in  STD_LOGIC_VECTOR (11 downto 0);
			  clkA : in STD_LOGIC; -- Clock for RAM Port A
           ENA : in  STD_LOGIC;
           WREN : in  STD_LOGIC;
			  RDEN : in  STD_LOGIC;
			  
			  -- Video Controller Interface 
			  VAdr : in  STD_LOGIC_VECTOR (11 downto 0);
			  VData : out  STD_LOGIC_VECTOR (7 downto 0);        
			  CLK : in  STD_LOGIC );
end VideoRam;

architecture Behavioral of VideoRam is

  type tRam is array (0 to 4095) of STD_LOGIC_VECTOR (7 downto 0);


--design time code

impure function InitFromFile  return tRam is
FILE RamFile : text is in RamFileName;
variable RamFileLine : line;
variable byte : STD_LOGIC_VECTOR(7 downto 0);
variable r : tRam;

begin
  for I in tRam'range loop
    if not endfile(RamFile) then
      readline (RamFile, RamFileLine);
      hread (RamFileLine, byte);
	   r(I) :=  byte;
	 else
 	   r(I) := X"20";
    end if;		
  end loop;
  return r; 
end function;
  
  
  signal ram : tRam := InitFromFile;
--  signal ar : STD_LOGIC_VECTOR (11 downto 0);

begin


  process(clkA) begin
    if rising_edge(clkA) then
		 if ena = '1' and wren='1'  then
			  ram(to_integer(unsigned(AdrBus))) <= DBIn;
			  DBOut <=DBIn;
		 else
           DBOut <= ram(to_integer(unsigned(AdrBus)));
       end if; 			  
		 
      -- ar <= AdrBus; -- Latch Address
		 			  
	  end if;
  
  end process;

 -- DBOut <= ram(to_integer(unsigned(ar))); -- Always output 

  process(clk) begin
    if rising_edge(clk) then 
	    
       VData <= ram(to_integer(unsigned(VAdr)));        		 
	 end if;
  
  end process;
 
  

end Behavioral;

