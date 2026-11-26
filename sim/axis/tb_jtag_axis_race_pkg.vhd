-------------------------------------------------------------------------------
-- Title      : tb_jtag_axis_race_pkg
-- Project    : Asylum
-------------------------------------------------------------------------------
-- File       : tb_jtag_axis_race_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-26
-- Last update: 2026-11-26
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario race : a transfer of the system during a scan, after its
--  Capture-DR, is not taken by its Update-DR. TX : the TX FIFO is empty in
--  Capture-DR (valid 0), the system writes a word during the shift : the
--  Update-DR does not remove it, the next scan reads it. RX : the RX FIFO is
--  full in Capture-DR (accepted 0), the system reads its words during the
--  shift : the word of the scan is not written. The scans shift 4 x
--  (DATA_WIDTH + 1) bits, the transfer of the system starts 5 TCK after the
--  start of the scan.
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

package tb_jtag_axis_race_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    );

end package tb_jtag_axis_race_pkg;

package body tb_jtag_axis_race_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tb_req      : out   tb_req_t;
    signal   tb_rsp      : in    tb_rsp_t;
    signal   arst_b      : out   std_logic;
    constant cfg         : in    tb_cfg_t
    ) is
    constant C_LEN    : positive := 4*(cfg.data_width + 1);
    constant C_ZERO   : std_logic_vector(C_LEN-1 downto 0) := (others => '0');
    constant C_DELAY  : time     := 5*cfg.bfm.tck_period;
    variable v_out    : std_logic_vector(C_LEN-1 downto 0);
    variable v_data   : std_logic_vector(C_LEN-1 downto 0);
  begin
    if cfg.tx_enable
    then
      tb_write_ir(JTAG_AXIS_IR_TX, "TX", jtag_if, cfg);
      tb_req.tx_target <= 1 after C_DELAY;
      jtag_scan_dr (data_value   => C_ZERO,
                    data_out     => v_out,
                    msg          => "TX scan, word written during the shift",
                    jtag_if      => jtag_if,
                    scope        => C_TB_SCOPE,
                    config       => cfg.bfm);
      check_value(v_out(cfg.data_width downto 0), C_ZERO(cfg.data_width downto 0), ERROR, "TX : empty in Capture-DR", C_TB_SCOPE);
      check_value(tb_rsp.tx_sent, 1, ERROR, "TX : word written during the scan", C_TB_SCOPE);
      tb_pop(true , 0, "not removed by the Update-DR of the previous scan", jtag_if, cfg);
      tb_pop(false, 0, "empty"                                            , jtag_if, cfg);
    end if;

    if cfg.rx_enable
    then
      tb_req.rx_mode <= RX_NEVER;
      tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
      for i in 0 to cfg.depth_rx-1
      loop
        tb_push(i, true, "fill", jtag_if, cfg);
      end loop;
      tb_req.rx_mode <= RX_ALWAYS after C_DELAY;
      -- Word depth_rx in the bits DATA_WIDTH downto 1 at the end of the scan
      v_data := (others => '0');
      v_data(C_LEN-1 downto C_LEN-cfg.data_width) := rx_word(cfg.depth_rx, cfg.data_width);
      jtag_scan_dr (data_value   => v_data,
                    data_out     => v_out,
                    msg          => "RX scan, words read during the shift",
                    jtag_if      => jtag_if,
                    scope        => C_TB_SCOPE,
                    config       => cfg.bfm);
      check_value(v_out(0), '0', ERROR, "RX : refused in Capture-DR (full)", C_TB_SCOPE);
      tb_wait_rx_cnt(cfg.depth_rx, tb_rsp, cfg);
      wait for 20*cfg.clk_period;
      check_value(tb_rsp.rx_cnt, cfg.depth_rx, ERROR, "RX : the refused word is not written", C_TB_SCOPE);
      tb_idle(4, jtag_if, cfg);
      tb_write_ir(JTAG_AXIS_IR_RX, "RX", jtag_if, cfg);
      tb_push(cfg.depth_rx, true, "written again", jtag_if, cfg);
      tb_wait_rx_cnt(cfg.depth_rx + 1, tb_rsp, cfg);
    end if;
  end procedure run;

end package body tb_jtag_axis_race_pkg;
