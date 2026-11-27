-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Testbench of jtag_axis : the debugger is the JTAG BFM of asylum_uvvm
--  (TCK of TCK_PERIOD ns), the system a model on clk (CLK_PERIOD ns) :
--  * s_axis : writes tx_word(0), tx_word(1) ... up to tb_req.tx_target
--    words since the reset, with random gaps if tb_req.tx_random, tvalid
--    and tdata held until the handshake ;
--  * m_axis : tready from tb_req.rx_mode (never, always, random), each word
--    read checked against rx_word(0), rx_word(1) ... ; tvalid and tdata
--    held while tready is low (AXI-Stream rule, checked on every cycle).
--  TCK_SYNC = false : TCK of the BFM on the DUT (unrelated to clk) ;
--  true : TCK resynchronized on clk by 2 flip-flops (as in PicoSoC).
--  TESTS_LIST : scenarios run in sequence, separated by ',' (names in
--  tb_jtag_axis_tests_pkg), each one after a reset pulse, then one TCK with
--  TMS = 0 (Run-Test/Idle) ; "" : build and elaboration only.
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
use     ieee.math_real.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.jtag_pkg.all;
use     asylum.string_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_axis_bfm_pkg.all;
use     work.tb_jtag_axis_tests_pkg.all;

entity tb_jtag_axis is
  generic (
    TESTS_LIST      : string   := ""                       -- Scenarios, e.g. "pop,push" (tb_jtag_axis_tests_pkg)
   ;DATA_WIDTH      : positive := 8                        -- Generics of the DUT
   ;TX_ENABLE       : boolean  := true
   ;RX_ENABLE       : boolean  := true
   ;DEPTH_TX        : positive := 4
   ;DEPTH_RX        : positive := 4
   ;CLK_PERIOD      : positive := 10                       -- Period of clk, ns
   ;TCK_PERIOD      : positive := 100                      -- Period of TCK, ns
   ;TCK_SYNC        : boolean  := false                    -- TCK resynchronized on clk
  );
end entity tb_jtag_axis;

architecture sim of tb_jtag_axis is

  constant C_SCOPE        : string    := "TB_JTAG_AXIS";

  signal   clk            : std_logic := '0';
  signal   clk_ena        : boolean   := true;
  signal   arst_b         : std_logic := '0';

  -- BFM and JTAG pins
  signal   jtag_if        : t_jtag_if := init_jtag_if_signals;
  signal   jtag_ini       : jtag_ini_t;
  signal   jtag_tgt       : jtag_tgt_t;
  signal   tck_sync_r     : std_logic_vector(2-1 downto 0);
  signal   dut_tck        : std_logic;

  -- AXI-Stream
  signal   s_tdata        : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
  signal   s_tvalid       : std_logic := '0';
  signal   s_tready       : std_logic;
  signal   m_tdata        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal   m_tvalid       : std_logic;
  signal   m_tready       : std_logic := '0';

  -- Scenarios
  signal   tb_req         : tb_req_t  := C_TB_REQ_IDLE;
  signal   tb_rsp         : tb_rsp_t;

begin  -- architecture sim

  clock_generator(clk, clk_ena, CLK_PERIOD * 1 ns, "TB Clock");

  -----------------------------------------------------------------------------
  -- DUT
  -----------------------------------------------------------------------------
  -- TCK of the BFM, or resynchronized on clk
  process(clk, arst_b)
  begin
    if arst_b = '0'
    then
      tck_sync_r <= (others => '0');
    elsif rising_edge(clk)
    then
      tck_sync_r <= tck_sync_r(0) & jtag_if.tck;
    end if;
  end process;

  dut_tck     <= tck_sync_r(1) when TCK_SYNC else
                 jtag_if.tck;

  jtag_ini    <= (tck    => dut_tck
                 ,trst_n => jtag_if.trst_b
                 ,tms    => jtag_if.tms
                 ,tdi    => jtag_if.tdi
                 );

  -- TDO tri-state at the pad
  jtag_if.tdo <= jtag_tgt.tdo when jtag_tgt.tdo_en = '1' else
                 'Z';

  dut : entity asylum.jtag_axis
    generic map
    (DATA_WIDTH      => DATA_WIDTH
    ,TX_ENABLE       => TX_ENABLE
    ,RX_ENABLE       => RX_ENABLE
    ,DEPTH_TX        => DEPTH_TX
    ,DEPTH_RX        => DEPTH_RX
    ,IDCODE          => C_IDCODE
    )
    port map
    (clk_i           => clk
    ,arst_b_i        => arst_b
    ,jtag_ini_i      => jtag_ini
    ,jtag_tgt_o      => jtag_tgt
    ,s_axis_tdata_i  => s_tdata
    ,s_axis_tvalid_i => s_tvalid
    ,s_axis_tready_o => s_tready
    ,m_axis_tdata_o  => m_tdata
    ,m_axis_tvalid_o => m_tvalid
    ,m_axis_tready_i => m_tready
    );

  tb_rsp.s_tready <= s_tready;
  tb_rsp.m_tvalid <= m_tvalid;
  tb_rsp.m_tdata  <= std_logic_vector(resize(unsigned(m_tdata), C_MAX_WIDTH));

  -----------------------------------------------------------------------------
  -- System model, s_axis : tx_word(0) ... up to tb_req.tx_target words
  -----------------------------------------------------------------------------
  p_soc_tx : process(clk, arst_b)
    variable v_sent  : natural  := 0;
    variable v_seed1 : positive := 3;
    variable v_seed2 : positive := 5;
    variable v_r     : real;
  begin
    if arst_b = '0'
    then
      v_sent         := 0;
      s_tvalid       <= '0';
      tb_rsp.tx_sent <= 0;
    elsif rising_edge(clk)
    then
      if s_tvalid = '1' and s_tready = '1'
      then
        v_sent := v_sent + 1;
      end if;
      -- tvalid and tdata held until the handshake
      if s_tvalid = '0' or s_tready = '1'
      then
        uniform(v_seed1, v_seed2, v_r);
        if v_sent < tb_req.tx_target and (not tb_req.tx_random or v_r < 0.5)
        then
          s_tvalid <= '1';
          s_tdata  <= tx_word(v_sent, DATA_WIDTH);
        else
          s_tvalid <= '0';
        end if;
      end if;
      tb_rsp.tx_sent <= v_sent;
    end if;
  end process p_soc_tx;

  -----------------------------------------------------------------------------
  -- System model, m_axis : ready mode, each word read checked, tvalid and
  -- tdata held while tready is low
  -----------------------------------------------------------------------------
  p_soc_rx : process(clk, arst_b)
    variable v_cnt   : natural  := 0;
    variable v_seed1 : positive := 7;
    variable v_seed2 : positive := 9;
    variable v_r     : real;
    variable v_held  : boolean  := false;
    variable v_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  begin
    if arst_b = '0'
    then
      v_cnt         := 0;
      v_held        := false;
      m_tready      <= '0';
      tb_rsp.rx_cnt <= 0;
    elsif rising_edge(clk)
    then
      if v_held and (m_tvalid /= '1' or m_tdata /= v_data)
      then
        alert(ERROR, "m_axis : tvalid or tdata changed while tready was low", C_SCOPE);
      end if;
      if m_tvalid = '1' and m_tready = '1'
      then
        check_value(m_tdata, rx_word(v_cnt, DATA_WIDTH), ERROR, "m_axis : RX word " & to_string(v_cnt), C_SCOPE);
        v_cnt := v_cnt + 1;
      end if;
      v_held := m_tvalid = '1' and m_tready = '0';
      v_data := m_tdata;

      uniform(v_seed1, v_seed2, v_r);
      case tb_req.rx_mode is
        when RX_NEVER  => m_tready <= '0';
        when RX_ALWAYS => m_tready <= '1';
        when RX_RANDOM => m_tready <= to_sl(v_r < 0.4);
      end case;
      tb_rsp.rx_cnt <= v_cnt;
    end if;
  end process p_soc_rx;

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_main : process is
    variable v_cfg : tb_cfg_t;
  begin
    v_cfg.data_width      := DATA_WIDTH;
    v_cfg.tx_enable       := TX_ENABLE;
    v_cfg.rx_enable       := RX_ENABLE;
    v_cfg.depth_tx        := DEPTH_TX;
    v_cfg.depth_rx        := DEPTH_RX;
    v_cfg.clk_period      := CLK_PERIOD * 1 ns;
    v_cfg.bfm             := C_JTAG_BFM_CONFIG_DEFAULT;
    v_cfg.bfm.ir_width    := JTAG_AXIS_IR_WIDTH;
    v_cfg.bfm.tck_period  := TCK_PERIOD * 1 ns;
    log(ID_LOG_HDR, "DATA_WIDTH " & to_string(DATA_WIDTH) & ", TX_ENABLE " & to_string(TX_ENABLE) & ", RX_ENABLE " & to_string(RX_ENABLE) &
        ", DEPTH_TX " & to_string(DEPTH_TX) & ", DEPTH_RX " & to_string(DEPTH_RX) & ", clk " & to_string(CLK_PERIOD) & " ns, TCK " &
        to_string(TCK_PERIOD) & " ns, TCK_SYNC " & to_string(TCK_SYNC) & ", TESTS_LIST : " & TESTS_LIST, C_SCOPE);

    if DATA_WIDTH > C_MAX_WIDTH - 1 or (TCK_SYNC and TCK_PERIOD < 8*CLK_PERIOD)
    then
      alert(TB_ERROR, "DATA_WIDTH up to 63 ; TCK_SYNC : TCK_PERIOD >= 8 x CLK_PERIOD", C_SCOPE);
    end if;

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST)
    loop
      if not list_contains(C_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests : " & C_TESTS & ")", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST)
    loop
      -- Stimuli idle, reset pulse (released with TCK low), then
      -- Run-Test/Idle : each scenario starts from reset
      jtag_if <= init_jtag_if_signals;
      tb_req  <= C_TB_REQ_IDLE;
      arst_b  <= '0';
      wait for 4*maximum(CLK_PERIOD, TCK_PERIOD) * 1 ns;
      arst_b  <= '1';
      wait for 4*CLK_PERIOD * 1 ns;
      tb_idle(1, jtag_if, v_cfg);

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), jtag_if, tb_req, tb_rsp, arst_b, v_cfg);
      wait for 4*maximum(CLK_PERIOD, TCK_PERIOD) * 1 ns;
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;
