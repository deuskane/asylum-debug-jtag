-------------------------------------------------------------------------------
-- Title      : tb_jtag_idcode_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_idcode_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario idcode of tb_jtag : IDCODE : selected by the power-on reset, selected again by an IR scan,
--  32-bit register (a 64-bit scan returns IDCODE then the shifted-in bits),
--  captured again by each scan.
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

package tb_jtag_idcode_pkg is

  -- IDCODE
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_idcode_pkg;

package body tb_jtag_idcode_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    variable v_data      : std_logic_vector(64-1 downto 0);
  begin
    v_data := x"0123456789ABCDEF";
    check_value(to_integer(unsigned(tb_rsp.ir)), C_IR_IDCODE, ERROR, "ir_o = IDCODE after the power-on reset", C_TB_SCOPE);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE after the power-on reset", jtag_if, cfg);
    tb_write_ir(ir_bypass(cfg), "BYPASS", jtag_if, tb_rsp, cfg);
    tb_write_ir(C_IR_IDCODE   , "IDCODE", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"FFFFFFFF", C_IDCODE, "IDCODE selected by an IR scan", jtag_if, cfg);
    tb_check_dr(v_data, v_data(32-1 downto 0) & C_IDCODE, "64-bit scan : IDCODE, then the shifted-in bits", jtag_if, cfg);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE captured again", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_idcode_pkg;
