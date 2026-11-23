-------------------------------------------------------------------------------
-- Title      : tb_bitbang_tests_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_tests_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenarios of tb_bitbang : names (valid items of TESTS_LIST) and dispatch
--  (run_test) to the package of each scenario (tb_bitbang_<name>_pkg).
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.string_pkg.all;

use     work.tb_bitbang_bfm_pkg.all;

package tb_bitbang_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS : string := "write,read,reset,blink,ignored,backpressure,idcode,dr_scan,uart";

  -- Run the scenario name
  procedure run_test(
    constant name        : in    string;
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    );

end package tb_bitbang_tests_pkg;

package body tb_bitbang_tests_pkg is

  procedure run_test(
    constant name        : in    string;
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    ) is
  begin
    if string_eq(name, "write")
    then
      work.tb_bitbang_write_pkg.run        (tb_req, tb_rsp, clk);
    elsif string_eq(name, "read")
    then
      work.tb_bitbang_read_pkg.run         (tb_req, tb_rsp, clk);
    elsif string_eq(name, "reset")
    then
      work.tb_bitbang_reset_pkg.run        (tb_req, tb_rsp, clk);
    elsif string_eq(name, "blink")
    then
      work.tb_bitbang_blink_pkg.run        (tb_req, tb_rsp, clk);
    elsif string_eq(name, "ignored")
    then
      work.tb_bitbang_ignored_pkg.run      (tb_req, tb_rsp, clk);
    elsif string_eq(name, "backpressure")
    then
      work.tb_bitbang_backpressure_pkg.run (tb_req, tb_rsp, clk);
    elsif string_eq(name, "idcode")
    then
      work.tb_bitbang_idcode_pkg.run       (tb_req, tb_rsp, clk);
    elsif string_eq(name, "dr_scan")
    then
      work.tb_bitbang_dr_scan_pkg.run      (tb_req, tb_rsp, clk);
    elsif string_eq(name, "uart")
    then
      work.tb_bitbang_uart_pkg.run         (tb_req, tb_rsp, clk);
    else
      alert(TB_ERROR, "Unknown test " & name, C_TB_SCOPE);
    end if;
  end procedure run_test;

end package body tb_bitbang_tests_pkg;
