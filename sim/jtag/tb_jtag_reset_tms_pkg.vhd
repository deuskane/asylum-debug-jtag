-------------------------------------------------------------------------------
-- Title      : tb_jtag_reset_tms_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_reset_tms_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario reset_tms of tb_jtag : Reset by TMS only (5 TCK with TMS = 1, no TRST*) : Test-Logic-Reset and
--  IDCODE selected from BYPASS, from a user instruction and from an unclaimed
--  opcode.
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

package tb_jtag_reset_tms_pkg is

  -- Reset by TMS only
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_reset_tms_pkg;

package body tb_jtag_reset_tms_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    type opcodes_t is array (natural range <>) of natural;
    variable v_opcodes   : opcodes_t(0 to 2);
  begin
    v_opcodes := (ir_bypass(cfg), C_IR_USER, C_IR_UNCLAIMED);
    for i in v_opcodes'range loop
      tb_write_ir(v_opcodes(i), "Instruction before the TMS reset", jtag_if, tb_rsp, cfg);
      tb_reset(false, "5 TMS = 1, no TRST*", jtag_if, cfg);
      check_value(to_integer(unsigned(tb_rsp.ir)), C_IR_IDCODE, ERROR, "ir_o = IDCODE after the TMS reset", C_TB_SCOPE);
      tb_check_dr(x"00000000", C_IDCODE, "IDCODE selected by the TMS reset", jtag_if, cfg);
    end loop;
  end procedure run;

end package body tb_jtag_reset_tms_pkg;
