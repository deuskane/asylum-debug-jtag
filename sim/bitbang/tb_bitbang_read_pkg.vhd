-------------------------------------------------------------------------------
-- Title      : tb_bitbang_read_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_read_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario read of tb_bitbang : 'R' answers '0' or '1' : TDO of the TAP in
--  Shift-IR / Shift-DR (Capture-IR value, BYPASS register), '1' when TDO is
--  not driven (tdo_en = 0, the TDO register of the TAP at 0 : pull-up).
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

use     work.tb_bitbang_bfm_pkg.all;

package tb_bitbang_read_pkg is

  -- Read command
  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    );

end package tb_bitbang_read_pkg;

package body tb_bitbang_read_pkg is

  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    ) is
    variable v_tdo       : std_logic;
    variable v_out       : std_logic_vector(8-1 downto 0);
  begin
    -- Test-Logic-Reset : TDO not driven, the TDO register of the TAP is 0
    tb_read(v_tdo, tb_req, tb_rsp, clk);
    check_value(v_tdo, '1', ERROR, "'R' with TDO not driven (Test-Logic-Reset) : pull-up", C_TB_SCOPE);

    -- IR scan : Capture-IR "00001" read LSB first (checked by tb_write_ir)
    tb_tms("0", tb_req, tb_rsp, clk);
    tb_write_ir(C_IR_BYPASS, "BYPASS", tb_req, tb_rsp, clk);

    -- DR scan through BYPASS : one bit delay, captured 0
    tb_scan(false, x"A5", v_out, tb_req, tb_rsp, clk);
    check_value(v_out, x"4A", ERROR, "DR scan of xA5 through BYPASS", C_TB_SCOPE);

    -- One 'R' per TDO value in Shift-DR
    tb_tms("100", tb_req, tb_rsp, clk);
    tb_read(v_tdo, tb_req, tb_rsp, clk);
    check_value(v_tdo, '0', ERROR, "'R' in Shift-DR, BYPASS captured 0", C_TB_SCOPE);
    tb_tms("0", tb_req, tb_rsp, clk);
    tb_read(v_tdo, tb_req, tb_rsp, clk);
    check_value(v_tdo, '0', ERROR, "'R' in Shift-DR, 0 shifted in", C_TB_SCOPE);
    tb_write('0', '0', '1', tb_req, tb_rsp, clk);
    tb_write('1', '0', '1', tb_req, tb_rsp, clk);
    tb_write('0', '0', '1', tb_req, tb_rsp, clk);
    tb_read(v_tdo, tb_req, tb_rsp, clk);
    check_value(v_tdo, '1', ERROR, "'R' in Shift-DR, 1 shifted in", C_TB_SCOPE);

    -- Exit1-DR (TDI 0 shifted in : TDO register at 0), Update-DR,
    -- Run-Test/Idle : TDO not driven
    tb_tms("110", tb_req, tb_rsp, clk);
    tb_read(v_tdo, tb_req, tb_rsp, clk);
    check_value(v_tdo, '1', ERROR, "'R' with TDO not driven (Run-Test/Idle) : pull-up", C_TB_SCOPE);
  end procedure run;

end package body tb_bitbang_read_pkg;
