-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_reset_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_reset_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario reset : words in the FIFOs, then a reset pulse (arst_b_i)
--  empties them : CONFIG empty, no word on m_axis or in a TX scan ; words
--  written after the reset go through
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

package tb_jtag_axis_reset_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_reset_pkg;

package body tb_jtag_axis_reset_pkg is

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
      tb_req.tx_target <= 2;
      tb_wait_tx_sent(2, tb_rsp, cfg);
    end if;
    if cfg.rx_enable
    then
      tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
      tb_push(0, true, "before the reset", jtag_if, cfg);
      tb_push(1, true, "before the reset", jtag_if, cfg);
    end if;
    tb_idle(4, jtag_if, cfg);

    -- Reset pulse (the system model restarts its counters), TAP back to
    -- Run-Test/Idle
    tb_req.tx_target <= 0;
    wait for 2*cfg.clk_period;
    arst_b <= '0';
    wait for 4*cfg.clk_period;
    arst_b <= '1';
    tb_reset("after the reset pulse", jtag_if, cfg);
    wait for 20*cfg.clk_period;
    check_value(tb_rsp.m_tvalid, '0', ERROR, "m_axis_tvalid_o after the reset", C_TB_SCOPE);
    check_value(tb_rsp.s_tready, to_sl(cfg.tx_enable), ERROR, "s_axis_tready_o after the reset", C_TB_SCOPE);
    tb_check_config('1', not to_sl(cfg.tx_enable), '1', not to_sl(cfg.rx_enable), "after the reset", jtag_if, cfg);

    if cfg.tx_enable
    then
      tb_write_ir(JTAG_AXIS_IR_TX, "TX", jtag_if, cfg);
      tb_pop(false, 0, "after the reset", jtag_if, cfg);
      tb_req.tx_target <= 1;
      tb_wait_tx_sent(1, tb_rsp, cfg);
      tb_idle(4, jtag_if, cfg);
      tb_pop(true , 0, "written after the reset", jtag_if, cfg);
    end if;
    if cfg.rx_enable
    then
      tb_req.rx_mode <= RX_ALWAYS;
      tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
      tb_push(0, true, "after the reset", jtag_if, cfg);
      tb_wait_rx_cnt(1, tb_rsp, cfg);
      wait for 20*cfg.clk_period;
      check_value(tb_rsp.rx_cnt, 1, ERROR, "Words read on m_axis after the reset", C_TB_SCOPE);
    end if;
  end procedure run;

end package body tb_jtag_axis_reset_pkg;
