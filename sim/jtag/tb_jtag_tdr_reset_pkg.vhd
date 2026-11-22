-------------------------------------------------------------------------------
-- Title      : tb_jtag_tdr_reset_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_tdr_reset_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario tdr_reset of tb_jtag : Reset values of the TDRs : data_o of jtag_tdr_out and jtag_tdr_inout
--  cleared by the power-on reset ; TRST* clears data_o and the shift
--  registers (with TRST_ENABLE = false : both kept) ; Test-Logic-Reset (5 TMS
--  = 1) clears data_o, the shift registers are kept ; data_o held by the
--  Update-DR of BYPASS while the shift registers differ from data_o.
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

use     work.tb_jtag_bfm_pkg.all;

package tb_jtag_tdr_reset_pkg is

  -- Reset values of the TDRs
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_tdr_reset_pkg;

package body tb_jtag_tdr_reset_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    constant WO          : positive := cfg.tdr_out_width;
    constant WI          : positive := cfg.tdr_inout_width;
    variable v_o1        : std_logic_vector(WO-1 downto 0);
    variable v_o2        : std_logic_vector(WO-1 downto 0);
    variable v_i1        : std_logic_vector(WI-1 downto 0);
    variable v_i2        : std_logic_vector(WI-1 downto 0);
    variable v_o_exp     : std_logic_vector(WO-1 downto 0);
    variable v_i_exp     : std_logic_vector(WI-1 downto 0);
    variable v_dummy_o   : std_logic_vector(WO-1 downto 0);
    variable v_dummy_i   : std_logic_vector(WI-1 downto 0);

    -- Scan of value_out in jtag_tdr_out and of value_io in jtag_tdr_inout,
    -- check of their data_o
    procedure load(value_out : std_logic_vector; value_io : std_logic_vector; msg : string) is
    begin
      tb_write_ir(C_IR_TDR_OUT  , "jtag_tdr_out"  , jtag_if, tb_rsp, cfg);
      tb_scan_dr(value_out, v_dummy_o, "jtag_tdr_out " & msg, jtag_if, cfg);
      tb_write_ir(C_IR_TDR_INOUT, "jtag_tdr_inout", jtag_if, tb_rsp, cfg);
      tb_scan_dr(value_io , v_dummy_i, "jtag_tdr_inout " & msg, jtag_if, cfg);
      check_value(tb_rsp.tdr_out_data  (WO-1 downto 0), value_out, ERROR, "data_o of jtag_tdr_out " & msg, C_TB_SCOPE);
      check_value(tb_rsp.tdr_inout_data(WI-1 downto 0), value_io , ERROR, "data_o of jtag_tdr_inout " & msg, C_TB_SCOPE);
    end procedure load;
  begin
    v_o1 := tdr_pattern(WO, 1);
    v_o2 := tdr_pattern(WO, 2);
    v_i1 := tdr_pattern(WI, 3);
    v_i2 := tdr_pattern(WI, 4);
    tb_req.tdr_inout_data(WI-1 downto 0) <= (WI-1 downto 0 => '1');
    check_value(tb_rsp.tdr_out_data  (WO-1 downto 0), (WO-1 downto 0 => '0'), ERROR, "data_o of jtag_tdr_out after the power-on reset", C_TB_SCOPE);
    check_value(tb_rsp.tdr_inout_data(WI-1 downto 0), (WI-1 downto 0 => '0'), ERROR, "data_o of jtag_tdr_inout after the power-on reset", C_TB_SCOPE);

    -- TRST* : data_o and shift registers cleared (kept without TRST_ENABLE)
    load(v_o1, v_i1, "before TRST*");
    tb_trst_pulse("TRST*", jtag_if, cfg);
    tb_idle(1, "Run-Test/Idle", jtag_if, cfg);
    if cfg.trst_enable
    then
      v_o_exp := (others => '0');
      v_i_exp := (others => '0');
    else
      v_o_exp := v_o1;
      v_i_exp := v_i1;
    end if;
    check_value(tb_rsp.tdr_out_data  (WO-1 downto 0), v_o_exp, ERROR, "data_o of jtag_tdr_out after TRST*", C_TB_SCOPE);
    check_value(tb_rsp.tdr_inout_data(WI-1 downto 0), v_i_exp, ERROR, "data_o of jtag_tdr_inout after TRST*", C_TB_SCOPE);
    tb_write_ir(C_IR_TDR_OUT, "jtag_tdr_out", jtag_if, tb_rsp, cfg);
    tb_check_dr(v_o2, v_o_exp, "Shift register of jtag_tdr_out after TRST*", jtag_if, cfg);

    -- Test-Logic-Reset : data_o cleared, shift registers kept
    load(v_o1, v_i2, "before the TMS reset");
    tb_reset(false, "5 TMS = 1, no TRST*", jtag_if, cfg);
    check_value(tb_rsp.tdr_out_data  (WO-1 downto 0), (WO-1 downto 0 => '0'), ERROR, "data_o of jtag_tdr_out after Test-Logic-Reset", C_TB_SCOPE);
    check_value(tb_rsp.tdr_inout_data(WI-1 downto 0), (WI-1 downto 0 => '0'), ERROR, "data_o of jtag_tdr_inout after Test-Logic-Reset", C_TB_SCOPE);
    tb_write_ir(ir_bypass(cfg), "BYPASS", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"5A", bypass_of(x"5A"), "BYPASS after Test-Logic-Reset", jtag_if, cfg);
    check_value(tb_rsp.tdr_out_data  (WO-1 downto 0), (WO-1 downto 0 => '0'), ERROR, "data_o of jtag_tdr_out held (Update-DR of BYPASS)", C_TB_SCOPE);
    check_value(tb_rsp.tdr_inout_data(WI-1 downto 0), (WI-1 downto 0 => '0'), ERROR, "data_o of jtag_tdr_inout held (Update-DR of BYPASS)", C_TB_SCOPE);
    tb_write_ir(C_IR_TDR_OUT, "jtag_tdr_out", jtag_if, tb_rsp, cfg);
    tb_check_dr(v_o2, v_o1, "Shift register of jtag_tdr_out kept by Test-Logic-Reset", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_tdr_reset_pkg;
