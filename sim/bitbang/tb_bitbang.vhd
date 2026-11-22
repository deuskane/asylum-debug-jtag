-------------------------------------------------------------------------------
-- Title      : tb_bitbang
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Testbench of jtag_bitbang (clk 100 MHz) : the commands of OpenOCD are
--  sent as bytes on s_axis (tb_bitbang_bfm_pkg), jtag_bitbang drives the
--  real jtag_tap of the IP (IR 5 bits) with one jtag_tdr_inout of 8 bits
--  (opcode 2).
--  Monitor of m_axis : takes the answers (m_axis_tready from the scenario),
--  each one must be '0' or '1', and a pending answer (tvalid = 1, tready =
--  0) must stay valid and unchanged.
--  TESTS_LIST : scenarios run in sequence, separated by ',' (names in
--  tb_bitbang_tests_pkg), each one after a reset pulse ; "" : build and
--  elaboration only.
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

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.jtag_pkg.all;
use     asylum.string_pkg.all;

use     work.tb_bitbang_bfm_pkg.all;
use     work.tb_bitbang_tests_pkg.all;

entity tb_bitbang is
  generic (
    TESTS_LIST      : string   := ""                       -- Scenarios, e.g. "write,idcode" (tb_bitbang_tests_pkg)
  );
end entity tb_bitbang;

architecture sim of tb_bitbang is

  constant C_SCOPE        : string    := "TB_BITBANG";

  signal   clk            : std_logic;
  signal   clk_ena        : boolean   := true;
  signal   arst_b         : std_logic := '0';

  -- DUT
  signal   s_tready       : std_logic;
  signal   m_tdata        : std_logic_vector(8-1 downto 0);
  signal   m_tvalid       : std_logic;
  signal   jtag_ini       : jtag_ini_t;
  signal   jtag_tgt       : jtag_tgt_t;

  -- TAP and TDR
  signal   tap_tck        : std_logic;
  signal   tap_trst_b     : std_logic;
  signal   tap_tlr        : std_logic;
  signal   tap_ir         : std_logic_vector(C_IR_WIDTH-1 downto 0);
  signal   tap_capture_dr : std_logic;
  signal   tap_shift_dr   : std_logic;
  signal   tap_update_dr  : std_logic;
  signal   tap_tdi        : std_logic;
  signal   tdr_sel        : std_logic;
  signal   tdr_tdo        : std_logic;

  -- Scenarios
  signal   tb_req         : tb_req_t  := C_TB_REQ_IDLE;
  signal   tb_rsp         : tb_rsp_t;

begin  -- architecture sim

  clock_generator(clk, clk_ena, C_CLK_PERIOD, "TB Clock");

  -----------------------------------------------------------------------------
  -- DUT
  -----------------------------------------------------------------------------
  dut : entity asylum.jtag_bitbang
    port map
    (clk_i           => clk
    ,arst_b_i        => arst_b
    ,s_axis_tdata_i  => tb_req.s_tdata
    ,s_axis_tvalid_i => tb_req.s_tvalid
    ,s_axis_tready_o => s_tready
    ,m_axis_tdata_o  => m_tdata
    ,m_axis_tvalid_o => m_tvalid
    ,m_axis_tready_i => tb_req.m_tready
    ,jtag_ini_o      => jtag_ini
    ,jtag_tgt_i      => jtag_tgt
    ,srst_o          => tb_rsp.srst
    ,blink_o         => tb_rsp.blink
    );

  -----------------------------------------------------------------------------
  -- TAP and one TDR (opcode C_IR_TDR)
  -----------------------------------------------------------------------------
  ins_tap : entity asylum.jtag_tap
    generic map
    (IR_WIDTH        => C_IR_WIDTH
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

  tdr_sel <= '1' when to_integer(unsigned(tap_ir)) = C_IR_TDR else '0';

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
    ,data_i          => tb_req.tdr_data
    ,data_o          => tb_rsp.tdr_data
    );

  -----------------------------------------------------------------------------
  -- Outputs to the scenarios
  -----------------------------------------------------------------------------
  tb_rsp.s_tready <= s_tready;
  tb_rsp.m_tdata  <= m_tdata;
  tb_rsp.m_tvalid <= m_tvalid;
  tb_rsp.pins     <= jtag_ini.tck & jtag_ini.tms & jtag_ini.tdi;
  tb_rsp.trst_n   <= jtag_ini.trst_n;
  tb_rsp.tlr      <= tap_tlr;
  tb_rsp.ir       <= tap_ir;

  -----------------------------------------------------------------------------
  -- Monitor of m_axis : answers taken, '0' or '1' only, a pending answer
  -- stays valid and unchanged
  -----------------------------------------------------------------------------
  p_answers : process
    variable v_pending : boolean := false;
    variable v_data    : std_logic_vector(8-1 downto 0);
  begin
    wait until rising_edge(clk);
    if arst_b = '0'
    then
      tb_rsp.answer_cnt <= 0;
      tb_rsp.answers    <= (others => 'U');
      v_pending         := false;
    else
      if v_pending and (m_tvalid /= '1' or m_tdata /= v_data)
      then
        alert(ERROR, "Pending answer lost or changed (tvalid " & to_string(m_tvalid) & ", tdata " & to_hstring(m_tdata) & ")", C_SCOPE);
      end if;
      v_pending := m_tvalid = '1' and tb_req.m_tready = '0';
      v_data    := m_tdata;

      if m_tvalid = '1' and tb_req.m_tready = '1'
      then
        if m_tdata /= to_byte('0') and m_tdata /= to_byte('1')
        then
          alert(ERROR, "Answer x" & to_hstring(m_tdata) & " is not '0' or '1'", C_SCOPE);
        end if;
        if tb_rsp.answer_cnt < C_MAX_ANSWERS
        then
          tb_rsp.answers(tb_rsp.answer_cnt) <= m_tdata(0);
        end if;
        tb_rsp.answer_cnt <= tb_rsp.answer_cnt + 1;
      end if;
    end if;
  end process p_answers;

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_main : process is
  begin
    log(ID_LOG_HDR, "jtag_bitbang, TESTS_LIST : " & TESTS_LIST, C_SCOPE);

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST) loop
      if not list_contains(C_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests : " & C_TESTS & ")", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST) loop
      -- Stimuli idle, reset pulse released on the falling edge of clk : each
      -- scenario starts from reset
      tb_req <= C_TB_REQ_IDLE;
      arst_b <= '0';
      wait until falling_edge(clk);
      wait for 2*C_CLK_PERIOD;
      arst_b <= '1';
      wait until falling_edge(clk);

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), tb_req, tb_rsp, clk);
      wait for 4*C_CLK_PERIOD;
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;
