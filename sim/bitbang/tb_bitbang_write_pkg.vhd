-------------------------------------------------------------------------------
-- Title      : tb_bitbang_write_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_write_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario write of tb_bitbang : write commands '0' to '7' : TCK, TMS and
--  TDI are the bits 2, 1 and 0 of the command, every bit set and cleared ;
--  TRST, SRST, LED and m_axis unchanged.
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

package tb_bitbang_write_pkg is

  -- Write commands
  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    );

end package tb_bitbang_write_pkg;

package body tb_bitbang_write_pkg is

  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    ) is
    variable v_cmd       : natural;
  begin
    check_value(tb_rsp.pins, "010", ERROR, "TCK, TMS, TDI after the reset", C_TB_SCOPE);
    for i in 0 to 15 loop
      -- '0' to '7', then '7' to '0'
      v_cmd := i when i < 8 else 15-i;
      tb_send(character'val(character'pos('0') + v_cmd), tb_req, tb_rsp, clk);
      wait until falling_edge(clk);
      check_value(tb_rsp.pins, std_logic_vector(to_unsigned(v_cmd, 3)), ERROR, "TCK, TMS, TDI after '" & character'val(character'pos('0') + v_cmd) & "'", C_TB_SCOPE);
    end loop;
    check_value(tb_rsp.trst_n    , '1', ERROR, "TRST* not asserted by the write commands", C_TB_SCOPE);
    check_value(tb_rsp.srst      , '0', ERROR, "SRST not asserted by the write commands" , C_TB_SCOPE);
    check_value(tb_rsp.blink     , '0', ERROR, "LED off"                                 , C_TB_SCOPE);
    check_value(tb_rsp.answer_cnt, 0  , ERROR, "No answer to the write commands"         , C_TB_SCOPE);
  end procedure run;

end package body tb_bitbang_write_pkg;
