----------------------------------------------------------------------------------
-- Atari 7800 for MEGA65
--
-- Wrapper for the MiSTer Atari 7800 core (Atari7800_MiSTer by Jamie Blanks)
--
-- Clock domains:
--    clk_main_i  (14.318182 MHz): the console (MiSTer clk_sys), keyboard, joysticks, settings
--    clk_video_i (57.272727 MHz): video output (MiSTer clk_vid), 4 x clk_main_i, edges aligned
--
-- Based on the MiSTer2MEGA65 framework (sy2002 and MJoergen), licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity main is
   port (
      clk_main_i              : in  std_logic;              -- 14.318182 MHz
      clk_video_i             : in  std_logic;              -- 57.272727 MHz
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Settings (clk_main_i domain, from the options menu)
      region_i                : in  std_logic_vector(1 downto 0);   -- 0 auto, 1 NTSC, 2 PAL
      use_bios_i              : in  std_logic;
      diff_left_b_i           : in  std_logic;
      diff_right_b_i          : in  std_logic;
      bw_i                    : in  std_logic;
      hide_border_i           : in  std_logic;
      show_overscan_i         : in  std_logic;
      pal_temp_i              : in  std_logic_vector(1 downto 0);
      stereo_tia_i            : in  std_logic;
      pokey_irq_i             : in  std_logic;
      hsc_mode_i              : in  std_logic_vector(1 downto 0);   -- 0 auto, 1 on, 2 off
      clear_random_i          : in  std_logic;
      cpu_driver_maria_i      : in  std_logic;
      decomb_i                : in  std_logic;
      blend_i                 : in  std_logic;
      tia_stab_off_i          : in  std_logic;
      bs_override_i           : in  std_logic_vector(4 downto 0);   -- 0 = auto
      fix_sc_i                : in  std_logic;
      paddles_a_i             : in  std_logic;              -- paddles in port 1
      paddles_b_i             : in  std_logic;              -- paddles in port 2
      paddles_invert_i        : in  std_logic;

      -- Cartridge (cart.vhd): MiSTer download stream and ROM read port
      cart_loading_i          : in  std_logic;              -- hold the core in reset
      cart_loaded_i           : in  std_logic;
      dl_active_i             : in  std_logic;
      dl_tia_i                : in  std_logic;
      dl_addr_i               : in  std_logic_vector(24 downto 0);
      dl_data_i               : in  std_logic_vector(7 downto 0);
      dl_wr_i                 : in  std_logic;
      rom_addr_o              : out std_logic_vector(24 downto 0);
      rom_rd_o                : out std_logic;
      rom_data_i              : in  std_logic_vector(7 downto 0);

      -- BIOS (bios.vhd)
      bios_loading_i          : in  std_logic;
      bios_loaded_i           : in  std_logic;
      bios_addr_o             : out std_logic_vector(14 downto 0);
      bios_data_i             : in  std_logic_vector(7 downto 0);

      -- Video output (clk_video_i domain)
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(7 downto 0);
      video_green_o           : out std_logic_vector(7 downto 0);
      video_blue_o            : out std_logic_vector(7 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0)
   );
end entity main;

architecture synthesis of main is

component atari7800_m65 is
   port (
      clk_sys           : in  std_logic;
      reset_in          : in  std_logic;
      dl_active         : in  std_logic;
      dl_tia            : in  std_logic;
      dl_addr           : in  std_logic_vector(24 downto 0);
      dl_data           : in  std_logic_vector(7 downto 0);
      dl_wr             : in  std_logic;
      cart_loaded_in    : in  std_logic;
      rom_rd            : out std_logic;
      rom_addr          : out std_logic_vector(24 downto 0);
      rom_data          : in  std_logic_vector(7 downto 0);
      bios_addr         : out std_logic_vector(14 downto 0);
      bios_data         : in  std_logic_vector(7 downto 0);
      bios_loaded       : in  std_logic;
      region            : in  std_logic_vector(1 downto 0);
      use_bios          : in  std_logic;
      diff_left_b       : in  std_logic;
      diff_right_b      : in  std_logic;
      bw                : in  std_logic;
      hide_border       : in  std_logic;
      show_overscan     : in  std_logic;
      pal_temp          : in  std_logic_vector(1 downto 0);
      stereo_tia        : in  std_logic;
      pokey_irq         : in  std_logic;
      hsc_mode          : in  std_logic_vector(1 downto 0);
      clear_random      : in  std_logic;
      cpu_driver_maria  : in  std_logic;
      decomb            : in  std_logic;
      blend             : in  std_logic;
      tia_stab_off      : in  std_logic;
      bs_override       : in  std_logic_vector(4 downto 0);
      fix_sc            : in  std_logic;
      joy0              : in  std_logic_vector(8 downto 0);
      joy1              : in  std_logic_vector(8 downto 0);
      paddles_a         : in  std_logic;
      paddles_b         : in  std_logic;
      pad0              : in  std_logic_vector(7 downto 0);
      pad1              : in  std_logic_vector(7 downto 0);
      pad2              : in  std_logic_vector(7 downto 0);
      pad3              : in  std_logic_vector(7 downto 0);
      pad_btn           : in  std_logic_vector(3 downto 0);
      red               : out std_logic_vector(7 downto 0);
      green             : out std_logic_vector(7 downto 0);
      blue              : out std_logic_vector(7 downto 0);
      hsync             : out std_logic;
      vsync             : out std_logic;
      hblank            : out std_logic;
      vblank            : out std_logic;
      ce_pix            : out std_logic;
      tia_en_o          : out std_logic;
      pal_o             : out std_logic;
      audio_l           : out std_logic_vector(15 downto 0);
      audio_r           : out std_logic_vector(15 downto 0)
   );
end component atari7800_m65;

-- keyboard (high active)
signal key_up, key_down, key_left, key_right    : std_logic;
signal key_fire1, key_fire2                     : std_logic;
signal key_select, key_reset, key_pause         : std_logic;

-- MiSTer joystick bits (high active): 0 R, 1 L, 2 D, 3 U, 4 fire 1, 5 fire 2, 6 pause, 7 select, 8 reset
signal joy0, joy1                               : std_logic_vector(8 downto 0);
signal pad0, pad1, pad2, pad3                   : std_logic_vector(7 downto 0);
signal pad_btn                                  : std_logic_vector(3 downto 0);

signal core_reset                               : std_logic;

-- core outputs (clk_main_i domain)
signal c_r, c_g, c_b                            : std_logic_vector(7 downto 0);
signal c_hs, c_vs, c_hb, c_vb                   : std_logic;
signal c_audio_l, c_audio_r                     : std_logic_vector(15 downto 0);

-- video sampling (clk_main_i domain)
signal s_phase                                  : std_logic := '0';
signal s_hs_d                                   : std_logic := '0';
signal s_vs_line                                : std_logic := '0';
signal s_tog                                    : std_logic := '0';
signal s_r, s_g, s_b                            : std_logic_vector(7 downto 0) := (others => '0');
signal s_hs, s_vs, s_hb, s_vb                   : std_logic := '0';

-- video output (clk_video_i domain)
signal v_tog_d1, v_tog_d2                       : std_logic := '0';
signal v_cnt                                    : unsigned(2 downto 0) := (others => '0');

begin

   ---------------------------------------------------------------------------------------------
   -- Controls
   ---------------------------------------------------------------------------------------------

   i_keyboard : entity work.keyboard
      port map (
         clk_main_i           => clk_main_i,
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,
         key_up_o             => key_up,
         key_down_o           => key_down,
         key_left_o           => key_left,
         key_right_o          => key_right,
         key_fire1_o          => key_fire1,
         key_fire2_o          => key_fire2,
         key_select_o         => key_select,
         key_reset_o          => key_reset,
         key_pause_o          => key_pause
      ); -- i_keyboard

   -- Player 1: joystick port 1 and the keyboard (incl. the console keys); player 2: joystick port 2.
   -- The MEGA65 joysticks have one button: button 1 (2600: fire). Button 2 is Z on the keyboard.
   joy0(0) <= not joy_1_right_n_i or key_right;
   joy0(1) <= not joy_1_left_n_i  or key_left;
   joy0(2) <= not joy_1_down_n_i  or key_down;
   joy0(3) <= not joy_1_up_n_i    or key_up;
   joy0(4) <= not joy_1_fire_n_i  or key_fire1;
   joy0(5) <= key_fire2;
   joy0(6) <= key_pause;
   joy0(7) <= key_select;
   joy0(8) <= key_reset;

   joy1(0) <= not joy_2_right_n_i;
   joy1(1) <= not joy_2_left_n_i;
   joy1(2) <= not joy_2_down_n_i;
   joy1(3) <= not joy_2_up_n_i;
   joy1(4) <= not joy_2_fire_n_i;
   joy1(5) <= '0';
   joy1(6) <= '0';
   joy1(7) <= '0';
   joy1(8) <= '0';

   -- Paddles: C64/Atari paddles in the MEGA65 ports. The paddle buttons are the joystick left/right
   -- lines (MiSTer: paddles 0/1 = port 1, 2/3 = port 2).
   pad0 <= not pot1_x_i when paddles_invert_i = '1' else pot1_x_i;
   pad1 <= not pot1_y_i when paddles_invert_i = '1' else pot1_y_i;
   pad2 <= not pot2_x_i when paddles_invert_i = '1' else pot2_x_i;
   pad3 <= not pot2_y_i when paddles_invert_i = '1' else pot2_y_i;
   pad_btn(0) <= not joy_1_left_n_i;
   pad_btn(1) <= not joy_1_right_n_i;
   pad_btn(2) <= not joy_2_left_n_i;
   pad_btn(3) <= not joy_2_right_n_i;

   -- MiSTer also resets the core while a cartridge or the BIOS is downloaded
   core_reset <= reset_soft_i or reset_hard_i or cart_loading_i or bios_loading_i;

   ---------------------------------------------------------------------------------------------
   -- The Atari 7800
   ---------------------------------------------------------------------------------------------

   i_atari7800 : atari7800_m65
      port map (
         clk_sys           => clk_main_i,
         reset_in          => core_reset,
         dl_active         => dl_active_i,
         dl_tia            => dl_tia_i,
         dl_addr           => dl_addr_i,
         dl_data           => dl_data_i,
         dl_wr             => dl_wr_i,
         cart_loaded_in    => cart_loaded_i,
         rom_rd            => rom_rd_o,
         rom_addr          => rom_addr_o,
         rom_data          => rom_data_i,
         bios_addr         => bios_addr_o,
         bios_data         => bios_data_i,
         bios_loaded       => bios_loaded_i,
         region            => region_i,
         use_bios          => use_bios_i,
         diff_left_b       => diff_left_b_i,
         diff_right_b      => diff_right_b_i,
         bw                => bw_i,
         hide_border       => hide_border_i,
         show_overscan     => show_overscan_i,
         pal_temp          => pal_temp_i,
         stereo_tia        => stereo_tia_i,
         pokey_irq         => pokey_irq_i,
         hsc_mode          => hsc_mode_i,
         clear_random      => clear_random_i,
         cpu_driver_maria  => cpu_driver_maria_i,
         decomb            => decomb_i,
         blend             => blend_i,
         tia_stab_off      => tia_stab_off_i,
         bs_override       => bs_override_i,
         fix_sc            => fix_sc_i,
         joy0              => joy0,
         joy1              => joy1,
         paddles_a         => paddles_a_i,
         paddles_b         => paddles_b_i,
         pad0              => pad0,
         pad1              => pad1,
         pad2              => pad2,
         pad3              => pad3,
         pad_btn           => pad_btn,
         red               => c_r,
         green             => c_g,
         blue              => c_b,
         hsync             => c_hs,
         vsync             => c_vs,
         hblank            => c_hb,
         vblank            => c_vb,
         ce_pix            => open,
         tia_en_o          => open,
         pal_o             => open,
         audio_l           => c_audio_l,
         audio_r           => c_audio_r
      ); -- i_atari7800

   ---------------------------------------------------------------------------------------------
   -- Audio: MiSTer AUDIO_S = 0, i.e. unsigned. To signed: flip the MSB. Muted while the core is
   -- held in reset (cartridge loading).
   ---------------------------------------------------------------------------------------------

   p_audio : process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         if core_reset = '1' then
            audio_left_o  <= (others => '0');
            audio_right_o <= (others => '0');
         else
            audio_left_o  <= signed((not c_audio_l(15)) & c_audio_l(14 downto 0));
            audio_right_o <= signed((not c_audio_r(15)) & c_audio_r(14 downto 0));
         end if;
      end if;
   end process p_audio;

   ---------------------------------------------------------------------------------------------
   -- Video, step 1 (clk_main_i): sample the core output at the MARIA pixel rate, every second
   -- clk_main_i (7.16 MHz; MARIA changes its output at most that often, a 2600 TIA pixel is sampled
   -- twice). VSYNC only changes at the start of a line (hsync edge) and the VSYNC lines are blanked:
   -- the HDMI scaler (ascal) starts a new frame at the first visible pixel after the VSYNC edge, so a
   -- VSYNC in the middle of an unblanked line (2600 games set VSYNC in software) shifts the picture.
   -- Each new sample toggles s_tog.
   ---------------------------------------------------------------------------------------------

   p_sample : process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         s_hs_d <= c_hs;
         if s_hs_d = '0' and c_hs = '1' then
            s_vs_line <= c_vs;
         end if;

         s_phase <= not s_phase;
         if s_phase = '1' then
            s_r   <= c_r;
            s_g   <= c_g;
            s_b   <= c_b;
            s_hs  <= c_hs;
            s_vs  <= s_vs_line;
            s_hb  <= c_hb;
            s_vb  <= c_vb or s_vs_line;
            s_tog <= not s_tog;
         end if;
      end if;
   end process p_sample;

   ---------------------------------------------------------------------------------------------
   -- Video, step 2 (clk_video_i = 4 x clk_main_i, edges aligned, so Vivado times these paths):
   -- a change of s_tog marks a new pixel. The sample registers are stable for 8 clk_video_i cycles.
   -- video_ce_o = one pulse per pixel (7.16 MHz), video_ce_ovl_o = twice that (post scandoubler).
   ---------------------------------------------------------------------------------------------

   p_video : process(clk_video_i)
   begin
      if rising_edge(clk_video_i) then
         v_tog_d1       <= s_tog;
         v_tog_d2       <= v_tog_d1;
         video_ce_o     <= '0';
         video_ce_ovl_o <= '0';
         v_cnt          <= v_cnt + 1;

         if v_tog_d1 /= v_tog_d2 then
            video_ce_o     <= '1';
            video_ce_ovl_o <= '1';
            v_cnt          <= "001";
            video_red_o    <= s_r;
            video_green_o  <= s_g;
            video_blue_o   <= s_b;
            video_hs_o     <= s_hs;
            video_vs_o     <= s_vs;
            video_hblank_o <= s_hb;
            video_vblank_o <= s_vb;
         elsif v_cnt = 4 then
            video_ce_ovl_o <= '1';
         end if;
      end if;
   end process p_video;

end architecture synthesis;

