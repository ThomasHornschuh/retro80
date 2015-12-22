--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   19:13:54 12/22/2015
-- Design Name:   
-- Module Name:   C:/daten/development/fpga/socz80/fpga/vgatest.vhd
-- Project Name:  socz80
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: vgatop
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY vgatest IS
END vgatest;
 
ARCHITECTURE behavior OF vgatest IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT vgatop
    PORT(
         O_VSYNC : OUT  std_logic;
         O_HSYNC : OUT  std_logic;
         O_VIDEO_B : OUT  std_logic_vector(3 downto 0);
         O_VIDEO_G : OUT  std_logic_vector(3 downto 0);
         O_VIDEO_R : OUT  std_logic_vector(3 downto 0);
         clk32Mhz : IN  std_logic;
         DBOut : OUT  std_logic_vector(7 downto 0);
         DBIn : IN  std_logic_vector(7 downto 0);
         AdrBus : IN  std_logic_vector(11 downto 0);
         ENA : IN  std_logic;
         WREN : IN  std_logic;
         clkA : IN  std_logic;
         I_RESET : IN  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk32Mhz : std_logic := '0';
   signal DBIn : std_logic_vector(7 downto 0) := (others => '0');
   signal AdrBus : std_logic_vector(11 downto 0) := (others => '0');
   signal ENA : std_logic := '0';
   signal WREN : std_logic := '0';
   signal clkA : std_logic := '0';
   signal I_RESET : std_logic := '0';

 	--Outputs
   signal O_VSYNC : std_logic;
   signal O_HSYNC : std_logic;
   signal O_VIDEO_B : std_logic_vector(3 downto 0);
   signal O_VIDEO_G : std_logic_vector(3 downto 0);
   signal O_VIDEO_R : std_logic_vector(3 downto 0);
   signal DBOut : std_logic_vector(7 downto 0);

   -- Clock period definitions
   constant clk32Mhz_period : time := 31.25 ns;
   constant clkA_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: vgatop PORT MAP (
          O_VSYNC => O_VSYNC,
          O_HSYNC => O_HSYNC,
          O_VIDEO_B => O_VIDEO_B,
          O_VIDEO_G => O_VIDEO_G,
          O_VIDEO_R => O_VIDEO_R,
          clk32Mhz => clk32Mhz,
          DBOut => DBOut,
          DBIn => DBIn,
          AdrBus => AdrBus,
          ENA => ENA,
          WREN => WREN,
          clkA => clkA,
          I_RESET => I_RESET
        );

   -- Clock process definitions
   clk32Mhz_process :process
   begin
		clk32Mhz <= '0';
		wait for clk32Mhz_period/2;
		clk32Mhz <= '1';
		wait for clk32Mhz_period/2;
   end process;
 
   clkA_process :process
   begin
		clkA <= '0';
		wait for clkA_period/2;
		clkA <= '1';
		wait for clkA_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 30 ns;	

    
      -- insert stimulus here 

      wait;
   end process;

END;
