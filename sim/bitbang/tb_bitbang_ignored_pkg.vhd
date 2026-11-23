-------------------------------------------------------------------------------
-- Title      : tb_bitbang_ignored_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_ignored_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario ignored of tb_bitbang : the 241 bytes that are not a command
--  ('Q', SWD and sleep commands of newer OpenOCD versions, any other value)
--  are ignored : sent in two states of the outputs (TCK, TMS, TDI 101, SRST,
--  LED on ; 010, TRST*, LED off), none changes an output or gives an answer
--  (checked after each byte), s_axis ready again at once.
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

package tb_bitbang_ignored_pkg is

  -- Ignored bytes
  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    );

end package tb_bitbang_ignored_pkg;

package body tb_bitbang_ignored_pkg is

  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    ) is
    constant C_COMMANDS  : string := "01234567RrstuBb";
    variable v_state     : std_logic_vector(6-1 downto 0);

    function is_command(b : natural) return boolean is
    begin
      for i in C_COMMANDS'range loop
        if character'pos(C_COMMANDS(i)) = b
        then
          return true;
        end if;
      end loop;
      return false;
    end function is_command;

    -- TCK, TMS, TDI, TRST*, SRST, LED
    impure function state return std_logic_vector is
    begin
      return tb_rsp.pins & tb_rsp.trst_n & tb_rsp.srst & tb_rsp.blink;
    end function state;
  begin
    for k in 0 to 1 loop
      if k = 0
      then
        tb_send('5', tb_req, tb_rsp, clk);
        tb_send('s', tb_req, tb_rsp, clk);
        tb_send('B', tb_req, tb_rsp, clk);
      else
        tb_send('2', tb_req, tb_rsp, clk);
        tb_send('t', tb_req, tb_rsp, clk);
        tb_send('b', tb_req, tb_rsp, clk);
      end if;
      wait until falling_edge(clk);
      v_state := state;
      if k = 0
      then
        check_value(v_state, "101111", ERROR, "TCK, TMS, TDI 101, SRST, LED on before the ignored bytes", C_TB_SCOPE);
      else
        check_value(v_state, "010000", ERROR, "TCK, TMS, TDI 010, TRST*, LED off before the ignored bytes", C_TB_SCOPE);
      end if;

      for b in 0 to 255 loop
        if not is_command(b)
        then
          tb_send(character'val(b), tb_req, tb_rsp, clk);
          wait until falling_edge(clk);
          if state /= v_state or tb_rsp.m_tvalid /= '0' or tb_rsp.s_tready /= '1'
          then
            alert(ERROR, "Byte x" & to_hstring(to_byte(character'val(b))) & " not ignored", C_TB_SCOPE);
          end if;
        end if;
      end loop;

      check_value(state            , v_state, ERROR, "Outputs after the 241 ignored bytes", C_TB_SCOPE);
      check_value(tb_rsp.answer_cnt, 0      , ERROR, "No answer to the ignored bytes"     , C_TB_SCOPE);
    end loop;
  end procedure run;

end package body tb_bitbang_ignored_pkg;
