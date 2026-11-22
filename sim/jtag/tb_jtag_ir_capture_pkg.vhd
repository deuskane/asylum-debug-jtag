-------------------------------------------------------------------------------
-- Title      : tb_jtag_ir_capture_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_ir_capture_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario ir_capture of tb_jtag : Capture-IR loads "0...01" : every bit shifted out by an IR scan, whatever
--  the current and the new instruction ; ir_o changes in Update-IR only
--  (monitor).
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

package tb_jtag_ir_capture_pkg is

  -- Capture-IR value
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_ir_capture_pkg;

package body tb_jtag_ir_capture_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    type opcodes_t is array (natural range <>) of natural;
    variable v_opcodes   : opcodes_t(0 to 4);
    variable v_exp       : std_logic_vector(cfg.ir_width-1 downto 0);
  begin
    v_exp     := std_logic_vector(to_unsigned(1, cfg.ir_width));
    v_opcodes := (ir_bypass(cfg), C_IR_TDR_IN, 0, C_IR_UNCLAIMED, C_IR_IDCODE);
    for i in v_opcodes'range loop
      tb_write_ir(v_opcodes(i), "IR scan " & to_string(i), jtag_if, tb_rsp, cfg);
      check_value(tb_rsp.ir_len, cfg.ir_width, ERROR, "Bits shifted out by the IR scan", C_TB_SCOPE);
      check_value(tb_rsp.ir_capture(cfg.ir_width-1 downto 0), v_exp, ERROR, "Capture-IR value", C_TB_SCOPE);
    end loop;
  end procedure run;

end package body tb_jtag_ir_capture_pkg;
