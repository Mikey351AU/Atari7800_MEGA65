----------------------------------------------------------------------------------
-- Atari 7800 for MEGA65
--
-- Optional BIOS device: 32 KB RAM plus the M2M "manually loadable ROM" protocol
-- (CSR in 4k window 0xFFFF, see cart.vhd). MiSTer: boot0.rom / "Load BIOS" (bios_download).
--
-- The BIOS is read like MiSTer's: address = SALLY's address AND the mask, where the mask is the
-- last address written (BIOS images are 4 KB or 16 KB, a power of two).
-- The core only runs the BIOS when "Bypass BIOS" is off in the menu.
--
-- Licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library xpm;
use xpm.vcomponents.all;

entity bios is
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
      main_loaded_o     : out std_logic;                        -- a BIOS has been loaded
      main_addr_i       : in  std_logic_vector(14 downto 0);    -- SALLY address (unmasked)
      main_data_o       : out std_logic_vector(7 downto 0)
   );
end entity bios;

architecture synthesis of bios is

   constant C_ST_IDLE   : std_logic_vector(15 downto 0) := x"0000";
   constant C_ST_LDNG   : std_logic_vector(15 downto 0) := x"0001";
   constant C_ST_OK     : std_logic_vector(15 downto 0) := x"0003";

   constant C_PT_IDLE   : std_logic_vector(15 downto 0) := x"0000";
   constant C_PT_PRSNG  : std_logic_vector(15 downto 0) := x"0001";
   constant C_PT_OK     : std_logic_vector(15 downto 0) := x"0002";
   constant C_PT_ERR    : std_logic_vector(15 downto 0) := x"0003";

   constant C_ERR_EMPTY : string := "Empty file";
   constant C_ERR_LARGE : string := "Too large: max. 32 KB";

   type state_t is (S_IDLE, S_CHECK, S_SETTLE);
   signal state         : state_t := S_IDLE;

   signal csr_status    : std_logic_vector(15 downto 0) := C_ST_IDLE;
   signal csr_fs_lo     : std_logic_vector(15 downto 0) := (others => '0');
   signal csr_fs_hi     : std_logic_vector(15 downto 0) := (others => '0');
   signal parse_st      : std_logic_vector(15 downto 0) := C_PT_IDLE;
   signal parse_err     : std_logic_vector(15 downto 0) := (others => '0');

   signal loading       : std_logic := '0';
   signal loaded        : std_logic := '0';
   signal mask          : std_logic_vector(14 downto 0) := (others => '0');
   signal settle_cnt    : unsigned(4 downto 0);

   signal is_csr        : std_logic;
   signal w_we          : std_logic := '0';
   signal w_addr        : std_logic_vector(14 downto 0);
   signal w_data        : std_logic_vector(7 downto 0);

   type ram_t is array(0 to 32767) of std_logic_vector(7 downto 0);
   signal ram           : ram_t := (others => (others => '0'));
   attribute ram_style  : string;
   attribute ram_style of ram : signal is "block";

   signal main_sync     : std_logic_vector(16 downto 0);
   signal main_mask     : std_logic_vector(14 downto 0);

   pure function str_char(s : string; i : natural) return std_logic_vector is
   begin
      if i < s'length then
         return std_logic_vector(to_unsigned(character'pos(s(s'low + i)), 16));
      else
         return x"0000";
      end if;
   end function str_char;

begin

   is_csr <= '1' when qnice_addr_i(27 downto 12) = x"FFFF" else '0';

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

   -- QNICE bus is sampled on the falling edge; the RAM is written one full clock later (falling edge)
   p_capture : process(qnice_clk_i)
   begin
      if falling_edge(qnice_clk_i) then
         w_we <= '0';
         if qnice_ce_i = '1' and qnice_we_i = '1' and is_csr = '0' and
            unsigned(qnice_addr_i(27 downto 15)) = 0 then
            w_we   <= '1';
            w_addr <= qnice_addr_i(14 downto 0);
            w_data <= qnice_data_i(7 downto 0);
         end if;
      end if;
   end process p_capture;

   p_ram_write : process(qnice_clk_i)
   begin
      if falling_edge(qnice_clk_i) then
         if w_we = '1' then
            ram(to_integer(unsigned(w_addr))) <= w_data;
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
                     loading  <= '1';
                     loaded   <= '0';
                     parse_st <= C_PT_IDLE;
                  elsif qnice_data_i = C_ST_OK then
                     loading  <= '1';
                     parse_st <= C_PT_PRSNG;
                     state    <= S_CHECK;
                  else
                     loading  <= '0';
                  end if;
               when x"001" => csr_fs_lo <= qnice_data_i;
               when x"002" => csr_fs_hi <= qnice_data_i;
               when others => null;
            end case;
         end if;

         case state is
            when S_IDLE =>
               null;

            when S_CHECK =>
               fs := unsigned(csr_fs_hi) & unsigned(csr_fs_lo);
               if fs = 0 or fs > 32768 then
                  if fs = 0 then
                     parse_err <= x"0001";
                  else
                     parse_err <= x"0002";
                  end if;
                  parse_st <= C_PT_ERR;
                  loading  <= '0';
                  state    <= S_IDLE;
               else
                  parse_err  <= x"0000";
                  mask       <= std_logic_vector(resize(fs - 1, 15));
                  loaded     <= '1';
                  settle_cnt <= (others => '1');
                  state      <= S_SETTLE;
               end if;

            when S_SETTLE =>
               if settle_cnt = 0 then
                  parse_st <= C_PT_OK;
                  loading  <= '0';
                  state    <= S_IDLE;
               else
                  settle_cnt <= settle_cnt - 1;
               end if;
         end case;

         if qnice_rst_i = '1' then
            state      <= S_IDLE;
            csr_status <= C_ST_IDLE;
            parse_st   <= C_PT_IDLE;
            loading    <= '0';
         end if;
      end if;
   end process p_csr;

   i_cdc_status : xpm_cdc_array_single
      generic map (
         DEST_SYNC_FF   => 3,
         SRC_INPUT_REG  => 1,
         WIDTH          => 17
      )
      port map (
         src_clk        => qnice_clk_i,
         src_in         => loading & loaded & mask,
         dest_clk       => main_clk_i,
         dest_out       => main_sync
      ); -- i_cdc_status

   main_loading_o <= main_sync(16);
   main_loaded_o  <= main_sync(15);
   main_mask      <= main_sync(14 downto 0);

   p_bios_read : process(main_clk_i)
   begin
      if rising_edge(main_clk_i) then
         main_data_o <= ram(to_integer(unsigned(main_addr_i and main_mask)));
      end if;
   end process p_bios_read;

end architecture synthesis;

