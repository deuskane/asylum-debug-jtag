-------------------------------------------------------------------------------
-- Title      : tb_pad_mux
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_pad_mux.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Testbench of jtag_pad_mux : NB_FUNC functions on NB_PAD pads,
--  PAD_IN_DEFAULT from pad_in_default (0 and 1 bits). The DUT is
--  combinational : no clock, the checks are made C_DELAY after each change of
--  the inputs.
--  TESTS_LIST : scenarios run in sequence, separated by ',' (names in
--  tb_pad_mux_tests_pkg), each one after the inputs are put back to idle (0) ;
--  "" : build and elaboration only.
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
use     work.tb_pad_mux_tests_pkg.all;

entity tb_pad_mux is
  generic (
    TESTS_LIST      : string   := ""                       -- Scenarios, e.g. "select,default" (tb_pad_mux_tests_pkg)
   ;NB_FUNC         : positive := 3                        -- Number of functions
   ;NB_PAD          : positive := 4                        -- Number of pads
  );
end entity tb_pad_mux;

architecture sim of tb_pad_mux is

  constant C_SCOPE        : string := "TB_PAD_MUX";
  constant C_PAD_IN_DEF   : std_logic_vector(NB_PAD-1 downto 0) := pad_in_default(NB_PAD);
  constant C_PAD_IDLE     : std_logic_vector(NB_PAD-1 downto 0) := (others => '0');

  signal   sel            : natural range 0 to NB_FUNC-1 := 0;
  signal   func_out       : pad_array_t(0 to NB_FUNC-1)(NB_PAD-1 downto 0) := (others => C_PAD_IDLE);
  signal   func_oe        : pad_array_t(0 to NB_FUNC-1)(NB_PAD-1 downto 0) := (others => C_PAD_IDLE);
  signal   func_in        : pad_array_t(0 to NB_FUNC-1)(NB_PAD-1 downto 0);
  signal   pad_out        : std_logic_vector(NB_PAD-1 downto 0);
  signal   pad_oe         : std_logic_vector(NB_PAD-1 downto 0);
  signal   pad_in         : std_logic_vector(NB_PAD-1 downto 0) := C_PAD_IDLE;

begin  -- architecture sim

  -----------------------------------------------------------------------------
  -- DUT
  -----------------------------------------------------------------------------
  dut : entity asylum.jtag_pad_mux
    generic map
    (NB_FUNC         => NB_FUNC
    ,NB_PAD          => NB_PAD
    ,PAD_IN_DEFAULT  => C_PAD_IN_DEF
    )
    port map
    (sel_i           => sel
    ,func_out_i      => func_out
    ,func_oe_i       => func_oe
    ,func_in_o       => func_in
    ,pad_out_o       => pad_out
    ,pad_oe_o        => pad_oe
    ,pad_in_i        => pad_in
    );

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_main : process is
    constant C_CFG : tb_cfg_t := (nb_func        => NB_FUNC,
                                  nb_pad         => NB_PAD,
                                  pad_in_default => C_PAD_IN_DEF);
  begin
    log(ID_LOG_HDR, to_string(NB_FUNC) & " functions, " & to_string(NB_PAD) & " pads, PAD_IN_DEFAULT " &
        to_string(C_PAD_IN_DEF) & ", TESTS_LIST : " & TESTS_LIST, C_SCOPE);

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST) loop
      if not list_contains(C_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests : " & C_TESTS & ")", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST) loop
      -- Inputs back to idle : each scenario builds its own context
      sel      <= 0;
      func_out <= (others => C_PAD_IDLE);
      func_oe  <= (others => C_PAD_IDLE);
      pad_in   <= C_PAD_IDLE;
      wait for C_DELAY;

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), sel, func_out, func_oe, func_in, pad_out, pad_oe, pad_in, C_CFG);
      wait for C_DELAY;
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;
