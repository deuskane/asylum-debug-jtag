-------------------------------------------------------------------------------
-- Title      : tb_pad_mux_default_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_pad_mux_default_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario default of tb_pad_mux : Each function selected in turn, pad inputs equal to the complement of
--  PAD_IN_DEFAULT, then to PAD_IN_DEFAULT : every unselected function sees
--  PAD_IN_DEFAULT, the selected one sees the pad inputs.
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

package tb_pad_mux_default_pkg is

  -- Unselected functions see PAD_IN_DEFAULT
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

end package tb_pad_mux_default_pkg;

package body tb_pad_mux_default_pkg is

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
      pad_in <= not cfg.pad_in_default;
      wait for C_DELAY;
      for g in 0 to cfg.nb_func-1 loop
        if g = f
        then
          check_value(func_in(g), not cfg.pad_in_default, ERROR, "Function " & to_string(g) & " selected : pad inputs", C_TB_SCOPE);
        else
          check_value(func_in(g), cfg.pad_in_default, ERROR, "Function " & to_string(g) & " not selected (" & to_string(f) & ") : PAD_IN_DEFAULT", C_TB_SCOPE);
        end if;
      end loop;
    end loop;
  end procedure run;

end package body tb_pad_mux_default_pkg;
