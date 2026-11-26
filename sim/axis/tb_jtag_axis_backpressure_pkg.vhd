-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_backpressure_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_backpressure_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario backpressure : the system holds m_axis_tready_i low : the
--  first word stays on m_axis (tvalid and tdata held, also checked on
--  every cycle by the system model), then random ready : every word read
--  in order
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

package tb_jtag_axis_backpressure_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_backpressure_pkg;

package body tb_jtag_axis_backpressure_pkg is

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
      alert(TB_ERROR, "backpressure needs RX_ENABLE", C_TB_SCOPE);
    end if;
    tb_req.rx_mode <= RX_NEVER;
    tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
    for i in 0 to N-1
    loop
      tb_push(i, true, "accepted", jtag_if, cfg);
    end loop;
    for k in 1 to 3
    loop
      wait for 10*cfg.clk_period;
      check_value(tb_rsp.m_tvalid, '1', ERROR, "m_axis_tvalid_o held", C_TB_SCOPE);
      check_value(tb_rsp.m_tdata(cfg.data_width-1 downto 0), rx_word(0, cfg.data_width), ERROR, "m_axis_tdata_o held", C_TB_SCOPE);
    end loop;
    check_value(tb_rsp.rx_cnt, 0, ERROR, "No word read without m_axis_tready_i", C_TB_SCOPE);
    tb_req.rx_mode <= RX_RANDOM;
    tb_wait_rx_cnt(N, tb_rsp, cfg);
  end procedure run;

end package body tb_jtag_axis_backpressure_pkg;
