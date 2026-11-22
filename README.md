Atari 7800 for MEGA65
=====================

A port of the MiSTer Atari 7800 core
([Atari7800_MiSTer](https://github.com/MiSTer-devel/Atari7800_MiSTer) by Jamie Blanks, MIT
license) to the MEGA65, built on the [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
framework (by sy2002 and MJoergen). The original framework README is in `M2M-README.md`.

It plays **7800 and 2600 cartridges** (the 7800 contains a 2600; the MiSTer core models both).

Status: **V0.2 works on a MEGA65 R6** (HDMI, confirmed by the user 2026-11-22): 7800 games Commando,
Mario Bros and Xevious play without the V0.1 sprite corruption; 2600 games Miner 2049er, H.E.R.O.,
Pitfall, Berzerk and Missile Command work. See "Build status" and "MiSTer source version" below.

V0.3 = V0.2 plus a fix in the QNICE FAT32 library for the file browser error "SD Card: Unknown
error while trying to browse. Error code: 2704" (see "QNICE FAT32 fix" below). **V0.3 works on
the R6** (confirmed by the user 2026-11-22): the `NTSCVideo` folder that crashed V0.2 now browses.

QNICE FAT32 fix (V0.3)
----------------------

On V0.2 the user's archive folder `NTSCVideo` (88 files with long names) stopped the browser with
error 2704; the same folder also crashed the Atari 2600 and C64MEGA65 cores, so it is a framework
bug, not a core bug. Cause, in `M2M/QNICE/monitor/fat32_library.asm` (QNICE-FPGA `2eb27dd5`, which
the M2M firmware includes directly):
* `FAT32$DIR_LIST` stops only at a directory entry whose first byte is 0x00.
* A directory whose last cluster is **completely full** has no such entry (the directory is about
  12 KB = exactly 3 clusters of 4 KB).
* `FAT32$READ_FDH` then follows the FAT entry of the last cluster without checking for the end of
  the chain (0x0FFFFFF8..0x0FFFFFFF) and asks the card for a sector far outside the card. The card
  returns a data error token (0x04); the browser shows error 0x2704.

Fix (marked "MiSTer2MEGA65" in the file): `READ_FDH` masks the reserved upper 4 bits of the FAT
entry and returns `FAT32$EOF` at the end of the chain; `DIR_LIST` treats that as the end of the
directory. Checked in the QNICE emulator with a FAT32 test image (directory of 3 full clusters,
64 long names, plus a normal small directory) and an emulated SD card that returns an error for
out-of-range reads: before the fix error 2704 after the last name, after the fix all entries and
a clean end. Because `M2M/QNICE` is a git submodule (QNICE-FPGA `2eb27dd5`, unpatched), the
fixed library is kept as `M2M/rom/fat32_library.asm` and `M2M/rom/main.asm` includes that copy
(the firmware ROM is byte-identical to the one in the tested V0.3 build). Other M2M cores keep the
bug until it is fixed upstream.

License note: the MiSTer core sources (`CORE/Atari7800_MiSTer`) are Creative Commons
Attribution-NonCommercial 4.0 (see `AUTHORS`).

MiSTer source version
---------------------

V0.2 is based on the **last released MiSTer core**: commit `4372b3e3` ("Sys Update and New
Release (#45)", 2 June 2026, release `Atari7800_20260530.rbf`), downloaded to
`C:\phnx\src_atari7800_rel`. That is the version MiSTer users run (T65 CPU, VHDL POKEY).

V0.1 was based on the repository HEAD (11 Sep 2026), which contains large **unreleased** changes
made after that release: a new 6502 ("SALLY") model, new POKEY/RIOT/line RAM, ARM mappers,
BupChip (#59, #61, #62). On a MEGA65 R6 V0.1 showed **sprite corruption** in Commando, Mario Bros
and Xevious (backgrounds and text fine). Checks done on V0.1 without finding a port bug:
* the cartridge BRAM timing vs. MiSTer's SDRAM timing (whole console simulated with Mario Bros,
  both memory models: byte-identical line RAM contents),
* MARIA synthesized by Vivado vs. its RTL (600,000 random cycles with DMA: equivalent),
* the synthesized CPU's cycle counts (all 151 legal 6502 opcodes correct).
So the corruption most likely comes from the unreleased upstream code. The HEAD sources stay in
`C:\phnx\src_atari7800` for reference.

Build status
------------

V0.3, built 2026-11-22 for the **MEGA65 R6** with Vivado 2022.2 (same core as V0.2 plus the
QNICE FAT32 fix; the numbers below are unchanged from V0.2) (`release/a7800_r6.cor`, made with
mega65-tools `bit2core`: magic `MEGA65BITSTREAM0`, name `Atari7800`, version `V0.3`, target
`mega65r6`, model id 0x06, CRC32 set):
* `impl_1 status: write_bitstream Complete!`, "All user specified timing constraints are met".
  WNS +0.208 ns is in the framework's HyperRAM interface (`hr_rwds`); main_clk +33.4 ns,
  video_clk +6.6 ns, qnice_clk +0.8 ns.
* No critical warnings in synthesis or implementation; all 10 `$readmemh` init files read
  successfully; no block RAM demoted to LUTs.
* Block RAM 240 of 365 tiles (66%), LUTs 21%, DSP 62.
* Tested on a MEGA65 R6 (see Status). R3/R4/R5 not built. No virtual drives, so the M2M V2.0.1
  template bugs #58/#52/#57 do not apply.

Project layout
--------------

| Path                              | What it is                                                              |
|-----------------------------------|-------------------------------------------------------------------------|
| `CORE/Atari7800_MiSTer/rtl/`      | The released MiSTer core's `rtl/` (see changes below)                   |
| `CORE/Atari7800_MiSTer/m65/`      | Port additions: `bram.v`/`cache_ram.v` (portable `spram`, from the MiSTer HEAD sources), `t65_m65.vhd` (T65 wrapper) |
| `CORE/Atari7800_MiSTer/atari7800_m65.sv` | Wrapper: the machine part of MiSTer's `Atari7800.sv` (header parsing, 2600 mapper detection, splash ROM, high score cart RAM, controls) |
| `CORE/Atari7800_MiSTer/Atari7800.sv` | MiSTer's top level, for reference only (not in the project)          |
| `CORE/vhdl/main.vhd`              | Controls, paddles, video into the video clock domain, audio             |
| `CORE/vhdl/cart.vhd`              | Cartridge device: 512 KB BRAM, M2M ROM loader protocol, A78 header split, download stream replay |
| `CORE/vhdl/bios.vhd`              | Optional BIOS device: 32 KB BRAM                                        |
| `CORE/vhdl/mega65.vhd`            | Clocks, menu settings, QNICE devices, video/audio settings              |
| `CORE/vhdl/clk.vhd`               | 14.318182 MHz core clock and 57.272727 MHz video clock                  |
| `CORE/vhdl/keyboard.vhd`          | MEGA65 key mapping                                                      |
| `CORE/vhdl/globals.vhd`           | Clock speed, OSM size, devices, cartridge RAM size                      |
| `CORE/vhdl/config.vhd`            | Welcome screen, help, options menu                                      |
| `build/`                          | Build scripts (Vivado for Windows + WSL), `bit2core` from mega65-tools  |
| `sdcard/atari7800/a78cfg`         | Empty settings file (103 bytes 0xFF) for the SD card                    |

How the port works
------------------

* **Clocks:** one MMCM, 100 MHz / 5 x 31.5 = 630 MHz VCO: `main_clk` = / 44 = 14.318182 MHz
  (MiSTer `clk_sys`, the NTSC 7800 master clock; the whole console and the framework's core
  domain), `video_clk` = / 11 = 57.272727 MHz (MiSTer `clk_vid`). Same VCO, phase 0, so every
  4th video_clk edge is a main_clk edge and Vivado times the paths between them.
  This port always runs at the NTSC rate, so **PAL games run 0.92% too fast** (their 313 line
  picture is still made correctly by MARIA/TIA).
* **Cartridges:** loaded with the M2M file browser (folder `/atari7800`) into a **512 KB** block
  RAM in `cart.vhd` (M2M "manually loadable ROM" protocol, CSR in 4K window `0xFFFF`).
  7800 or 2600 is decided **from the content**: a file with an A78 header ("ATARI7800" at
  offset 1) is a 7800 cartridge, everything else a 2600 cartridge, whatever the extension
  (MiSTer: `.a78` = 7800, `.a26`/`.bin` = 2600). Like on MiSTer, 7800 games need the A78 header.
  The 128 header bytes go into their own small RAM, the cartridge RAM gets the data behind them
  (like MiSTer's SDRAM), so a 512 KB game with header fits.
  After loading, `cart.vhd` **replays the file as MiSTer's download stream** (`ioctl_download`,
  `ioctl_addr`, `ioctl_dout`, `ioctl_wr`, one byte per 5 core clocks, ~0.2 s for 512 KB) while the
  core is held in reset, so MiSTer's header parsing and 2600 bank switching detection
  (`detect2600`) run unchanged.
  The core reads the cartridge like MiSTer's SDRAM (address taken on the rising edge of
  `cart_read`, data held until the next read); the BRAM answers after one core clock.
* **Memory budget** (Porting Guide 1.4.2, "1.4 MB rule"): cartridge 512 KB (128 RAMB36), the
  core's cartridge RAM 128 KB (32 tiles), BIOS 32 KB, splash ROM 16 KB, high score RAM 8 KB,
  palettes; framework ~44 tiles. MiSTer allows 1 MB cartridges in SDRAM; the limit here is
  512 KB (all commercial 7800 games are <= 144 KB).
* **BIOS:** not needed (MiSTer's "Bypass BIOS" is the default here too). A BIOS can be loaded with
  "BIOS" in the menu (4 or 16 KB, max. 32 KB) and is used when "Use BIOS (if loaded)" is on.
* **Video:** MARIA/TIA output is sampled every second core clock (the MARIA pixel rate,
  7.16 MHz; a 2600 pixel is sampled twice) and handed to the 57.27 MHz video clock with a toggle
  bit. VSYNC only changes at line starts and the VSYNC lines are blanked (Atari 2600 port
  recipe). MiSTer's 2600 "Stabilize video" is on by default ("2600: No stabilizer" switches it
  off). OSM: 640 x 384 = 40 x 24 characters.
* **Audio:** what the MiSTer core mixes: TIA, POKEY (incl. XM), YM2151 (jt51), Covox. Unsigned
  16 bit from the core, converted to signed, muted while the core is held in reset.
* **Not connected (yet):** light gun, trakball, mice, keypads, SaveKey, Quadtari, SNAC, XEGS
  keyboard. High score cartridge works (RAM in the FPGA) but is not saved to the SD card. Custom
  palettes (MiSTer "Load Palette") and the 2600 tape input are not there.

Changes to the MiSTer sources (`CORE/Atari7800_MiSTer/rtl`, each marked "MiSTer2MEGA65"):
* `bss_pkg.sv` (new): the 2600 bank switching enum, moved out of `detect2600.sv` where it was
  declared at `$unit` scope (Vivado project mode does not guarantee the compile order);
  `detect2600.sv` and `cart2600.sv` import it.
* `top.sv`: T65 is instantiated through `m65/t65_m65.vhd` (plain ports: T65's record `DEBUG` port
  cannot cross into SystemVerilog, and Vivado would tie the unconnected `Abort_n`/`SO_n` to 0).
* Outputs that are assigned in always blocks declared `output logic` (Vivado Synth 8-2577):
  `TIA.sv` (`d_out`, `i_out`, `col`, `lum`, `paddle_read`), `RIOT/M6532.sv` (`d_out`),
  `cart2600.sv` (`d_out`), `paddles.sv` (`select`, `charged`), `top.sv` (`M6502C.is_halted`).
* **Combinational loops** (Vivado refuses to write a bitstream with them, DRC LUTLP-1; Quartus
  builds them): `TIA.sv` `f_cell` (two transparent `sr_latch` cells, used by the object counters,
  audio pulse counters and player delays) replaced by the registered master/slave `f_cell` from the
  MiSTer HEAD sources; checked equal at its outputs with 400,000 random input cycles. `top.sv`:
  TIA's external phase inputs (`phi2`, `phi1_in`) get MARIA's phases (`pclk0_m`, `pclk1_m`)
  instead of the muxed `pclk0`/`pclk1`, which were themselves selected from TIA's output; the
  same signal in 7800 mode, unused in 2600 mode (HEAD did the same).
* `banks2600.sv`: the Supercharger header checksum used the array method `.sum()`, which Vivado
  does not support; written out as a sum of the 8 bytes.
* `spram` instances (`banks2600.sv`, `cart.sv`, `cart2600.sv`, `video_mux.sv`): `data`/`wren`/`cs`
  connected explicitly (they relied on VHDL defaults, which Vivado ignores for unconnected inputs),
  `.enable` removed, and a `sim_init_file` (`.hex`, path relative to the Vivado run folder) added
  next to each `.mif`. `spram` itself is the portable Verilog version from the MiSTer HEAD sources
  (`m65/bram.v`, `m65/cache_ram.v`); the `.hex` files are the HEAD ones (the `.mif` files are
  identical in both versions). `bram.vhd`/`dpram.vhd` (altsyncram) are not used.
* Not used: `Atari7800.sv` (MiSTer framework top), `sdram.sv`, PLL, `lightgun.sv`, `mouse_st.sv`,
  `EEPROM_24LC256.sv`, `cofi.sv`.

Controls
--------

| MEGA65                         | Atari 7800                                        |
|--------------------------------|---------------------------------------------------|
| Joystick ports 1 and 2         | Joysticks (button 1), or paddles (menu)           |
| Cursor keys                    | Joystick 1                                        |
| Space / Z                      | Joystick 1 button 1 / button 2                    |
| F1                             | Select                                            |
| F3                             | Reset (2600: Game Reset)                          |
| F5                             | Pause (7800)                                      |
| Help                           | Options menu, load cartridge / BIOS               |

The MEGA65 joysticks have one button; 7800 games that need the second button (right button)
get it from Z. Difficulty switches (default A, like MiSTer), 2600 colour/B&W, region, 2600 bank
switching, colour temperature, border/overscan and the advanced MiSTer options are in the menu.
Paddles: MEGA65 paddle inputs, buttons on the joystick left/right lines (like Atari/C64 paddles).

Installing
----------

1. Create the folder `/atari7800` on the SD card for your cartridges (7800 games with A78 header,
   2600 games as `.a26`/`.bin`, up to 512 KB).
2. Copy `sdcard/atari7800/a78cfg` there too, so the menu settings are saved. **V0.2/V0.3 have a
   different menu size than V0.1 (103 instead of 105 bytes): replace the old file.**
3. Flash `release/a7800_r6.cor` with the MEGA65 core menu.

Building
--------

Vivado 2022.2 for Windows plus WSL (Ubuntu), as for the other ports in `C:\phnx`. One-time setup
in `build\`: `wsl bash ./setup_wsl.sh`. Then:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Board R6
```

writes `release\a7800_r6.bit` and `release\a7800_r6.cor` (header by `build/m65_bit2core/bit2core`).

Known limitations / TODO
------------------------

* PAL games run at the NTSC clock (0.92% fast). A second MMCM setting or a BUFGMUX would fix it.
* Max. 512 KB cartridges (MiSTer: 1 MB). The released MiSTer core has no ARM (DPC+/CDF/BUS) games.
* No light gun, trakball, mice, keypads, SaveKey; no saving of high scores.
* HDMI: M2M's 4:3 window, no MiSTer-style aspect ratio per border/overscan setting.
* R3/R4/R5 projects exist but were not built.

License
-------

GPL v3 (MiSTer2MEGA65 port), the MiSTer core sources keep their original licenses (MIT, jt51 and
the POKEY/T65 VHDL: see the file headers).
