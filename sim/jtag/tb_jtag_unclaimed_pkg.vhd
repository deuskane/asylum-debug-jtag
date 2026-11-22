-------------------------------------------------------------------------------
-- Title      : tb_jtag_unclaimed_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_unclaimed_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario unclaimed of tb_jtag : Opcodes claimed neither by the TAP nor by the user decoder select BYPASS :
--  the all-zero opcode (EXTEST in IEEE 1149.1, no boundary scan here), an
--  unclaimed opcode, all ones but the LSB.
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

package tb_jtag_unclaimed_pkg is

  -- Unclaimed opcodes select BYPASS
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_unclaimed_pkg;

package body tb_jtag_unclaimed_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    type opcodes_t is array (natural range <>) of natural;
    variable v_opcodes   : opcodes_t(0 to 2);
  begin
    v_opcodes := (0, C_IR_UNCLAIMED, ir_bypass(cfg)-1);
    for i in v_opcodes'range loop
      tb_write_ir(v_opcodes(i), "Unclaimed opcode " & to_string(v_opcodes(i)), jtag_if, tb_rsp, cfg);
      tb_check_dr(x"5A", bypass_of(x"5A"), "BYPASS selected by the opcode " & to_string(v_opcodes(i)), jtag_if, cfg);
    end loop;
  end procedure run;

end package body tb_jtag_unclaimed_pkg;
