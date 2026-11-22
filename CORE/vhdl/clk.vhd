-------------------------------------------------------------------------------------------------------------
-- Atari 7800 for MEGA65
--
-- Clock generator
--
--   main_clk  (14.318182 MHz) = the NTSC 7800 master crystal, 4 x the colour subcarrier (315/88 MHz).
--                               MiSTer: clk_sys. The whole console (SALLY, MARIA, TIA, RIOT, cartridge)
--                               and the framework's core clock domain run on it.
--   video_clk (57.272727 MHz) = 4 x main_clk. MiSTer: clk_vid (CLK_VIDEO). Video output to the framework.
--
--   100 MHz / 5 (DIVCLK) * 31.5 = 630 MHz VCO; / 11 = 57.272727 MHz; / 44 = 14.318182 MHz (NTSC exact).
--   Both outputs come from the same MMCM with phase 0, so their rising edges are aligned (every 4th
--   video_clk edge is a main_clk edge) and Vivado times all paths between them.
--
--   MiSTer reprograms its PLL for PAL (14.18758 MHz). This port always runs at the NTSC rate, so PAL
--   games run 0.92% fast (the PAL picture itself, 313 lines, is made by MARIA/TIA).
--   MiSTer's clk_arm (71.6 MHz, ARM7TDMI for 2600 ARM mappers) is not used: the ARM is left out.
--
-- Based on the MiSTer2MEGA65 framework template (sy2002 and MJoergen), licensed under GPL v3
-------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

entity clk is
   port (
      sys_clk_i       : in  std_logic;   -- expects 100 MHz

      main_clk_o      : out std_logic;   -- 14.318182 MHz
      main_rst_o      : out std_logic;   -- main's reset, synchronized

      video_clk_o     : out std_logic;   -- 57.272727 MHz
      video_rst_o     : out std_logic    -- video's reset, synchronized
   );
end entity clk;

architecture rtl of clk is

signal clkfb_mmcm         : std_logic;
signal clkfb              : std_logic;
signal video_clk_mmcm     : std_logic;
signal main_clk_mmcm      : std_logic;
signal video_clk          : std_logic;
signal main_clk           : std_logic;
signal locked             : std_logic;

begin

   i_clk_main : MMCME2_ADV
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKOUT4_CASCADE      => FALSE,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => FALSE,
         CLKIN1_PERIOD        => 10.0,       -- INPUT @ 100 MHz
         REF_JITTER1          => 0.010,
         DIVCLK_DIVIDE        => 5,          -- 20 MHz PFD
         CLKFBOUT_MULT_F      => 31.500,     -- 630 MHz VCO
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => FALSE,
         CLKOUT0_DIVIDE_F     => 11.000,     -- 57.272727 MHz (video)
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => FALSE,
         CLKOUT1_DIVIDE       => 44,         -- 14.318182 MHz (main)
         CLKOUT1_PHASE        => 0.000,
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_USE_FINE_PS  => FALSE
      )
      port map (
         CLKFBOUT            => clkfb_mmcm,
         CLKOUT0             => video_clk_mmcm,
         CLKOUT1             => main_clk_mmcm,
         CLKFBIN             => clkfb,
         CLKIN1              => sys_clk_i,
         CLKIN2              => '0',
         CLKINSEL            => '1',
         DADDR               => (others => '0'),
         DCLK                => '0',
         DEN                 => '0',
         DI                  => (others => '0'),
         DO                  => open,
         DRDY                => open,
         DWE                 => '0',
         PSCLK               => '0',
         PSEN                => '0',
         PSINCDEC            => '0',
         PSDONE              => open,
         LOCKED              => locked,
         CLKINSTOPPED        => open,
         CLKFBSTOPPED        => open,
         PWRDWN              => '0',
         RST                 => '0'
      ); -- i_clk_main

   clkfb_bufg : BUFG
      port map (
         I => clkfb_mmcm,
         O => clkfb
      );

   video_clk_bufg : BUFG
      port map (
         I => video_clk_mmcm,
         O => video_clk
      );

   main_clk_bufg : BUFG
      port map (
         I => main_clk_mmcm,
         O => main_clk
      );

   main_clk_o  <= main_clk;
   video_clk_o <= video_clk;

   i_xpm_cdc_async_rst_main : xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1,
         DEST_SYNC_FF    => 6
      )
      port map (
         src_arst  => not locked,
         dest_clk  => main_clk,
         dest_arst => main_rst_o
      );

   i_xpm_cdc_async_rst_video : xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1,
         DEST_SYNC_FF    => 6
      )
      port map (
         src_arst  => not locked,
         dest_clk  => video_clk,
         dest_arst => video_rst_o
      );

end architecture rtl;

