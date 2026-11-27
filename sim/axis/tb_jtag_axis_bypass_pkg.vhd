-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_bypass_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_bypass_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario bypass : unclaimed opcodes (all zeros, all ones, 00101,
--  11110) and the opcode of a disabled direction select BYPASS (one bit,
--  captured to 0)
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

package tb_jtag_axis_bypass_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_bypass_pkg;

package body tb_jtag_axis_bypass_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    type opcodes_t is array (natural range <>) of std_logic_vector(JTAG_AXIS_IR_WIDTH-1 downto 0);
    constant C_UNCLAIMED : opcodes_t := ("00000", "11111", "00101", "11110");
  begin
    for i in C_UNCLAIMED'range
    loop
      tb_write_ir(C_UNCLAIMED(i), "unclaimed " & to_string(C_UNCLAIMED(i)), jtag_if, cfg);
      tb_check_dr(x"A7", bypass_of(x"A7"), "BYPASS, opcode " & to_string(C_UNCLAIMED(i)), jtag_if, cfg);
    end loop;
    if not cfg.tx_enable
    then
      tb_write_ir(JTAG_AXIS_IR_TX, "TX (disabled)", jtag_if, cfg);
      tb_check_dr(x"A7", bypass_of(x"A7"), "BYPASS, TX disabled", jtag_if, cfg);
    end if;
    if not cfg.rx_enable
    then
      tb_write_ir(JTAG_AXIS_IR_RX, "RX (disabled)", jtag_if, cfg);
      tb_check_dr(x"A7", bypass_of(x"A7"), "BYPASS, RX disabled", jtag_if, cfg);
    end if;
  end procedure run;

end package body tb_jtag_axis_bypass_pkg;
