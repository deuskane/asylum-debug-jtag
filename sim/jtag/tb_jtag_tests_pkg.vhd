-------------------------------------------------------------------------------
-- Title      : tb_jtag_tests_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_tests_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenarios of tb_jtag : names (valid items of TESTS_LIST) and dispatch
--  (run_test) to the package of each scenario (tb_jtag_<name>_pkg).
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

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;

package tb_jtag_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS : string := "reset_trst,reset_tms,ir_capture,idcode,bypass,unclaimed,user,tdo_en,pause,tdr_in,tdr_out,tdr_inout,tdr_reset";

  -- Run the scenario name
  procedure run_test(
    constant name        : in    string;
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_tests_pkg;

package body tb_jtag_tests_pkg is

  procedure run_test(
    constant name        : in    string;
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
  begin
    if    string_eq(name, "reset_trst")
    then
      work.tb_jtag_reset_trst_pkg.run (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "reset_tms")
    then
      work.tb_jtag_reset_tms_pkg.run  (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "ir_capture")
    then
      work.tb_jtag_ir_capture_pkg.run (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "idcode")
    then
      work.tb_jtag_idcode_pkg.run     (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "bypass")
    then
      work.tb_jtag_bypass_pkg.run     (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "unclaimed")
    then
      work.tb_jtag_unclaimed_pkg.run  (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "user")
    then
      work.tb_jtag_user_pkg.run       (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "tdo_en")
    then
      work.tb_jtag_tdo_en_pkg.run     (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "pause")
    then
      work.tb_jtag_pause_pkg.run      (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "tdr_in")
    then
      work.tb_jtag_tdr_in_pkg.run     (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "tdr_out")
    then
      work.tb_jtag_tdr_out_pkg.run    (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "tdr_inout")
    then
      work.tb_jtag_tdr_inout_pkg.run  (jtag_if, tb_req, tb_rsp, cfg);
    elsif string_eq(name, "tdr_reset")
    then
      work.tb_jtag_tdr_reset_pkg.run  (jtag_if, tb_req, tb_rsp, cfg);
    else
      alert(TB_ERROR, "Unknown test " & name, C_TB_SCOPE);
    end if;
  end procedure run_test;

end package body tb_jtag_tests_pkg;
