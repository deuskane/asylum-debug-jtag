-------------------------------------------------------------------------------
-- Title      : tb_bitbang
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Testbench of jtag_bitbang (clk 100 MHz) : the commands of OpenOCD are
--  sent as bytes on s_axis by the remote_bitbang BFM rbb_bfm_pkg of
--  asylum-verification-uvvm (helpers in tb_bitbang_bfm_pkg), jtag_bitbang
--  drives the real jtag_tap of the IP (IR 5 bits) with one jtag_tdr_inout
--  of 8 bits (opcode 2).
--  Scenario uart : the commands go through the UART (UVVM UART BFM ->
--  uart_rx_axis -> jtag_bitbang -> uart_tx_axis -> UVVM UART BFM), 16 clock
--  cycles per bit ; an overrun or a framing error of uart_rx_axis is an
--  error.
--  Monitors : answers taken on m_axis (m_axis_tready from the scenario) or
--  received through the UART (rbb_axis_monitor, rbb_uart_monitor : each one
--  must be '0' or '1') ; a pending answer (tvalid = 1, tready = 0) must stay
--  valid and unchanged ; the Capture-IR value "00001" of each IR scan, on
--  the pins of the TAP (jtag_ir_capture_monitor).
--  TESTS_LIST : scenarios run in sequence, separated by ',' (names in
--  tb_bitbang_tests_pkg), each one after a reset pulse ; "" : build and
--  elaboration only.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-- 2026-11-24  1.2.0    mrosiere remote_bitbang BFM and its answer monitors,
--                               jtag_ir_capture_monitor
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_uart;
use     bitvis_vip_uart.uart_bfm_pkg.all;

library asylum;
use     asylum.jtag_pkg.all;
use     asylum.string_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;
use     asylum_uvvm.rbb_bfm_pkg.all;

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
  signal   s_tdata        : std_logic_vector(8-1 downto 0);
  signal   s_tvalid       : std_logic;
  signal   s_tready       : std_logic;
  signal   m_tdata        : std_logic_vector(8-1 downto 0);
  signal   m_tvalid       : std_logic;
  signal   m_tready       : std_logic;
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

  -- UART (scenario uart)
  constant C_UART_CNT     : std_logic_vector(16-1 downto 0) := std_logic_vector(to_unsigned(C_UART_CNT_MAX, 16));
  signal   rx_tdata       : std_logic_vector(8-1 downto 0);
  signal   rx_tvalid      : std_logic;
  signal   rx_tick        : std_logic;
  signal   rx_tick_half   : std_logic;
  signal   rx_tick_en     : std_logic;
  signal   rx_overrun     : std_logic;
  signal   rx_framing     : std_logic;
  signal   tx_tvalid      : std_logic;
  signal   tx_tready      : std_logic;
  signal   tx_tick        : std_logic;
  signal   uart_tx        : std_logic;
  signal   uart_stop      : std_logic;

  -- Answers taken on m_axis and through the UART
  signal   axis_answers   : t_rbb_answers;
  signal   uart_answers   : t_rbb_answers;

  -- Pins of the TAP (Capture-IR monitor)
  signal   jtag_if        : t_jtag_if;

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
    ,s_axis_tdata_i  => s_tdata
    ,s_axis_tvalid_i => s_tvalid
    ,s_axis_tready_o => s_tready
    ,m_axis_tdata_o  => m_tdata
    ,m_axis_tvalid_o => m_tvalid
    ,m_axis_tready_i => m_tready
    ,jtag_ini_o      => jtag_ini
    ,jtag_tgt_i      => jtag_tgt
    ,srst_o          => tb_rsp.srst
    ,blink_o         => tb_rsp.blink
    );

  -- Commands and answers : scenario (s_axis, m_axis) or UART
  s_tdata   <= rx_tdata  when tb_req.uart else tb_req.rbb.tdata;
  s_tvalid  <= rx_tvalid when tb_req.uart else tb_req.rbb.tvalid;
  m_tready  <= tx_tready when tb_req.uart else tb_req.m_tready;
  tx_tvalid <= m_tvalid  when tb_req.uart else '0';

  tb_req.rbb.tready <= s_tready;

  -----------------------------------------------------------------------------
  -- UART : receiver of the commands, transmitter of the answers
  -----------------------------------------------------------------------------
  ins_rx_baud : entity asylum.uart_baud_rate_gen
    generic map
    (BAUD_TICK_CNT_WIDTH     => 16
    )
    port map
    (clk_i                   => clk
    ,arst_b_i                => arst_b
    ,baud_tick_en_i          => rx_tick_en
    ,baud_tick_o             => rx_tick
    ,baud_tick_half_o        => rx_tick_half
    ,cfg_baud_tick_cnt_max_i => C_UART_CNT
    );

  ins_rx : entity asylum.uart_rx_axis
    generic map
    (WIDTH                   => 8
    )
    port map
    (clk_i                   => clk
    ,arst_b_i                => arst_b
    ,uart_rx_i               => tb_req.rbb.tx
    ,m_axis_tdata_o          => rx_tdata
    ,m_axis_parity_error_o   => open
    ,m_axis_tvalid_o         => rx_tvalid
    ,m_axis_tready_i         => s_tready
    ,baud_tick_i             => rx_tick
    ,baud_tick_half_i        => rx_tick_half
    ,baud_tick_en_o          => rx_tick_en
    ,parity_enable_i         => '0'
    ,parity_odd_i            => '0'
    ,last_parity_error_o     => open
    ,err_overrun_o           => rx_overrun
    ,err_parity_o            => open
    ,err_framing_o           => rx_framing
    ,err_break_o             => open
    ,debug_o                 => open
    );

  ins_tx_baud : entity asylum.uart_baud_rate_gen
    generic map
    (BAUD_TICK_CNT_WIDTH     => 16
    )
    port map
    (clk_i                   => clk
    ,arst_b_i                => arst_b
    ,baud_tick_en_i          => '1'
    ,baud_tick_o             => tx_tick
    ,baud_tick_half_o        => open
    ,cfg_baud_tick_cnt_max_i => C_UART_CNT
    );

  ins_tx : entity asylum.uart_tx_axis
    generic map
    (WIDTH                   => 8
    )
    port map
    (clk_i                   => clk
    ,arst_b_i                => arst_b
    ,s_axis_tdata_i          => m_tdata
    ,s_axis_tvalid_i         => tx_tvalid
    ,s_axis_tready_o         => tx_tready
    ,uart_tx_o               => uart_tx
    ,uart_cts_b_i            => '0'
    ,baud_tick_i             => tx_tick
    ,parity_enable_i         => '0'
    ,parity_odd_i            => '0'
    ,debug_o                 => open
    );

  p_uart_errors : process
  begin
    wait until rising_edge(clk);
    if tb_req.uart and (rx_overrun = '1' or rx_framing = '1')
    then
      alert(ERROR, "uart_rx_axis : overrun (" & to_string(rx_overrun) & ") or framing error (" & to_string(rx_framing) & ")", C_SCOPE);
    end if;
  end process p_uart_errors;

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

  tb_rsp.answers  <= uart_answers when tb_req.uart else axis_answers;

  -----------------------------------------------------------------------------
  -- Answers taken on m_axis ('0' or '1' only), a pending answer stays valid
  -- and unchanged (with the UART too)
  -----------------------------------------------------------------------------
  rbb_axis_monitor(clk, m_tdata, m_tvalid, m_tready, axis_answers, C_SCOPE);

  p_pending : process
    variable v_pending : boolean := false;
    variable v_data    : std_logic_vector(8-1 downto 0);
  begin
    wait until rising_edge(clk);
    if arst_b = '0'
    then
      v_pending         := false;
    else
      if v_pending and (m_tvalid /= '1' or m_tdata /= v_data)
      then
        alert(ERROR, "Pending answer lost or changed (tvalid " & to_string(m_tvalid) & ", tdata " & to_hstring(m_tdata) & ")", C_SCOPE);
      end if;
      v_pending := m_tvalid = '1' and m_tready = '0';
      v_data    := m_tdata;
    end if;
  end process p_pending;

  -----------------------------------------------------------------------------
  -- Answers received through the UART (scenario uart)
  -----------------------------------------------------------------------------
  uart_stop <= '0' when tb_req.uart else '1';

  rbb_uart_monitor(uart_tx, uart_stop, uart_answers, C_SCOPE, C_RBB_UART_CONFIG);

  -----------------------------------------------------------------------------
  -- Capture-IR value of each IR scan ("00001"), on the pins of the TAP ;
  -- back to Test-Logic-Reset with the reset of each scenario
  -----------------------------------------------------------------------------
  jtag_if.tck    <= jtag_ini.tck;
  jtag_if.tms    <= jtag_ini.tms;
  jtag_if.tdi    <= jtag_ini.tdi;
  jtag_if.trst_b <= jtag_ini.trst_n and arst_b;
  jtag_if.tdo    <= jtag_tgt.tdo when jtag_tgt.tdo_en = '1' else
                    '1';

  jtag_ir_capture_monitor(jtag_if, "00001", C_SCOPE, shared_msg_id_panel, C_JTAG_CONFIG);

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
