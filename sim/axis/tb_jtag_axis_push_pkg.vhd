-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_push_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_push_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario push : the debugger writes min(3, DEPTH_RX) words with RX
--  scans (accepted), the system reads them in order on m_axis (always
--  ready) ; CONFIG flags after
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

package tb_jtag_axis_push_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_push_pkg;

package body tb_jtag_axis_push_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    constant N : natural := minimum(3, cfg.depth_rx);
  begin
    if not cfg.rx_enable
    then
      alert(TB_ERROR, "push needs RX_ENABLE", C_TB_SCOPE);
    end if;
    tb_req.rx_mode <= RX_ALWAYS;
    tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
    for i in 0 to N-1
    loop
      tb_push(i, true, "accepted", jtag_if, cfg);
    end loop;
    tb_wait_rx_cnt(N, tb_rsp, cfg);
    tb_idle(4, jtag_if, cfg);
    tb_check_config('1', not to_sl(cfg.tx_enable), '1', '0', "RX read by the system", jtag_if, cfg);
  end procedure run;

end package body tb_jtag_axis_push_pkg;
