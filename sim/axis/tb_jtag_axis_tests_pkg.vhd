-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_tests_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_tests_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenarios of tb_jtag_axis : names (valid items of TESTS_LIST) and
--  dispatch (run_test) to the package of each scenario
--  (tb_jtag_axis_<name>_pkg).
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-26  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.string_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_axis_bfm_pkg.all;

package tb_jtag_axis_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS : string := "idcode,bypass,config,pop,push,tx_full,rx_full,backpressure,stream,reset,race,tx_burst,rx_burst,duplex_burst,visibility,trst,trst_scan,reset_scan";

  -- Run the scenario name
  procedure run_test(
    constant name        : in    string;
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_tests_pkg;

package body tb_jtag_axis_tests_pkg is

  procedure run_test(
    constant name        : in    string;
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
  begin
    if    string_eq(name, "idcode")
    then
      work.tb_jtag_axis_idcode_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "bypass")
    then
      work.tb_jtag_axis_bypass_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "config")
    then
      work.tb_jtag_axis_config_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "pop")
    then
      work.tb_jtag_axis_pop_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "push")
    then
      work.tb_jtag_axis_push_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "tx_full")
    then
      work.tb_jtag_axis_tx_full_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "rx_full")
    then
      work.tb_jtag_axis_rx_full_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "backpressure")
    then
      work.tb_jtag_axis_backpressure_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "stream")
    then
      work.tb_jtag_axis_stream_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "reset")
    then
      work.tb_jtag_axis_reset_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "race")
    then
      work.tb_jtag_axis_race_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "tx_burst")
    then
      work.tb_jtag_axis_tx_burst_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "rx_burst")
    then
      work.tb_jtag_axis_rx_burst_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "duplex_burst")
    then
      work.tb_jtag_axis_duplex_burst_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "visibility")
    then
      work.tb_jtag_axis_visibility_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "trst")
    then
      work.tb_jtag_axis_trst_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "trst_scan")
    then
      work.tb_jtag_axis_trst_scan_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    elsif string_eq(name, "reset_scan")
    then
      work.tb_jtag_axis_reset_scan_pkg.run(jtag_if, tb_req, tb_rsp, arst_b, cfg);
    else
      alert(TB_ERROR, "Unknown test " & name, C_TB_SCOPE);
    end if;
  end procedure run_test;

end package body tb_jtag_axis_tests_pkg;
