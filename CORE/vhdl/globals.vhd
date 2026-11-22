----------------------------------------------------------------------------------
-- Atari 7800 for MEGA65
--
-- Global constants
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.qnice_tools.all;
use work.video_modes_pkg.all;

package globals is

----------------------------------------------------------------------------------------------------------
-- QNICE Firmware
----------------------------------------------------------------------------------------------------------

-- QNICE Firmware: Use the regular QNICE "operating system" called "Monitor" while developing and
-- debugging the firmware/ROM itself. If you are using the M2M ROM (the "Shell") as provided by the
-- framework, then always use the release version of the M2M firmware: QNICE_FIRMWARE_M2M
--
-- Hint: You need to run QNICE/tools/make-toolchain.sh to obtain "monitor.rom" and
-- you need to run CORE/m2m-rom/make_rom.sh to obtain the .rom file
constant QNICE_FIRMWARE_MONITOR   : string  := "../../../M2M/QNICE/monitor/monitor.rom";    -- debug/development
constant QNICE_FIRMWARE_M2M       : string  := "../../../CORE/m2m-rom/m2m-rom.rom";         -- release

-- Select firmware here
constant QNICE_FIRMWARE           : string  := QNICE_FIRMWARE_M2M;

----------------------------------------------------------------------------------------------------------
-- Clock Speed(s)
----------------------------------------------------------------------------------------------------------

-- main_clk: the 7800 master clock (MiSTer clk_sys), 630 MHz / 44 = 14.318181818 MHz (clk.vhd)
constant CORE_CLK_SPEED       : natural := 14_318_182;

-- video_clk: 4 x main_clk (MiSTer clk_vid), 630 MHz / 11 = 57.272727 MHz
constant VIDEO_CLK_SPEED      : natural := 57_272_727;

-- System clock speed (crystal that is driving the FPGA) and QNICE clock speed
-- !!! Do not touch !!!
constant BOARD_CLK_SPEED      : natural := 100_000_000;
constant QNICE_CLK_SPEED      : natural := 50_000_000;   -- a change here has dependencies in qnice_globals.vhd

----------------------------------------------------------------------------------------------------------
-- Video Mode
----------------------------------------------------------------------------------------------------------

-- Rendering constants (in pixels)
--    VGA_*   size of the core's target output post scandoubler
-- video_ce_o runs at the MARIA pixel rate (7.16 MHz: 454 per line, about 320 visible; one 2600 TIA pixel
-- is two of them), video_ce_ovl_o at twice that. At least 192 lines are visible (2600 games).
-- Same OSM size as the Atari 2600 port (40 x 24 characters).
constant VGA_DX               : natural := 640;
constant VGA_DY               : natural := 384;

--    FONT_*  size of one OSM character
constant FONT_FILE            : string  := "../font/Anikki-16x16-m2m.rom";
constant FONT_DX              : natural := 16;
constant FONT_DY              : natural := 16;

-- Constants for the OSM screen memory
constant CHARS_DX             : natural := VGA_DX / FONT_DX;
constant CHARS_DY             : natural := VGA_DY / FONT_DY;
constant CHAR_MEM_SIZE        : natural := CHARS_DX * CHARS_DY;
constant VRAM_ADDR_WIDTH      : natural := f_log2(CHAR_MEM_SIZE);

----------------------------------------------------------------------------------------------------------
-- HyperRAM memory map (in units of 4kW)
----------------------------------------------------------------------------------------------------------

constant C_HMAP_M2M           : std_logic_vector(15 downto 0) := x"0000";     -- Reserved for the M2M framework

----------------------------------------------------------------------------------------------------------
-- QNICE devices of this core (ids >= 0x0100)
----------------------------------------------------------------------------------------------------------

constant C_DEV_A78_CART       : std_logic_vector(15 downto 0) := x"0100";     -- cartridge (cart.vhd)
constant C_DEV_A78_BIOS       : std_logic_vector(15 downto 0) := x"0101";     -- optional BIOS (bios.vhd)

-- Cartridge RAM size: 2^C_CART_ADDR_BITS bytes (BRAM). 19 = 512 KB: all commercial 7800 and 2600
-- cartridges and most homebrews (MiSTer: 1 MB in SDRAM).
constant C_CART_ADDR_BITS     : natural := 19;

----------------------------------------------------------------------------------------------------------
-- Virtual Drive Management System: not used
----------------------------------------------------------------------------------------------------------

type vd_buf_array is array(natural range <>) of std_logic_vector;
constant C_VDNUM              : natural := 0;
constant C_VD_DEVICE          : std_logic_vector(15 downto 0) := x"EEEE";
constant C_VD_BUFFER          : vd_buf_array := (x"EEEE", x"EEEE");

----------------------------------------------------------------------------------------------------------
-- System for handling simulated cartridges and ROM loaders
----------------------------------------------------------------------------------------------------------

type crtrom_buf_array is array(natural range<>) of std_logic_vector;
constant ENDSTR : character := character'val(0);

-- Cartridges and ROMs can be stored into QNICE devices, HyperRAM and SDRAM
constant C_CRTROMTYPE_DEVICE     : std_logic_vector(15 downto 0) := x"0000";
constant C_CRTROMTYPE_HYPERRAM   : std_logic_vector(15 downto 0) := x"0001";
constant C_CRTROMTYPE_SDRAM      : std_logic_vector(15 downto 0) := x"0002";           -- @TODO/RESERVED for future R4 boards

-- Types of automatically loaded ROMs:
-- If a mandatory file is missing, then the core outputs the missing file and goes fatal
constant C_CRTROMTYPE_MANDATORY  : std_logic_vector(15 downto 0) := x"0003";
constant C_CRTROMTYPE_OPTIONAL   : std_logic_vector(15 downto 0) := x"0004";

-- Manually loadable ROMs and cartridges as defined in config.vhd (OPTM_G_LOAD_ROM items, same order):
--    1) the cartridge, 2) the optional BIOS
-- Both are QNICE devices; their control and status register is in the 4k window 0xFFFF.
constant C_CRTROMS_MAN_NUM       : natural := 2;                                       -- amount of manually loadable ROMs and carts; maximum is 16
constant C_CRTROMS_MAN           : crtrom_buf_array := ( C_CRTROMTYPE_DEVICE, C_DEV_A78_CART,
                                                         C_CRTROMTYPE_DEVICE, C_DEV_A78_BIOS,
                                                         x"EEEE");                     -- Always finish the array using x"EEEE"

-- Automatically loaded ROMs: none
constant C_CRTROMS_AUTO_NUM      : natural := 0;                                       -- Amount of automatically loadable ROMs and carts, maximum is 16
constant C_CRTROMS_AUTO_NAMES    : string  := "" & ENDSTR;
constant C_CRTROMS_AUTO          : crtrom_buf_array := ( x"EEEE", x"EEEE", x"EEEE", x"EEEE",
                                                         x"EEEE");                     -- Always finish the array using x"EEEE"

----------------------------------------------------------------------------------------------------------
-- Audio filters (optional, menu "Improve audio"): template values (C64)
----------------------------------------------------------------------------------------------------------

constant audio_flt_rate : std_logic_vector(31 downto 0) := std_logic_vector(to_signed(7056000, 32));
constant audio_cx       : std_logic_vector(39 downto 0) := std_logic_vector(to_signed(4258969, 40));
constant audio_cx0      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(3, 8));
constant audio_cx1      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(2, 8));
constant audio_cx2      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(1, 8));
constant audio_cy0      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed(-6216759, 24));
constant audio_cy1      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed( 6143386, 24));
constant audio_cy2      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed(-2023767, 24));
constant audio_att      : std_logic_vector( 4 downto 0) := "00000";
constant audio_mix      : std_logic_vector( 1 downto 0) := "00"; -- 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

end package globals;
