-------------------------------------------------------------------------------
-- Title      : tb_bitbang_uart_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_uart_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario uart of tb_bitbang : the commands go through a real UART as on a
--  board (UVVM UART BFM -> uart_rx_axis -> jtag_bitbang -> uart_tx_axis ->
--  UVVM UART BFM, back-to-back frames) : LED, IDCODE read, DR scan of the
--  TDR, TRST and SRST, without overrun of uart_rx_axis.
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

package tb_bitbang_uart_pkg is

  -- Through a UART
  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    );

end package tb_bitbang_uart_pkg;

package body tb_bitbang_uart_pkg is

  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    ) is
    procedure check_outputs(trst_n, srst, blink : std_logic; msg : string) is
    begin
      -- uart_rx_axis delivers the byte after the middle of the stop bit
      wait for C_UART_BIT;
      check_value(tb_rsp.trst_n, trst_n, ERROR, "TRST* after " & msg, C_TB_SCOPE);
      check_value(tb_rsp.srst  , srst  , ERROR, "SRST after "  & msg, C_TB_SCOPE);
      check_value(tb_rsp.blink , blink , ERROR, "LED after "   & msg, C_TB_SCOPE);
    end procedure check_outputs;
  begin
    tb_req.uart <= true;
    wait until falling_edge(clk);

    tb_send('B', tb_req, tb_rsp, clk);
    check_outputs('1', '0', '1', "'B'");
    tb_tms("111110", tb_req, tb_rsp, clk);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE through the UART", tb_req, tb_rsp, clk);
    tb_write_ir(C_IR_TDR, "TDR", tb_req, tb_rsp, clk);
    tb_req.tdr_data <= x"3C";
    tb_check_dr(x"96", x"3C", "data_i x3C captured", tb_req, tb_rsp, clk);
    check_value(tb_rsp.tdr_data, x"96", ERROR, "data_o after the scan of x96", C_TB_SCOPE);
    tb_send('t', tb_req, tb_rsp, clk);
    check_outputs('0', '0', '1', "'t'");
    check_value(tb_rsp.tlr, '1', ERROR, "TAP in Test-Logic-Reset after 't'", C_TB_SCOPE);
    tb_send('s', tb_req, tb_rsp, clk);
    check_outputs('1', '1', '1', "'s'");
    tb_send('r', tb_req, tb_rsp, clk);
    tb_send('b', tb_req, tb_rsp, clk);
    check_outputs('1', '0', '0', "'r' and 'b'");
  end procedure run;

end package body tb_bitbang_uart_pkg;
