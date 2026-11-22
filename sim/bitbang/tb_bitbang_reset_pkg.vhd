-------------------------------------------------------------------------------
-- Title      : tb_bitbang_reset_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_reset_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario reset of tb_bitbang : reset commands 'r', 's', 't', 'u' : TRST /
--  SRST = 00 / 01 / 10 / 11 (1 : asserted, TRST* is active low), TRST* resets
--  the TAP, SRST does not.
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

package tb_bitbang_reset_pkg is

  -- Reset commands
  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    );

end package tb_bitbang_reset_pkg;

package body tb_bitbang_reset_pkg is

  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    ) is
    procedure check_resets(trst_n, srst, tlr : std_logic; msg : string) is
    begin
      wait until falling_edge(clk);
      check_value(tb_rsp.trst_n, trst_n, ERROR, "TRST* after " & msg, C_TB_SCOPE);
      check_value(tb_rsp.srst  , srst  , ERROR, "SRST after "  & msg, C_TB_SCOPE);
      check_value(tb_rsp.tlr   , tlr   , ERROR, "TAP in Test-Logic-Reset after " & msg, C_TB_SCOPE);
    end procedure check_resets;
  begin
    tb_tms("0", tb_req, tb_rsp, clk);
    check_resets('1', '0', '0', "the reset and TMS 0 (Run-Test/Idle)");
    tb_send('t', tb_req, tb_rsp, clk);
    check_resets('0', '0', '1', "'t'");
    tb_send('r', tb_req, tb_rsp, clk);
    check_resets('1', '0', '1', "'r'");
    tb_tms("0", tb_req, tb_rsp, clk);
    tb_send('s', tb_req, tb_rsp, clk);
    check_resets('1', '1', '0', "'s' in Run-Test/Idle");
    tb_send('u', tb_req, tb_rsp, clk);
    check_resets('0', '1', '1', "'u'");
    tb_send('r', tb_req, tb_rsp, clk);
    check_resets('1', '0', '1', "'r'");
    check_value(tb_rsp.pins, "000", ERROR, "TCK, TMS, TDI unchanged by the reset commands", C_TB_SCOPE);
  end procedure run;

end package body tb_bitbang_reset_pkg;
