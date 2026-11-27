-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_pop_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_pop_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario pop : the system writes min(3, DEPTH_TX) words on s_axis, the
--  debugger reads them in order with TX scans (valid), then the scans
--  return an empty FIFO ; CONFIG flags before and after
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

package tb_jtag_axis_pop_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_pop_pkg;

package body tb_jtag_axis_pop_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    constant N : natural := minimum(3, cfg.depth_tx);
  begin
    if not cfg.tx_enable
    then
      alert(TB_ERROR, "pop needs TX_ENABLE", C_TB_SCOPE);
    end if;
    tb_req.tx_target <= N;
    tb_wait_tx_sent(N, tb_rsp, cfg);
    tb_idle(4, jtag_if, cfg);
    tb_check_config('0', to_sl(N = cfg.depth_tx), '1', not to_sl(cfg.rx_enable), "TX words written", jtag_if, cfg);
    tb_write_ir(JTAG_AXIS_IR_TX, "TX", jtag_if, cfg);
    for i in 0 to N-1
    loop
      tb_pop(true , i, "read in order", jtag_if, cfg);
    end loop;
    tb_pop(false, 0, "after the last word", jtag_if, cfg);
    tb_pop(false, 0, "still empty"        , jtag_if, cfg);
    tb_check_config('1', '0', '1', not to_sl(cfg.rx_enable), "TX read", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_axis_pop_pkg;
