-------------------------------------------------------------------------------
-- Title      : tb_bitbang_blink_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_blink_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario blink of tb_bitbang : 'B' / 'b' switch blink_o on / off, the
--  other outputs unchanged.
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

package tb_bitbang_blink_pkg is

  -- Blink commands
  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    );

end package tb_bitbang_blink_pkg;

package body tb_bitbang_blink_pkg is

  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    ) is
  begin
    check_value(tb_rsp.blink, '0', ERROR, "LED off after the reset", C_TB_SCOPE);
    tb_send('B', tb_req, tb_rsp, clk);
    wait until falling_edge(clk);
    check_value(tb_rsp.blink, '1', ERROR, "LED on after 'B'", C_TB_SCOPE);
    tb_send('B', tb_req, tb_rsp, clk);
    wait until falling_edge(clk);
    check_value(tb_rsp.blink, '1', ERROR, "LED on after 'B' again", C_TB_SCOPE);
    tb_send('b', tb_req, tb_rsp, clk);
    wait until falling_edge(clk);
    check_value(tb_rsp.blink, '0', ERROR, "LED off after 'b'", C_TB_SCOPE);
    tb_send('b', tb_req, tb_rsp, clk);
    wait until falling_edge(clk);
    check_value(tb_rsp.blink, '0', ERROR, "LED off after 'b' again", C_TB_SCOPE);
    check_value(tb_rsp.pins  , "010", ERROR, "TCK, TMS, TDI unchanged by the blink commands", C_TB_SCOPE);
    check_value(tb_rsp.trst_n, '1'  , ERROR, "TRST* unchanged by the blink commands", C_TB_SCOPE);
    check_value(tb_rsp.srst  , '0'  , ERROR, "SRST unchanged by the blink commands" , C_TB_SCOPE);
  end procedure run;

end package body tb_bitbang_blink_pkg;
