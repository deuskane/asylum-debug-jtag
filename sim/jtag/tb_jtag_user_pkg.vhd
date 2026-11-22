-------------------------------------------------------------------------------
-- Title      : tb_jtag_user_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_user_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Last update: 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario user of tb_jtag : User instruction (user_tdo_en_i = 1 from the decoder of the testbench) :
--  TDO comes from user_tdo_i (held at 1, then at 0), not from BYPASS ;
--  IDCODE and BYPASS selected again afterwards.
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

package tb_jtag_user_pkg is

  -- User instruction : TDO from user_tdo_i
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_user_pkg;

package body tb_jtag_user_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    constant cfg         : in    tb_cfg_t
    ) is
  begin
    tb_write_ir(C_IR_USER, "User instruction", jtag_if, tb_rsp, cfg);
    tb_req.user_tdo <= '1';
    tb_check_dr(x"00", x"FF", "TDO from user_tdo_i = 1", jtag_if, cfg);
    tb_req.user_tdo <= '0';
    tb_check_dr(x"FF", x"00", "TDO from user_tdo_i = 0", jtag_if, cfg);
    tb_req.user_tdo <= '1';
    tb_write_ir(C_IR_IDCODE, "IDCODE", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE after the user instruction", jtag_if, cfg);
    tb_write_ir(ir_bypass(cfg), "BYPASS", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"3C", bypass_of(x"3C"), "BYPASS after the user instruction", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_user_pkg;
