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
--  Scenario user of tb_jtag : User instructions (user_tdo_en_i = 1 from the decoder of the testbench) :
--  TDO comes from user_tdo_i, the TDO of the TDR selected by the opcode, not
--  from BYPASS ; IDCODE and BYPASS selected again afterwards.
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

  -- User instructions : TDO from user_tdo_i
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
    variable v_in        : std_logic_vector(cfg.tdr_in_width   -1 downto 0);
    variable v_out       : std_logic_vector(cfg.tdr_out_width  -1 downto 0);
    variable v_io        : std_logic_vector(cfg.tdr_inout_width-1 downto 0);
  begin
    v_in  := tdr_pattern(cfg.tdr_in_width   , 3);
    v_out := tdr_pattern(cfg.tdr_out_width  , 5);
    v_io  := tdr_pattern(cfg.tdr_inout_width, 7);
    tb_req.tdr_in_data   (cfg.tdr_in_width   -1 downto 0) <= v_in;
    tb_req.tdr_inout_data(cfg.tdr_inout_width-1 downto 0) <= v_io;
    tb_write_ir(C_IR_TDR_IN   , "jtag_tdr_in"   , jtag_if, tb_rsp, cfg);
    tb_check_dr((v_in'range => '0'), v_in, "TDO from jtag_tdr_in", jtag_if, cfg);
    tb_write_ir(C_IR_TDR_INOUT, "jtag_tdr_inout", jtag_if, tb_rsp, cfg);
    tb_check_dr((v_io'range => '0'), v_io, "TDO from jtag_tdr_inout", jtag_if, cfg);
    tb_write_ir(C_IR_TDR_OUT  , "jtag_tdr_out"  , jtag_if, tb_rsp, cfg);
    tb_check_dr(v_out, (v_out'range => '0'), "TDO from jtag_tdr_out (power-on value)", jtag_if, cfg);
    tb_check_dr((v_out'range => '0'), v_out, "TDO from jtag_tdr_out (bits of the previous scan)", jtag_if, cfg);
    tb_write_ir(C_IR_IDCODE, "IDCODE", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE after the user instructions", jtag_if, cfg);
    tb_write_ir(ir_bypass(cfg), "BYPASS", jtag_if, tb_rsp, cfg);
    tb_check_dr(x"3C", bypass_of(x"3C"), "BYPASS after the user instructions", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_user_pkg;
