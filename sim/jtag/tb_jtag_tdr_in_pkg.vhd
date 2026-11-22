-------------------------------------------------------------------------------
-- Title      : tb_jtag_tdr_in_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_tdr_in_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario tdr_in of tb_jtag : jtag_tdr_in : Capture-DR loads data_i (twice, data_i changed between
--  two scans), a scan of twice the width returns data_i then the shifted-in
--  bits ; while another instruction is selected (BYPASS, IDCODE, another TDR)
--  the shift register neither captures data_i nor shifts (monitor of its
--  tdo_o) ; captured again once selected.
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

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;

package tb_jtag_tdr_in_pkg is

  -- jtag_tdr_in : capture, no capture or shift when not selected
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_tdr_in_pkg;

package body tb_jtag_tdr_in_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    constant W           : positive := cfg.tdr_in_width;
    variable v_p1        : std_logic_vector(W-1 downto 0);
    variable v_p2        : std_logic_vector(W-1 downto 0);
    variable v_p3        : std_logic_vector(W-1 downto 0);
    variable v_long      : std_logic_vector(2*W-1 downto 0);
    variable v_out       : std_logic_vector(cfg.tdr_out_width-1 downto 0);
  begin
    v_p1   := tdr_pattern(W, 1);
    v_p2   := tdr_pattern(W, 2);
    v_long := tdr_pattern(2*W, 4);
    tb_req.tdr_in_data(W-1 downto 0) <= v_p1;
    tb_write_ir(C_IR_TDR_IN, "jtag_tdr_in", jtag_if, tb_rsp, cfg);
    tb_check_dr((v_p1'range => '0'), v_p1, "Capture of data_i", jtag_if, cfg);
    tb_req.tdr_in_data(W-1 downto 0) <= v_p2;
    tb_check_dr((v_p2'range => '1'), v_p2, "Capture of the new data_i", jtag_if, cfg);
    tb_check_dr(v_long, v_long(W-1 downto 0) & v_p2, "Scan of 2 x width bits : data_i, then the shifted-in bits", jtag_if, cfg);

    -- Shift register = v_long(2*W-1 downto W) ; data_i differs on every bit
    v_p3 := not v_long(2*W-1 downto W);
    tb_req.tdr_in_data(W-1 downto 0) <= v_p3;
    tb_write_ir(ir_bypass(cfg), "BYPASS", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"A5", bypass_of(x"A5"), "BYPASS, jtag_tdr_in not selected", jtag_if, cfg);
    tb_write_ir(C_IR_IDCODE, "IDCODE", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE, jtag_tdr_in not selected", jtag_if, cfg);
    tb_write_ir(C_IR_TDR_OUT, "jtag_tdr_out", jtag_if, tb_rsp, cfg);
    tb_scan_dr((v_out'range => '1'), v_out, "jtag_tdr_out, jtag_tdr_in not selected", jtag_if, cfg);
    tb_write_ir(C_IR_TDR_IN, "jtag_tdr_in", jtag_if, tb_rsp, cfg);
    tb_check_dr((v_p3'range => '0'), v_p3, "Capture once selected again", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_tdr_in_pkg;
