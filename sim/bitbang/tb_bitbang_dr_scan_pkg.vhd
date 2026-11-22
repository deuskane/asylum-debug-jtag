-------------------------------------------------------------------------------
-- Title      : tb_bitbang_dr_scan_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_bitbang_dr_scan_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario dr_scan of tb_bitbang : IR scan of the opcode of the
--  jtag_tdr_inout, DR scans : data_i captured and read by 'R', data_o updated
--  with the bits shifted in.
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

package tb_bitbang_dr_scan_pkg is

  -- DR scan of a TDR
  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    );

end package tb_bitbang_dr_scan_pkg;

package body tb_bitbang_dr_scan_pkg is

  procedure run(
    signal   tb_req      : inout tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   clk         : in    std_logic
    ) is
  begin
    tb_tms("0", tb_req, tb_rsp, clk);
    tb_write_ir(C_IR_TDR, "TDR", tb_req, tb_rsp, clk);
    tb_req.tdr_data <= x"5A";
    tb_check_dr(x"C3", x"5A", "data_i x5A captured", tb_req, tb_rsp, clk);
    check_value(tb_rsp.tdr_data, x"C3", ERROR, "data_o after the scan of xC3", C_TB_SCOPE);
    tb_req.tdr_data <= x"A6";
    tb_check_dr(x"0F", x"A6", "data_i xA6 captured", tb_req, tb_rsp, clk);
    check_value(tb_rsp.tdr_data, x"0F", ERROR, "data_o after the scan of x0F", C_TB_SCOPE);
  end procedure run;

end package body tb_bitbang_dr_scan_pkg;
