----------------------------------------------------------------------------------
-- Atari 7800 for MEGA65
--
-- Configuration data for the Shell
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity config is
port (
   clk_i       : in std_logic;

   -- bits 27 .. 12:    select configuration data block; called "Selector" hereafter
   -- bits 11 downto 0: address the up to 4k the configuration data
   address_i   : in std_logic_vector(27 downto 0);

   -- config data
   data_o      : out std_logic_vector(15 downto 0)
);
end entity config;

architecture beh of config is

--------------------------------------------------------------------------------------------------------------------
-- String and character constants (specific for the Anikki-16x16 font)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant CHR_LINE_1  : character := character'val(196);
constant CHR_LINE_5  : string := CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1;
constant CHR_LINE_10 : string := CHR_LINE_5 & CHR_LINE_5;
constant CHR_LINE_50 : string := CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10;

--------------------------------------------------------------------------------------------------------------------
-- Welcome and Help Screens (Selectors 0x1000 .. 0x1FFF)
--------------------------------------------------------------------------------------------------------------------

-- define the amount of WHS array elements: between 1 and 16
constant WHS_RECORDS   : natural := 2;

-- define the maximum amount of pages per WHS array element: between 1 and 256
-- (this is necessary because Vivado does not support unconstrained arrays in a record)
constant WHS_MAX_PAGES : natural := 2;

 -- !!! DO NOT TOUCH !!!
constant SEL_WHS           : std_logic_vector(15 downto 0) := x"1000";
type WHS_INDEX_TYPE is array (0 to WHS_MAX_PAGES - 1) of natural;
type WHS_RECORD_TYPE is record
   page_count  : natural;
   page_start  : WHS_INDEX_TYPE;
   page_length : WHS_INDEX_TYPE;
end record;
type WHS_RECORD_ARRAY_TYPE is array (0 to WHS_RECORDS - 1) of WHS_RECORD_TYPE;

-- START YOUR CONFIGURATION BELOW THIS LINE

-- IMPORTANT: The OSM resolution is 640 x 384 pixels (VGA_DX/VGA_DY in globals.vhd), i.e. 40 x 24
-- characters. Minus the frame, every line can have at most 38 characters and every screen at most
-- 22 lines.

constant SCR_WELCOME : string :=

   " Atari 7800 for MEGA65 Version 0.3\n\n" &

   " MiSTer core by Jamie Blanks\n" &
   " (Atari7800_MiSTer)\n\n" &

   -- We are not insisting. But it would be nice if you gave us credit for MiSTer2MEGA65 by leaving these lines in
   " Powered by MiSTer2MEGA65\n" &
   " by sy2002 and MJoergen\n\n" &

   " Key              Function\n" &
   " " & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_5 & "\n" &
   " Help             Menu and cartridges\n" &
   " Cursor keys      Joystick 1\n" &
   " Space / Z        Buttons 1 / 2\n" &
   " F1 / F3 / F5     Select/Reset/Pause\n\n" &

   " Joysticks or paddles: ports 1 and 2\n\n" &

   " Press Space to continue.\n";

constant HELP_1 : string :=

   "\n Atari 7800 for MEGA65 Version 0.3\n\n" &

   " Plays 7800 and 2600 cartridges.\n" &
   " Load one with 'Cartridge' (folder\n" &
   " /atari7800, max. 512 KB). A file\n" &
   " with an A78 header is a 7800 game,\n" &
   " all others are 2600 games.\n\n" &

   " 2600 bank switching is detected\n" &
   " from the cartridge. If a game does\n" &
   " not work, set '2600 type'.\n" &
   " ARM games (DPC+, CDF, BUS) are not\n" &
   " supported.\n\n" &

   " A BIOS is not needed. Load one with\n" &
   " 'BIOS' and switch on 'Use BIOS'.\n\n" &

   " Cursor right: next page    (1 of 2)\n" &
   " Space: close help";

constant HELP_2 : string :=

   "\n Controls\n\n" &

   " Joysticks: ports 1 and 2. Cursor\n" &
   " keys, Space (button 1) and Z\n" &
   " (button 2) work as joystick 1.\n\n" &

   " Paddles: 'Controls' in the menu.\n" &
   " Port 1 = paddles 1 and 2, port 2 =\n" &
   " paddles 3 and 4. 'Invert paddles'\n" &
   " turns the direction.\n\n" &

   " Console: F1 = Select, F3 = Reset,\n" &
   " F5 = Pause (7800). Difficulty and\n" &
   " B&W are in 'Console switches'.\n\n" &

   " Most changes need a reset.\n\n" &

   " Cursor left: previous page (2 of 2)\n" &
   " Space: close help";

-- Concatenate all your Welcome and Help screens into one large string, so that during synthesis one large string ROM can be build.
constant WHS_DATA : string := SCR_WELCOME & HELP_1 & HELP_2;

constant SCR_WELCOME_START : natural := 0;
constant HELP_1_START      : natural := SCR_WELCOME'length;
constant HELP_2_START      : natural := HELP_1_START + HELP_1'length;

constant WHS : WHS_RECORD_ARRAY_TYPE := (
   --- Welcome Screen
   (page_count    => 1,
    page_start    => (SCR_WELCOME_START,  0),
    page_length   => (SCR_WELCOME'length, 0)),

   --- Help pages
   (page_count    => 2,
    page_start    => (HELP_1_START,  HELP_2_START),
    page_length   => (HELP_1'length, HELP_2'length))
);

--------------------------------------------------------------------------------------------------------------------
-- Set start folder for file browser and specify config file for menu persistence (Selectors 0x0100 and 0x0101)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant SEL_DIR_START     : std_logic_vector(15 downto 0) := x"0100";
constant SEL_CFG_FILE      : std_logic_vector(15 downto 0) := x"0101";

-- START YOUR CONFIGURATION BELOW THIS LINE

constant DIR_START         : string := "/atari7800";
constant CFG_FILE          : string := "/atari7800/a78cfg";

--------------------------------------------------------------------------------------------------------------------
-- General configuration settings: Reset, Pause, OSD behavior, Ascal, etc. (Selector 0x0110)
--------------------------------------------------------------------------------------------------------------------

constant SEL_GENERAL       : std_logic_vector(15 downto 0) := x"0110";  -- !!! DO NOT TOUCH !!!

-- START YOUR CONFIGURATION BELOW THIS LINE

constant RESET_COUNTER     : natural := 100;

-- put the core in PAUSE state if any OSD opens
-- Atari 7800: false (like the Atari 2600 port and like MiSTer's default "Pause Core on OSD: Off").
-- In 2600 mode the game software generates VSYNC, so a halted CPU means a picture without vertical
-- sync behind the menu. The game keeps running behind the menu; inputs are disconnected.
constant OPTM_PAUSE        : boolean := false;

constant WELCOME_ACTIVE    : boolean := true;
constant WELCOME_AT_RESET  : boolean := false;

constant KEYBOARD_AT_RESET : boolean := false;
constant JOY_1_AT_RESET    : boolean := false;
constant JOY_2_AT_RESET    : boolean := false;

constant KEYBOARD_AT_OSD   : boolean := false;
constant JOY_1_AT_OSD      : boolean := false;
constant JOY_2_AT_OSD      : boolean := false;

constant ASCAL_USAGE       : natural := 2;
constant ASCAL_MODE        : natural := 0;

constant SAVE_SETTINGS     : boolean := true;

constant VD_ANTI_THRASHING_DELAY : natural := 2000;
constant VD_ITERATION_SIZE       : natural := 100;

--------------------------------------------------------------------------------------------------------------------
-- Name and version of the core  (Selector 0x0200)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant SEL_CORENAME      : std_logic_vector(15 downto 0) := x"0200";

-- START YOUR CONFIGURATION BELOW THIS LINE

constant CORENAME          : string := "ATARI 7800 FOR MEGA65 V0.3";

--------------------------------------------------------------------------------------------------------------------
-- "Help" menu / Options menu  (Selectors 0x0300 .. 0x0312): DO NOT TOUCH
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!! Selectors for accessing the menu configuration data
constant SEL_OPTM_ITEMS       : std_logic_vector(15 downto 0) := x"0300";
constant SEL_OPTM_GROUPS      : std_logic_vector(15 downto 0) := x"0301";
constant SEL_OPTM_STDSEL      : std_logic_vector(15 downto 0) := x"0302";
constant SEL_OPTM_LINES       : std_logic_vector(15 downto 0) := x"0303";
constant SEL_OPTM_START       : std_logic_vector(15 downto 0) := x"0304";
constant SEL_OPTM_ICOUNT      : std_logic_vector(15 downto 0) := x"0305";
constant SEL_OPTM_MOUNT_DRV   : std_logic_vector(15 downto 0) := x"0306";
constant SEL_OPTM_SINGLESEL   : std_logic_vector(15 downto 0) := x"0307";
constant SEL_OPTM_MOUNT_STR   : std_logic_vector(15 downto 0) := x"0308";
constant SEL_OPTM_DIMENSIONS  : std_logic_vector(15 downto 0) := x"0309";
constant SEL_OPTM_SAVING_STR  : std_logic_vector(15 downto 0) := x"030A";
constant SEL_OPTM_HELP        : std_logic_vector(15 downto 0) := x"0310";
constant SEL_OPTM_CRTROM      : std_logic_vector(15 downto 0) := x"0311";
constant SEL_OPTM_CRTROM_STR  : std_logic_vector(15 downto 0) := x"0312";

-- !!! DO NOT TOUCH !!! Configuration constants for OPTM_GROUPS (shell.asm and menu.asm expect them to be like this)
constant OPTM_G_TEXT       : integer := 16#00000#;         -- text that cannot be selected
constant OPTM_G_CLOSE      : integer := 16#000FF#;        -- menu items that closes menu
constant OPTM_G_STDSEL     : integer := 16#00100#;        -- item within a group that is selected by default
constant OPTM_G_LINE       : integer := 16#00200#;        -- draw a line at this position
constant OPTM_G_START      : integer := 16#00400#;        -- selector / cursor position after startup (only use once!)
                                                          -- 16#00800# is used in OPTM_G_MOUNT_DRV (OPTM_G_SINGLESEL)
constant OPTM_G_HEADLINE   : integer := 16#01000#;        -- like OPTM_G_TEXT but will be shown in a brigher color
                                                          -- 16#02000# is used in OPTM_G_HELP (plus OPTM_G_SINGLESEL)
                                                          -- 16#04000# is used in OPTM_G_SUBMENU
constant OPTM_G_SINGLESEL  : integer := 16#08000#;        -- single select item
constant OPTM_G_MOUNT_DRV  : integer := 16#08800#;        -- line item means: mount drive; first occurance = drive 0, second = drive 1, ...
constant OPTM_G_HELP       : integer := 16#0A000#;        -- line item means: help screen; first occurance = WHS(1), second = WHS(2), ...
constant OPTM_G_SUBMENU    : integer := 16#0C000#;        -- starts/ends a section that is treated as submenu
constant OPTM_G_LOAD_ROM   : integer := 16#18000#;        -- line item means: load ROM; first occurance = rom 0, second = rom 1, ...

constant OPTM_GTC          : natural := 17;                -- Amount of significant bits in OPTM_G_* constants

--------------------------------------------------------------------------------------------------------------------
-- "Help" menu / Options menu: START YOUR CONFIGURATION BELOW THIS LINE
--------------------------------------------------------------------------------------------------------------------

constant OPTM_S_MOUNT      : string := "<Mount>";
constant OPTM_S_CRTROM     : string := "<Load>";            -- nothing loaded, yet
constant OPTM_S_SAVING     : string := "<Saving>";

-- IMPORTANT: The menu item positions (0-based line numbers) are used as C_MENU_* constants in mega65.vhd.
--            If you change this menu, update mega65.vhd accordingly.
constant OPTM_SIZE         : natural := 103; -- amount of items including empty lines:
                                             -- needs to be equal to the number of lines in OPTM_ITEMS and amount of items in OPTM_GROUPS
                                             -- IMPORTANT: If SAVE_SETTINGS is true and OPTM_SIZE changes: Make sure to re-generate and
                                             -- and re-distribute the config file. You can make a new one using M2M/tools/make_config.sh

-- OSM is 40 x 24 characters: OPTM_DX <= 38, OPTM_DY <= 22.
-- OPTM_DY has to fit the main menu (17 lines) and the largest submenu ("2600 type", 21 lines).
constant OPTM_DX           : natural := 34;
constant OPTM_DY           : natural := 21;

constant OPTM_ITEMS        : string :=

   " Atari 7800\n"              &    --   0
   "\n"                         &    --   1
   " Cartridge: %s\n"           &    --   2  load cartridge
   " BIOS: %s\n"                &    --   3  load BIOS (optional)
   "\n"                         &    --   4

   " Region: %s\n"              &    --   5  region submenu
   " Region\n"                  &    --   6
   "\n"                         &    --   7
   " Auto\n"                    &    --   8
   " NTSC\n"                    &    --   9
   " PAL\n"                     &    --  10
   "\n"                         &    --  11
   " Back\n"                    &    --  12

   " Console switches\n"        &    --  13 console submenu
   " Console switches\n"        &    --  14
   "\n"                         &    --  15
   " Left difficulty B\n"       &    --  16
   " Right difficulty B\n"      &    --  17
   " 2600: Black & white\n"     &    --  18
   " Use BIOS (if loaded)\n"    &    --  19
   "\n"                         &    --  20
   " Back\n"                    &    --  21

   " Controls: %s\n"            &    --  22 controls submenu
   " Controls\n"                &    --  23
   "\n"                         &    --  24
   " Joysticks\n"               &    --  25
   " Paddles in port 1\n"       &    --  26
   " Paddles in port 2\n"       &    --  27
   " Paddles in both\n"         &    --  28
   "\n"                         &    --  29
   " Invert paddles\n"          &    --  30
   " Swap joysticks\n"          &    --  31
   "\n"                         &    --  32
   " Back\n"                    &    --  33

   " 2600 type: %s\n"           &    --  34 2600 bank switching submenu
   " 2600 bank switching\n"     &    --  35
   "\n"                         &    --  36
   " Auto (detect)\n"           &    --  37
   " F8  8K Atari\n"            &    --  38
   " F6  16K Atari\n"           &    --  39
   " F4  32K Atari\n"           &    --  40
   " FE  8K Activision\n"       &    --  41
   " E0  8K Parker Bros\n"      &    --  42
   " 3F  Tigervision\n"         &    --  43
   " 3E  Tigervision+RAM\n"     &    --  44
   " FA  12K CBS RAM Plus\n"    &    --  45
   " CV  Commavid\n"            &    --  46
   " UA  UA Limited\n"          &    --  47
   " E7  16K M-Network\n"       &    --  48
   " F0  64K Dynacom\n"         &    --  49
   " P2  Pitfall II (DPC)\n"    &    --  50
   " AR  Supercharger\n"        &    --  51
   " SB  Superbanking\n"        &    --  52
   " EF  64K Homestar\n"        &    --  53
   "\n"                         &    --  54
   " Back\n"                    &    --  55

   " Video and audio\n"         &    --  56 video & audio submenu
   " Video and audio\n"         &    --  57
   "\n"                         &    --  58
   " Warm colors\n"             &    --  59
   " Cool colors\n"             &    --  60
   " Hot colors\n"              &    --  61
   "\n"                         &    --  62
   " Hide border\n"             &    --  63
   " Show overscan\n"           &    --  64
   " 2600: Flicker blend\n"     &    --  65
   " 2600: De-comb\n"           &    --  66
   " 2600: No stabilizer\n"     &    --  67
   " Stereo TIA\n"              &    --  68
   " Audio improvements\n"      &    --  69
   " HDMI: CRT emulation\n"     &    --  70
   " HDMI: Zoom-in\n"           &    --  71
   "\n"                         &    --  72
   " Back\n"                    &    --  73

   " Advanced\n"                &    --  74 advanced submenu
   " Advanced\n"                &    --  75
   "\n"                         &    --  76
   " High score cart: Auto\n"   &    --  77
   " High score cart: On\n"     &    --  78
   " High score cart: Off\n"    &    --  79
   "\n"                         &    --  80
   " Pokey IRQ\n"               &    --  81
   " Random memory\n"           &    --  82
   " 2600: CPU driver MARIA\n"  &    --  83
   " 2600: Fix SC checksums\n"  &    --  84
   "\n"                         &    --  85
   " Back\n"                    &    --  86

   " HDMI: %s\n"                &    --  87 HDMI submenu
   " HDMI mode\n"               &    --  88
   "\n"                         &    --  89
   " 720p 50 Hz 16:9\n"         &    --  90
   " 720p 60 Hz 16:9\n"         &    --  91
   " 576p 50 Hz 4:3\n"          &    --  92
   " 576p 50 Hz 5:4\n"          &    --  93
   " 640x480 60 Hz\n"           &    --  94
   " 720x480 59.94 Hz\n"        &    --  95
   " 800x600 60 Hz\n"           &    --  96
   "\n"                         &    --  97
   " Back\n"                    &    --  98

   "\n"                         &    --  99
   " About & Help\n"            &    -- 100
   "\n"                         &    -- 101
   " Close Menu\n";                  -- 102

-- Group ids: must start with 1 and be monotonic increasing
constant OPTM_G_Cart       : integer := 1;
constant OPTM_G_Bios       : integer := 2;
constant OPTM_G_Region     : integer := 3;
constant OPTM_G_DifL       : integer := 4;
constant OPTM_G_DifR       : integer := 5;
constant OPTM_G_BW         : integer := 6;
constant OPTM_G_UseBios    : integer := 7;
constant OPTM_G_Ctrl       : integer := 8;
constant OPTM_G_InvPad     : integer := 9;
constant OPTM_G_Swap       : integer := 10;
constant OPTM_G_CartType   : integer := 11;
constant OPTM_G_Temp       : integer := 12;
constant OPTM_G_Border     : integer := 13;
constant OPTM_G_Overscan   : integer := 14;
constant OPTM_G_Blend      : integer := 15;
constant OPTM_G_Decomb     : integer := 16;
constant OPTM_G_NoStab     : integer := 17;
constant OPTM_G_Stereo     : integer := 18;
constant OPTM_G_Audio      : integer := 19;
constant OPTM_G_CRT        : integer := 20;
constant OPTM_G_Zoom       : integer := 21;
constant OPTM_G_HSC        : integer := 22;
constant OPTM_G_PokeyIRQ   : integer := 23;
constant OPTM_G_Random     : integer := 24;
constant OPTM_G_Driver     : integer := 25;
constant OPTM_G_FixSC      : integer := 26;
constant OPTM_G_HDMI       : integer := 27;
constant OPTM_G_About      : integer := 28;

-- !!! DO NOT TOUCH !!!
type OPTM_GTYPE is array (0 to OPTM_SIZE - 1) of integer range 0 to 2**OPTM_GTC- 1;

constant OPTM_GROUPS       : OPTM_GTYPE := ( OPTM_G_TEXT + OPTM_G_HEADLINE,            --   0 Headline
                                             OPTM_G_LINE,                              --   1 Line
                                             OPTM_G_Cart + OPTM_G_LOAD_ROM + OPTM_G_START, --   2 Load cartridge; cursor start
                                             OPTM_G_Bios + OPTM_G_LOAD_ROM,            --   3 Load BIOS
                                             OPTM_G_LINE,                              --   4

                                             OPTM_G_SUBMENU,                           --   5 Region submenu START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            --   6
                                             OPTM_G_LINE,                              --   7
                                             OPTM_G_Region + OPTM_G_STDSEL,            --   8 Auto (default)
                                             OPTM_G_Region,                            --   9 NTSC
                                             OPTM_G_Region,                            --  10 PAL
                                             OPTM_G_LINE,                              --  11
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            --  12 Back / END

                                             OPTM_G_SUBMENU,                           --  13 Console submenu START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            --  14
                                             OPTM_G_LINE,                              --  15
                                             OPTM_G_DifL + OPTM_G_SINGLESEL,           --  16 Left difficulty B (off = A, like MiSTer)
                                             OPTM_G_DifR + OPTM_G_SINGLESEL,           --  17 Right difficulty B
                                             OPTM_G_BW + OPTM_G_SINGLESEL,             --  18 2600: Black & white
                                             OPTM_G_UseBios + OPTM_G_SINGLESEL,        --  19 Use BIOS
                                             OPTM_G_LINE,                              --  20
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            --  21 Back / END

                                             OPTM_G_SUBMENU,                           --  22 Controls submenu START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            --  23
                                             OPTM_G_LINE,                              --  24
                                             OPTM_G_Ctrl + OPTM_G_STDSEL,              --  25 Joysticks (default)
                                             OPTM_G_Ctrl,                              --  26 Paddles in port 1
                                             OPTM_G_Ctrl,                              --  27 Paddles in port 2
                                             OPTM_G_Ctrl,                              --  28 Paddles in both
                                             OPTM_G_LINE,                              --  29
                                             OPTM_G_InvPad + OPTM_G_SINGLESEL,         --  30 Invert paddles
                                             OPTM_G_Swap + OPTM_G_SINGLESEL,           --  31 Swap joysticks
                                             OPTM_G_LINE,                              --  32
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            --  33 Back / END

                                             OPTM_G_SUBMENU,                           --  34 2600 type submenu START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            --  35
                                             OPTM_G_LINE,                              --  36
                                             OPTM_G_CartType + OPTM_G_STDSEL,          --  37 Auto (default)
                                             OPTM_G_CartType,                          --  38 F8
                                             OPTM_G_CartType,                          --  39 F6
                                             OPTM_G_CartType,                          --  40 F4
                                             OPTM_G_CartType,                          --  41 FE
                                             OPTM_G_CartType,                          --  42 E0
                                             OPTM_G_CartType,                          --  43 3F
                                             OPTM_G_CartType,                          --  44 3E
                                             OPTM_G_CartType,                          --  45 FA
                                             OPTM_G_CartType,                          --  46 CV
                                             OPTM_G_CartType,                          --  47 UA
                                             OPTM_G_CartType,                          --  48 E7
                                             OPTM_G_CartType,                          --  49 F0
                                             OPTM_G_CartType,                          --  50 P2
                                             OPTM_G_CartType,                          --  51 AR
                                             OPTM_G_CartType,                          --  52 SB
                                             OPTM_G_CartType,                          --  53 EF
                                             OPTM_G_LINE,                              --  54
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            --  55 Back / END

                                             OPTM_G_SUBMENU,                           --  56 Video and audio submenu START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            --  57
                                             OPTM_G_LINE,                              --  58
                                             OPTM_G_Temp + OPTM_G_STDSEL,              --  59 Warm colors (default)
                                             OPTM_G_Temp,                              --  60 Cool colors
                                             OPTM_G_Temp,                              --  61 Hot colors
                                             OPTM_G_LINE,                              --  62
                                             OPTM_G_Border + OPTM_G_SINGLESEL,         --  63 Hide border
                                             OPTM_G_Overscan + OPTM_G_SINGLESEL,       --  64 Show overscan
                                             OPTM_G_Blend + OPTM_G_SINGLESEL,          --  65 2600: Flicker blend
                                             OPTM_G_Decomb + OPTM_G_SINGLESEL,         --  66 2600: De-comb
                                             OPTM_G_NoStab + OPTM_G_SINGLESEL,         --  67 2600: No stabilizer
                                             OPTM_G_Stereo + OPTM_G_SINGLESEL,         --  68 Stereo TIA
                                             OPTM_G_Audio + OPTM_G_SINGLESEL,          --  69 Audio improvements
                                             OPTM_G_CRT + OPTM_G_SINGLESEL,            --  70 HDMI: CRT emulation
                                             OPTM_G_Zoom + OPTM_G_SINGLESEL,           --  71 HDMI: Zoom-in
                                             OPTM_G_LINE,                              --  72
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            --  73 Back / END

                                             OPTM_G_SUBMENU,                           --  74 Advanced submenu START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            --  75
                                             OPTM_G_LINE,                              --  76
                                             OPTM_G_HSC + OPTM_G_STDSEL,               --  77 High score cart: Auto (default)
                                             OPTM_G_HSC,                               --  78 High score cart: On
                                             OPTM_G_HSC,                               --  79 High score cart: Off
                                             OPTM_G_LINE,                              --  80
                                             OPTM_G_PokeyIRQ + OPTM_G_SINGLESEL,       --  81 Pokey IRQ
                                             OPTM_G_Random + OPTM_G_SINGLESEL,         --  82 Random memory
                                             OPTM_G_Driver + OPTM_G_SINGLESEL,         --  83 2600: CPU driver MARIA
                                             OPTM_G_FixSC + OPTM_G_SINGLESEL,          --  84 2600: Fix SC checksums
                                             OPTM_G_LINE,                              --  85
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            --  86 Back / END

                                             OPTM_G_SUBMENU,                           --  87 HDMI submenu START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            --  88
                                             OPTM_G_LINE,                              --  89
                                             OPTM_G_HDMI,                              --  90 720p 50 Hz 16:9
                                             OPTM_G_HDMI + OPTM_G_STDSEL,              --  91 720p 60 Hz 16:9 (default: NTSC)
                                             OPTM_G_HDMI,                              --  92 576p 50 Hz 4:3
                                             OPTM_G_HDMI,                              --  93 576p 50 Hz 5:4
                                             OPTM_G_HDMI,                              --  94 640x480 60 Hz
                                             OPTM_G_HDMI,                              --  95 720x480 59.94 Hz
                                             OPTM_G_HDMI,                              --  96 800x600 60 Hz
                                             OPTM_G_LINE,                              --  97
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            --  98 Back / END

                                             OPTM_G_LINE,                              --  99
                                             OPTM_G_About + OPTM_G_HELP,               -- 100 About & Help -> WHS(1)
                                             OPTM_G_LINE,                              -- 101
                                             OPTM_G_CLOSE                              -- 102 Close Menu
                                           );

--------------------------------------------------------------------------------------------------------------------
-- !!! CAUTION: M2M FRAMEWORK CODE !!! DO NOT TOUCH ANYTHING BELOW THIS LINE !!!
--------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------
-- Address Decoding
--------------------------------------------------------------------------------------------------------------------

begin

addr_decode : process(clk_i)
   -- return ASCII value of given string at the position defined by index (zero-based)
   pure function str2data(str : string; index : integer) return std_logic_vector is
   variable strpos : integer;
   begin
      strpos := index + 1;
      if strpos <= str'length then
         return std_logic_vector(to_unsigned(character'pos(str(strpos)), 16));
      else
         return X"0000"; -- zero terminated strings
      end if;
   end function str2data;

   -- return the dimensions of the Options menu
   pure function getDXDY(dx, dy, index: natural) return std_logic_vector is
   begin
      case index is
         when 0 => return std_logic_vector(to_unsigned(dx + 2, 16));
         when 1 => return std_logic_vector(to_unsigned(dy + 2, 16));
         when others => return X"0000";
      end case;
   end function getDXDY;

   -- convert bool to std_logic_vector
   pure function bool2slv(b: boolean) return std_logic_vector is
   begin
      if b then
         return x"0001";
      else
         return x"0000";
      end if;
   end function bool2slv;

   -- return the General Configuration settings
   function getGenConf(index: natural) return std_logic_vector is
   begin
      case index is
         when 1      => return std_logic_vector(to_unsigned(RESET_COUNTER, 16));
         when 2      => return bool2slv(OPTM_PAUSE);
         when 3      => return bool2slv(WELCOME_ACTIVE);
         when 4      => return bool2slv(WELCOME_AT_RESET);
         when 5      => return bool2slv(KEYBOARD_AT_RESET);
         when 6      => return bool2slv(JOY_1_AT_RESET);
         when 7      => return bool2slv(JOY_2_AT_RESET);
         when 8      => return bool2slv(KEYBOARD_AT_OSD);
         when 9      => return bool2slv(JOY_1_AT_OSD);
         when 10     => return bool2slv(JOY_2_AT_OSD);
         when 11     => return std_logic_vector(to_unsigned(ASCAL_USAGE, 16));
         when 12     => return std_logic_vector(to_unsigned(ASCAL_MODE, 16));
         when 13     => return std_logic_vector(to_unsigned(VD_ANTI_THRASHING_DELAY, 16));
         when 14     => return std_logic_vector(to_unsigned(VD_ITERATION_SIZE, 16));
         when 15     => return bool2slv(SAVE_SETTINGS);
         when others => return x"0000";
      end case;
   end function getGenConf;

   variable index           : integer;
   variable whs_page_index  : integer;
   variable whs_array_index : integer;

begin

   if falling_edge(clk_i) then

      index := to_integer(unsigned(address_i(11 downto 0)));
      whs_page_index  := to_integer(unsigned(address_i(19 downto 12)));
      whs_array_index := to_integer(unsigned(address_i(23 downto 20)));

      data_o <= x"EEEE";

      -----------------------------------------------------------------------------------
      -- Welcome & Help System: upper 4 bits of address equal SEL_WHS' upper 4 bits
      -----------------------------------------------------------------------------------

      if address_i(27 downto 24) = SEL_WHS(15 downto 12) then

         if  whs_array_index < WHS_RECORDS then
            if index = 4095 then
               data_o <= std_logic_vector(to_unsigned(WHS(whs_array_index).page_count, 16));
            else
               if index < WHS(whs_array_index).page_length(whs_page_index) then
                  data_o <= str2data(WHS_DATA, WHS(whs_array_index).page_start(whs_page_index) + index);
               else
                  data_o <= (others => '0'); -- zero-terminated strings
               end if;
            end if;
         end if;

      -----------------------------------------------------------------------------------
      -- All other selectors, which are 16-bit values
      -----------------------------------------------------------------------------------

      else

         case address_i(27 downto 12) is
            when SEL_GENERAL           => data_o <= getGenConf(index);
            when SEL_DIR_START         => data_o <= str2data(DIR_START, index);
            when SEL_CFG_FILE          => data_o <= str2data(CFG_FILE, index);
            when SEL_CORENAME          => data_o <= str2data(CORENAME, index);
            when SEL_OPTM_ITEMS        => data_o <= str2data(OPTM_ITEMS, index);
            when SEL_OPTM_MOUNT_STR    => data_o <= str2data(OPTM_S_MOUNT, index);
            when SEL_OPTM_CRTROM_STR   => data_o <= str2data(OPTM_S_CRTROM, index);
            when SEL_OPTM_SAVING_STR   => data_o <= str2data(OPTM_S_SAVING, index);
            when SEL_OPTM_GROUPS       => data_o <= std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(15)) &
                                                    std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(14)) & "0" &
                                                    std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(12)) & "0000" &
                                                    std_logic_vector(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(7 downto 0));
            when SEL_OPTM_STDSEL       => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(8));
            when SEL_OPTM_LINES        => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(9));
            when SEL_OPTM_START        => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(10));
            when SEL_OPTM_MOUNT_DRV    => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(11));
            when SEL_OPTM_HELP         => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(13));
            when SEL_OPTM_SINGLESEL    => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(15));
            when SEL_OPTM_CRTROM       => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(16));
            when SEL_OPTM_ICOUNT       => data_o <= x"00" & std_logic_vector(to_unsigned(OPTM_SIZE, 8));
            when SEL_OPTM_DIMENSIONS   => data_o <= getDXDY(OPTM_DX, OPTM_DY, index);

            when others                => null;
         end case;
      end if;
   end if;
end process;

end architecture beh;

