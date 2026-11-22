-------------------------------------------------------------------------------
-- Title      : tb_jtag_bfm_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Constants, types and helpers shared by the scenarios of tb_jtag :
--  configuration of the testbench, opcodes of the user decoder of the
--  testbench, reference model of the TAP controller (IEEE 1149.1), records
--  between the scenarios and the testbench (tb_req_t : stimuli, tb_rsp_t :
--  outputs of the DUT and monitors), JTAG procedures through the JTAG BFM of
--  asylum_uvvm.
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

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

package tb_jtag_bfm_pkg is

  constant C_TB_SCOPE     : string := "TB_JTAG";      -- Scope of the scenarios (C_SCOPE of uvvm_util is hidden by the C_SCOPE of the testbench)

  -- IDCODE of the DUT (bit 0 = 1, IEEE 1149.1) and period of TCK
  constant C_IDCODE       : std_logic_vector(32-1 downto 0) := x"4A7C0E35";
  constant C_TCK_PERIOD   : time    := 100 ns;

  -- Opcodes : IDCODE ("0...01") and the user instruction of the decoder
  -- of the testbench ; every other opcode selects BYPASS
  constant C_IR_IDCODE    : natural := 1;
  constant C_IR_USER      : natural := 2;
  constant C_IR_UNCLAIMED : natural := 3;

  -- Width of the vectors of tb_req_t / tb_rsp_t (the DUT uses the LSB)
  constant C_MAX_WIDTH    : natural := 64;

  -- Configuration of the testbench (generics of tb_jtag)
  type tb_cfg_t is record
    ir_width       : positive;
    trst_enable    : boolean;
    bfm            : t_jtag_bfm_config;
  end record tb_cfg_t;

  -- Stimuli of the scenarios
  type tb_req_t is record
    user_tdo       : std_logic;                                    -- TDO of the user instruction
  end record tb_req_t;

  -- Outputs of the DUT and monitors
  type tb_rsp_t is record
    ir             : std_logic_vector(32-1 downto 0);              -- ir_o of the TAP (LSB)
    tlr            : std_logic;                                    -- tlr_o of the TAP
    tdo_en         : std_logic;                                    -- tdo_en of the TAP
    ir_capture     : std_logic_vector(32-1 downto 0);              -- Bits shifted out by the last IR scan (LSB first)
    ir_len         : natural;                                      -- Number of bits of the last IR scan
    tdo_en_cnt     : natural;                                      -- TCK cycles with tdo_en = 1 in the last scan
  end record tb_rsp_t;

  -- States of the TAP controller (IEEE 1149.1)
  type tap_state_t is (TEST_LOGIC_RESET, RUN_TEST_IDLE,
                       SELECT_DR_SCAN, CAPTURE_DR, SHIFT_DR, EXIT1_DR, PAUSE_DR, EXIT2_DR, UPDATE_DR,
                       SELECT_IR_SCAN, CAPTURE_IR, SHIFT_IR, EXIT1_IR, PAUSE_IR, EXIT2_IR, UPDATE_IR);

  -- Reference model of the TAP controller : next state for TMS
  function tap_next(state : tap_state_t; tms : std_logic) return tap_state_t;

  -- Opcode of BYPASS (all ones)
  function ir_bypass(cfg : tb_cfg_t) return natural;

  -- JTAG procedures through the BFM
  procedure tb_reset(
    constant trst         : in    boolean;                         -- true : TRST* pulse, then 5 TMS = 1 ; false : TMS only
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  -- TRST* pulse alone (TCK low, TMS = 1), the TAP stays in its state
  -- after the pulse (Test-Logic-Reset when TRST_ENABLE)
  procedure tb_trst_pulse(
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  procedure tb_idle(
    constant num_cycles   : in    natural;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    );

  -- IR scan, then check of ir_o
  procedure tb_write_ir(
    constant opcode       : in    natural;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tb_rsp       : in    tb_rsp_t;
    constant cfg          : in    tb_cfg_t
    );

  procedure tb_scan_dr(
    constant data         : in    std_logic_vector;
    variable data_out     : out   std_logic_vector;
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

  -- Value seen through BYPASS : data delayed by one bit, captured 0 first
  function bypass_of(data : std_logic_vector) return std_logic_vector;

end package tb_jtag_bfm_pkg;

package body tb_jtag_bfm_pkg is

  function tap_next(state : tap_state_t; tms : std_logic) return tap_state_t is
    type next_t is array (tap_state_t, boolean) of tap_state_t;
    -- (TMS = 0, TMS = 1)
    constant C_NEXT : next_t := (
      TEST_LOGIC_RESET => (false => RUN_TEST_IDLE , true => TEST_LOGIC_RESET),
      RUN_TEST_IDLE    => (false => RUN_TEST_IDLE , true => SELECT_DR_SCAN  ),
      SELECT_DR_SCAN   => (false => CAPTURE_DR    , true => SELECT_IR_SCAN  ),
      CAPTURE_DR       => (false => SHIFT_DR      , true => EXIT1_DR        ),
      SHIFT_DR         => (false => SHIFT_DR      , true => EXIT1_DR        ),
      EXIT1_DR         => (false => PAUSE_DR      , true => UPDATE_DR       ),
      PAUSE_DR         => (false => PAUSE_DR      , true => EXIT2_DR        ),
      EXIT2_DR         => (false => SHIFT_DR      , true => UPDATE_DR       ),
      UPDATE_DR        => (false => RUN_TEST_IDLE , true => SELECT_DR_SCAN  ),
      SELECT_IR_SCAN   => (false => CAPTURE_IR    , true => TEST_LOGIC_RESET),
      CAPTURE_IR       => (false => SHIFT_IR      , true => EXIT1_IR        ),
      SHIFT_IR         => (false => SHIFT_IR      , true => EXIT1_IR        ),
      EXIT1_IR         => (false => PAUSE_IR      , true => UPDATE_IR       ),
      PAUSE_IR         => (false => PAUSE_IR      , true => EXIT2_IR        ),
      EXIT2_IR         => (false => SHIFT_IR      , true => UPDATE_IR       ),
      UPDATE_IR        => (false => RUN_TEST_IDLE , true => SELECT_DR_SCAN  ));
  begin
    return C_NEXT(state, tms = '1');
  end function tap_next;

  function ir_bypass(cfg : tb_cfg_t) return natural is
  begin
    return 2**cfg.ir_width-1;
  end function ir_bypass;

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
    constant trst         : in    boolean;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
    variable v_config     : t_jtag_bfm_config := cfg.bfm;
  begin
    v_config.trst_enable := trst;
    jtag_reset   (msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => v_config);
  end procedure tb_reset;

  procedure tb_trst_pulse(
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
  begin
    jtag_if.tck    <= '0';
    jtag_if.tms    <= '1';
    jtag_if.trst_b <= '0';
    wait for cfg.bfm.tck_period;
    jtag_if.trst_b <= '1';
    wait for cfg.bfm.tck_period;
    log(ID_BFM, "TRST* pulse. " & add_msg_delimiter(msg), C_TB_SCOPE);
  end procedure tb_trst_pulse;

  procedure tb_idle(
    constant num_cycles   : in    natural;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
  begin
    jtag_idle    (num_cycles   => num_cycles,
                  msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => cfg.bfm);
  end procedure tb_idle;

  procedure tb_write_ir(
    constant opcode       : in    natural;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tb_rsp       : in    tb_rsp_t;
    constant cfg          : in    tb_cfg_t
    ) is
    constant C_OPCODE     : std_logic_vector(cfg.ir_width-1 downto 0) := std_logic_vector(to_unsigned(opcode, cfg.ir_width));
  begin
    jtag_write_ir(ir_value     => C_OPCODE,
                  msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => cfg.bfm);
    check_value(tb_rsp.ir(cfg.ir_width-1 downto 0), C_OPCODE, ERROR, "ir_o after the IR scan " & msg, C_TB_SCOPE);
  end procedure tb_write_ir;

  procedure tb_scan_dr(
    constant data         : in    std_logic_vector;
    variable data_out     : out   std_logic_vector;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    constant cfg          : in    tb_cfg_t
    ) is
  begin
    jtag_scan_dr (data_value   => data,
                  data_out     => data_out,
                  msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => cfg.bfm);
  end procedure tb_scan_dr;

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

end package body tb_jtag_bfm_pkg;
