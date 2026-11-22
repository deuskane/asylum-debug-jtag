-------------------------------------------------------------------------------
-- Title      : tb_pad_mux_tests_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_pad_mux_tests_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenarios of tb_pad_mux : names (valid items of TESTS_LIST) and dispatch
--  (run_test) to the package of each scenario (tb_pad_mux_<name>_pkg).
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
use     asylum.jtag_pkg.all;
use     asylum.string_pkg.all;

use     work.tb_pad_mux_bfm_pkg.all;

package tb_pad_mux_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS : string := "select,default,output_enable";

  -- Run the scenario name
  procedure run_test(
    constant name        : in    string;
    signal   sel         : out   natural;
    signal   func_out    : out   pad_array_t;
    signal   func_oe     : out   pad_array_t;
    signal   func_in     : in    pad_array_t;
    signal   pad_out     : in    std_logic_vector;
    signal   pad_oe      : in    std_logic_vector;
    signal   pad_in      : out   std_logic_vector;
    constant cfg         : in    tb_cfg_t
    );

end package tb_pad_mux_tests_pkg;

package body tb_pad_mux_tests_pkg is

  procedure run_test(
    constant name        : in    string;
    signal   sel         : out   natural;
    signal   func_out    : out   pad_array_t;
    signal   func_oe     : out   pad_array_t;
    signal   func_in     : in    pad_array_t;
    signal   pad_out     : in    std_logic_vector;
    signal   pad_oe      : in    std_logic_vector;
    signal   pad_in      : out   std_logic_vector;
    constant cfg         : in    tb_cfg_t
    ) is
  begin
    if    string_eq(name, "select")
    then
      work.tb_pad_mux_select_pkg.run        (sel, func_out, func_oe, func_in, pad_out, pad_oe, pad_in, cfg);
    elsif string_eq(name, "default")
    then
      work.tb_pad_mux_default_pkg.run       (sel, func_out, func_oe, func_in, pad_out, pad_oe, pad_in, cfg);
    elsif string_eq(name, "output_enable")
    then
      work.tb_pad_mux_output_enable_pkg.run (sel, func_out, func_oe, func_in, pad_out, pad_oe, pad_in, cfg);
    else
      alert(TB_ERROR, "Unknown test " & name, C_TB_SCOPE);
    end if;
  end procedure run_test;

end package body tb_pad_mux_tests_pkg;
