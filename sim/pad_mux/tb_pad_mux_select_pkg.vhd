-------------------------------------------------------------------------------
-- Title      : tb_pad_mux_select_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_pad_mux_select_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario select of tb_pad_mux : Each function selected in turn : the pads are driven by its outputs and
--  output enables (every function drives other values), it sees the pad
--  inputs (two values).
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

use     work.tb_pad_mux_bfm_pkg.all;

package tb_pad_mux_select_pkg is

  -- Pads driven by the selected function
  procedure run(
    signal   sel         : out   natural;
    signal   func_out    : out   pad_array_t;
    signal   func_oe     : out   pad_array_t;
    signal   func_in     : in    pad_array_t;
    signal   pad_out     : in    std_logic_vector;
    signal   pad_oe      : in    std_logic_vector;
    signal   pad_in      : out   std_logic_vector;
    constant cfg         : in    tb_cfg_t
    );

end package tb_pad_mux_select_pkg;

package body tb_pad_mux_select_pkg is

  procedure run(
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
    drive_functions(func_out, func_oe, cfg);
    for f in 0 to cfg.nb_func-1 loop
      sel    <= f;
      pad_in <= pad_pattern(cfg.nb_pad, 2*f+1);
      wait for C_DELAY;
      check_value(pad_out, func_pattern(cfg.nb_pad, f, 0), ERROR, "pad_out_o from the function " & to_string(f), C_TB_SCOPE);
      check_value(pad_oe , func_pattern(cfg.nb_pad, f, 1), ERROR, "pad_oe_o from the function " & to_string(f), C_TB_SCOPE);
      check_value(func_in(f), pad_pattern(cfg.nb_pad, 2*f+1), ERROR, "Pad inputs seen by the function " & to_string(f), C_TB_SCOPE);
      pad_in <= pad_pattern(cfg.nb_pad, 2*f+2);
      wait for C_DELAY;
      check_value(func_in(f), pad_pattern(cfg.nb_pad, 2*f+2), ERROR, "New pad inputs seen by the function " & to_string(f), C_TB_SCOPE);
    end loop;
  end procedure run;

end package body tb_pad_mux_select_pkg;
