-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_config_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_config_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario config : CONFIG after the reset (DATA_WIDTH, enables, a direction
--  enabled is empty and not full, a disabled one empty and full), read
--  twice
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

package tb_jtag_axis_config_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_config_pkg;

package body tb_jtag_axis_config_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    constant C_TX_FULL : std_logic := not to_sl(cfg.tx_enable);
    constant C_RX_FULL : std_logic := not to_sl(cfg.rx_enable);
  begin
    tb_check_config('1', C_TX_FULL, '1', C_RX_FULL, "after the reset", jtag_if, cfg);
    tb_check_config('1', C_TX_FULL, '1', C_RX_FULL, "read again"     , jtag_if, cfg);
  end procedure run;

end package body tb_jtag_axis_config_pkg;
