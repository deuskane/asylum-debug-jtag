-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_tx_full_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_tx_full_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario tx_full : the system writes DEPTH_TX + 2 words : the TX FIFO
--  is full (s_axis_tready_o = 0, CONFIG TX full), each TX scan frees a
--  place, every word read in order, then empty
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

package tb_jtag_axis_tx_full_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_tx_full_pkg;

package body tb_jtag_axis_tx_full_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    constant D : natural := cfg.depth_tx;
  begin
    if not cfg.tx_enable
    then
      alert(TB_ERROR, "tx_full needs TX_ENABLE", C_TB_SCOPE);
    end if;
    tb_req.tx_target <= D + 2;
    tb_wait_tx_sent(D, tb_rsp, cfg);
    wait for 20*cfg.clk_period;
    check_value(tb_rsp.tx_sent , D  , ERROR, "Words accepted on s_axis while full", C_TB_SCOPE);
    check_value(tb_rsp.s_tready, '0', ERROR, "s_axis_tready_o, TX FIFO full", C_TB_SCOPE);
    tb_idle(4, jtag_if, cfg);
    tb_check_config('0', '1', '1', not to_sl(cfg.rx_enable), "TX full", jtag_if, cfg);
    tb_write_ir(JTAG_AXIS_IR_TX, "TX", jtag_if, cfg);
    tb_pop(true, 0, "frees a place", jtag_if, cfg);
    tb_wait_tx_sent(D + 1, tb_rsp, cfg);
    for i in 1 to D + 1
    loop
      if i = D + 1
      then
        tb_wait_tx_sent(D + 2, tb_rsp, cfg);
        tb_idle(4, jtag_if, cfg);
      end if;
      tb_pop(true, i, "read in order", jtag_if, cfg);
    end loop;
    tb_pop(false, 0, "after the last word", jtag_if, cfg);
    tb_check_config('1', '0', '1', not to_sl(cfg.rx_enable), "TX read", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_axis_tx_full_pkg;
