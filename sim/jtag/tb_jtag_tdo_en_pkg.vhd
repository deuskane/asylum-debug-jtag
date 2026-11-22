-------------------------------------------------------------------------------
-- Title      : tb_jtag_tdo_en_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_tdo_en_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario tdo_en of tb_jtag : tdo_en is high in Shift-IR / Shift-DR only : number of TCK cycles with
--  tdo_en = 1 in IR, IDCODE, BYPASS and 1-bit scans, tdo_en low in
--  Run-Test/Idle (each TCK cycle is also checked against the model of the TAP
--  by the testbench).
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

package tb_jtag_tdo_en_pkg is

  -- tdo_en in Shift-IR / Shift-DR only
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_tdo_en_pkg;

package body tb_jtag_tdo_en_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    variable v_data      : std_logic_vector(32-1 downto 0);
    variable v_bit       : std_logic_vector(0 downto 0);
  begin
    tb_write_ir(C_IR_IDCODE, "IDCODE", jtag_if, tb_rsp, cfg);
    check_value(tb_rsp.tdo_en_cnt, cfg.ir_width, ERROR, "TCK cycles with tdo_en = 1, IR scan", C_TB_SCOPE);
    tb_scan_dr(x"00000000", v_data, "IDCODE", jtag_if, cfg);
    check_value(tb_rsp.tdo_en_cnt, 32, ERROR, "TCK cycles with tdo_en = 1, 32-bit scan", C_TB_SCOPE);
    tb_write_ir(ir_bypass(cfg), "BYPASS", jtag_if, tb_rsp, cfg);
    tb_scan_dr("1", v_bit, "BYPASS", jtag_if, cfg);
    check_value(tb_rsp.tdo_en_cnt, 1, ERROR, "TCK cycles with tdo_en = 1, 1-bit scan", C_TB_SCOPE);
    tb_idle(4, "Run-Test/Idle", jtag_if, cfg);
    check_value(tb_rsp.tdo_en, '0', ERROR, "tdo_en low in Run-Test/Idle", C_TB_SCOPE);
  end procedure run;

end package body tb_jtag_tdo_en_pkg;
