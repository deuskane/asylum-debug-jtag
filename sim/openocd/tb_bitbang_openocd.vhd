-------------------------------------------------------------------------------
-- Title      : tb_bitbang_openocd
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_openocd.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Co-simulation of jtag_bitbang with OpenOCD : the bytes of the OpenOCD
--  remote_bitbang adapter (TCP) go to s_axis, the answers from m_axis back
--  to OpenOCD (rbb_axis of the co-simulation kit asylum:verification:openocd,
--  BYTE mode of its rbb_server.c, one byte per clk cycle at most).
--  jtag_bitbang drives jtag_tap (IR 5 bits, IDCODE x4A7C0E35) and a
--  jtag_tdr_inout of 8 bits (opcode 2, data_o looped back to data_i).
--  OpenOCD runs the checks of sim/openocd/jtag.cfg (hooks : cosim.sh of the
--  kit) ; the testbench checks that OpenOCD used every command : 'R', TRST,
--  SRST and the LED. End when OpenOCD closes the connection.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-- 2026-11-24  1.2.0    mrosiere rbb_axis of the co-simulation kit
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.jtag_pkg.all;

library asylum_uvvm;

entity tb_bitbang_openocd is
end entity tb_bitbang_openocd;

architecture sim of tb_bitbang_openocd is

  constant C_SCOPE        : string    := "TB_BITBANG_OPENOCD";
  constant C_CLK_PERIOD   : time      := 10 ns;
  constant C_IDCODE       : std_logic_vector(32-1 downto 0) := x"4A7C0E35";  -- sim/openocd/jtag.cfg

  signal   clk            : std_logic;
  signal   clk_ena        : boolean   := true;
  signal   arst_b         : std_logic := '0';

  -- DUT
  signal   s_tdata        : std_logic_vector(8-1 downto 0);
  signal   s_tvalid       : std_logic;
  signal   s_tready       : std_logic;
  signal   m_tdata        : std_logic_vector(8-1 downto 0);
  signal   m_tvalid       : std_logic;
  signal   jtag_ini       : jtag_ini_t;
  signal   jtag_tgt       : jtag_tgt_t;
  signal   srst           : std_logic;
  signal   blink          : std_logic;
  signal   closed         : boolean   := false;
  signal   quit           : std_logic;

  -- TAP and TDR
  signal   tap_tck        : std_logic;
  signal   tap_trst_b     : std_logic;
  signal   tap_tlr        : std_logic;
  signal   tap_ir         : std_logic_vector(5-1 downto 0);
  signal   tap_capture_dr : std_logic;
  signal   tap_shift_dr   : std_logic;
  signal   tap_update_dr  : std_logic;
  signal   tap_tdi        : std_logic;
  signal   tdr_sel        : std_logic;
  signal   tdr_tdo        : std_logic;
  signal   tdr_data       : std_logic_vector(8-1 downto 0);

begin  -- architecture sim

  clock_generator(clk, clk_ena, C_CLK_PERIOD, "TB Clock");
  arst_b <= '1' after 4*C_CLK_PERIOD + C_CLK_PERIOD/2;

  -----------------------------------------------------------------------------
  -- DUT, TAP and TDR
  -----------------------------------------------------------------------------
  dut : entity asylum.jtag_bitbang
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
    ,srst_o          => srst
    ,blink_o         => blink
    );

  ins_tap : entity asylum.jtag_tap
    generic map
    (IR_WIDTH        => 5
    ,IDCODE_VALUE    => C_IDCODE
    ,TRST_ENABLE     => true
    )
    port map
    (arst_b_i        => arst_b
    ,jtag_ini_i      => jtag_ini
    ,jtag_tgt_o      => jtag_tgt
    ,tck_o           => tap_tck
    ,trst_b_o        => tap_trst_b
    ,tlr_o           => tap_tlr
    ,ir_o            => tap_ir
    ,capture_dr_o    => tap_capture_dr
    ,shift_dr_o      => tap_shift_dr
    ,update_dr_o     => tap_update_dr
    ,tdi_o           => tap_tdi
    ,user_tdo_en_i   => tdr_sel
    ,user_tdo_i      => tdr_tdo
    );

  tdr_sel <= '1' when tap_ir = "00010" else '0';

  ins_tdr : entity asylum.jtag_tdr_inout
    port map
    (tck_i           => tap_tck
    ,trst_b_i        => tap_trst_b
    ,tlr_i           => tap_tlr
    ,sel_i           => tdr_sel
    ,capture_dr_i    => tap_capture_dr
    ,shift_dr_i      => tap_shift_dr
    ,update_dr_i     => tap_update_dr
    ,tdi_i           => tap_tdi
    ,tdo_o           => tdr_tdo
    ,data_i          => tdr_data
    ,data_o          => tdr_data
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
  -- Commands used by OpenOCD, end of the simulation
  -----------------------------------------------------------------------------
  p_main : process
    variable v_reads : natural := 0;
    variable v_trst  : boolean := false;
    variable v_srst  : boolean := false;
    variable v_blink : boolean := false;
  begin
    while not closed loop
      wait until rising_edge(clk) or closed;
      v_reads := v_reads + 1 when m_tvalid = '1' else v_reads;
      v_trst  := v_trst  or jtag_ini.trst_n = '0';
      v_srst  := v_srst  or srst  = '1';
      v_blink := v_blink or blink = '1';
    end loop;
    log(ID_LOG_HDR, "OpenOCD closed the connection at " & integer'image(now / 1 us) & " us, " & integer'image(v_reads) & " answers to 'R'", C_SCOPE);
    check_value(v_reads > 0, true, ERROR, "OpenOCD read TDO ('R')"           , C_SCOPE);
    check_value(v_trst     , true, ERROR, "OpenOCD asserted TRST ('t')"      , C_SCOPE);
    check_value(v_srst     , true, ERROR, "OpenOCD asserted SRST ('s')"      , C_SCOPE);
    check_value(v_blink    , true, ERROR, "OpenOCD switched the LED on ('B')", C_SCOPE);
    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;
