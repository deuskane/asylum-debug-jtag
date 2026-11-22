-------------------------------------------------------------------------------
-- Title      : tb_jtag_tdr_out_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_tdr_out_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario tdr_out of tb_jtag : jtag_tdr_out : data_o cleared by the power-on reset, Update-DR copies
--  the shift register to data_o, no capture (a scan returns the bits shifted
--  in by the previous one, the power-on value first), data_o held during the
--  scans (monitor) and while another instruction is selected (BYPASS, another
--  TDR), the shift register kept while not selected.
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

package tb_jtag_tdr_out_pkg is

  -- jtag_tdr_out : update, no capture, data_o held
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_tdr_out_pkg;

package body tb_jtag_tdr_out_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    constant W           : positive := cfg.tdr_out_width;
    variable v_p1        : std_logic_vector(W-1 downto 0);
    variable v_p2        : std_logic_vector(W-1 downto 0);
    variable v_p3        : std_logic_vector(W-1 downto 0);
    variable v_io        : std_logic_vector(cfg.tdr_inout_width-1 downto 0);
  begin
    v_p1 := tdr_pattern(W, 1);
    v_p2 := tdr_pattern(W, 2);
    v_p3 := tdr_pattern(W, 3);
    check_value(tb_rsp.tdr_out_data(W-1 downto 0), (v_p1'range => '0'), ERROR, "data_o after the power-on reset", C_TB_SCOPE);
    tb_write_ir(C_IR_TDR_OUT, "jtag_tdr_out", jtag_if, tb_rsp, cfg);
    tb_check_dr(v_p1, (v_p1'range => '0'), "No capture : power-on value of the shift register", jtag_if, cfg);
    check_value(tb_rsp.tdr_out_data(W-1 downto 0), v_p1, ERROR, "data_o updated", C_TB_SCOPE);
    tb_check_dr(v_p2, v_p1, "No capture : bits shifted in by the previous scan", jtag_if, cfg);
    check_value(tb_rsp.tdr_out_data(W-1 downto 0), v_p2, ERROR, "data_o updated again", C_TB_SCOPE);

    tb_write_ir(ir_bypass(cfg), "BYPASS", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"3C", bypass_of(x"3C"), "BYPASS, jtag_tdr_out not selected", jtag_if, cfg);
    check_value(tb_rsp.tdr_out_data(W-1 downto 0), v_p2, ERROR, "data_o held (BYPASS scan)", C_TB_SCOPE);
    tb_write_ir(C_IR_TDR_INOUT, "jtag_tdr_inout", jtag_if, tb_rsp, cfg);
    tb_scan_dr((v_io'range => '1'), v_io, "jtag_tdr_inout, jtag_tdr_out not selected", jtag_if, cfg);
    check_value(tb_rsp.tdr_out_data(W-1 downto 0), v_p2, ERROR, "data_o held (Update-DR of another TDR)", C_TB_SCOPE);
    tb_write_ir(C_IR_TDR_OUT, "jtag_tdr_out", jtag_if, tb_rsp, cfg);
    tb_check_dr(v_p3, v_p2, "Shift register kept while not selected", jtag_if, cfg);
    check_value(tb_rsp.tdr_out_data(W-1 downto 0), v_p3, ERROR, "data_o updated once selected again", C_TB_SCOPE);
  end procedure run;

end package body tb_jtag_tdr_out_pkg;
