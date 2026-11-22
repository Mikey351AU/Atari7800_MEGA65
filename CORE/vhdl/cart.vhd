----------------------------------------------------------------------------------
-- Atari 7800 for MEGA65
--
-- Cartridge device: cartridge RAM (BRAM) plus the M2M "manually loadable ROM" protocol
--
-- QNICE side (device C_DEV_A78_CART, see globals.vhd C_CRTROMS_MAN):
--    4k windows 0x0000 .. : the file, one byte per address, written in order by the M2M file loader
--    4k window  0xFFFF    : control and status registers (CSR), see M2M/rom/sysdef.asm:
--       0x000 status (QNICE -> device): 0=idle, 1=loading, 2=error, 3=ok (loading finished)
--       0x001 file size, low word      0x002 file size, high word (written after the data)
--       0x010 parse status (device -> QNICE): 0=idle, 1=parsing, 2=ok, 3=error
--       0x011 error code               0x012/0x013 load address (always 0)
--       0x100 error string (zero terminated)
--
-- 7800 or 2600: decided from the content, not from the file name. A file with an A78 header
-- ("ATARI7800" at offset 1) is a 7800 cartridge, everything else a 2600 cartridge. (MiSTer decides
-- by the extension: .a78 = 7800, .a26/.bin = 2600, so a 7800 game needs a header there, too.)
-- The 128 byte A78 header goes into its own small RAM, the cartridge RAM gets the data after it
-- (like MiSTer's SDRAM, which is written with ioctl_addr - 128). So a 512 KB game with header fits.
--
-- After QNICE reports "ok", the replayer (main clock domain) reads the file back (header, then
-- data) and presents it as MiSTer's download stream (ioctl_download/addr/dout/wr): the MiSTer logic
-- in atari7800_m65.sv parses the header, sizes the cartridge (a78_cart_extent) and detects the 2600
-- bank switching (detect2600) exactly as on MiSTer. The core is held in reset meanwhile.
--
-- Core read port (main clock): like MiSTer's sdram.sv, the address is taken on the rising edge of
-- rom_rd_i and the data stays valid until the next read. MiSTer's SDRAM needs ~1.5 core clocks,
-- this RAM delivers the data one main_clk after the read starts.
--
-- Licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity cart is
   generic (
      G_ADDR_BITS       : natural                               -- cartridge RAM: 2^G_ADDR_BITS bytes
   );
   port (
      -- QNICE clock domain
      qnice_clk_i       : in  std_logic;
      qnice_rst_i       : in  std_logic;
      qnice_addr_i      : in  std_logic_vector(27 downto 0);
      qnice_data_i      : in  std_logic_vector(15 downto 0);
      qnice_data_o      : out std_logic_vector(15 downto 0);
      qnice_ce_i        : in  std_logic;
      qnice_we_i        : in  std_logic;

      -- main clock domain
      main_clk_i        : in  std_logic;
      main_loading_o    : out std_logic;                        -- hold the core in reset
      main_loaded_o     : out std_logic;                        -- a cartridge has been loaded

      -- MiSTer download stream (ioctl_*), main clock domain
      main_dl_active_o  : out std_logic;                        -- ioctl_download for the cartridge
      main_dl_tia_o     : out std_logic;                        -- 1 = 2600 cartridge (MiSTer: ioctl_index[7:6] /= 0)
      main_dl_addr_o    : out std_logic_vector(24 downto 0);    -- ioctl_addr (file offset)
      main_dl_data_o    : out std_logic_vector(7 downto 0);     -- ioctl_dout
      main_dl_wr_o      : out std_logic;                        -- ioctl_wr

      -- cartridge ROM read port (MiSTer: sdram ch0), main clock domain
      main_rom_addr_i   : in  std_logic_vector(24 downto 0);
      main_rom_rd_i     : in  std_logic;
      main_rom_data_o   : out std_logic_vector(7 downto 0)
   );
end entity cart;

architecture synthesis of cart is

   constant C_ST_IDLE   : std_logic_vector(15 downto 0) := x"0000";
   constant C_ST_LDNG   : std_logic_vector(15 downto 0) := x"0001";
   constant C_ST_ERR    : std_logic_vector(15 downto 0) := x"0002";
   constant C_ST_OK     : std_logic_vector(15 downto 0) := x"0003";

   constant C_PT_IDLE   : std_logic_vector(15 downto 0) := x"0000";
   constant C_PT_PRSNG  : std_logic_vector(15 downto 0) := x"0001";
   constant C_PT_OK     : std_logic_vector(15 downto 0) := x"0002";
   constant C_PT_ERR    : std_logic_vector(15 downto 0) := x"0003";

   constant C_ERR_EMPTY : string := "Empty file";
   constant C_ERR_LARGE : string := "Too large: max. 512 KB";

   constant C_MAX_SIZE  : natural := 2 ** G_ADDR_BITS;
   constant C_SIG       : string  := "ATARI7800";               -- A78 header, offset 1

   -------------------------------------------------------------------------------------------------
   -- QNICE clock domain
   -------------------------------------------------------------------------------------------------

   type q_state_t is (QS_IDLE, QS_CHECK, QS_SETTLE, QS_WAIT);
   signal q_state       : q_state_t := QS_IDLE;

   signal csr_status    : std_logic_vector(15 downto 0) := C_ST_IDLE;
   signal csr_fs_lo     : std_logic_vector(15 downto 0) := (others => '0');
   signal csr_fs_hi     : std_logic_vector(15 downto 0) := (others => '0');
   signal parse_st      : std_logic_vector(15 downto 0) := C_PT_IDLE;
   signal parse_err     : std_logic_vector(15 downto 0) := (others => '0');

   signal q_loading     : std_logic := '0';
   signal q_hdr_ok      : std_logic := '1';                     -- bytes 1..9 = "ATARI7800" so far
   signal q_is7800      : std_logic := '0';
   signal q_size        : unsigned(G_ADDR_BITS downto 0) := (others => '0');   -- file size (incl. header)
   signal q_req         : std_logic := '0';                     -- toggles: start the replay
   signal q_done_sync   : std_logic;                            -- replay done toggle, synchronized
   signal q_done_seen   : std_logic := '0';
   signal q_settle      : unsigned(5 downto 0);

   signal is_csr        : std_logic;
   signal q_addr_int    : unsigned(27 downto 0);

   -- registered write into the RAMs (one QNICE clock later, on the next falling edge)
   signal w_cart_we     : std_logic := '0';
   signal w_cart_addr   : std_logic_vector(G_ADDR_BITS-1 downto 0);
   signal w_hdr_we      : std_logic := '0';
   signal w_hdr_addr    : std_logic_vector(6 downto 0);
   signal w_data        : std_logic_vector(7 downto 0);

   -------------------------------------------------------------------------------------------------
   -- RAMs: written on qnice_clk, read on main_clk
   -------------------------------------------------------------------------------------------------

   type cart_ram_t is array(0 to C_MAX_SIZE-1) of std_logic_vector(7 downto 0);
   type hdr_ram_t  is array(0 to 127) of std_logic_vector(7 downto 0);
   signal cart_ram      : cart_ram_t := (others => (others => '0'));
   signal hdr_ram       : hdr_ram_t  := (others => (others => '0'));
   attribute ram_style  : string;
   attribute ram_style of cart_ram : signal is "block";
   attribute ram_style of hdr_ram  : signal is "block";

   -------------------------------------------------------------------------------------------------
   -- main clock domain
   -------------------------------------------------------------------------------------------------

   signal m_sync        : std_logic_vector(G_ADDR_BITS+2 downto 0);
   signal m_loading     : std_logic;
   signal m_is7800      : std_logic;
   signal m_size        : unsigned(G_ADDR_BITS downto 0);
   signal m_req_sync    : std_logic;
   signal m_req_seen    : std_logic := '0';
   signal m_done        : std_logic := '0';                     -- toggles: replay done

   type m_state_t is (MS_IDLE, MS_WAIT, MS_ADDR, MS_READ, MS_DATA, MS_WRITE, MS_NEXT, MS_END);
   signal m_state       : m_state_t := MS_IDLE;
   signal m_busy        : std_logic := '0';
   signal m_loaded      : std_logic := '0';
   signal m_cnt         : unsigned(G_ADDR_BITS downto 0);       -- file offset
   signal m_wait        : unsigned(7 downto 0);

   signal m_rd_d        : std_logic := '0';
   signal m_rom_addr    : std_logic_vector(G_ADDR_BITS-1 downto 0) := (others => '0');
   signal m_cart_raddr  : std_logic_vector(G_ADDR_BITS-1 downto 0);
   signal m_hdr_raddr   : std_logic_vector(6 downto 0);
   signal m_cart_q      : std_logic_vector(7 downto 0);
   signal m_hdr_q       : std_logic_vector(7 downto 0);

   pure function str_char(s : string; i : natural) return std_logic_vector is
   begin
      if i < s'length then
         return std_logic_vector(to_unsigned(character'pos(s(s'low + i)), 16));
      else
         return x"0000";
      end if;
   end function str_char;

begin

   ---------------------------------------------------------------------------------------------
   -- QNICE: CSR read
   ---------------------------------------------------------------------------------------------

   is_csr     <= '1' when qnice_addr_i(27 downto 12) = x"FFFF" else '0';
   q_addr_int <= unsigned(qnice_addr_i);

   p_read : process(all)
      variable idx : natural;
   begin
      qnice_data_o <= x"0000";
      idx := to_integer(unsigned(qnice_addr_i(7 downto 0)));
      if is_csr = '1' then
         qnice_data_o <= x"EEEE";
         case qnice_addr_i(11 downto 0) is
            when x"000" => qnice_data_o <= csr_status;
            when x"001" => qnice_data_o <= csr_fs_lo;
            when x"002" => qnice_data_o <= csr_fs_hi;
            when x"010" => qnice_data_o <= parse_st;
            when x"011" => qnice_data_o <= parse_err;
            when x"012" => qnice_data_o <= x"0000";
            when x"013" => qnice_data_o <= x"0000";
            when others =>
               if qnice_addr_i(11 downto 8) = x"1" then
                  if parse_err = x"0001" then
                     qnice_data_o <= str_char(C_ERR_EMPTY, idx);
                  else
                     qnice_data_o <= str_char(C_ERR_LARGE, idx);
                  end if;
               end if;
         end case;
      end if;
   end process p_read;

   ---------------------------------------------------------------------------------------------
   -- QNICE: data writes, CSR writes and the load state machine.
   -- QNICE drives its bus on the falling clock edge (M2M convention): sample the write on the
   -- falling edge, write the RAMs one full clock later (next falling edge), so the write has a whole
   -- QNICE clock to reach the 128 block RAMs.
   ---------------------------------------------------------------------------------------------

   p_capture : process(qnice_clk_i)
      variable a : unsigned(27 downto 0);
   begin
      if falling_edge(qnice_clk_i) then
         w_cart_we <= '0';
         w_hdr_we  <= '0';
         if qnice_ce_i = '1' and qnice_we_i = '1' and is_csr = '0' then
            a      := q_addr_int;
            w_data <= qnice_data_i(7 downto 0);
            -- header copy and A78 signature check (the loader writes the file in order)
            if a < 128 then
               w_hdr_we   <= '1';
               w_hdr_addr <= std_logic_vector(a(6 downto 0));
            end if;
            if a >= 1 and a <= 9 then
               if qnice_data_i(7 downto 0) /= std_logic_vector(to_unsigned(character'pos(C_SIG(to_integer(a))), 8)) then
                  q_hdr_ok <= '0';
               end if;
            end if;
            -- cartridge RAM: the data after the A78 header starts at address 0
            if q_hdr_ok = '1' and a >= 128 then
               a := a - 128;
            end if;
            if a < C_MAX_SIZE then
               w_cart_we   <= '1';
               w_cart_addr <= std_logic_vector(a(G_ADDR_BITS-1 downto 0));
            end if;
         end if;
         -- a new file starts
         if qnice_ce_i = '1' and qnice_we_i = '1' and is_csr = '1' and
            qnice_addr_i(11 downto 0) = x"000" and qnice_data_i = C_ST_LDNG then
            q_hdr_ok <= '1';
         end if;
      end if;
   end process p_capture;

   p_ram_write : process(qnice_clk_i)
   begin
      if falling_edge(qnice_clk_i) then
         if w_cart_we = '1' then
            cart_ram(to_integer(unsigned(w_cart_addr))) <= w_data;
         end if;
         if w_hdr_we = '1' then
            hdr_ram(to_integer(unsigned(w_hdr_addr))) <= w_data;
         end if;
      end if;
   end process p_ram_write;

   p_csr : process(qnice_clk_i)
      variable fs : unsigned(31 downto 0);
   begin
      if rising_edge(qnice_clk_i) then
         if qnice_ce_i = '1' and qnice_we_i = '1' and is_csr = '1' then
            case qnice_addr_i(11 downto 0) is
               when x"000" =>
                  csr_status <= qnice_data_i;
                  if qnice_data_i = C_ST_LDNG then
                     q_loading <= '1';
                     parse_st  <= C_PT_IDLE;
                  elsif qnice_data_i = C_ST_OK then
                     q_loading <= '1';
                     parse_st  <= C_PT_PRSNG;
                     q_state   <= QS_CHECK;
                  else
                     q_loading <= '0';                      -- idle or error: run the previous content
                  end if;
               when x"001" => csr_fs_lo <= qnice_data_i;
               when x"002" => csr_fs_hi <= qnice_data_i;
               when others => null;
            end case;
         end if;

         case q_state is
            when QS_IDLE =>
               null;

            when QS_CHECK =>
               fs := unsigned(csr_fs_hi) & unsigned(csr_fs_lo);
               if fs = 0 then
                  parse_err <= x"0001";
                  parse_st  <= C_PT_ERR;
                  q_loading <= '0';
                  q_state   <= QS_IDLE;
               elsif (q_hdr_ok = '1' and fs > 128 and fs > C_MAX_SIZE + 128) or
                     ((q_hdr_ok = '0' or fs <= 128) and fs > C_MAX_SIZE) then
                  parse_err <= x"0002";
                  parse_st  <= C_PT_ERR;
                  q_loading <= '0';
                  q_state   <= QS_IDLE;
               else
                  parse_err <= x"0000";
                  q_size    <= fs(G_ADDR_BITS downto 0);
                  if q_hdr_ok = '1' and fs > 128 then
                     q_is7800 <= '1';
                  else
                     q_is7800 <= '0';
                  end if;
                  q_settle  <= (others => '1');
                  q_state   <= QS_SETTLE;
               end if;

            -- give size/is7800 time to cross into the main clock domain, then start the replay
            when QS_SETTLE =>
               if q_settle = 0 then
                  q_req   <= not q_req;
                  q_state <= QS_WAIT;
               else
                  q_settle <= q_settle - 1;
               end if;

            -- wait for the replay (main clock domain) to finish
            when QS_WAIT =>
               if q_done_sync /= q_done_seen then
                  q_done_seen <= q_done_sync;
                  parse_st    <= C_PT_OK;
                  q_loading   <= '0';
                  q_state     <= QS_IDLE;
               end if;
         end case;

         if qnice_rst_i = '1' then
            q_state     <= QS_IDLE;
            csr_status  <= C_ST_IDLE;
            parse_st    <= C_PT_IDLE;
            q_loading   <= '0';
            q_done_seen <= q_done_sync;
         end if;
      end if;
   end process p_csr;

   ---------------------------------------------------------------------------------------------
   -- Clock domain crossings
   ---------------------------------------------------------------------------------------------

   -- quasi static: stable for many clocks before the replay request toggles
   i_cdc_status : xpm_cdc_array_single
      generic map (
         DEST_SYNC_FF   => 3,
         SRC_INPUT_REG  => 1,
         WIDTH          => G_ADDR_BITS + 3
      )
      port map (
         src_clk        => qnice_clk_i,
         src_in         => q_loading & q_is7800 & std_logic_vector(q_size),
         dest_clk       => main_clk_i,
         dest_out       => m_sync
      ); -- i_cdc_status

   m_loading <= m_sync(G_ADDR_BITS + 2);
   m_is7800  <= m_sync(G_ADDR_BITS + 1);
   m_size    <= unsigned(m_sync(G_ADDR_BITS downto 0));

   i_cdc_req : xpm_cdc_single
      generic map (
         DEST_SYNC_FF   => 3,
         SRC_INPUT_REG  => 1
      )
      port map (
         src_clk        => qnice_clk_i,
         src_in         => q_req,
         dest_clk       => main_clk_i,
         dest_out       => m_req_sync
      ); -- i_cdc_req

   i_cdc_done : xpm_cdc_single
      generic map (
         DEST_SYNC_FF   => 3,
         SRC_INPUT_REG  => 1
      )
      port map (
         src_clk        => main_clk_i,
         src_in         => m_done,
         dest_clk       => qnice_clk_i,
         dest_out       => q_done_sync
      ); -- i_cdc_done

   ---------------------------------------------------------------------------------------------
   -- main clock domain: replayer and core read port
   ---------------------------------------------------------------------------------------------

   p_replay : process(main_clk_i)
   begin
      if rising_edge(main_clk_i) then
         main_dl_wr_o <= '0';

         case m_state is
            when MS_IDLE =>
               if m_req_sync /= m_req_seen then
                  m_req_seen <= m_req_sync;
                  m_busy     <= '1';
                  m_wait     <= (others => '1');
                  m_state    <= MS_WAIT;
               end if;

            -- a few clocks with the reset applied before the download starts
            when MS_WAIT =>
               if m_wait = 0 then
                  main_dl_active_o <= '1';
                  main_dl_tia_o    <= not m_is7800;
                  m_cnt            <= (others => '0');
                  m_state          <= MS_ADDR;
               else
                  m_wait <= m_wait - 1;
               end if;

            -- read address set: m_cart_raddr / m_hdr_raddr follow m_cnt (below)
            when MS_ADDR =>
               m_state <= MS_READ;

            when MS_READ =>                                -- RAMs latch the address
               m_state <= MS_DATA;

            when MS_DATA =>                                -- RAM outputs valid
               main_dl_addr_o <= std_logic_vector(resize(m_cnt, 25));
               if m_is7800 = '1' and m_cnt < 128 then
                  main_dl_data_o <= m_hdr_q;
               else
                  main_dl_data_o <= m_cart_q;
               end if;
               m_state <= MS_WRITE;

            when MS_WRITE =>
               main_dl_wr_o <= '1';
               m_state      <= MS_NEXT;

            when MS_NEXT =>
               if m_cnt = m_size - 1 then
                  main_dl_active_o <= '0';
                  m_wait           <= (others => '1');
                  m_state          <= MS_END;
               else
                  m_cnt   <= m_cnt + 1;
                  m_state <= MS_ADDR;
               end if;

            -- let the MiSTer logic finish (end of download), then report
            when MS_END =>
               if m_wait = 0 then
                  m_loaded <= '1';
                  m_busy   <= '0';
                  m_done   <= not m_done;
                  m_state  <= MS_IDLE;
               else
                  m_wait <= m_wait - 1;
               end if;
         end case;
      end if;
   end process p_replay;

   main_loading_o <= m_loading or m_busy;
   main_loaded_o  <= m_loaded;

   -- Replay: file offset -> header RAM / cartridge RAM address. Core: address of the current read.
   m_hdr_raddr  <= std_logic_vector(m_cnt(6 downto 0));
   m_cart_raddr <= std_logic_vector(m_cnt(G_ADDR_BITS-1 downto 0) - 128) when m_busy = '1' and m_is7800 = '1' else
                   std_logic_vector(m_cnt(G_ADDR_BITS-1 downto 0))       when m_busy = '1' else
                   main_rom_addr_i(G_ADDR_BITS-1 downto 0)               when main_rom_rd_i = '1' and m_rd_d = '0' else
                   m_rom_addr;

   p_rom_port : process(main_clk_i)
   begin
      if rising_edge(main_clk_i) then
         m_rd_d <= main_rom_rd_i;
         if main_rom_rd_i = '1' and m_rd_d = '0' then
            m_rom_addr <= main_rom_addr_i(G_ADDR_BITS-1 downto 0);
         end if;
         m_cart_q <= cart_ram(to_integer(unsigned(m_cart_raddr)));
         m_hdr_q  <= hdr_ram(to_integer(unsigned(m_hdr_raddr)));
      end if;
   end process p_rom_port;

   main_rom_data_o <= m_cart_q;

end architecture synthesis;

