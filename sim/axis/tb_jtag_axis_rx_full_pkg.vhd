-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_rx_full_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_rx_full_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario rx_full : the system does not read : DEPTH_RX words
--  accepted, the next one refused (accepted bit 0, CONFIG RX full, word
--  never delivered) ; the system reads them, then the refused word is
--  written again and accepted
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

package tb_jtag_axis_rx_full_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_rx_full_pkg;

package body tb_jtag_axis_rx_full_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    constant D : natural := cfg.depth_rx;
  begin
    if not cfg.rx_enable
    then
      alert(TB_ERROR, "rx_full needs RX_ENABLE", C_TB_SCOPE);
    end if;
    tb_req.rx_mode <= RX_NEVER;
    tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
    for i in 0 to D-1
    loop
      tb_push(i, true, "accepted", jtag_if, cfg);
    end loop;
    tb_push(D, false, "refused, RX FIFO full", jtag_if, cfg);
    tb_check_config('1', not to_sl(cfg.tx_enable), '0', '1', "RX full", jtag_if, cfg);
    check_value(tb_rsp.m_tvalid, '1', ERROR, "m_axis_tvalid_o, words waiting", C_TB_SCOPE);
    tb_req.rx_mode <= RX_ALWAYS;
    tb_wait_rx_cnt(D, tb_rsp, cfg);
    wait for 20*cfg.clk_period;
    check_value(tb_rsp.rx_cnt, D, ERROR, "Words read on m_axis : the refused word is not delivered", C_TB_SCOPE);
    tb_idle(4, jtag_if, cfg);
    tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
    tb_push(D, true, "written again, accepted", jtag_if, cfg);
    tb_wait_rx_cnt(D + 1, tb_rsp, cfg);
  end procedure run;

end package body tb_jtag_axis_rx_full_pkg;
