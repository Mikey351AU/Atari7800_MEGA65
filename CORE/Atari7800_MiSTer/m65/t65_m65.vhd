----------------------------------------------------------------------------------
-- Atari 7800 for MEGA65
--
-- Thin wrapper around T65 for the SystemVerilog top level (rtl/top.sv, module M6502C):
--    * plain std_logic ports only: T65's DEBUG port is a VHDL record, which cannot cross the
--      VHDL/SystemVerilog boundary in Vivado (Porting Guide 3.E.4)
--    * every T65 input is driven here: Vivado ties unconnected inputs of a VHDL entity
--      instantiated from Verilog to 0 and ignores VHDL defaults (Abort_n, SO_n)
--    * no ports named do/di (Verilog keyword trouble, Porting Guide S44)
--
-- Licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity t65_m65 is
   port (
      clk      : in  std_logic;
      enable   : in  std_logic;
      res_n    : in  std_logic;
      rdy      : in  std_logic;
      irq_n    : in  std_logic;
      nmi_n    : in  std_logic;
      r_w_n    : out std_logic;
      addr     : out std_logic_vector(15 downto 0);
      din      : in  std_logic_vector(7 downto 0);
      dout     : out std_logic_vector(7 downto 0)
   );
end entity t65_m65;

architecture rtl of t65_m65 is
   signal a : std_logic_vector(23 downto 0);
begin

   i_t65 : entity work.T65
      port map (
         Mode    => "00",          -- 6502
         BCD_en  => '1',
         Res_n   => res_n,
         Enable  => enable,
         Clk     => clk,
         Rdy     => rdy,
         Abort_n => '1',
         IRQ_n   => irq_n,
         NMI_n   => nmi_n,
         SO_n    => '1',
         R_W_n   => r_w_n,
         Sync    => open,
         EF      => open,
         MF      => open,
         XF      => open,
         ML_n    => open,
         VP_n    => open,
         VDA     => open,
         VPA     => open,
         A       => a,
         DI      => din,
         DO      => dout,
         Regs    => open,
         DEBUG   => open,
         NMI_ack => open
      );

   addr <= a(15 downto 0);

end architecture rtl;
