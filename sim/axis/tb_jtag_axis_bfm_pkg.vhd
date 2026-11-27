-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_bfm_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Constants, types and helpers shared by the scenarios of tb_jtag_axis :
--  configuration of the testbench (generics), records between the
--  scenarios and the system model of the testbench (tb_req_t : words the
--  system writes on s_axis, m_axis ready mode ; tb_rsp_t : counters and
--  m_axis), words of each direction, JTAG procedures through the JTAG BFM
--  of asylum_uvvm (IR scan, CONFIG check, pop of a TX word, push of an RX
--  word).
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
use     asylum_uvvm.jtag_bfm_pkg.all;

package tb_jtag_axis_bfm_pkg is

  constant C_TB_SCOPE     : string := "TB_JTAG_AXIS";       -- Scope of the scenarios (C_SCOPE of uvvm_util is hidden by the C_SCOPE of the testbench)

  -- IDCODE of the DUT (bit 0 = 1, IEEE 1149.1)
  constant C_IDCODE       : std_logic_vector(32-1 downto 0) := x"10004001";

  -- Width of the vectors of tb_rsp_t (the DUT uses the LSB)
  constant C_MAX_WIDTH    : natural := 64;

  -- Ready mode of the system on m_axis
  type rx_mode_t is (RX_NEVER, RX_ALWAYS, RX_RANDOM);

  -- Configuration of the testbench (generics of tb_jtag_axis)
  type tb_cfg_t is record
    data_width      : positive;
    tx_enable       : boolean;
    rx_enable       : boolean;
    depth_tx        : positive;
    depth_rx        : positive;
    clk_period      : time;
    bfm             : t_jtag_bfm_config;
  end record tb_cfg_t;

  -- Stimuli of the system model
  type tb_req_t is record
    tx_target       : natural;          -- Number of words written on s_axis since the reset (tx_word(0), tx_word(1) ...)
    tx_random       : boolean;          -- Random gaps between the words
    rx_mode         : rx_mode_t;        -- m_axis_tready_i
  end record tb_req_t;

  constant C_TB_REQ_IDLE  : tb_req_t := (tx_target => 0, tx_random => false, rx_mode => RX_NEVER);

  -- Outputs of the DUT and of the system model
  type tb_rsp_t is record
    tx_sent         : natural;          -- Words written on s_axis (handshakes)
    s_tready        : std_logic;        -- s_axis_tready_o
    rx_cnt          : natural;          -- Words read on m_axis (handshakes, each one checked)
    m_tvalid        : std_logic;        -- m_axis_tvalid_o
    m_tdata         : std_logic_vector(C_MAX_WIDTH-1 downto 0);  -- m_axis_tdata_o (LSB)
  end record tb_rsp_t;

  -- '1' for true
  function to_sl(b : boolean) return std_logic;

  -- Word number n of the TX direction (written on s_axis) and of the RX
  -- direction (pushed through JTAG), width bits
  function tx_word(n : natural; width : positive) return std_logic_vector;
  function rx_word(n : natural; width : positive) return std_logic_vector;

  -- Value seen through BYPASS : data delayed by one bit, captured 0 first
  function bypass_of(data : std_logic_vector) return std_logic_vector;

  -- JTAG procedures through the BFM
  procedure tb_reset(
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  -- num_cycles TCK in Run-Test/Idle (time for the synchronizers of the
  -- FIFOs on the TCK side)
  procedure tb_idle(
    constant num_cycles   : in    natural;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  procedure tb_write_ir(
    constant opcode       : in    std_logic_vector;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  procedure tb_check_dr(
    constant data         : in    std_logic_vector;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  -- CONFIG : IR scan, then check of the 16 bits (DATA_WIDTH, enables and the
  -- 4 flags given)
  procedure tb_check_config(
    constant tx_empty     : in    std_logic;
    constant tx_full      : in    std_logic;
    constant rx_empty     : in    std_logic;
    constant rx_full      : in    std_logic;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  -- TX selected : one DR scan, expects tx_word(n) valid (valid true) or
  -- an empty FIFO (valid false : all zeros)
  procedure tb_pop(
    constant valid        : in    boolean;
    constant n            : in    natural;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  -- TX selected : one DR scan, returns the valid bit and the word
  procedure tb_pop_read(
    variable valid        : out   boolean;
    variable word         : out   std_logic_vector;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  -- RX selected : one DR scan shifting rx_word(n) in, expects the accepted
  -- bit
  procedure tb_push(
    constant n            : in    natural;
    constant accepted     : in    boolean;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  -- RX selected : one DR scan shifting rx_word(n) in, returns the accepted
  -- bit
  procedure tb_push_try(
    constant n            : in    natural;
    variable accepted     : out   boolean;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  -- Wait until the system model wrote n words on s_axis (TB_ERROR after
  -- 1000 clock cycles)
  procedure tb_wait_tx_sent(
    constant n            : in    natural;
    signal   tb_rsp       : in    tb_rsp_t;
    constant cfg          : in    tb_cfg_t
    );

  -- Wait until the system model read n words on m_axis (TB_ERROR after
  -- 1000 clock cycles)
  procedure tb_wait_rx_cnt(
    constant n            : in    natural;
    signal   tb_rsp       : in    tb_rsp_t;
    constant cfg          : in    tb_cfg_t
    );

end package tb_jtag_axis_bfm_pkg;

package body tb_jtag_axis_bfm_pkg is

  function to_sl(b : boolean) return std_logic is
  begin
    if b
    then
      return '1';
    end if;
    return '0';
  end function to_sl;

  function word(n : natural; seed : natural; width : positive) return std_logic_vector is
    variable v : std_logic_vector(width-1 downto 0);
    variable b : unsigned(8-1 downto 0);
  begin
    -- Byte k of the word : (n*37 + seed*101 + 5 + k*29) mod 256
    for i in 0 to width-1
    loop
      b    := to_unsigned((n*37 + seed*101 + 5 + (i/8)*29) mod 2**8, 8);
      v(i) := b(i mod 8);
    end loop;
    return v;
  end function word;

  function tx_word(n : natural; width : positive) return std_logic_vector is
  begin
    return word(n, 1, width);
  end function tx_word;

  function rx_word(n : natural; width : positive) return std_logic_vector is
  begin
    return word(n, 2, width);
  end function rx_word;

  function bypass_of(data : std_logic_vector) return std_logic_vector is
    alias    v_data : std_logic_vector(data'length-1 downto 0) is data;
  begin
    if data'length = 1
    then
      return "0";
    end if;
    return v_data(data'length-2 downto 0) & '0';
  end function bypass_of;

  procedure tb_reset(
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
  begin
    jtag_reset   (msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => cfg.bfm);
  end procedure tb_reset;

  procedure tb_idle(
    constant num_cycles   : in    natural;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
  begin
    jtag_idle    (num_cycles   => num_cycles,
                  msg          => "Synchronizers",
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => cfg.bfm);
  end procedure tb_idle;

  procedure tb_write_ir(
    constant opcode       : in    std_logic_vector;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
  begin
    jtag_write_ir(ir_value     => opcode,
                  msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => cfg.bfm);
  end procedure tb_write_ir;

  procedure tb_check_dr(
    constant data         : in    std_logic_vector;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
  begin
    jtag_check_dr(data_value   => data,
                  data_exp     => data_exp,
                  msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => cfg.bfm);
  end procedure tb_check_dr;

  procedure tb_check_config(
    constant tx_empty     : in    std_logic;
    constant tx_full      : in    std_logic;
    constant rx_empty     : in    std_logic;
    constant rx_full      : in    std_logic;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
    variable v_exp        : std_logic_vector(JTAG_AXIS_CONFIG_WIDTH-1 downto 0);
  begin
    v_exp := std_logic_vector(to_unsigned(cfg.data_width,  8)) &
             '0' & rx_full & rx_empty & to_sl(cfg.rx_enable) &
             '0' & tx_full & tx_empty & to_sl(cfg.tx_enable);
    tb_write_ir(JTAG_AXIS_IR_CONFIG, "CONFIG", jtag_if, cfg);
    tb_check_dr((v_exp'range => '0'), v_exp, "CONFIG : " & msg, jtag_if, cfg);
  end procedure tb_check_config;

  procedure tb_pop(
    constant valid        : in    boolean;
    constant n            : in    natural;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
    constant C_ZERO       : std_logic_vector(cfg.data_width downto 0) := (others => '0');
  begin
    if valid
    then
      tb_check_dr(C_ZERO, tx_word(n, cfg.data_width) & '1', "TX word " & to_string(n) & " : " & msg, jtag_if, cfg);
    else
      tb_check_dr(C_ZERO, C_ZERO, "TX empty : " & msg, jtag_if, cfg);
    end if;
  end procedure tb_pop;

  procedure tb_pop_read(
    variable valid        : out   boolean;
    variable word         : out   std_logic_vector;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
    variable v_out        : std_logic_vector(cfg.data_width downto 0);
  begin
    jtag_scan_dr (data_value   => (v_out'range => '0'),
                  data_out     => v_out,
                  msg          => "TX pop",
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => cfg.bfm);
    valid := v_out(0) = '1';
    word  := v_out(cfg.data_width downto 1);
  end procedure tb_pop_read;

  procedure tb_push(
    constant n            : in    natural;
    constant accepted     : in    boolean;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
    constant C_ZERO       : std_logic_vector(cfg.data_width-1 downto 0) := (others => '0');
  begin
    tb_check_dr(rx_word(n, cfg.data_width) & '0', C_ZERO & to_sl(accepted), "RX word " & to_string(n) & " : " & msg, jtag_if, cfg);
  end procedure tb_push;

  procedure tb_push_try(
    constant n            : in    natural;
    variable accepted     : out   boolean;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
    variable v_out        : std_logic_vector(cfg.data_width downto 0);
  begin
    jtag_scan_dr (data_value   => rx_word(n, cfg.data_width) & '0',
                  data_out     => v_out,
                  msg          => "RX push " & to_string(n),
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => cfg.bfm);
    accepted := v_out(0) = '1';
  end procedure tb_push_try;

  procedure tb_wait_tx_sent(
    constant n            : in    natural;
    signal   tb_rsp       : in    tb_rsp_t;
    constant cfg          : in    tb_cfg_t
    ) is
  begin
    if tb_rsp.tx_sent < n
    then
      wait until tb_rsp.tx_sent >= n for 1000*cfg.clk_period;
    end if;
    check_value(tb_rsp.tx_sent, n, TB_ERROR, "Words written on s_axis", C_TB_SCOPE, ID_NEVER);
  end procedure tb_wait_tx_sent;

  procedure tb_wait_rx_cnt(
    constant n            : in    natural;
    signal   tb_rsp       : in    tb_rsp_t;
    constant cfg          : in    tb_cfg_t
    ) is
  begin
    if tb_rsp.rx_cnt < n
    then
      wait until tb_rsp.rx_cnt >= n for 1000*cfg.clk_period;
    end if;
    check_value(tb_rsp.rx_cnt, n, TB_ERROR, "Words read on m_axis", C_TB_SCOPE, ID_NEVER);
  end procedure tb_wait_rx_cnt;

end package body tb_jtag_axis_bfm_pkg;
