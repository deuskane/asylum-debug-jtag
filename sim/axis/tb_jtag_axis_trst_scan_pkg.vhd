-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_trst_scan_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_trst_scan_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-27
-- Last update: 2026-11-27
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario trst_scan : TRST in the middle of a scan, after its Capture-DR :
--  the TAP goes to Test-Logic-Reset, the scan never reaches its Update-DR,
--  so the TX word captured is not removed and the RX word shifted in is not
--  written ; both go through afterwards
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

package tb_jtag_axis_trst_scan_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_trst_scan_pkg;

package body tb_jtag_axis_trst_scan_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    constant C_LEN    : positive := 4*(cfg.data_width + 1);
    constant C_ZERO   : std_logic_vector(C_LEN-1 downto 0) := (others => '0');
    constant C_T      : time     := cfg.bfm.tck_period;
    variable v_out    : std_logic_vector(C_LEN-1 downto 0);
  begin
    if cfg.tx_enable
    then
      tb_req.tx_target <= 1;
      tb_wait_tx_sent(1, tb_rsp, cfg);
      tb_idle(4, jtag_if, cfg);
      tb_write_ir(JTAG_AXIS_IR_TX, "TX", jtag_if, cfg);
      jtag_if.trst_b <= '0' after 6*C_T, '1' after 7*C_T;
      jtag_scan_dr(data_value => C_ZERO, data_out => v_out, msg => "TX scan cut by TRST",
                   jtag_if => jtag_if, scope => C_TB_SCOPE, config => cfg.bfm);
      tb_reset("after TRST", jtag_if, cfg);
      tb_write_ir(JTAG_AXIS_IR_TX, "TX", jtag_if, cfg);
      tb_pop(true , 0, "not removed by the scan cut by TRST", jtag_if, cfg);
      tb_pop(false, 0, "empty"                              , jtag_if, cfg);
    end if;

    if cfg.rx_enable
    then
      tb_req.rx_mode <= RX_ALWAYS;
      tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
      jtag_if.trst_b <= '0' after 6*C_T, '1' after 7*C_T;
      jtag_scan_dr(data_value => rx_word(5, cfg.data_width) & '0' & C_ZERO(C_LEN-cfg.data_width-2 downto 0), data_out => v_out, msg => "RX scan cut by TRST",
                   jtag_if => jtag_if, scope => C_TB_SCOPE, config => cfg.bfm);
      tb_reset("after TRST", jtag_if, cfg);
      wait for 20*cfg.clk_period;
      check_value(tb_rsp.rx_cnt, 0, ERROR, "No word written by the scan cut by TRST", C_TB_SCOPE);
      tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
      tb_push(0, true, "after TRST", jtag_if, cfg);
      tb_wait_rx_cnt(1, tb_rsp, cfg);
    end if;
  end procedure run;

end package body tb_jtag_axis_trst_scan_pkg;
