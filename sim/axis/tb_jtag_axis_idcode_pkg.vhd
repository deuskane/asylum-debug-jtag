-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_idcode_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_idcode_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario idcode : IDCODE selected after the reset, and by an IR scan
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-26  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.jtag_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_axis_bfm_pkg.all;

package tb_jtag_axis_idcode_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_idcode_pkg;

package body tb_jtag_axis_idcode_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
  begin
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE after the reset", jtag_if, cfg);
    tb_write_ir(JTAG_AXIS_IR_CONFIG, "CONFIG", jtag_if, cfg);
    tb_write_ir("00001"            , "IDCODE", jtag_if, cfg);
    tb_check_dr(x"FFFFFFFF", C_IDCODE, "IDCODE selected by an IR scan", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_axis_idcode_pkg;
