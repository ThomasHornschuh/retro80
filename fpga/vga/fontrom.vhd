----------------------------------------------------------------------------------
--+ RETRO80
--+ An 8-Bit Retro Computer running Digital Research MP/M II and CP/M. 
--+ Based on Will Sowerbutts  SOCZ80 Project:
--+ http://sowerbutts.com/
--+ RETRO80 extensions (c) 2015-2016 by Thomas Hornschuh
--+ This project is licensed under the GPLV3: https://www.gnu.org/licenses/gpl-3.0.txt
-- 
-- Create Date:    17:33:05 12/22/2015 
-- Design Name: 
-- Module Name:    fontrom - Behavioral 
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

entity fontrom is
    generic (RamFileName : string := "");
    Port ( clka : in  STD_LOGIC;
           addra : in  STD_LOGIC_VECTOR (11 downto 0);
           douta : out  STD_LOGIC_VECTOR (7 downto 0));
end fontrom;

architecture Behavioral of fontrom is

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
 	   r(I) := X"00";
    end if;		
  end loop;
  return r; 
end function;
  
  
  signal ram : tRam := InitFromFile;


begin

   process(clka) begin
    if rising_edge(clka) then 	    
       douta <= ram(to_integer(unsigned(addra)));        		 
	 end if;
  
  end process;

end Behavioral;

