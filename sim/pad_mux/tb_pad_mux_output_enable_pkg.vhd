-------------------------------------------------------------------------------
-- Title      : tb_pad_mux_output_enable_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_pad_mux_output_enable_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario output_enable of tb_pad_mux : Output enables of the selected function only : for each function, its
--  output enables low while every other function drives them high, then the
--  opposite.
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

package tb_pad_mux_output_enable_pkg is

  -- Pad output enables from the selected function only
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

end package tb_pad_mux_output_enable_pkg;

package body tb_pad_mux_output_enable_pkg is

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
    variable v_oe        : std_logic;
  begin
    for f in 0 to cfg.nb_func-1 loop
      sel <= f;
      for k in 0 to 1 loop
        v_oe := '1' when k = 1 else '0';
        for g in 0 to cfg.nb_func-1 loop
          func_oe(g) <= (cfg.nb_pad-1 downto 0 => v_oe) when g = f else (cfg.nb_pad-1 downto 0 => not v_oe);
        end loop;
        wait for C_DELAY;
        check_value(pad_oe, (cfg.nb_pad-1 downto 0 => v_oe), ERROR, "pad_oe_o of the function " & to_string(f) & " only (" & to_string(v_oe) & ")", C_TB_SCOPE);
      end loop;
    end loop;
  end procedure run;

end package body tb_pad_mux_output_enable_pkg;
