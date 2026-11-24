-------------------------------------------------------------------------------
-- Title      : tb_bitbang_backpressure_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_backpressure_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario backpressure of tb_bitbang : m_axis_tready low : the answer to
--  'R' stays pending (valid and unchanged, monitor), s_axis_tready is low and
--  the next command waits (TCK, TMS, TDI unchanged) ; each answer is taken
--  exactly once, in order.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-- 2026-11-24  1.2.0    mrosiere remote_bitbang BFM of asylum-verification-uvvm
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use     work.tb_bitbang_bfm_pkg.all;

package tb_bitbang_backpressure_pkg is

  -- Back-pressure on m_axis
  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    );

end package tb_bitbang_backpressure_pkg;

package body tb_bitbang_backpressure_pkg is

  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    ) is
    constant C_FIRST     : natural := tb_rsp.answers.cnt;
  begin
    -- Answer pending, a write command offered meanwhile
    tb_req.m_tready <= '0';
    tb_send('R', tb_req, tb_rsp, clk);
    tb_req.rbb.tdata  <= to_byte('7');
    tb_req.rbb.tvalid <= '1';
    for i in 1 to 10 loop
      wait until falling_edge(clk);
    end loop;
    check_value(tb_rsp.m_tvalid               , '1'         , ERROR, "Answer pending while m_axis_tready is low"    , C_TB_SCOPE);
    check_value(tb_rsp.m_tdata                , to_byte('1'), ERROR, "Pending answer : TDO not driven"              , C_TB_SCOPE);
    check_value(tb_rsp.s_tready               , '0'         , ERROR, "s_axis_tready low while the answer is pending", C_TB_SCOPE);
    check_value(tb_rsp.pins                   , "010"       , ERROR, "'7' not taken while the answer is pending"    , C_TB_SCOPE);
    check_value(tb_rsp.answers.cnt            , C_FIRST     , ERROR, "No answer taken"                              , C_TB_SCOPE);

    -- Answer taken, then the write command
    tb_req.m_tready <= '1';
    wait until rising_edge(clk) and tb_rsp.s_tready = '1' for C_TIMEOUT;
    tb_req.rbb.tvalid <= '0';
    wait until falling_edge(clk);
    check_value(tb_rsp.answers.cnt            , C_FIRST+1   , ERROR, "Answer taken once"                            , C_TB_SCOPE);
    check_value(tb_rsp.answers.tdo(0)         , '1'         , ERROR, "Answer taken : TDO not driven"                , C_TB_SCOPE);
    check_value(tb_rsp.pins                   , "111"       , ERROR, "'7' taken after the answer"                   , C_TB_SCOPE);

    -- Two 'R' : the second one waits for the first answer
    tb_req.m_tready <= '0';
    tb_send('R', tb_req, tb_rsp, clk);
    tb_req.rbb.tdata  <= to_byte('R');
    tb_req.rbb.tvalid <= '1';
    for i in 1 to 5 loop
      wait until falling_edge(clk);
    end loop;
    check_value(tb_rsp.s_tready               , '0'         , ERROR, "Second 'R' waits for the first answer"        , C_TB_SCOPE);
    tb_req.m_tready <= '1';
    wait until rising_edge(clk) and tb_rsp.s_tready = '1' for C_TIMEOUT;
    tb_req.rbb.tvalid <= '0';
    tb_req.m_tready   <= '0';
    for i in 1 to 5 loop
      wait until falling_edge(clk);
    end loop;
    check_value(tb_rsp.answers.cnt            , C_FIRST+2   , ERROR, "First answer taken once"                      , C_TB_SCOPE);
    check_value(tb_rsp.m_tvalid               , '1'         , ERROR, "Second answer pending"                        , C_TB_SCOPE);
    tb_req.m_tready <= '1';
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    check_value(tb_rsp.answers.cnt            , C_FIRST+3   , ERROR, "Second answer taken once"                     , C_TB_SCOPE);
    check_value(tb_rsp.m_tvalid               , '0'         , ERROR, "No answer left"                               , C_TB_SCOPE);
    check_value(tb_rsp.answers.tdo(2 downto 0), "111"       , ERROR, "Answers : TDO not driven"                     , C_TB_SCOPE);
  end procedure run;

end package body tb_bitbang_backpressure_pkg;
