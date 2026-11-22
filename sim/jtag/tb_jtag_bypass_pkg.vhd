-------------------------------------------------------------------------------
-- Title      : tb_jtag_bypass_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_bypass_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario bypass of tb_jtag : BYPASS (all ones) : one bit register captured to 0, data delayed by one
--  bit (8-bit, 1-bit and 33-bit scans).
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

package tb_jtag_bypass_pkg is

  -- BYPASS
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_bypass_pkg;

package body tb_jtag_bypass_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    variable v_data      : std_logic_vector(33-1 downto 0);
  begin
    v_data := '1' & x"C3A5F00F";
    tb_write_ir(ir_bypass(cfg), "BYPASS", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"A7", bypass_of(x"A7"), "BYPASS, 8-bit scan", jtag_if, cfg);
    tb_check_dr("1", "0", "BYPASS, 1-bit scan", jtag_if, cfg);
    tb_check_dr("1", "0", "BYPASS captured to 0 again", jtag_if, cfg);
    tb_check_dr(v_data, bypass_of(v_data), "BYPASS, 33-bit scan", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_bypass_pkg;
