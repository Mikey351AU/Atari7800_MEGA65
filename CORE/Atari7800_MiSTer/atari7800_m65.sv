//-------------------------------------------------------------------------------------------------
// Atari 7800 for MEGA65
//
// MEGA65 wrapper of the MiSTer Atari 7800 core: the parts of MiSTer's Atari7800.sv (module emu)
// that belong to the machine, without the MiSTer framework (hps_io, PLL, SDRAM, DDR3, OSD).
// Copied from Atari7800.sv of the released MiSTer core (commit 4372b3e3, 2 June 2026; Jamie Blanks,
// MIT license) and reduced:
//    * cartridge download stream, A78 header parsing, cartridge size, 2600 mapper detection,
//      splash ROM, BIOS, high score cartridge RAM: as in Atari7800.sv
//    * cartridge ROM: an external RAM (cart.vhd) instead of the SDRAM
//    * controls: 7800/2600 joysticks and paddles (MEGA65 joystick ports + keyboard) only. Light gun,
//      trakball, mice, keypads, SaveKey, Quadtari and SNAC are not connected (yet).
//    * no state save (high score cartridge and SaveKey are not written to the SD card)
//
// Everything runs on clk_sys (14.318182 MHz, MiSTer clk_sys).
//
// This machine is based on Atari7800_MiSTer (https://github.com/MiSTer-devel/Atari7800_MiSTer)
// Powered by MiSTer2MEGA65, MEGA65 port licensed under GPL v3
//-------------------------------------------------------------------------------------------------

`default_nettype none

module atari7800_m65
(
	input  wire        clk_sys,
	input  wire        reset_in,          // framework resets, BIOS loading

	// cartridge download stream (cart.vhd replays the loaded file)
	input  wire        dl_active,         // MiSTer cart_download
	input  wire        dl_tia,            // 1 = 2600 cartridge (MiSTer ioctl_index[7:6] != 0)
	input  wire [24:0] dl_addr,
	input  wire  [7:0] dl_data,
	input  wire        dl_wr,
	input  wire        cart_loaded_in,    // a cartridge was loaded (else: splash ROM)

	// cartridge ROM (cart.vhd)
	output wire        rom_rd,
	output wire [24:0] rom_addr,
	input  wire  [7:0] rom_data,

	// BIOS (bios.vhd)
	output wire [14:0] bios_addr,
	input  wire  [7:0] bios_data,
	input  wire        bios_loaded,

	// settings
	input  wire  [1:0] region,            // 0 = auto, 1 = NTSC, 2 = PAL (MiSTer status[16:15])
	input  wire        use_bios,          // 1 = run the BIOS if one is loaded (MiSTer: Bypass Bios = No)
	input  wire        diff_left_b,       // 1 = left difficulty B (MiSTer status[13])
	input  wire        diff_right_b,      // 1 = right difficulty B (MiSTer status[12])
	input  wire        bw,                // 2600: black & white (MiSTer status[62])
	input  wire        hide_border,       // MiSTer status[14]
	input  wire        show_overscan,     // MiSTer status[29]
	input  wire  [1:0] pal_temp,          // 0 warm, 1 cool, 2 hot (MiSTer status[31:30])
	input  wire        stereo_tia,        // MiSTer status[4]
	input  wire        pokey_irq,         // MiSTer status[8]
	input  wire  [1:0] hsc_mode,          // 0 auto, 1 on, 2 off (MiSTer status[19:18])
	input  wire        clear_random,      // MiSTer status[1]: clear memory with random values
	input  wire        cpu_driver_maria,  // MiSTer status[21]: 2600 CPU driver MARIA
	input  wire        decomb,            // MiSTer status[47]
	input  wire        blend,             // MiSTer status[61]: 2600 flicker blend
	input  wire        tia_stab_off,      // MiSTer status[63]: 2600 stabilize video off
	input  wire  [4:0] bs_override,       // MiSTer status[60:56]: 0 = auto, else the bank switching type
	input  wire        fix_sc,            // MiSTer status[55]

	// controls, high active, MiSTer joystick bit order:
	// 0 right, 1 left, 2 down, 3 up, 4 fire 1, 5 fire 2, 6 pause, 7 select, 8 reset (start)
	input  wire  [8:0] joy0,
	input  wire  [8:0] joy1,
	input  wire        paddles_a,         // port 1 has paddles
	input  wire        paddles_b,         // port 2 has paddles
	input  wire  [7:0] pad0,              // paddle positions (0..255)
	input  wire  [7:0] pad1,
	input  wire  [7:0] pad2,
	input  wire  [7:0] pad3,
	input  wire  [3:0] pad_btn,           // paddle buttons, high active

	// video (clk_sys domain, MiSTer ce_pix marks a new pixel)
	output wire  [7:0] red,
	output wire  [7:0] green,
	output wire  [7:0] blue,
	output wire        hsync,
	output wire        vsync,
	output wire        hblank,
	output wire        vblank,
	output wire        ce_pix,
	output wire        tia_en_o,          // 1 = 2600 mode
	output wire        pal_o,             // 1 = PAL timing

	// audio (MiSTer AUDIO_L/R, AUDIO_S = 0: unsigned)
	output wire [15:0] audio_l,
	output wire [15:0] audio_r
);

////////////////////////////  DECLARATIONS  ///////////////////////////////
// (all at the top: Vivado turns signals used before their declaration into 1-bit nets)

logic        reset;
logic        old_cart_download = 1'b0;
wire         cart_download = dl_active;

logic        tia_en;
logic  [3:0] idump;
logic  [1:0] ilatch;
logic  [7:0] PAin, PBin, PAout, PBout;
wire   [7:0] R, G, B;
wire         HSync, VSync, HBlank, VBlank, VBlank_orig;
wire  [15:0] AB;
logic  [7:0] cart_data;
logic  [7:0] joy0_type = 8'd1, joy1_type = 8'd1, cart_region = 8'd0, cart_save = 8'd0;
logic [15:0] cart_flags = 16'd0;
logic [39:0] cart_header = "ATARI";
logic [31:0] cart_size = 32'h00008000;
logic [24:0] cart_addr;
logic  [7:0] cart_xm = 8'd0;
logic        cart_read;
logic        RW;
logic        cart_is_7800 = 1'b1;
logic        tia_mode = 1'b0;
logic  [7:0] hsc_ram_dout, din;
logic        hsc_ram_cs;
logic        ce_pix_raw;
logic  [7:0] cart_din;
wire   [4:0] force_bs;
wire         sc;
logic [15:0] rnd = 16'h1234;
logic  [7:0] rval;
wire         PAread;
logic  [3:0] iout;
logic        tia_hsync;
logic        tia_pal, tia_f1;
logic  [3:0] i_read;
wire  [17:0] cartram_addr;
wire         cartram_wr, cartram_rd;
wire   [7:0] cartram_wrdata;
wire         region_select;
wire         bypass_bios;
logic  [7:0] porta_type, portb_type;
logic  [3:0] pad_wire;
logic  [3:0] pad_muxa, pad_muxb;
logic [33:0] difference0, difference1, difference2, difference3;

////////////////////////////  RESET  //////////////////////////////////////

// MiSTer: reset <= RESET | buttons[1] | status[0] | cart_download | bios_download | ...
// (old_cart_download added: one more clock of reset after the download, while detect2600 settles)
always @(posedge clk_sys) begin
	old_cart_download <= cart_download;
	reset <= reset_in | cart_download | old_cart_download;
end

////////////////////////////  SYSTEM  /////////////////////////////////////

// MiSTer uses a free running LFSR built from lcells (asynchronous ring); a clocked LFSR here
always @(posedge clk_sys) begin
	rnd  <= {rnd[14:0], rnd[15] ^ rnd[13] ^ rnd[12] ^ rnd[10]};
	rval <= rnd[7:0];
end

assign region_select = ~|region ? (tia_en ? tia_pal : cart_region[0]) : region[1];

// No BIOS loaded: always bypass it
assign bypass_bios = ~(use_bios & bios_loaded);

Atari7800 main
(
	.clk_sys      (clk_sys),
	.reset        (reset),
	.loading      (cart_download),
	.pause        (1'b0),

	// Video
	.RED          (R),
	.GREEN        (G),
	.BLUE         (B),
	.HSync        (HSync),
	.VSync        (VSync),
	.HBlank       (HBlank),
	.VBlank       (VBlank),
	.VBlank_orig  (VBlank_orig),
	.ce_pix       (ce_pix_raw),
	.show_border  (~hide_border),
	.show_overscan(show_overscan),
	.PAL          (region_select),
	.pal_temp     (pal_temp),
	.tia_mode     (tia_mode && bypass_bios),
	.bypass_bios  (bypass_bios),
	.pokey_irq    (pokey_irq),
	.hsc_en       ((~|hsc_mode && (|cart_save || cart_xm[0])) ? 1'b1 : hsc_mode[0]),
	.hsc_ram_dout (hsc_ram_dout),
	.hsc_ram_cs   (hsc_ram_cs),
	.dout         (din),
	.cpu_ce       (),

	// Audio
	.AUDIO_R      (audio_r),
	.AUDIO_L      (audio_l),

	// Cart Interface
	.cart_out     (cart_download ? dl_data : (cart_loaded_in ? rom_data : cart_data)),
	.cart_read    (cart_read),
	.cart_size    (cart_size),
	.cart_addr_out(cart_addr),
	.cart_flags   (cart_is_7800 ? cart_flags[15:0] : 16'd0),
	.cart_save    (cart_save),
	.cart_din     (cart_din),
	.cart_xm      (cart_is_7800 ? cart_xm : 8'h0),
	.ps2_key      (11'd0),

	// Cartridge RAM: the one inside top.sv (EXTERNAL_CARTRAM is not defined)
	.cartram_addr   (cartram_addr),
	.cartram_wr     (cartram_wr),
	.cartram_rd     (cartram_rd),
	.cartram_wrdata (cartram_wrdata),
	.cartram_data   (8'hFF),

	// BIOS
	.bios_out     (bios_data),
	.AB           (AB),
	.RW           (RW),

	// Tia
	.idump        (idump),
	.ilatch       (ilatch),
	.i_out        (iout),
	.tia_en       (tia_en),
	.tia_hsync    (tia_hsync),
	.use_stereo   (stereo_tia),
	.cpu_driver   (~cpu_driver_maria),
	.tia_f1       (tia_f1),
	.tia_pal      (tia_pal),
	.tia_stab     (tia_stab_off),    // MiSTer status[63], "Stabilize Video: On, Off": 1 = off

	// RIOT
	.PAin         (PAin),
	.PBin         (PBin),
	.PAout        (PAout),
	.PBout        (PBout),
	.PAread       (PAread),

	// 2600 Cart Flags from detect2600
	.force_bs     (force_bs),
	.sc           (sc),
	.clearval     (clear_random ? rval : 8'h00),
	.random       (rval),
	.decomb       (decomb),
	.mapper       (bs_override),     // MiSTer status[60:56]: 0 = auto (force_bs), else the type
	.tape_in      (2'b00),
	.fix_sc_cs    (fix_sc),
	.ar_control   (1'b0),            // not connected on MiSTer either

	// Palette loading: not used
	.pal_load     (1'b0),
	.pal_addr     (10'd0),
	.pal_wr       (1'b0),
	.pal_data     (8'd0),
	.blend        (blend),
	.i_read       (i_read)
);

assign tia_en_o = tia_en;
assign pal_o    = region_select;
assign red      = R;
assign green    = G;
assign blue     = B;
assign hsync    = HSync;
assign vsync    = VSync;
assign hblank   = HBlank;
assign vblank   = VBlank;
assign ce_pix   = ce_pix_raw;

// cartridge ROM (MiSTer: sdram ch0_rd = cart_read & ~cart_download & ~reset)
assign rom_rd    = cart_read & ~cart_download & ~reset;
assign rom_addr  = cart_addr;
assign bios_addr = AB[14:0];

////////////////////////////  MEMORY  /////////////////////////////////////

detect2600 detect2600
(
	.clk        (clk_sys),
	.addr       (dl_addr[15:0]),
	.reset      (~old_cart_download && cart_download),
	.cart_size  (cart_size),
	.enable     (dl_wr & cart_download),
	.data       (dl_data),
	.force_bs   (force_bs),
	.sc         (sc)
);

// A78 header and cartridge size (MiSTer Atari7800.sv, unchanged)
always_ff @(posedge clk_sys) begin
	cart_is_7800 <= (cart_header == "ATARI");
	if (cart_download && dl_wr)
		cart_size <= (dl_addr - (cart_is_7800 ? 8'd128 : 1'b0)) + 1'd1; // 32 bit 1
	if (cart_download) begin
		tia_mode <= dl_tia;
		if (!tia_mode) begin
			case (dl_addr)
				'd01: cart_header[39:32] <= dl_data;
				'd02: cart_header[31:24] <= dl_data;
				'd03: cart_header[23:16] <= dl_data;
				'd04: cart_header[15:8] <= dl_data;
				'd05: cart_header[7:0] <= dl_data;
				'd53: cart_flags[15:8] <= dl_data;
				'd54: cart_flags[7:0] <= dl_data;
				'd55: joy0_type <= dl_data;   // 0=none, 1=joystick, 2=lightgun
				'd56: joy1_type <= dl_data;
				'd57: cart_region <= dl_data; // 0=ntsc, 1=pal
				'd58: cart_save <= dl_data;   // 0=none, 1=high score cart, 2=savekey
				'd63: cart_xm <= dl_data;     // 1 = Has XM
				default: ;
			endcase
			if (!cart_is_7800) begin
				joy0_type <= 8'd1;
				joy1_type <= 8'd1;
			end
		end else begin
			joy0_type <= 8'd1;
			joy1_type <= 8'd1;
			cart_header <= '0;
			cart_flags <= 0;
			cart_region <= 0;
			cart_save <= 0;
			cart_xm <= 0;
		end
	end
end

// Built-in splash ROM, shown until a cartridge is loaded (MiSTer: spram "Cart", mem0.mif)
spram #(
	.addr_width(14),
	.mem_name("Cart"),
	.sim_init_file("../../Atari7800_MiSTer/rtl/mem0.hex")
) cart
(
	.address (cart_addr[13:0]),
	.clock   (clk_sys),
	.data    (8'd0),
	.wren    (1'b0),
	.cs      (1'b1),
	.q       (cart_data)
);

// High score cartridge RAM ($1000-$17FF). MiSTer: dpram_dc, 16 KB (shared with the SaveKey, which is
// not connected here) with a second port for the save file.
spram #(.addr_width(13), .mem_name("HSC")) hsc_ram
(
	.clock   (clk_sys),
	.address (AB[12:0]),
	.data    (din),
	.wren    (~RW & hsc_ram_cs),
	.cs      (1'b1),
	.q       (hsc_ram_dout)
);

//////////////////////////////  IO  ///////////////////////////////////////

// RIOT Ports:
// 4 bits of PA are used for first stick, other 4 bits for second stick.
// 2600: Bits PB 0,1,3,6,7 are used for reset, select, b/w, left diff, right diff
// 7800: Bits PB 0,1,3,6,7 are used for reset, select, pause, left diff, right diff
// 7800: Bits PB 2 & 4 are used for output to select 2 button mode.

wire [15:0] joya = {7'd0, joy0};
wire [15:0] joyb = {7'd0, joy1};

assign PBin[7] = ~diff_right_b;            // Right diff
assign PBin[6] = ~diff_left_b;             // Left diff
assign PBin[5] = PBout[5];                 // Unused (Not connected)
assign PBin[4] = PBout[4];                 // Unused (used for 2 button sensing)
assign PBin[3] = tia_en ? ~bw : (~joya[6] & ~joyb[6]);    // Pause/B&W
assign PBin[2] = PBout[2];                 // Unused (used for 2 button sensing)
assign PBin[1] = (~joya[7] & ~joyb[7]);    // Select
assign PBin[0] = (~joya[8] & ~joyb[8]);    // Start/Reset

// Paddles (MiSTer: paddle_chooser + paddle_timer). The positions come straight from the MEGA65 pots.
wire [3:0] paddle_mask = {(portb_type == 8'd3 ? 2'b11 : 2'b00), (porta_type == 8'd3 ? 2'b11 : 2'b00)};

paddle_timer pt0 (clk_sys, 1'b1, reset || ~paddle_mask[0], {2'b0, pad0}, ~iout[1], i_read[0], pad_wire[0], difference0);
paddle_timer pt1 (clk_sys, 1'b1, reset || ~paddle_mask[1], {2'b0, pad1}, ~iout[1], i_read[1], pad_wire[1], difference1);
paddle_timer pt2 (clk_sys, 1'b1, reset || ~paddle_mask[2], {2'b0, pad2}, ~iout[1], i_read[2], pad_wire[2], difference2);
paddle_timer pt3 (clk_sys, 1'b1, reset || ~paddle_mask[3], {2'b0, pad3}, ~iout[1], i_read[3], pad_wire[3], difference3);

wire joya_b2 = ~PBout[2] && ~tia_en && joy0_type != 5;
wire joyb_b2 = ~PBout[4] && ~tia_en && joy1_type != 5;

//   0 = none
//   1 = 7800 joystick
//   3 = paddle
//   5 = 2600 joystick
// Other header types (light gun, trakball, keypad, mice, ...) have no device here: joystick.
always_comb begin
	porta_type = paddles_a ? 8'd3 : ((joy0_type == 8'd0) ? 8'd0 : 8'd1);
	portb_type = paddles_b ? 8'd3 : ((joy1_type == 8'd0) ? 8'd0 : 8'd1);

	pad_muxa = {~pad_btn[0], ~pad_btn[1], pad_wire[1:0]};
	pad_muxb = {~pad_btn[2], ~pad_btn[3], pad_wire[3:2]};

	idump = tia_en ? {(|portb_type ? 1'b0 : ~joyb[5]), 1'd0, (|porta_type ? 1'b0 : ~joya[5]), 1'd0} : {joyb[4], joyb[5], joya[4], joya[5]}; // P2 F1, P2 F2, P1 F1, P1 F2 or Analog
	PAin[7:4] = {~joya[0], ~joya[1], ~joya[2], ~joya[3]}; // P1: R L D U
	PAin[3:0] = {~joyb[0], ~joyb[1], ~joyb[2], ~joyb[3]}; // P2: R L D U
	ilatch[0] = tia_en ? ~joya[4] : ~(joya[4] || joya[5]); // P1 Fire
	ilatch[1] = tia_en ? ~joyb[4] : ~(joyb[4] || joyb[5]); // P2 Fire

	case (porta_type)
		8'd0: begin PAin[7:4] = 4'b1111; ilatch[0] = 1'b1; idump[1:0] = 2'b00; end
		8'd3: begin PAin[7:4] = {pad_muxa[3:2], 2'b11}; idump[1:0] = pad_muxa[1:0]; ilatch[0] = 1'b1; end
		default: ;
	endcase

	case (portb_type)
		8'd0: begin PAin[3:0] = 4'b1111; ilatch[1] = 1'b1; idump[3:2] = 2'b00; end
		8'd3: begin PAin[3:0] = {pad_muxb[3:2], 2'b11}; idump[3:2] = pad_muxb[1:0]; ilatch[1] = 1'b1; end
		default: ;
	endcase

	// In two button mode, pin 6 is pulled up strongly, and won't lower
	// In one button mode, it will lower if *either* pin 5 or 9 are pressed
	if (joya_b2)
		ilatch[0] = 1;
	if (joyb_b2)
		ilatch[1] = 1;
end

endmodule

`default_nettype wire
