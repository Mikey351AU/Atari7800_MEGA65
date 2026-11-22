---------------------------------------------------------------------------------------------------------
-- Atari 7800 for MEGA65
--
-- MEGA65 keyboard -> 7800 controls (high active, '1' = pressed)
--    Cursor keys       joystick 1 directions
--    Space             joystick 1 button 1 (left button; 2600 fire)
--    Z                 joystick 1 button 2 (right button). Not a Shift key: the MEGA65's
--                      dedicated cursor up/left keys may report a Shift as well
--    F1                console "Select"
--    F3                console "Reset" (2600: Game Reset)
--    F5                console "Pause" (7800 only; the 2600 colour/B&W switch is in the menu)
--
-- kb_key_num_i runs through the key numbers 0 to 79 (1000 times per second), kb_key_pressed_n_i
-- is debounced and low active.
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
---------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity keyboard is
   port (
      clk_main_i           : in std_logic;               -- core clock

      -- Interface to the MEGA65 keyboard
      key_num_i            : in integer range 0 to 79;   -- cycles through all MEGA65 keys
      key_pressed_n_i      : in std_logic;               -- low active: debounced feedback: is kb_key_num_i pressed right now?

      key_up_o             : out std_logic;
      key_down_o           : out std_logic;
      key_left_o           : out std_logic;
      key_right_o          : out std_logic;
      key_fire1_o          : out std_logic;
      key_fire2_o          : out std_logic;
      key_select_o         : out std_logic;
      key_reset_o          : out std_logic;
      key_pause_o          : out std_logic
   );
end keyboard;

architecture beh of keyboard is

-- MEGA65 key codes that kb_key_num_i is using while
-- kb_key_pressed_n_i is signalling (low active) which key is pressed
constant m65_horz_crsr     : integer := 2;   -- means cursor right in C64 terminology
constant m65_f1            : integer := 4;
constant m65_f3            : integer := 5;
constant m65_f5            : integer := 6;
constant m65_vert_crsr     : integer := 7;   -- means cursor down in C64 terminology
constant m65_z             : integer := 12;
constant m65_space         : integer := 60;
constant m65_up_crsr       : integer := 73;  -- cursor up
constant m65_left_crsr     : integer := 74;  -- cursor left

signal key_pressed_n : std_logic_vector(79 downto 0) := (others => '1');

begin

   -- m65_vert_crsr is cursor down and m65_horz_crsr is cursor right; up and left are dedicated keys.
   -- The opposite direction is suppressed while a dedicated key is held.
   key_up_o     <= not key_pressed_n(m65_up_crsr);
   key_down_o   <= not key_pressed_n(m65_vert_crsr) and key_pressed_n(m65_up_crsr);
   key_left_o   <= not key_pressed_n(m65_left_crsr);
   key_right_o  <= not key_pressed_n(m65_horz_crsr) and key_pressed_n(m65_left_crsr);
   key_fire1_o  <= not key_pressed_n(m65_space);
   key_fire2_o  <= not key_pressed_n(m65_z);
   key_select_o <= not key_pressed_n(m65_f1);
   key_reset_o  <= not key_pressed_n(m65_f3);
   key_pause_o  <= not key_pressed_n(m65_f5);

   keyboard_state : process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         key_pressed_n(key_num_i) <= key_pressed_n_i;
      end if;
   end process;

end beh;
