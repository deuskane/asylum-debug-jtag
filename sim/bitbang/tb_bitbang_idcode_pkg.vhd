-------------------------------------------------------------------------------
-- Title      : tb_bitbang_idcode_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_idcode_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario idcode of tb_bitbang : IDCODE read through the TAP as OpenOCD
--  does : TMS reset (5 TCK with TMS = 1), DR scan after the reset (IDCODE
--  selected), then IR scans of BYPASS and IDCODE and a new DR scan.
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

package tb_bitbang_idcode_pkg is

  -- IDCODE
  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    );

end package tb_bitbang_idcode_pkg;

package body tb_bitbang_idcode_pkg is

  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    ) is
  begin
    tb_tms("111110", tb_req, tb_rsp, clk);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE after the TMS reset", tb_req, tb_rsp, clk);
    tb_write_ir(C_IR_BYPASS, "BYPASS", tb_req, tb_rsp, clk);
    tb_write_ir(C_IR_IDCODE, "IDCODE", tb_req, tb_rsp, clk);
    tb_check_dr(x"FFFFFFFF", C_IDCODE, "IDCODE selected by an IR scan", tb_req, tb_rsp, clk);
  end procedure run;

end package body tb_bitbang_idcode_pkg;
