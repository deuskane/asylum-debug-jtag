-------------------------------------------------------------------------------
-- Title      : jtag_bitbang
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : jtag_bitbang.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
-- JTAG master driven by the ASCII byte stream of the OpenOCD remote_bitbang
-- adapter (one byte per command, clk domain) : with a UART in front of it,
-- any USB-UART cable becomes a JTAG probe.
--  * '0'..'7' : TCK / TMS / TDI = bits 2 / 1 / 0 of the byte
--  * 'R'      : answer '0' or '1' on m_axis : TDO (1 when tdo_en = 0, as a
--               pull-up on the TDO line)
--  * 'r' 's' 't' 'u' : TRST / SRST = 00 / 01 / 10 / 11 (1 : asserted)
--  * 'B' / 'b' : blink_o = 1 / 0
--  * any other byte ('Q', SWD and sleep commands of newer OpenOCD) : ignored
-- s_axis_tready_o is low while an answer is pending on m_axis : no command
-- is lost and the answers keep their order.
-- TCK is a register of the clk domain : the TAPs see a clock derived from
-- data, at most clk / 2. OpenOCD changes TMS / TDI with TCK low, one byte
-- before the rising edge of TCK.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library asylum;
use     asylum.jtag_pkg.all;

entity jtag_bitbang is
  port (
    -- Clock and Reset
    clk_i            : in  std_logic
   ;arst_b_i         : in  std_logic
    -- Commands of OpenOCD (bytes of the remote_bitbang protocol)
   ;s_axis_tdata_i   : in  std_logic_vector(8-1 downto 0)
   ;s_axis_tvalid_i  : in  std_logic
   ;s_axis_tready_o  : out std_logic
    -- Answers to 'R' ('0' or '1')
   ;m_axis_tdata_o   : out std_logic_vector(8-1 downto 0)
   ;m_axis_tvalid_o  : out std_logic
   ;m_axis_tready_i  : in  std_logic
    -- JTAG pins (TCK is a register of the clk domain)
   ;jtag_ini_o       : out jtag_ini_t
   ;jtag_tgt_i       : in  jtag_tgt_t
    -- System reset request (SRST, active high) and LED
   ;srst_o           : out std_logic
   ;blink_o          : out std_logic
  );
end entity jtag_bitbang;

architecture rtl of jtag_bitbang is

  signal   cmd              : character;
  signal   s_axis_tready    : std_logic;
  signal   tdo              : std_logic;

  signal   tck_r            : std_logic;
  signal   tms_r            : std_logic;
  signal   tdi_r            : std_logic;
  signal   trst_r           : std_logic;
  signal   srst_r           : std_logic;
  signal   blink_r          : std_logic;
  signal   m_axis_tvalid_r  : std_logic;

begin  -- architecture rtl

  cmd           <= character'val(to_integer(unsigned(s_axis_tdata_i)));

  -- No new command while an answer is pending
  s_axis_tready <= not m_axis_tvalid_r;

  -- TDO line with a pull-up : 1 when not driven
  tdo           <= jtag_tgt_i.tdo when jtag_tgt_i.tdo_en = '1' else
                   '1';

  -----------------------------------------------------------------------------
  -- Commands
  -----------------------------------------------------------------------------
  process(clk_i, arst_b_i)
  begin
    if arst_b_i = '0'
    then
      tck_r           <= '0';
      tms_r           <= '1';
      tdi_r           <= '0';
      trst_r          <= '0';
      srst_r          <= '0';
      blink_r         <= '0';
      m_axis_tvalid_r <= '0';
    elsif rising_edge(clk_i)
    then
      if m_axis_tready_i = '1'
      then
        m_axis_tvalid_r <= '0';
      end if;

      if s_axis_tvalid_i = '1' and s_axis_tready = '1'
      then
        case cmd is
          -- '0' is x"30" : TCK, TMS and TDI are the bits 2, 1 and 0
          when '0' to '7' => tck_r           <= s_axis_tdata_i(2);
                             tms_r           <= s_axis_tdata_i(1);
                             tdi_r           <= s_axis_tdata_i(0);
          when 'R'        => m_axis_tvalid_r <= '1';
          when 'r'        => trst_r          <= '0'; srst_r <= '0';
          when 's'        => trst_r          <= '0'; srst_r <= '1';
          when 't'        => trst_r          <= '1'; srst_r <= '0';
          when 'u'        => trst_r          <= '1'; srst_r <= '1';
          when 'B'        => blink_r         <= '1';
          when 'b'        => blink_r         <= '0';
          when others     => null;
        end case;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  s_axis_tready_o   <= s_axis_tready;

  -- '0' or '1' : TDO does not change while the answer is pending (no
  -- command accepted, TCK held)
  m_axis_tdata_o    <= "0011000" & tdo;
  m_axis_tvalid_o   <= m_axis_tvalid_r;

  jtag_ini_o.tck    <= tck_r;
  jtag_ini_o.trst_n <= not trst_r;
  jtag_ini_o.tms    <= tms_r;
  jtag_ini_o.tdi    <= tdi_r;

  srst_o            <= srst_r;
  blink_o           <= blink_r;

end architecture rtl;
