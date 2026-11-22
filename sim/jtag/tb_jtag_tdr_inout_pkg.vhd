-------------------------------------------------------------------------------
-- Title      : tb_jtag_tdr_inout_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_tdr_inout_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario tdr_inout of tb_jtag : jtag_tdr_inout : data_o cleared by the power-on reset, Capture-DR loads
--  data_i and Update-DR copies the shift register to data_o in the same scan
--  (twice), data_o held during the scans (monitor) and while another
--  instruction is selected (BYPASS, another TDR), capture and update again
--  once selected.
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

package tb_jtag_tdr_inout_pkg is

  -- jtag_tdr_inout : capture and update
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_tdr_inout_pkg;

package body tb_jtag_tdr_inout_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    constant W           : positive := cfg.tdr_inout_width;
    type patterns_t is array (1 to 5) of std_logic_vector(W-1 downto 0);
    variable v_p         : patterns_t;
    variable v_out       : std_logic_vector(cfg.tdr_out_width-1 downto 0);
  begin
    for k in v_p'range loop
      v_p(k) := tdr_pattern(W, k);
    end loop;
    check_value(tb_rsp.tdr_inout_data(W-1 downto 0), (W-1 downto 0 => '0'), ERROR, "data_o after the power-on reset", C_TB_SCOPE);
    tb_req.tdr_inout_data(W-1 downto 0) <= v_p(1);
    tb_write_ir(C_IR_TDR_INOUT, "jtag_tdr_inout", jtag_if, tb_rsp, cfg);
    tb_check_dr(v_p(2), v_p(1), "Capture of data_i", jtag_if, cfg);
    check_value(tb_rsp.tdr_inout_data(W-1 downto 0), v_p(2), ERROR, "data_o updated", C_TB_SCOPE);
    tb_req.tdr_inout_data(W-1 downto 0) <= v_p(3);
    tb_check_dr(v_p(4), v_p(3), "Capture of the new data_i", jtag_if, cfg);
    check_value(tb_rsp.tdr_inout_data(W-1 downto 0), v_p(4), ERROR, "data_o updated again", C_TB_SCOPE);

    tb_req.tdr_inout_data(W-1 downto 0) <= v_p(5);
    tb_write_ir(ir_bypass(cfg), "BYPASS", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"C3", bypass_of(x"C3"), "BYPASS, jtag_tdr_inout not selected", jtag_if, cfg);
    check_value(tb_rsp.tdr_inout_data(W-1 downto 0), v_p(4), ERROR, "data_o held (BYPASS scan)", C_TB_SCOPE);
    tb_write_ir(C_IR_TDR_OUT, "jtag_tdr_out", jtag_if, tb_rsp, cfg);
    tb_scan_dr((v_out'range => '1'), v_out, "jtag_tdr_out, jtag_tdr_inout not selected", jtag_if, cfg);
    check_value(tb_rsp.tdr_inout_data(W-1 downto 0), v_p(4), ERROR, "data_o held (Update-DR of another TDR)", C_TB_SCOPE);
    tb_write_ir(C_IR_TDR_INOUT, "jtag_tdr_inout", jtag_if, tb_rsp, cfg);
    tb_check_dr(v_p(1), v_p(5), "Capture once selected again", jtag_if, cfg);
    check_value(tb_rsp.tdr_inout_data(W-1 downto 0), v_p(1), ERROR, "data_o updated once selected again", C_TB_SCOPE);
  end procedure run;

end package body tb_jtag_tdr_inout_pkg;
