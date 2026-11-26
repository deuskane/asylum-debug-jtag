-------------------------------------------------------------------------------
-- Title      : tb_axis_openocd
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_axis_openocd.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Co-simulation of jtag_axis with OpenOCD : rbb_axis (co-simulation kit
--  asylum:verification:openocd) receives the remote_bitbang bytes of
--  OpenOCD, jtag_bitbang drives the JTAG pins (TCK is a register of clk)
--  of jtag_axis (8-bit words, FIFOs of 4 words), whose m_axis (RX) is
--  looped back to its s_axis (TX). The checks are in sim/openocd/axis.cfg
--  (procedures of tools/openocd/jtag_axis.tcl) ; the testbench checks that
--  OpenOCD read TDO and that words went through the loop, then ends when
--  OpenOCD closes the connection.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-26  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.jtag_pkg.all;

library asylum_uvvm;

entity tb_axis_openocd is
end entity tb_axis_openocd;

architecture sim of tb_axis_openocd is

  constant C_SCOPE        : string    := "TB_AXIS_OPENOCD";
  constant C_CLK_PERIOD   : time      := 10 ns;

  signal   clk            : std_logic;
  signal   clk_ena        : boolean   := true;
  signal   arst_b         : std_logic := '0';

  -- remote_bitbang bytes
  signal   s_tdata        : std_logic_vector(8-1 downto 0);
  signal   s_tvalid       : std_logic;
  signal   s_tready       : std_logic;
  signal   m_tdata        : std_logic_vector(8-1 downto 0);
  signal   m_tvalid       : std_logic;
  signal   jtag_ini       : jtag_ini_t;
  signal   jtag_tgt       : jtag_tgt_t;
  signal   closed         : boolean   := false;
  signal   quit           : std_logic;

  -- Loop of jtag_axis : m_axis (RX) to s_axis (TX)
  signal   loop_tdata     : std_logic_vector(8-1 downto 0);
  signal   loop_tvalid    : std_logic;
  signal   loop_tready    : std_logic;

begin  -- architecture sim

  clock_generator(clk, clk_ena, C_CLK_PERIOD, "TB Clock");
  arst_b <= '1' after 4*C_CLK_PERIOD + C_CLK_PERIOD/2;

  -----------------------------------------------------------------------------
  -- JTAG master (OpenOCD remote_bitbang) and DUT
  -----------------------------------------------------------------------------
  ins_bitbang : entity asylum.jtag_bitbang
    port map
    (clk_i           => clk
    ,arst_b_i        => arst_b
    ,s_axis_tdata_i  => s_tdata
    ,s_axis_tvalid_i => s_tvalid
    ,s_axis_tready_o => s_tready
    ,m_axis_tdata_o  => m_tdata
    ,m_axis_tvalid_o => m_tvalid
    ,m_axis_tready_i => '1'
    ,jtag_ini_o      => jtag_ini
    ,jtag_tgt_i      => jtag_tgt
    ,srst_o          => open
    ,blink_o         => open
    );

  dut : entity asylum.jtag_axis
    generic map
    (DATA_WIDTH      => 8
    ,TX_ENABLE       => true
    ,RX_ENABLE       => true
    ,DEPTH_TX        => 4
    ,DEPTH_RX        => 4
    ,IDCODE          => x"10004001"                               -- sim/openocd/axis.cfg
    )
    port map
    (clk_i           => clk
    ,arst_b_i        => arst_b
    ,jtag_ini_i      => jtag_ini
    ,jtag_tgt_o      => jtag_tgt
    ,s_axis_tdata_i  => loop_tdata
    ,s_axis_tvalid_i => loop_tvalid
    ,s_axis_tready_o => loop_tready
    ,m_axis_tdata_o  => loop_tdata
    ,m_axis_tvalid_o => loop_tvalid
    ,m_axis_tready_i => loop_tready
    );

  -----------------------------------------------------------------------------
  -- Bytes of OpenOCD to s_axis, answers of m_axis (always taken) to OpenOCD
  -----------------------------------------------------------------------------
  ins_rbb : entity asylum_uvvm.rbb_axis
    port map
    (clk_i           => clk
    ,arst_b_i        => arst_b
    ,m_axis_tdata_o  => s_tdata
    ,m_axis_tvalid_o => s_tvalid
    ,m_axis_tready_i => s_tready
    ,s_axis_tdata_i  => m_tdata
    ,s_axis_tvalid_i => m_tvalid
    ,s_axis_tready_o => open
    ,quit_o          => quit
    );

  closed <= quit = '1';

  -----------------------------------------------------------------------------
  -- End of the simulation : TDO read by OpenOCD, words through the loop
  -----------------------------------------------------------------------------
  p_main : process
    variable v_reads : natural := 0;
    variable v_words : natural := 0;
  begin
    while not closed loop
      wait until rising_edge(clk) or closed;
      v_reads := v_reads + 1 when m_tvalid = '1' else v_reads;
      v_words := v_words + 1 when loop_tvalid = '1' and loop_tready = '1' else v_words;
    end loop;
    log(ID_LOG_HDR, "OpenOCD closed the connection at " & integer'image(now / 1 us) & " us, " & integer'image(v_reads) & " answers to 'R', " &
        integer'image(v_words) & " words looped back", C_SCOPE);
    check_value(v_reads > 0, true, ERROR, "OpenOCD read TDO ('R')"           , C_SCOPE);
    check_value(v_words > 0, true, ERROR, "Words written and read by OpenOCD", C_SCOPE);
    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;
