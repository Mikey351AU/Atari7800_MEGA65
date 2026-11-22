----------------------------------------------------------------------------------
-- Atari 7800 for MEGA65
--
-- MEGA65 main file that contains the whole machine (based on the MiSTer2MEGA65 framework)
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.globals.all;
use work.types_pkg.all;
use work.video_modes_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity MEGA65_Core is
generic (
   G_BOARD : string                                         -- Which platform are we running on.
);
port (
   --------------------------------------------------------------------------------------------------------
   -- QNICE Clock Domain
   --------------------------------------------------------------------------------------------------------

   -- Get QNICE clock from the framework: for the vdrives as well as for RAMs and ROMs
   qnice_clk_i             : in  std_logic;
   qnice_rst_i             : in  std_logic;

   -- Video and audio mode control
   qnice_dvi_o             : out std_logic;              -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_video_mode_o      : out video_mode_type;        -- Defined in video_modes_pkg.vhd
   qnice_osm_cfg_scaling_o : out std_logic_vector(8 downto 0);
   qnice_scandoubler_o     : out std_logic;              -- 0 = no scandoubler, 1 = scandoubler
   qnice_audio_mute_o      : out std_logic;
   qnice_audio_filter_o    : out std_logic;
   qnice_zoom_crop_o       : out std_logic;
   qnice_ascal_mode_o      : out std_logic_vector(1 downto 0);
   qnice_ascal_polyphase_o : out std_logic;
   qnice_ascal_triplebuf_o : out std_logic;
   qnice_retro15kHz_o      : out std_logic;              -- 0 = normal frequency, 1 = retro 15 kHz frequency
   qnice_csync_o           : out std_logic;              -- 0 = normal HS/VS, 1 = Composite Sync  

   -- Flip joystick ports
   qnice_flip_joyports_o   : out std_logic;

   -- On-Screen-Menu selections
   qnice_osm_control_i     : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register
   qnice_gp_reg_i          : in  std_logic_vector(255 downto 0);

   -- Core-specific devices
   qnice_dev_id_i          : in  std_logic_vector(15 downto 0);
   qnice_dev_addr_i        : in  std_logic_vector(27 downto 0);
   qnice_dev_data_i        : in  std_logic_vector(15 downto 0);
   qnice_dev_data_o        : out std_logic_vector(15 downto 0);
   qnice_dev_ce_i          : in  std_logic;
   qnice_dev_we_i          : in  std_logic;
   qnice_dev_wait_o        : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- HyperRAM Clock Domain
   --------------------------------------------------------------------------------------------------------

   hr_clk_i                : in  std_logic;
   hr_rst_i                : in  std_logic;
   hr_core_write_o         : out std_logic;
   hr_core_read_o          : out std_logic;
   hr_core_address_o       : out std_logic_vector(31 downto 0);
   hr_core_writedata_o     : out std_logic_vector(15 downto 0);
   hr_core_byteenable_o    : out std_logic_vector( 1 downto 0);
   hr_core_burstcount_o    : out std_logic_vector( 7 downto 0);
   hr_core_readdata_i      : in  std_logic_vector(15 downto 0);
   hr_core_readdatavalid_i : in  std_logic;
   hr_core_waitrequest_i   : in  std_logic;
   hr_high_i               : in  std_logic;  -- Core is too fast
   hr_low_i                : in  std_logic;  -- Core is too slow

   --------------------------------------------------------------------------------------------------------
   -- Video Clock Domain
   --------------------------------------------------------------------------------------------------------

   video_clk_o             : out std_logic;
   video_rst_o             : out std_logic;
   video_ce_o              : out std_logic;
   video_ce_ovl_o          : out std_logic;
   video_red_o             : out std_logic_vector(7 downto 0);
   video_green_o           : out std_logic_vector(7 downto 0);
   video_blue_o            : out std_logic_vector(7 downto 0);
   video_vs_o              : out std_logic;
   video_hs_o              : out std_logic;
   video_hblank_o          : out std_logic;
   video_vblank_o          : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- Core Clock Domain
   --------------------------------------------------------------------------------------------------------

   clk_i                   : in  std_logic;              -- 100 MHz clock

   -- Share clock and reset with the framework
   main_clk_o              : out std_logic;              -- 14.318182 MHz main clock (core and framework)
   main_rst_o              : out std_logic;              -- CORE's reset, synchronized

   -- M2M's reset manager provides 2 signals:
   --    m2m:   Reset the whole machine: Core and Framework
   --    core:  Only reset the core
   main_reset_m2m_i        : in  std_logic;
   main_reset_core_i       : in  std_logic;

   main_pause_core_i       : in  std_logic;

   -- On-Screen-Menu selections
   main_osm_control_i      : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register converted to main clock domain
   main_qnice_gp_reg_i     : in  std_logic_vector(255 downto 0);

   -- Audio output (Signed PCM)
   main_audio_left_o       : out signed(15 downto 0);
   main_audio_right_o      : out signed(15 downto 0);

   -- M2M Keyboard interface (incl. power led and drive led)
   main_kb_key_num_i       : in  integer range 0 to 79;  -- cycles through all MEGA65 keys
   main_kb_key_pressed_n_i : in  std_logic;              -- low active: debounced feedback: is kb_key_num_i pressed right now?
   main_power_led_o        : out std_logic;
   main_power_led_col_o    : out std_logic_vector(23 downto 0);
   main_drive_led_o        : out std_logic;
   main_drive_led_col_o    : out std_logic_vector(23 downto 0);

   -- Joysticks and paddles input
   main_joy_1_up_n_i       : in  std_logic;
   main_joy_1_down_n_i     : in  std_logic;
   main_joy_1_left_n_i     : in  std_logic;
   main_joy_1_right_n_i    : in  std_logic;
   main_joy_1_fire_n_i     : in  std_logic;
   main_joy_1_up_n_o       : out std_logic;
   main_joy_1_down_n_o     : out std_logic;
   main_joy_1_left_n_o     : out std_logic;
   main_joy_1_right_n_o    : out std_logic;
   main_joy_1_fire_n_o     : out std_logic;
   main_joy_2_up_n_i       : in  std_logic;
   main_joy_2_down_n_i     : in  std_logic;
   main_joy_2_left_n_i     : in  std_logic;
   main_joy_2_right_n_i    : in  std_logic;
   main_joy_2_fire_n_i     : in  std_logic;
   main_joy_2_up_n_o       : out std_logic;
   main_joy_2_down_n_o     : out std_logic;
   main_joy_2_left_n_o     : out std_logic;
   main_joy_2_right_n_o    : out std_logic;
   main_joy_2_fire_n_o     : out std_logic;

   main_pot1_x_i           : in  std_logic_vector(7 downto 0);
   main_pot1_y_i           : in  std_logic_vector(7 downto 0);
   main_pot2_x_i           : in  std_logic_vector(7 downto 0);
   main_pot2_y_i           : in  std_logic_vector(7 downto 0);
   main_rtc_i              : in  std_logic_vector(64 downto 0);

   -- CBM-488/IEC serial port
   iec_reset_n_o           : out std_logic;
   iec_atn_n_o             : out std_logic;
   iec_clk_en_o            : out std_logic;
   iec_clk_n_i             : in  std_logic;
   iec_clk_n_o             : out std_logic;
   iec_data_en_o           : out std_logic;
   iec_data_n_i            : in  std_logic;
   iec_data_n_o            : out std_logic;
   iec_srq_en_o            : out std_logic;
   iec_srq_n_i             : in  std_logic;
   iec_srq_n_o             : out std_logic;

   -- C64 Expansion Port (aka Cartridge Port)
   cart_en_o               : out std_logic;  -- Enable port, active high
   cart_phi2_o             : out std_logic;
   cart_dotclock_o         : out std_logic;
   cart_dma_i              : in  std_logic;
   cart_reset_oe_o         : out std_logic;
   cart_reset_i            : in  std_logic;
   cart_reset_o            : out std_logic;
   cart_game_oe_o          : out std_logic;
   cart_game_i             : in  std_logic;
   cart_game_o             : out std_logic;
   cart_exrom_oe_o         : out std_logic;
   cart_exrom_i            : in  std_logic;
   cart_exrom_o            : out std_logic;
   cart_nmi_oe_o           : out std_logic;
   cart_nmi_i              : in  std_logic;
   cart_nmi_o              : out std_logic;
   cart_irq_oe_o           : out std_logic;
   cart_irq_i              : in  std_logic;
   cart_irq_o              : out std_logic;
   cart_roml_oe_o          : out std_logic;
   cart_roml_i             : in  std_logic;
   cart_roml_o             : out std_logic;
   cart_romh_oe_o          : out std_logic;
   cart_romh_i             : in  std_logic;
   cart_romh_o             : out std_logic;
   cart_ctrl_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_ba_i               : in  std_logic;
   cart_rw_i               : in  std_logic;
   cart_io1_i              : in  std_logic;
   cart_io2_i              : in  std_logic;
   cart_ba_o               : out std_logic;
   cart_rw_o               : out std_logic;
   cart_io1_o              : out std_logic;
   cart_io2_o              : out std_logic;
   cart_addr_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_a_i                : in  unsigned(15 downto 0);
   cart_a_o                : out unsigned(15 downto 0);
   cart_data_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_d_i                : in  unsigned( 7 downto 0);
   cart_d_o                : out unsigned( 7 downto 0)
);
end entity MEGA65_Core;

architecture synthesis of MEGA65_Core is

---------------------------------------------------------------------------------------------
-- Clocks and active high reset signals for each clock domain
---------------------------------------------------------------------------------------------

signal main_clk               : std_logic;               -- 14.318182 MHz (core, framework)
signal main_rst               : std_logic;
signal video_clk              : std_logic;               -- 57.272727 MHz (video)
signal video_rst              : std_logic;

---------------------------------------------------------------------------------------------
-- Options menu items (0-based line numbers in config.vhd's OPTM_ITEMS)
---------------------------------------------------------------------------------------------

constant C_MENU_REGION_NTSC   : natural := 9;
constant C_MENU_REGION_PAL    : natural := 10;
constant C_MENU_DIF_LEFT_B    : natural := 16;
constant C_MENU_DIF_RIGHT_B   : natural := 17;
constant C_MENU_BW            : natural := 18;
constant C_MENU_USE_BIOS      : natural := 19;
constant C_MENU_PADDLES_1     : natural := 26;
constant C_MENU_PADDLES_2     : natural := 27;
constant C_MENU_PADDLES_BOTH  : natural := 28;
constant C_MENU_PADDLES_INV   : natural := 30;
constant C_MENU_SWAP_JOY      : natural := 31;
constant C_MENU_BS_F8         : natural := 38;           -- 2600 bank switching: 38 .. 53
constant C_MENU_BS_F6         : natural := 39;
constant C_MENU_BS_F4         : natural := 40;
constant C_MENU_BS_FE         : natural := 41;
constant C_MENU_BS_E0         : natural := 42;
constant C_MENU_BS_3F         : natural := 43;
constant C_MENU_BS_3E         : natural := 44;
constant C_MENU_BS_FA         : natural := 45;
constant C_MENU_BS_CV         : natural := 46;
constant C_MENU_BS_UA         : natural := 47;
constant C_MENU_BS_E7         : natural := 48;
constant C_MENU_BS_F0         : natural := 49;
constant C_MENU_BS_P2         : natural := 50;
constant C_MENU_BS_AR         : natural := 51;
constant C_MENU_BS_SB         : natural := 52;
constant C_MENU_BS_EF         : natural := 53;
constant C_MENU_TEMP_COOL     : natural := 60;
constant C_MENU_TEMP_HOT      : natural := 61;
constant C_MENU_HIDE_BORDER   : natural := 63;
constant C_MENU_OVERSCAN      : natural := 64;
constant C_MENU_BLEND         : natural := 65;
constant C_MENU_DECOMB        : natural := 66;
constant C_MENU_NO_STAB       : natural := 67;
constant C_MENU_STEREO        : natural := 68;
constant C_MENU_IMPROVE_AUDIO : natural := 69;
constant C_MENU_CRT_EMULATION : natural := 70;
constant C_MENU_HDMI_ZOOM     : natural := 71;
constant C_MENU_HSC_ON        : natural := 78;
constant C_MENU_HSC_OFF       : natural := 79;
constant C_MENU_POKEY_IRQ     : natural := 81;
constant C_MENU_RANDOM        : natural := 82;
constant C_MENU_DRIVER_MARIA  : natural := 83;
constant C_MENU_FIX_SC        : natural := 84;
constant C_MENU_HDMI_16_9_50  : natural := 90;
constant C_MENU_HDMI_16_9_60  : natural := 91;
constant C_MENU_HDMI_4_3_50   : natural := 92;
constant C_MENU_HDMI_5_4_50   : natural := 93;
constant C_MENU_HDMI_640_60   : natural := 94;
constant C_MENU_HDMI_720_5994 : natural := 95;
constant C_MENU_SVGA_800_60   : natural := 96;

-- 2600 bank switching types (MiSTer detect2600.sv / bss_pkg.sv enum)
constant C_BS_F8              : std_logic_vector(4 downto 0) := "00001";
constant C_BS_F6              : std_logic_vector(4 downto 0) := "00010";
constant C_BS_FE              : std_logic_vector(4 downto 0) := "00011";
constant C_BS_E0              : std_logic_vector(4 downto 0) := "00100";
constant C_BS_3F              : std_logic_vector(4 downto 0) := "00101";
constant C_BS_F4              : std_logic_vector(4 downto 0) := "00110";
constant C_BS_P2              : std_logic_vector(4 downto 0) := "00111";
constant C_BS_FA              : std_logic_vector(4 downto 0) := "01000";
constant C_BS_CV              : std_logic_vector(4 downto 0) := "01001";
constant C_BS_UA              : std_logic_vector(4 downto 0) := "01011";
constant C_BS_E7              : std_logic_vector(4 downto 0) := "01100";
constant C_BS_F0              : std_logic_vector(4 downto 0) := "01101";
constant C_BS_AR              : std_logic_vector(4 downto 0) := "01111";
constant C_BS_3E              : std_logic_vector(4 downto 0) := "10000";
constant C_BS_SB              : std_logic_vector(4 downto 0) := "10001";
constant C_BS_EF              : std_logic_vector(4 downto 0) := "10011";

---------------------------------------------------------------------------------------------
-- main_clk
---------------------------------------------------------------------------------------------

signal main_region            : std_logic_vector(1 downto 0);
signal main_pal_temp          : std_logic_vector(1 downto 0);
signal main_hsc_mode          : std_logic_vector(1 downto 0);
signal main_bs_override       : std_logic_vector(4 downto 0);
signal main_paddles_a         : std_logic;
signal main_paddles_b         : std_logic;

signal main_cart_loading      : std_logic;
signal main_cart_loaded       : std_logic;
signal main_dl_active         : std_logic;
signal main_dl_tia            : std_logic;
signal main_dl_addr           : std_logic_vector(24 downto 0);
signal main_dl_data           : std_logic_vector(7 downto 0);
signal main_dl_wr             : std_logic;
signal main_rom_addr          : std_logic_vector(24 downto 0);
signal main_rom_rd            : std_logic;
signal main_rom_data          : std_logic_vector(7 downto 0);

signal main_bios_loading      : std_logic;
signal main_bios_loaded       : std_logic;
signal main_bios_addr         : std_logic_vector(14 downto 0);
signal main_bios_data         : std_logic_vector(7 downto 0);

---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

signal qnice_cart_ce          : std_logic;
signal qnice_cart_we          : std_logic;
signal qnice_cart_data        : std_logic_vector(15 downto 0);
signal qnice_bios_ce          : std_logic;
signal qnice_bios_we          : std_logic;
signal qnice_bios_data        : std_logic_vector(15 downto 0);

begin

   hr_core_write_o      <= '0';
   hr_core_read_o       <= '0';
   hr_core_address_o    <= (others => '0');
   hr_core_writedata_o  <= (others => '0');
   hr_core_byteenable_o <= (others => '0');
   hr_core_burstcount_o <= (others => '0');

   -- Tristate all expansion port drivers that we can directly control
   cart_ctrl_oe_o       <= '0';
   cart_addr_oe_o       <= '0';
   cart_data_oe_o       <= '0';

   -- Due to a bug in the R5/R6 boards, the cartridge port needs to be enabled for joystick port 2 to work
   cart_en_o            <= '1';

   cart_reset_oe_o      <= '0';
   cart_game_oe_o       <= '0';
   cart_exrom_oe_o      <= '0';
   cart_nmi_oe_o        <= '0';
   cart_irq_oe_o        <= '0';
   cart_roml_oe_o       <= '0';
   cart_romh_oe_o       <= '0';

   cart_phi2_o          <= '0';
   cart_reset_o         <= '1';
   cart_dotclock_o      <= '0';
   cart_game_o          <= '1';
   cart_exrom_o         <= '1';
   cart_nmi_o           <= '1';
   cart_irq_o           <= '1';
   cart_roml_o          <= '0';
   cart_romh_o          <= '0';
   cart_ba_o            <= '0';
   cart_rw_o            <= '0';
   cart_io1_o           <= '0';
   cart_io2_o           <= '0';
   cart_a_o             <= (others => '0');
   cart_d_o             <= (others => '0');

   main_joy_1_up_n_o    <= '1';
   main_joy_1_down_n_o  <= '1';
   main_joy_1_left_n_o  <= '1';
   main_joy_1_right_n_o <= '1';
   main_joy_1_fire_n_o  <= '1';
   main_joy_2_up_n_o    <= '1';
   main_joy_2_down_n_o  <= '1';
   main_joy_2_left_n_o  <= '1';
   main_joy_2_right_n_o <= '1';
   main_joy_2_fire_n_o  <= '1';

   -- IEC port is not used
   iec_reset_n_o        <= '1';
   iec_atn_n_o          <= '1';
   iec_clk_en_o         <= '0';
   iec_clk_n_o          <= '1';
   iec_data_en_o        <= '0';
   iec_data_n_o         <= '1';
   iec_srq_en_o         <= '0';
   iec_srq_n_o          <= '1';

   clk_gen : entity work.clk
      port map (
         sys_clk_i         => clk_i,
         main_clk_o        => main_clk,
         main_rst_o        => main_rst,
         video_clk_o       => video_clk,
         video_rst_o       => video_rst
      ); -- clk_gen

   main_clk_o  <= main_clk;
   main_rst_o  <= main_rst;
   video_clk_o <= video_clk;
   video_rst_o <= video_rst;

   ---------------------------------------------------------------------------------------------
   -- main_clk
   ---------------------------------------------------------------------------------------------

   main_power_led_o     <= '1';
   main_power_led_col_o <= x"0000FF" when main_reset_m2m_i else x"00FF00";

   -- Drive led: lights up while a cartridge or the BIOS is being loaded
   main_drive_led_o     <= main_cart_loading or main_bios_loading;
   main_drive_led_col_o <= x"00FF00";

   p_settings : process(main_clk)
   begin
      if rising_edge(main_clk) then
         -- Region: Auto (header / TIA line count), NTSC, PAL
         main_region <= "00";
         if main_osm_control_i(C_MENU_REGION_NTSC) = '1' then
            main_region <= "01";
         elsif main_osm_control_i(C_MENU_REGION_PAL) = '1' then
            main_region <= "10";
         end if;

         -- Colour temperature: warm, cool, hot
         main_pal_temp <= "00";
         if main_osm_control_i(C_MENU_TEMP_COOL) = '1' then
            main_pal_temp <= "01";
         elsif main_osm_control_i(C_MENU_TEMP_HOT) = '1' then
            main_pal_temp <= "10";
         end if;

         -- High score cartridge: auto, on, off
         main_hsc_mode <= "00";
         if main_osm_control_i(C_MENU_HSC_ON) = '1' then
            main_hsc_mode <= "01";
         elsif main_osm_control_i(C_MENU_HSC_OFF) = '1' then
            main_hsc_mode <= "10";
         end if;

         -- Controls
         main_paddles_a <= main_osm_control_i(C_MENU_PADDLES_1) or main_osm_control_i(C_MENU_PADDLES_BOTH);
         main_paddles_b <= main_osm_control_i(C_MENU_PADDLES_2) or main_osm_control_i(C_MENU_PADDLES_BOTH);

         -- 2600 bank switching: Auto (detected by detect2600) or a menu selection
         main_bs_override <= "00000";
         if    main_osm_control_i(C_MENU_BS_F8) = '1' then main_bs_override <= C_BS_F8;
         elsif main_osm_control_i(C_MENU_BS_F6) = '1' then main_bs_override <= C_BS_F6;
         elsif main_osm_control_i(C_MENU_BS_F4) = '1' then main_bs_override <= C_BS_F4;
         elsif main_osm_control_i(C_MENU_BS_FE) = '1' then main_bs_override <= C_BS_FE;
         elsif main_osm_control_i(C_MENU_BS_E0) = '1' then main_bs_override <= C_BS_E0;
         elsif main_osm_control_i(C_MENU_BS_3F) = '1' then main_bs_override <= C_BS_3F;
         elsif main_osm_control_i(C_MENU_BS_3E) = '1' then main_bs_override <= C_BS_3E;
         elsif main_osm_control_i(C_MENU_BS_FA) = '1' then main_bs_override <= C_BS_FA;
         elsif main_osm_control_i(C_MENU_BS_CV) = '1' then main_bs_override <= C_BS_CV;
         elsif main_osm_control_i(C_MENU_BS_UA) = '1' then main_bs_override <= C_BS_UA;
         elsif main_osm_control_i(C_MENU_BS_E7) = '1' then main_bs_override <= C_BS_E7;
         elsif main_osm_control_i(C_MENU_BS_F0) = '1' then main_bs_override <= C_BS_F0;
         elsif main_osm_control_i(C_MENU_BS_P2) = '1' then main_bs_override <= C_BS_P2;
         elsif main_osm_control_i(C_MENU_BS_AR) = '1' then main_bs_override <= C_BS_AR;
         elsif main_osm_control_i(C_MENU_BS_SB) = '1' then main_bs_override <= C_BS_SB;
         elsif main_osm_control_i(C_MENU_BS_EF) = '1' then main_bs_override <= C_BS_EF;
         end if;
      end if;
   end process p_settings;

   i_main : entity work.main
      port map (
         clk_main_i           => main_clk,
         clk_video_i          => video_clk,
         reset_soft_i         => main_reset_core_i,
         reset_hard_i         => main_reset_m2m_i,
         pause_i              => main_pause_core_i,

         clk_main_speed_i     => CORE_CLK_SPEED,

         region_i             => main_region,
         use_bios_i           => main_osm_control_i(C_MENU_USE_BIOS),
         diff_left_b_i        => main_osm_control_i(C_MENU_DIF_LEFT_B),
         diff_right_b_i       => main_osm_control_i(C_MENU_DIF_RIGHT_B),
         bw_i                 => main_osm_control_i(C_MENU_BW),
         hide_border_i        => main_osm_control_i(C_MENU_HIDE_BORDER),
         show_overscan_i      => main_osm_control_i(C_MENU_OVERSCAN),
         pal_temp_i           => main_pal_temp,
         stereo_tia_i         => main_osm_control_i(C_MENU_STEREO),
         pokey_irq_i          => main_osm_control_i(C_MENU_POKEY_IRQ),
         hsc_mode_i           => main_hsc_mode,
         clear_random_i       => main_osm_control_i(C_MENU_RANDOM),
         cpu_driver_maria_i   => main_osm_control_i(C_MENU_DRIVER_MARIA),
         decomb_i             => main_osm_control_i(C_MENU_DECOMB),
         blend_i              => main_osm_control_i(C_MENU_BLEND),
         tia_stab_off_i       => main_osm_control_i(C_MENU_NO_STAB),
         bs_override_i        => main_bs_override,
         fix_sc_i             => main_osm_control_i(C_MENU_FIX_SC),
         paddles_a_i          => main_paddles_a,
         paddles_b_i          => main_paddles_b,
         paddles_invert_i     => main_osm_control_i(C_MENU_PADDLES_INV),

         cart_loading_i       => main_cart_loading,
         cart_loaded_i        => main_cart_loaded,
         dl_active_i          => main_dl_active,
         dl_tia_i             => main_dl_tia,
         dl_addr_i            => main_dl_addr,
         dl_data_i            => main_dl_data,
         dl_wr_i              => main_dl_wr,
         rom_addr_o           => main_rom_addr,
         rom_rd_o             => main_rom_rd,
         rom_data_i           => main_rom_data,

         bios_loading_i       => main_bios_loading,
         bios_loaded_i        => main_bios_loaded,
         bios_addr_o          => main_bios_addr,
         bios_data_i          => main_bios_data,

         video_ce_o           => video_ce_o,
         video_ce_ovl_o       => video_ce_ovl_o,
         video_red_o          => video_red_o,
         video_green_o        => video_green_o,
         video_blue_o         => video_blue_o,
         video_vs_o           => video_vs_o,
         video_hs_o           => video_hs_o,
         video_hblank_o       => video_hblank_o,
         video_vblank_o       => video_vblank_o,

         audio_left_o         => main_audio_left_o,
         audio_right_o        => main_audio_right_o,

         kb_key_num_i         => main_kb_key_num_i,
         kb_key_pressed_n_i   => main_kb_key_pressed_n_i,

         joy_1_up_n_i         => main_joy_1_up_n_i,
         joy_1_down_n_i       => main_joy_1_down_n_i,
         joy_1_left_n_i       => main_joy_1_left_n_i,
         joy_1_right_n_i      => main_joy_1_right_n_i,
         joy_1_fire_n_i       => main_joy_1_fire_n_i,

         joy_2_up_n_i         => main_joy_2_up_n_i,
         joy_2_down_n_i       => main_joy_2_down_n_i,
         joy_2_left_n_i       => main_joy_2_left_n_i,
         joy_2_right_n_i      => main_joy_2_right_n_i,
         joy_2_fire_n_i       => main_joy_2_fire_n_i,

         pot1_x_i             => main_pot1_x_i,
         pot1_y_i             => main_pot1_y_i,
         pot2_x_i             => main_pot2_x_i,
         pot2_y_i             => main_pot2_y_i
      ); -- i_main

   ---------------------------------------------------------------------------------------------
   -- Audio and video settings (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   qnice_video_mode_o <= C_VIDEO_SVGA_800_60   when qnice_osm_control_i(C_MENU_SVGA_800_60)    = '1' else
                         C_VIDEO_HDMI_720_5994 when qnice_osm_control_i(C_MENU_HDMI_720_5994)  = '1' else
                         C_VIDEO_HDMI_640_60   when qnice_osm_control_i(C_MENU_HDMI_640_60)    = '1' else
                         C_VIDEO_HDMI_5_4_50   when qnice_osm_control_i(C_MENU_HDMI_5_4_50)    = '1' else
                         C_VIDEO_HDMI_4_3_50   when qnice_osm_control_i(C_MENU_HDMI_4_3_50)    = '1' else
                         C_VIDEO_HDMI_16_9_50  when qnice_osm_control_i(C_MENU_HDMI_16_9_50)   = '1' else
                         C_VIDEO_HDMI_16_9_60;

   qnice_dvi_o                <= '0';                                         -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_scandoubler_o        <= '1';                                         -- VGA output: 31 kHz
   qnice_audio_mute_o         <= '0';
   qnice_audio_filter_o       <= qnice_osm_control_i(C_MENU_IMPROVE_AUDIO);
   qnice_zoom_crop_o          <= qnice_osm_control_i(C_MENU_HDMI_ZOOM);
   qnice_retro15kHz_o         <= '0';
   qnice_csync_o              <= '0';
   qnice_osm_cfg_scaling_o    <= (others => '1');
   qnice_ascal_mode_o         <= "00";
   qnice_ascal_polyphase_o    <= qnice_osm_control_i(C_MENU_CRT_EMULATION);
   qnice_ascal_triplebuf_o    <= '0';

   -- Swap joysticks (the framework swaps the two ports)
   qnice_flip_joyports_o      <= qnice_osm_control_i(C_MENU_SWAP_JOY);

   ---------------------------------------------------------------------------------------------
   -- Core specific device handling (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   core_specific_devices : process(all)
   begin
      qnice_dev_data_o     <= x"EEEE";
      qnice_dev_wait_o     <= '0';
      qnice_cart_ce        <= '0';
      qnice_cart_we        <= '0';
      qnice_bios_ce        <= '0';
      qnice_bios_we        <= '0';

      case qnice_dev_id_i is
         when C_DEV_A78_CART =>
            qnice_cart_ce     <= qnice_dev_ce_i;
            qnice_cart_we     <= qnice_dev_we_i;
            qnice_dev_data_o  <= qnice_cart_data;

         when C_DEV_A78_BIOS =>
            qnice_bios_ce     <= qnice_dev_ce_i;
            qnice_bios_we     <= qnice_dev_we_i;
            qnice_dev_data_o  <= qnice_bios_data;

         when others => null;
      end case;
   end process core_specific_devices;

   ---------------------------------------------------------------------------------------------
   -- Cartridge (512 KB BRAM) and BIOS (32 KB BRAM), loaded by the M2M file browser (QNICE)
   ---------------------------------------------------------------------------------------------

   i_cart : entity work.cart
      generic map (
         G_ADDR_BITS       => C_CART_ADDR_BITS
      )
      port map (
         qnice_clk_i       => qnice_clk_i,
         qnice_rst_i       => qnice_rst_i,
         qnice_addr_i      => qnice_dev_addr_i,
         qnice_data_i      => qnice_dev_data_i,
         qnice_data_o      => qnice_cart_data,
         qnice_ce_i        => qnice_cart_ce,
         qnice_we_i        => qnice_cart_we,

         main_clk_i        => main_clk,
         main_loading_o    => main_cart_loading,
         main_loaded_o     => main_cart_loaded,
         main_dl_active_o  => main_dl_active,
         main_dl_tia_o     => main_dl_tia,
         main_dl_addr_o    => main_dl_addr,
         main_dl_data_o    => main_dl_data,
         main_dl_wr_o      => main_dl_wr,
         main_rom_addr_i   => main_rom_addr,
         main_rom_rd_i     => main_rom_rd,
         main_rom_data_o   => main_rom_data
      ); -- i_cart

   i_bios : entity work.bios
      port map (
         qnice_clk_i       => qnice_clk_i,
         qnice_rst_i       => qnice_rst_i,
         qnice_addr_i      => qnice_dev_addr_i,
         qnice_data_i      => qnice_dev_data_i,
         qnice_data_o      => qnice_bios_data,
         qnice_ce_i        => qnice_bios_ce,
         qnice_we_i        => qnice_bios_we,

         main_clk_i        => main_clk,
         main_loading_o    => main_bios_loading,
         main_loaded_o     => main_bios_loaded,
         main_addr_i       => main_bios_addr,
         main_data_o       => main_bios_data
      ); -- i_bios

end architecture synthesis;

