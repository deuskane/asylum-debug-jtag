-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_trst_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_trst_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-27
-- Last update: 2026-11-27
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario trst : TRST alone (no TCK) with words in both FIFOs : the TAP
--  goes to Test-Logic-Reset (IDCODE selected), the FIFOs keep their words
--  (CONFIG not empty, the TX word read, the RX word delivered)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-27  1.0      mrosiere Created
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

package tb_jtag_axis_trst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_trst_pkg;

package body tb_jtag_axis_trst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
  begin
    tb_req.rx_mode <= RX_NEVER;
    if cfg.tx_enable
    then
      tb_req.tx_target <= 1;
      tb_wait_tx_sent(1, tb_rsp, cfg);
    end if;
    if cfg.rx_enable
    then
      tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
      tb_push(0, true, "before TRST", jtag_if, cfg);
    end if;
    tb_idle(4, jtag_if, cfg);

    jtag_trst(msg => "TRST alone", jtag_if => jtag_if, scope => C_TB_SCOPE, config => cfg.bfm);
    tb_idle(1, jtag_if, cfg);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE selected by TRST", jtag_if, cfg);
    tb_check_config(not to_sl(cfg.tx_enable), not to_sl(cfg.tx_enable), not to_sl(cfg.rx_enable), not to_sl(cfg.rx_enable), "words kept by TRST", jtag_if, cfg);
    if cfg.tx_enable
    then
      tb_write_ir(JTAG_AXIS_IR_TX, "TX", jtag_if, cfg);
      tb_pop(true , 0, "kept by TRST", jtag_if, cfg);
      tb_pop(false, 0, "empty"       , jtag_if, cfg);
    end if;
    if cfg.rx_enable
    then
      tb_req.rx_mode <= RX_ALWAYS;
      tb_wait_rx_cnt(1, tb_rsp, cfg);
    end if;
  end procedure run;

end package body tb_jtag_axis_trst_pkg;
