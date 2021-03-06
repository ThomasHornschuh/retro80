--+-----------------------------------+-------------------------------------+--
--|                      ___   ___    | (c) 2013-2014 William R Sowerbutts  |--
--|   ___  ___   ___ ___( _ ) / _ \   | will@sowerbutts.com                 |--
--|  / __|/ _ \ / __|_  / _ \| | | |  |                                     |--
--|  \__ \ (_) | (__ / / (_) | |_| |  | A Z80 FPGA computer, just for fun   |--
--|  |___/\___/ \___/___\___/ \___/   |                                     |--
--|                                   |              http://sowerbutts.com/ |--
--+-----------------------------------+-------------------------------------+--
--| Top level module: connects modules to each other and the outside world  |--
--+-------------------------------------------------------------------------+--
--+ RETRO80
--+ An 8-Bit Retro Computer running Digital Research MP/M II and CP/M. 
--+ Based on Will Sowerbutts  SOCZ80 Project:
--+ http://sowerbutts.com/
--+ RETRO80 extensions (c) 2015-2016 by Thomas Hornschuh
--+ This project is licensed under the GPLV3: https://www.gnu.org/licenses/gpl-3.0.txt
--+
--
-- See README.txt for more details
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity top_level is
    Port ( sysclk_32m          : in    std_logic;
           leds                : out   std_logic_vector(4 downto 0);
           reset_button        : in    std_logic;
          -- console_select      : in    std_logic;

           -- UART0 (to FTDI USB chip, no flow control)
           serial_rx           : in    std_logic;
           serial_tx           : out   std_logic;

--           -- UART0 (to MAX3232 level shifter chip, hardware flow control)
--           uart1_rx            : in    std_logic;
--           uart1_cts           : in    std_logic;
--           uart1_tx            : out   std_logic;
--           uart1_rts           : out   std_logic;

           -- SPI flash chip
           flash_spi_cs        : out   std_logic;
           flash_spi_clk       : out   std_logic;
           flash_spi_mosi      : out   std_logic;
           flash_spi_miso      : in    std_logic;

           -- SD card socket
--           sdcard_spi_cs       : out   std_logic;
--           sdcard_spi_clk      : out   std_logic;
--           sdcard_spi_mosi     : out   std_logic;
--           sdcard_spi_miso     : in    std_logic;

           -- SDRAM chip
           SDRAM_CLK           : out   std_logic;
           SDRAM_CKE           : out   std_logic;
           SDRAM_CS            : out   std_logic;
           SDRAM_nRAS          : out   std_logic;
           SDRAM_nCAS          : out   std_logic;
           SDRAM_nWE           : out   std_logic;
           SDRAM_DQM           : out   std_logic_vector( 1 downto 0);
           SDRAM_ADDR          : out   std_logic_vector (12 downto 0);
           SDRAM_BA            : out   std_logic_vector( 1 downto 0);
           SDRAM_DQ            : inout std_logic_vector (15 downto 0);
			  
			  -- VGA Output 
			  O_VSYNC : OUT std_logic;
			  O_HSYNC : OUT std_logic;
			  O_VIDEO_B : OUT std_logic_vector(3 downto 0);
			  O_VIDEO_G : OUT std_logic_vector(3 downto 0);
			  O_VIDEO_R : OUT std_logic_vector(3 downto 0);
			  -- Push Button cross 
			  I_SW : 	  in std_logic_vector(3 downto 0);
			  -- PS/2 Port A
			  PS2DATA : in std_logic;
			  PS2CLKA : in std_logic
			  
       );
end top_level;

architecture Behavioral of top_level is
    constant clk_freq_hz         : natural :=114_800_000;
    constant clk_freq_mhz        : natural := clk_freq_hz / 1_000_000; -- this is the frequency which the PLL outputs, in MHz.

    -- SDRAM configuration
    constant sdram_address_width : natural := 22;
    constant sdram_column_bits   : natural := 8;
    constant cycles_per_refresh  : natural := (64000*clk_freq_mhz)/4096-1;

    -- For simulation, we don't need a long init stage. but for real DRAM we need approx 101us.
    -- The constant below has a different value when interpreted by the synthesis and simulator 
    -- tools in order to achieve the desired timing in each.
    constant sdram_startup_cycles: natural := 101 * clk_freq_mhz
    -- pragma translate_off
    - 10000 -- reduce the value the simulator uses
    -- pragma translate_on
    ;
	 
	 constant int_vector : std_logic_vector(7 downto 0) := X"00"; -- interrupt vector number for Z80 IM2

    -- signals for clocking
	 signal clk32Mhz : std_logic; -- Buffered Osc. Clock
	 
    signal clk_feedback         : std_logic;  -- PLL clock feedback
    signal clk_unbuffered       : std_logic;  -- unbuffered system clock
    signal clk                  : std_logic;  -- buffered system clock (all logic should be clocked by this)
	 signal clk25Mhz_unbuf,clk25Mhz : std_logic; -- TH: Pixel Clock

    -- console latch
   -- signal console_select_clk1  : std_logic;
   -- signal console_select_sync  : std_logic;
    signal swap_uart01          : std_logic := '1'; -- Changed to constant 1 (TH)

    -- system reset signals
    signal power_on_reset       : std_logic_vector(1 downto 0) := (others => '1');
    signal system_reset         : std_logic;
    signal reset_button_clk1    : std_logic;
    signal reset_button_sync    : std_logic; -- reset button signal, synchronised to our clock
    signal reset_request_uart   : std_logic; -- reset request signal from FTDI UART (when you send "!~!~!~" to the UART, this line is asserted)

   -- Input switches
   signal i_sw_clk1, i_sw_sync  : std_logic_vector(3 downto 0);


    -- CPU control
    signal coldboot             : std_logic;
    signal cpu_clk_enable       : std_logic;
    signal cpu_m1_cycle         : std_logic;
    signal cpu_req_mem          : std_logic;
    signal cpu_req_io           : std_logic;
    signal req_mem              : std_logic;
    signal req_io               : std_logic;
    signal req_read             : std_logic;
    signal req_write            : std_logic;
	 signal int_ack				  : std_logic;  -- TH 
    signal virtual_address      : std_logic_vector(15 downto 0);
    signal physical_address     : std_logic_vector(25 downto 0);
    signal mem_wait             : std_logic;
    signal cpu_wait             : std_logic;
    signal dram_wait            : std_logic;
    signal mmu_wait             : std_logic;
    signal spimaster0_wait      : std_logic;
    signal spimaster1_wait      : std_logic;

    -- chip selects
    signal mmu_cs               : std_logic;
    signal rom_cs               : std_logic;
    signal sram_cs              : std_logic;
    signal dram_cs              : std_logic;
    signal uartA_cs             : std_logic;
    signal uartB_cs             : std_logic;
    signal uart0_cs             : std_logic;
    signal uart1_cs             : std_logic;
    signal timer_cs             : std_logic;
    signal spimaster0_cs        : std_logic;
    signal spimaster1_cs        : std_logic;
    signal clkscale_cs          : std_logic;
    signal gpio_cs              : std_logic;
	 signal vram_cs				  : std_logic; -- TH: VGA VRAM select  
	 signal vga_cs					  : std_logic; -- TH: VGA IO Register Select
	 signal ps2a_cs				   : std_logic; -- TH
 
    -- data bus
    signal cpu_data_in          : std_logic_vector(7 downto 0);
    signal cpu_data_out         : std_logic_vector(7 downto 0);
    signal rom_data_out         : std_logic_vector(7 downto 0);
    signal sram_data_out        : std_logic_vector(7 downto 0);
    signal dram_data_out        : std_logic_vector(7 downto 0);
    signal uart0_data_out       : std_logic_vector(7 downto 0);
    signal uart1_data_out       : std_logic_vector(7 downto 0);
    signal timer_data_out       : std_logic_vector(7 downto 0);
    signal spimaster0_data_out  : std_logic_vector(7 downto 0);
    signal spimaster1_data_out  : std_logic_vector(7 downto 0);
    signal mmu_data_out         : std_logic_vector(7 downto 0);
    signal clkscale_out         : std_logic_vector(7 downto 0);
    signal gpio_data_out        : std_logic_vector(7 downto 0);
	 signal int_vector_out       : std_logic_vector(7 downto 0) := int_vector; -- TH
	 signal vga_data_out		  	  : std_logic_vector(7 downto 0); -- TH
	 signal ps2a_data_out		  : std_logic_vector(7 downto 0); -- TH
	 
	 

    -- GPIO
    signal gpio_input           : std_logic_vector(7 downto 0);
    signal gpio_output          : std_logic_vector(7 downto 0);

    -- Interrupts
    signal cpu_interrupt_in     : std_logic;
    signal timer_interrupt      : std_logic;
    signal uart0_interrupt      : std_logic;
    signal uart1_interrupt      : std_logic;
	 signal ps2a_interrupt  	  : std_logic; -- TH
	 

begin


-- Clock Buffer

 -- Input buffering
  --------------------------------------
  clkin1_buf : IBUFG
  port map
   (O => clk32Mhz,
    I => sysclk_32m);




    -- Hold CPU reset high for 8 clock cycles on startup,
    -- and when the user presses their reset button.
    process(clk)
    begin
        if rising_edge(clk) then
            -- Xilinx advises using two flip-flops are used to bring external
            -- signals which feed control logic into our clock domain.
            reset_button_clk1 <= reset_button;
            reset_button_sync <= reset_button_clk1;
           -- console_select_clk1 <= console_select;
           -- console_select_sync <= console_select_clk1;
			  i_sw_clk1 <= i_sw;
			  i_sw_sync <= i_sw_clk1;

            -- reset the system when requested
            if (power_on_reset(0) = '1' or reset_button_sync = '1' or reset_request_uart = '1') then
                system_reset <= '1';
            else
                system_reset <= '0';
            end if;

            -- shift 0s into the power_on_reset shift register from the MSB
            power_on_reset <= '0' & power_on_reset(power_on_reset'length-1 downto 1);

            -- During reset, latch the console select jumper. This is used to
            -- optionally swap over the UART roles and move the system console to
            -- the second serial port on the IO board.
--            if system_reset = '1' then
--                swap_uart01 <= console_select_sync;
--            else
--                swap_uart01 <= swap_uart01;
--            end if;
        end if;
    end process;

    -- GPIO input signal routing
    gpio_input <= coldboot & swap_uart01 & "00" & i_sw_sync; -- Added Input switches (TH)

    -- GPIO output signal routing
    leds(0) <= gpio_output(0);
    leds(1) <= gpio_output(1);
    leds(2) <= gpio_output(2);
    leds(3) <= gpio_output(3);

    -- User LED (LED1) on Papilio Pro indicates when the CPU is being asked to wait (eg by the SDRAM cache)
    leds(4) <= cpu_wait;

    -- Interrupt signal for the CPU
    cpu_interrupt_in <= (timer_interrupt or uart0_interrupt or uart1_interrupt or ps2a_interrupt);
	 
	 -- TH: Add of Display and PS/2 Keyboard
	 
	 display : entity work.vgatop
	 PORT MAP(
		O_VSYNC => O_VSYNC,
		O_HSYNC => O_HSYNC,
		O_VIDEO_B => O_VIDEO_B,
		O_VIDEO_G =>O_VIDEO_G ,
		O_VIDEO_R =>O_VIDEO_R ,
		--clk32Mhz => clk32Mhz,
		clk25 => clk25Mhz,
		DBOut => vga_data_out,
		DBIn => cpu_data_out,
		AdrBus => physical_address(11 downto 0),
		ENA => vram_cs,
		RDEN => req_read,
		WREN => req_write,
		clkA => clk ,
		IO_cs => vga_cs,
		I_RESET => system_reset
	);
	 
	
   Inst_ps2A:  entity work.ps2A PORT MAP(
		clk => clk,
		reset => system_reset,
		AdrBus => physical_address(1 downto 0),
		data_in => cpu_data_out,
		data_out =>ps2a_data_out,
		cs => ps2a_cs ,
		req_read => req_read,
		req_write => req_write,
		int_req => ps2a_interrupt,
		clk32Mhz => clk32Mhz,
		ps2_clk => PS2CLKA,
		ps2_data =>PS2DATA 
	);

	
	
	  
	 
	-- End TH 

    -- Z80 CPU core
    cpu: entity work.Z80cpu
    port map (
                 reset => system_reset,
                 clk => clk,
                 clk_enable => cpu_clk_enable,
                 m1_cycle => cpu_m1_cycle,
                 interrupt => cpu_interrupt_in,
                 nmi => '0',
                 req_mem => cpu_req_mem,
                 req_io => cpu_req_io,
                 req_read => req_read,
                 req_write => req_write,
                 mem_wait => cpu_wait,
					  int_ack => int_ack, 
                 address => virtual_address,
                 data_in => cpu_data_in,
                 data_out => cpu_data_out
             );

    -- Memory management unit
    mmu: entity work.MMU
    port map (
                reset => system_reset,
                clk => clk,
                address_in => virtual_address,
                address_out => physical_address,
                cpu_data_in => cpu_data_out,
                cpu_data_out => mmu_data_out,
                req_mem_in => cpu_req_mem,
                req_io_in  => cpu_req_io,
                req_mem_out => req_mem,
                req_io_out => req_io,
                req_read => req_read,
                req_write => req_write,
                io_cs => mmu_cs,
                cpu_wait => mmu_wait,
                access_violated => open -- for now!!
            );

    -- This process determines which IO or memory device the CPU is addressing
    -- and asserts the appropriate chip select signals.
    cs_process: process(req_mem, req_io,int_ack, physical_address, virtual_address, uartA_cs, uartB_cs, swap_uart01)
    begin
        -- memory chip selects: default to unselected
        rom_cs   <= '0';
        sram_cs  <= '0';
        dram_cs  <= '0';
		  vram_cs  <= '0';

        -- io chip selects: default to unselected
        uartA_cs      <= '0';
        uartB_cs      <= '0';
        mmu_cs        <= '0';
        timer_cs      <= '0';
        spimaster0_cs <= '0';
        spimaster1_cs <= '0';
        clkscale_cs   <= '0';
        gpio_cs       <= '0';
		  vga_cs        <= '0'; -- TH
		  ps2a_cs       <= '0'; -- TH

        -- memory address decoding
        -- address space is organised as:
        -- 0x0 000 000 - 0x0 FFF FFF  16MB DRAM (cached)    (mapped to 8MB DRAM twice)
        -- 0x1 000 000 - 0x1 FFF FFF  16MB DRAM (uncached)  (mapped to 8MB DRAM twice)
        -- 0x2 000 000 - 0x2 000 FFF   4KB monitor ROM      (FPGA block RAM)
        -- 0x2 001 000 - 0x2 001 FFF   4KB SRAM             (FPGA block RAM)
		  -- 0x2 002 000 - 0x2 002 FFF   4KB Video RAM        (FPGA block RAM)
        -- 0x2 003 000 - 0x3 FFF FFF  unused space for future expansion
        if physical_address(25) = '0' then
            -- bottom 32MB: DRAM handles this
            dram_cs <= req_mem;
        else
            -- top 32MB: other memory devices
            case physical_address(24 downto 12) is
                when "0000000000000" =>  rom_cs <= req_mem;
                when "0000000000001" => sram_cs <= req_mem;
					 when "0000000000010" => vram_cs <= req_mem;
                when others => -- undecoded memory space
            end case;
        end if;

        -- IO address decoding
        case virtual_address(7 downto 3) is
            when "00000" => uartA_cs            <= req_io;  -- 00 ... 07
            when "00010" => timer_cs            <= req_io;  -- 10 ... 17
            when "00011" => spimaster0_cs       <= req_io;  -- 18 ... 1F
            when "00100" => gpio_cs             <= req_io;  -- 20 ... 27
            when "00101" => uartB_cs            <= req_io;  -- 28 ... 2F
            when "00110" => spimaster1_cs       <= req_io;  -- 30 ... 37
				when "00111" => vga_cs					<= req_io;  -- 38 ... 3F  TH
				when "01000" => ps2a_cs	            <= req_io;  -- 40 ... 48  TH  
                                                            -- unused ports
            when "11110" => clkscale_cs         <= req_io;  -- F0 ... F7
            when "11111" => mmu_cs              <= req_io;  -- F8 ... FF
            when others =>
        end case;

        -- send the UART chip select to the appropriate UART depending
        -- on whether they have been swapped over or not.
        if swap_uart01 = '0' then
            uart0_cs <= uartB_cs;
            uart1_cs <= uartA_cs;
        else
            uart0_cs <= uartA_cs;
            uart1_cs <= uartB_cs;
        end if;
    end process;

    -- the selected memory device can request the CPU to wait
    mem_wait <=
       dram_wait       when dram_cs='1' else
       spimaster0_wait when spimaster0_cs='1' else
       spimaster1_wait when spimaster1_cs='1' else
       '0';

    -- the MMU can, at any time, request the CPU wait (this is used when 
    -- translating IO to memory requests, to implement a wait state for 
    -- the "17th page")
    cpu_wait <= (mem_wait or mmu_wait);

    -- input mux for CPU data bus
    cpu_data_in <=
       rom_data_out        when        rom_cs='1' else
       dram_data_out       when       dram_cs='1' else
       sram_data_out       when       sram_cs='1' else
		 vga_data_out        when       vram_cs='1' or vga_cs='1' else -- TH
		 ps2a_data_out       when       ps2a_cs='1' else -- TH
       uart0_data_out      when      uart0_cs='1' else
       uart1_data_out      when      uart1_cs='1' else
       timer_data_out      when      timer_cs='1' else
       mmu_data_out        when        mmu_cs='1' else
       spimaster0_data_out when spimaster0_cs='1' else
       spimaster1_data_out when spimaster1_cs='1' else
       clkscale_out        when   clkscale_cs='1' else
       gpio_data_out       when       gpio_cs='1' else		 
		 int_vector_out      when       int_ack='1' else  -- TH: Very simple "interrupt controller"
       rom_data_out; -- default case

   dram: entity work.DRAM
   generic map(
               sdram_address_width => sdram_address_width,
               sdram_column_bits   => sdram_column_bits,
               sdram_startup_cycles=> sdram_startup_cycles,
               cycles_per_refresh  => cycles_per_refresh
              )
   port map(
               clk             => clk,
               reset           => '0', -- important to note that we DO NOT reset the SDRAM controller on reset (it would stop refreshing, which would be bad)

               -- interface to synthetic CPU
               cs => dram_cs,
               req_read => req_read,
               req_write => req_write,
               mem_address => physical_address(24 downto 0),
               mem_wait => dram_wait,
               data_in => cpu_data_out,
               data_out => dram_data_out,
               coldboot => coldboot,

               -- interface to hardware SDRAM chip
               SDRAM_CLK       => SDRAM_CLK,
               SDRAM_CKE       => SDRAM_CKE,
               SDRAM_CS        => SDRAM_CS,
               SDRAM_nRAS      => SDRAM_nRAS,
               SDRAM_nCAS      => SDRAM_nCAS,
               SDRAM_nWE       => SDRAM_nWE,
               SDRAM_DQM       => SDRAM_DQM,
               SDRAM_BA        => SDRAM_BA,
               SDRAM_ADDR      => SDRAM_ADDR,
               SDRAM_DQ        => SDRAM_DQ
           );

   -- 4KB system ROM implemented in block RAM
   rom: entity work.MonZ80
   port map(
               clk => clk,
               A => physical_address(11 downto 0),
               D => rom_data_out
           );

   -- 4KB SRAM memory implemented in block RAM
   sram: entity work.SSRAM
   generic map(
                  AddrWidth => 12
              )
   port map(
               clk => clk,
               ce => sram_cs,
               we => req_write,
               A => physical_address(11 downto 0),
               DIn => cpu_data_out,
               DOut => sram_data_out
           );

   -- UART connected to FTDI USB UART
   uart0: entity work.uart_interface
   generic map ( watch_for_reset => 1, clk_frequency => clk_freq_hz )
   port map(
               clk => clk,
               reset => system_reset,
               reset_out => reset_request_uart, -- result of watching for reset sequence on the input
               serial_in => serial_rx,
               serial_out => serial_tx,
               serial_rts => open,
               serial_cts => '0',
               cpu_address => virtual_address(2 downto 0),
               cpu_data_in => cpu_data_out,
               cpu_data_out => uart0_data_out,
               enable => uart0_cs,
               interrupt => uart0_interrupt,
               req_read => req_read,
               req_write => req_write
           );

   -- UART connected to MAX3232 on optional IO board
--   uart1: entity work.uart_interface
--   generic map ( flow_control => 1, clk_frequency => (clk_freq_mhz * 1000000) )
--   port map(
--               clk => clk,
--               reset => system_reset,
--               serial_in => uart1_rx,
--               serial_out => uart1_tx,
--               serial_rts => uart1_rts,
--               serial_cts => uart1_cts,
--               cpu_address => virtual_address(2 downto 0),
--               cpu_data_in => cpu_data_out,
--               cpu_data_out => uart1_data_out,
--               enable => uart1_cs,
--               interrupt => uart1_interrupt,
--               req_read => req_read,
--               req_write => req_write
--           );

   -- Timer device (internally scales the clock to 1MHz)
   timer: entity work.timer
   generic map ( clk_frequency => clk_freq_hz )
   port map(
               clk => clk,
               reset => system_reset,
               cpu_address => virtual_address(2 downto 0),
               data_in => cpu_data_out,
               data_out => timer_data_out,
               enable => timer_cs,
               req_read => req_read,
               req_write => req_write,
               interrupt => timer_interrupt
           );

   -- SPI master device connected to Papilio Pro 8MB flash ROM
   spimaster0: entity work.spimaster
   port map(
               clk => clk,
               reset => system_reset,
               cpu_address => virtual_address(2 downto 0),
               cpu_wait => spimaster0_wait,
               data_in => cpu_data_out,
               data_out => spimaster0_data_out,
               enable => spimaster0_cs,
               req_read => req_read,
               req_write => req_write,
               slave_cs => flash_spi_cs,
               slave_clk => flash_spi_clk,
               slave_mosi => flash_spi_mosi,
               slave_miso => flash_spi_miso
           );

   -- SPI master device connected to SD card socket on the IO board
--   spimaster1: entity work.spimaster
--   port map(
--               clk => clk,
--               reset => system_reset,
--               cpu_address => virtual_address(2 downto 0),
--               cpu_wait => spimaster1_wait,
--               data_in => cpu_data_out,
--               data_out => spimaster1_data_out,
--               enable => spimaster1_cs,
--               req_read => req_read,
--               req_write => req_write,
--               slave_cs => sdcard_spi_cs,
--               slave_clk => sdcard_spi_clk,
--               slave_mosi => sdcard_spi_mosi,
--               slave_miso => sdcard_spi_miso
--           );

   -- GPIO to FPGA pins and/or internal signals
   gpio: entity work.gpio
   port map(
               clk => clk,
               reset => system_reset,
               cpu_address => virtual_address(2 downto 0),
               data_in => cpu_data_out,
               data_out => gpio_data_out,
               enable => gpio_cs,
               read_notwrite => req_read,
               input_pins => gpio_input,
               output_pins => gpio_output
           );

   -- An attempt to allow the CPU clock to be scaled back to run
   -- at slower speeds without affecting the clock signal sent to
   -- IO devices. Basically this was an attempt to make CP/M games 
   -- playable :) Very limited success. Might be simpler to remove
   -- this entirely.
   clkscale: entity work.clkscale
   port map (
               clk => clk,
               reset => system_reset,
               cpu_address => virtual_address(2 downto 0),
               data_in => cpu_data_out,
               data_out => clkscale_out,
               enable => clkscale_cs,
               read_notwrite => req_read,
               clk_enable => cpu_clk_enable
           );

   -- PLL scales 32MHz Papilio Pro oscillator frequency to 128MHz
   -- clock for our logic.
	-- TH : expermental derive CPU und Pixel Clock from PLL
	-- will lead do CPU Clock of 114,8 MhZ
   clock_pll: PLL_BASE 
   generic map (
               BANDWIDTH      => "OPTIMIZED",        -- "HIGH", "LOW" or "OPTIMIZED" 
               --CLKFBOUT_MULT  => 16,                 -- Multiply value for all CLKOUT clock outputs (1-64)
					CLKFBOUT_MULT => 25,                    -- 800 Mhz
               CLKFBOUT_PHASE => 0.0,                -- Phase offset in degrees of the clock feedback output (0.0-360.0).
               CLKIN_PERIOD   => 31.25,              -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
                                                     -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
              -- CLKOUT0_DIVIDE => 4,                  -- 32MHz * 16 / 4 = 128MHz. Adjust clk_freq_mhz constant (above) if you change this.
               CLKOUT0_DIVIDE => 7,                  -- 800 Mhz / 7 = 114.8 Mhz 
					CLKOUT1_DIVIDE => 32,                 -- 800 Mhz / 32 = 25 Mhz
               CLKOUT2_DIVIDE => 1,       
               CLKOUT3_DIVIDE => 1,
               CLKOUT4_DIVIDE => 1,       
               CLKOUT5_DIVIDE => 1,
                                               -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
               CLKOUT0_DUTY_CYCLE => 0.5, CLKOUT1_DUTY_CYCLE => 0.5,
               CLKOUT2_DUTY_CYCLE => 0.5, CLKOUT3_DUTY_CYCLE => 0.5,
               CLKOUT4_DUTY_CYCLE => 0.5, CLKOUT5_DUTY_CYCLE => 0.5,
                                               -- CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
               CLKOUT0_PHASE => 0.0,      CLKOUT1_PHASE => 0.0, -- Capture clock
               CLKOUT2_PHASE => 0.0,      CLKOUT3_PHASE => 0.0,
               CLKOUT4_PHASE => 0.0,      CLKOUT5_PHASE => 0.0,

               CLK_FEEDBACK => "CLKFBOUT",           -- Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
               COMPENSATION => "SYSTEM_SYNCHRONOUS", -- "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
               DIVCLK_DIVIDE => 1,                   -- Division value for all output clocks (1-52)
               REF_JITTER => 0.1,                    -- Reference Clock Jitter in UI (0.000-0.999).
               RESET_ON_LOSS_OF_LOCK => FALSE        -- Must be set to FALSE
           ) 
   port map(
               CLKIN    => clk32Mhz,   -- 1-bit input: Clock input
               CLKFBOUT => clk_feedback, -- 1-bit output: PLL_BASE feedback output
               CLKFBIN  => clk_feedback, -- 1-bit input: Feedback clock input
                                         -- CLKOUT0 - CLKOUT5: 1-bit (each) output: Clock outputs
               CLKOUT0 => clk_unbuffered, -- ~115 Mhz clock output
               CLKOUT1 => clk25Mhz_unbuf,       -- Pixel Clock
               CLKOUT2 => open,      
               CLKOUT3 => open,
               CLKOUT4 => open,      
               CLKOUT5 => open,
               LOCKED  => open,  -- 1-bit output: PLL_BASE lock status output
               RST     => '0'    -- 1-bit input: Reset input
           );

   -- Buffering of clocks
   BUFG_clk: BUFG 
   port map(
               O => clk,     
               I => clk_unbuffered
            );
				
   BUFG_clk25: BUFG 
   port map(
               O => clk25Mhz,     
               I => clk25Mhz_unbuf
            );				

end Behavioral;
