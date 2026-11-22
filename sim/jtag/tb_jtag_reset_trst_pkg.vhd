-------------------------------------------------------------------------------
-- Title      : tb_jtag_reset_trst_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_reset_trst_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario reset_trst of tb_jtag : TRST* pulse alone (no TCK) : Test-Logic-Reset and IDCODE selected from
--  BYPASS and from a user instruction (with TRST_ENABLE = false : TRST*
--  ignored, the instruction is kept).
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

package tb_jtag_reset_trst_pkg is

  -- TRST* pulse alone
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_reset_trst_pkg;

package body tb_jtag_reset_trst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
    variable v_exp_ir    : natural;
    variable v_data      : std_logic_vector(cfg.tdr_inout_width-1 downto 0);
  begin
    v_data := tdr_pattern(cfg.tdr_inout_width, 1);
    tb_req.tdr_inout_data(cfg.tdr_inout_width-1 downto 0) <= v_data;
    for i in 0 to 1 loop
      if i = 0
      then
        v_exp_ir := ir_bypass(cfg);
      else
        v_exp_ir := C_IR_TDR_INOUT;
      end if;
      tb_write_ir(v_exp_ir, "Instruction before TRST*", jtag_if, tb_rsp, cfg);
      tb_trst_pulse("TRST* alone", jtag_if, cfg);
      if cfg.trst_enable
      then
        v_exp_ir := C_IR_IDCODE;
      end if;
      check_value(tb_rsp.tlr = '1', cfg.trst_enable, ERROR, "tlr_o after TRST* (TRST_ENABLE)", C_TB_SCOPE);
      check_value(to_integer(unsigned(tb_rsp.ir)), v_exp_ir, ERROR, "ir_o after TRST*", C_TB_SCOPE);
      tb_idle(1, "Run-Test/Idle", jtag_if, cfg);
      if cfg.trst_enable
      then
        tb_check_dr(x"00000000", C_IDCODE, "IDCODE selected by TRST*", jtag_if, cfg);
      elsif v_exp_ir = C_IR_TDR_INOUT
      then
        tb_check_dr((v_data'range => '0'), v_data, "jtag_tdr_inout kept (TRST* ignored)", jtag_if, cfg);
      else
        tb_check_dr(x"A5", bypass_of(x"A5"), "BYPASS kept (TRST* ignored)", jtag_if, cfg);
      end if;
    end loop;
  end procedure run;

end package body tb_jtag_reset_trst_pkg;
