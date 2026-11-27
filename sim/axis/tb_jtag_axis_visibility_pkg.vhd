-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_visibility_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_visibility_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-27
-- Last update: 2026-11-27
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario visibility : a transfer of the system made while TCK is stopped
--  is seen by the very next scan, started from Run-Test/Idle with no idle
--  cycle (its Select-DR-Scan and Capture-DR edges are enough for the
--  synchronizers of the FIFOs) : TX, a word written on s_axis is valid in
--  the next TX scan ; RX, a place freed on m_axis (RX FIFO full before) is
--  accepted by the next RX scan
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

package tb_jtag_axis_visibility_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_visibility_pkg;

package body tb_jtag_axis_visibility_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
  begin
    if cfg.tx_enable
    then
      tb_write_ir(JTAG_AXIS_IR_TX, "TX", jtag_if, cfg);
      tb_pop(false, 0, "empty", jtag_if, cfg);
      -- TCK stopped while the system writes
      tb_req.tx_target <= 1;
      tb_wait_tx_sent(1, tb_rsp, cfg);
      wait for 10*cfg.clk_period;
      tb_pop(true , 0, "first scan after the write, no TCK edge before it", jtag_if, cfg);
    end if;

    if cfg.rx_enable
    then
      tb_req.rx_mode <= RX_NEVER;
      tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
      for i in 0 to cfg.depth_rx-1
      loop
        tb_push(i, true, "fill", jtag_if, cfg);
      end loop;
      -- TCK stopped while the system reads
      tb_req.rx_mode <= RX_ALWAYS;
      tb_wait_rx_cnt(cfg.depth_rx, tb_rsp, cfg);
      wait for 10*cfg.clk_period;
      tb_push(cfg.depth_rx, true, "first scan after the reads, no TCK edge before it", jtag_if, cfg);
      tb_wait_rx_cnt(cfg.depth_rx + 1, tb_rsp, cfg);
    end if;
  end procedure run;

end package body tb_jtag_axis_visibility_pkg;
