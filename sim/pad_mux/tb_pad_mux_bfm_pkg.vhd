-------------------------------------------------------------------------------
-- Title      : tb_pad_mux_bfm_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_pad_mux_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Constants, configuration and helpers shared by the scenarios of
--  tb_pad_mux : data patterns of the functions and of the pads.
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

library asylum;
use     asylum.jtag_pkg.all;

package tb_pad_mux_bfm_pkg is

  constant C_TB_SCOPE     : string := "TB_PAD_MUX";   -- Scope of the scenarios (C_SCOPE of uvvm_util is hidden by the C_SCOPE of the testbench)

  -- Time between a change of the inputs and the checks (combinational DUT)
  constant C_DELAY        : time   := 10 ns;

  -- Configuration of the testbench (generics of tb_pad_mux)
  type tb_cfg_t is record
    nb_func         : positive;
    nb_pad          : positive;
    pad_in_default  : std_logic_vector;                            -- PAD_IN_DEFAULT of the DUT
  end record tb_cfg_t;

  -- PAD_IN_DEFAULT of the DUT : pad i at 0 when i mod 3 = 1, else 1
  function pad_in_default(nb_pad : positive) return std_logic_vector;

  -- Pad pattern number k (k >= 1), different from one k to the next
  function pad_pattern(nb_pad : positive; k : natural) return std_logic_vector;

  -- Pattern driven by the function f on its outputs (kind 0) or on its
  -- output enables (kind 1) : different for each function and each kind
  function func_pattern(nb_pad : positive; f : natural; kind : natural) return std_logic_vector;

  -- Outputs and output enables of every function to func_pattern
  procedure drive_functions(
    signal   func_out    : out   pad_array_t;
    signal   func_oe     : out   pad_array_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_pad_mux_bfm_pkg;

package body tb_pad_mux_bfm_pkg is

  function pad_in_default(nb_pad : positive) return std_logic_vector is
    variable v_data : std_logic_vector(nb_pad-1 downto 0);
  begin
    for i in v_data'range loop
      v_data(i) := '0' when (i mod 3) = 1 else '1';
    end loop;
    return v_data;
  end function pad_in_default;

  function pad_pattern(nb_pad : positive; k : natural) return std_logic_vector is
    variable v_data : std_logic_vector(nb_pad-1 downto 0);
    variable v_byte : unsigned(8-1 downto 0);
  begin
    v_byte := to_unsigned((k*37) mod 256, 8);
    for i in v_data'range loop
      v_data(i) := v_byte(i mod 8) when ((i/8) mod 2) = 0 else not v_byte(i mod 8);
    end loop;
    v_data(0) := '1' when (k mod 2) = 1 else '0';
    return v_data;
  end function pad_pattern;

  function func_pattern(nb_pad : positive; f : natural; kind : natural) return std_logic_vector is
  begin
    return pad_pattern(nb_pad, 64 + 2*f + kind);
  end function func_pattern;

  procedure drive_functions(
    signal   func_out    : out   pad_array_t;
    signal   func_oe     : out   pad_array_t;
    constant cfg         : in    tb_cfg_t
    ) is
  begin
    for f in 0 to cfg.nb_func-1 loop
      func_out(f) <= func_pattern(cfg.nb_pad, f, 0);
      func_oe (f) <= func_pattern(cfg.nb_pad, f, 1);
    end loop;
  end procedure drive_functions;

end package body tb_pad_mux_bfm_pkg;
